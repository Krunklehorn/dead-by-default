local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Brush {
		double height;
		vec3 color;
	} Brush;
]]

Brush = {}

local function stencilFunc()
	local w, h = lg.getDimensions()
	local hw = w / 2
	local hyp = math.sqrt(2 * (hw * hw))

	lg.push("all")
		lg.origin()

		lg.push("all")
			lg.translate(0, h - hw)
			lg.rotate(math.rad(45))
			lg.rectangle("fill", 0, 0, hyp, hyp / 2)
		lg.pop()

		lg.translate(w, h - hw)
		lg.rotate(-math.rad(45))
		lg.rectangle("fill", 0, 0, -hyp, hyp / 2)
	lg.pop()
end

local circles_data = ld.newByteData(SDF_MAX_BRUSHES * 4 * 4)
local boxes_data = ld.newByteData(SDF_MAX_BRUSHES * 4 * 8)
local lines_data = ld.newByteData(SDF_MAX_BRUSHES * 4 * 8)
local lights_data = ld.newByteData(SDF_MAX_LIGHTS * 4 * 8)

local circles_floatptr = ffi.cast("float*", circles_data:getFFIPointer())
local boxes_floatptr = ffi.cast("float*", boxes_data:getFFIPointer())
local lines_floatptr = ffi.cast("float*", lines_data:getFFIPointer())
local lights_floatptr = ffi.cast("float*", lights_data:getFFIPointer())

function Brush.isBrush(obj)
	return ffi.istype("CircleBrush", obj) or
		   ffi.istype("BoxBrush", obj) or
		   ffi.istype("LineBrush", obj)
end

function Brush.batchSDF(brushes, entities)
	local lightShader = stache.shaders.light
	local shapeShader = stache.shaders.shape
	local camera = humpstate.current().camera
	local scale = camera:getNormalizedScale()

	SDF_FRONT:renderTo(lg.clear)
	SDF_BACK:renderTo(lg.clear)

	lg.push("all")
		if humpstate.current() ~= editState then
			lg.setCanvas{SDF_LIGHT, depthstencil = SDF_STENCIL}
			--lg.stencil(stencilFunc, "replace", 1)
		end

		local nCircles, nBoxes, nLines, nLights = 0, 0, 0, 0

		for b = 1, #brushes do
			local brush = brushes[b]
			local next = brushes[b + 1]

			if nCircles >= SDF_MAX_BRUSHES or nBoxes >= SDF_MAX_BRUSHES or nLines >= SDF_MAX_BRUSHES then
				utils.formatError("Brush.batchSDF() attempted to exceed a maximum for one or more SDF payloads: %q, %q, %q", nCircles, nBoxes, nLines) end

			if brush:instanceOf(CircleBrush) then
				brush:payload(circles_floatptr, nCircles * 4, camera, scale)
				nCircles = nCircles + 1
			elseif brush:instanceOf(BoxBrush) then
				brush:payload(boxes_floatptr, nBoxes * 8, camera, scale)
				nBoxes = nBoxes + 1
			elseif brush:instanceOf(LineBrush) then
				brush:payload(lines_floatptr, nLines * 8, camera, scale)
				nLines = nLines + 1
			end

			if next == nil or next.height > brush.height then
				local decals = {}

				for e = 1, #entities do
					local entity = entities[e]

					if nLights >= SDF_MAX_LIGHTS then
						utils.formatError("Brush.batchSDF() attempted to exceed the maximum light count: %q", nLights) end

					if entity.pos.z == brush.height then
						if entity:instanceOf(Decal) then
							decals[#decals + 1] = entity
						elseif entity:instanceOf(Light) then
							entity:payload(lights_floatptr, nLights * 8, camera, scale)
							nLights = nLights + 1
						end
					end
				end

				if #decals > 0 then
					if humpstate.current() == editState then
						lg.setCanvas(Decal.canvas)
					else
						lg.setCanvas{Decal.canvas, depthstencil = SDF_STENCIL}
						lg.setStencilTest("equal", 0)
					end

					lg.setShader()
					lg.setBlendMode("alpha")

					for d = 1, #decals do
						local decal = decals[d]
						local texture = Decal.textures[decal.tex]
						local cx, cy = texture:getWidth() / 2, texture:getHeight() / 2

						lg.push("all")
							stache.setColor(decal.color.table, decal.alpha)
							texture:setWrap("repeat", "repeat")
							lg.draw(texture, Decal.quads[decal.id], decal.pos.x, decal.pos.y, decal.angle, decal.hwidth / cx, decal.hlength / cy, cx, cy)
						lg.pop()
					end
				end

				lg.setBlendMode("replace")

				if nLights > 0 then
					if humpstate.current() == editState then
						lg.setCanvas(SDF_LIGHT)
					else
						lg.setCanvas{SDF_LIGHT, depthstencil = SDF_STENCIL}
						lg.setStencilTest("equal", 0)
					end

					lg.setShader(lightShader)

					utils.send(lightShader, "LINE_WIDTH", LINE_WIDTH)
					utils.send(lightShader, "LUMINANCE", LUMINANCE)
					utils.send(lightShader, "VISIBILITY", humpstate.current() ~= editState and VISIBILITY or false)
					utils.send(lightShader, "DEBUG_CLIPPING", DEBUG_DRAW and DEBUG_CLIPPING)
					utils.send(lightShader, "scale", scale)

					if nCircles > 0 then lightShader:send("circles", circles_data, 0, nCircles * 4 * 4) end
					if nBoxes > 0 then lightShader:send("boxes", boxes_data, 0, nBoxes * 4 * 8) end
					if nLines > 0 then lightShader:send("lines", lines_data, 0, nLines * 4 * 8) end
					if nLights > 0 then lightShader:send("lights", lights_data, 0, nLights * 4 * 8) end

					utils.send(lightShader, "nCircles", nCircles)
					utils.send(lightShader, "nBoxes", nBoxes * 2)
					utils.send(lightShader, "nLines", nLines * 2)
					utils.send(lightShader, "nLights", nLights * 2)

					lg.draw(SDF_UNITPLANE)
					lg.setStencilTest()

					nLights = 0
				end

				if nCircles > 0 or nBoxes > 0 or nLines > 0 then
					lg.setCanvas(SDF_BACK)
					lg.setShader(shapeShader)

					utils.send(shapeShader, "LINE_WIDTH", LINE_WIDTH)
					utils.send(shapeShader, "front", SDF_FRONT)
					utils.send(shapeShader, "lighting", SDF_LIGHT)
					utils.send(shapeShader, "decals", Decal.canvas)
					utils.send(shapeShader, "height", brush.height)

					if nCircles > 0 then shapeShader:send("circles", circles_data, 0, nCircles * 4 * 4) end
					if nBoxes > 0 then shapeShader:send("boxes", boxes_data, 0, nBoxes * 4 * 8) end
					if nLines > 0 then shapeShader:send("lines", lines_data, 0, nLines * 4 * 8) end

					utils.send(shapeShader, "nCircles", nCircles)
					utils.send(shapeShader, "nBoxes", nBoxes * 2)
					utils.send(shapeShader, "nLines", nLines * 2)

					lg.draw(SDF_UNITPLANE)

					nCircles, nBoxes, nLines = 0, 0, 0
				end

				if humpstate.current() == editState then
					lg.setBlendMode("alpha")

					for o = 1, #editState.selection do
						local obj = editState.selection[o]

						if (Brush.isBrush(obj) and obj.height == brush.height) or
						   (Entity.isEntity(obj) and obj.pos.z == brush.height) then
							obj:draw("selection") end
					end

					lg.setBlendMode("replace")
				end

				SDF_BACK, SDF_FRONT = SDF_FRONT, SDF_BACK
				Decal.canvas:renderTo(lg.clear)
				SDF_LIGHT:renderTo(lg.clear)
			end
		end

		lg.setCanvas()
		lg.setShader()

		lg.origin()
		lg.setStencilTest()
		lg.setBlendMode("alpha", "premultiplied")
		lg.draw(SDF_FRONT)
	lg.pop()
end

require "classes.brushes.circle"
require "classes.brushes.box"
require "classes.brushes.line"
