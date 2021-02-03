local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Brush {
		double height;
		const char* color;
	} Brush;
]]

Brush = {}

--[[local circles_pos_radius = {},
local boxes_pos_hdims = {},
local boxes_cosa_sina_radius = {},
local lines_pos_delta = {},
local lines_length2_radius = {}
local lights_pos_range_radius = {},
local lights_color = {}

for i = 0, SDF_MAX_BRUSHES - 1 do
	circles_pos_radius[i] = string.format("circles[%s].pos_radius", i)
	boxes_pos_hdims[i] = string.format("boxes[%s].pos_hdims", i)
	boxes_cosa_sina_radius[i] = string.format("boxes[%s].cosa_sina_radius", i)
	lines_pos_delta[i] = string.format("lines[%s].pos_delta", i)
	lines_length2_radius[i] = string.format("lines[%s].length2_radius", i)
end

for i = 0, SDF_MAX_LIGHTS - 1 do
	lights_pos_range_radius[i] = string.format("lights[%s].pos_range_radius", i)
	lights_color[i] = string.format("lights[%s].color", i)
end]]

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
	local sdfShader = stache.shaders.sdf
	local noiseShader = stache.shaders.noise

	lg.push("all")
		lg.setCanvas(SDF_CANVAS)
		lg.setShader(sdfShader)
			lg.clear()
			lg.setBlendMode("replace")
			utils.send(sdfShader, "LUMINANCE", LUMINANCE)
			utils.send(sdfShader, "DEBUG_CLIPPING", DEBUG_DRAW and DEBUG_CLIPPING)
			utils.send(sdfShader, "LINE_WIDTH", LINE_WIDTH)
			utils.send(sdfShader, "realtime", stopwatch.realtime)

			local camera = humpstate.current().camera
			local scale = camera:getNormalizedScale()
			local nCircles, nBoxes, nLines, nLights = 0, 0, 0, 0

			for b = 1, #brushes do
				local brush = brushes[b]
				local next = brushes[b + 1]

				if nCircles >= SDF_MAX_BRUSHES or nBoxes >= SDF_MAX_BRUSHES or nLines >= SDF_MAX_BRUSHES then
					utils.formatError("Brush.batchSDF() attempted to exceed a maximum for one or more SDF payloads: %s, %s, %s", nCircles, nBoxes, nLines) end

				if brush:instanceOf(CircleBrush) then
					local pos = camera:toScreen(brush.pos)

					circles_floatptr[nCircles * 4 + 0] = pos.x
					circles_floatptr[nCircles * 4 + 1] = pos.y
					circles_floatptr[nCircles * 4 + 2] = brush.radius * scale
					--circles_floatptr[nCircles * 4 + 3] = 0

					--utils.send(sdfShader, circles_pos_radius[nCircles], { pos.x, pos.y, brush.radius * scale })
					nCircles = nCircles + 1
				elseif brush:instanceOf(BoxBrush) then
					local pos = camera:toScreen(brush.pos)
					local hdims = brush.hdims:scaled(scale)
					local angle = -(brush.angle - camera.angle)

					boxes_floatptr[nBoxes * 8 + 0] = pos.x
					boxes_floatptr[nBoxes * 8 + 1] = pos.y
					boxes_floatptr[nBoxes * 8 + 2] = hdims.x
					boxes_floatptr[nBoxes * 8 + 3] = hdims.y
					boxes_floatptr[nBoxes * 8 + 4] = math.cos(angle)
					boxes_floatptr[nBoxes * 8 + 5] = math.sin(angle)
					boxes_floatptr[nBoxes * 8 + 6] = brush.radius * scale
					--boxes_floatptr[nBoxes * 8 + 7] = 0

					--utils.send(sdfShader, boxes_pos_hdims[nBoxes], { pos.x, pos.y, hdims.x, hdims.y })
					--utils.send(sdfShader, boxes_cosa_sina_radius[nBoxes], { math.cos(angle), math.sin(angle), brush.radius * scale })
					nBoxes = nBoxes + 1
				elseif brush:instanceOf(LineBrush) then
					local pos = camera:toScreen(brush.p1)
					local delta = brush.delta:scaled(scale):rotated(-camera.angle)

					lines_floatptr[nLines * 8 + 0] = pos.x
					lines_floatptr[nLines * 8 + 1] = pos.y
					lines_floatptr[nLines * 8 + 2] = delta.x
					lines_floatptr[nLines * 8 + 3] = delta.y
					lines_floatptr[nLines * 8 + 4] = delta.x * delta.x + delta.y * delta.y
					lines_floatptr[nLines * 8 + 5] = brush.radius * scale
					--lines_floatptr[nLines * 8 + 6] = 0
					--lines_floatptr[nLines * 8 + 7] = 0

					--utils.send(sdfShader, lines_pos_delta[nLines], { pos.x, pos.y, delta.x, delta.y })
					--utils.send(sdfShader, lines_length2_radius[nLines], { delta.x * delta.x + delta.y * delta.y, brush.radius * scale })
					nLines = nLines + 1
				end

				if next == nil or next.height > brush.height then
					for e = 1, #entities do
						local entity = entities[e]

						if nLights >= SDF_MAX_LIGHTS then
							utils.formatError("Brush.batchSDF() attempted to exceed the maximum light count: %s", nLights) end

						if entity:instanceOf(Light) and entity.pos.z == brush.height then
							local pos = camera:toScreen(entity.pos.xy)

							lights_floatptr[nLights * 8 + 0] = pos.x
							lights_floatptr[nLights * 8 + 1] = pos.y
							lights_floatptr[nLights * 8 + 2] = entity.range * scale
							lights_floatptr[nLights * 8 + 3] = entity.radius * scale
							lights_floatptr[nLights * 8 + 4] = entity.color.x
							lights_floatptr[nLights * 8 + 5] = entity.color.y
							lights_floatptr[nLights * 8 + 6] = entity.color.z
							lights_floatptr[nLights * 8 + 7] = entity.intensity

							--utils.send(sdfShader, lights_pos_range_radius[nLights], { pos.x, pos.y, entity.range * scale, entity.radius * scale })
							--utils.send(sdfShader, lights_color[nLights], { entity.color.x, entity.color.y, entity.color.z, entity.intensity })
							nLights = nLights + 1
						end
					end

					utils.send(sdfShader, "canvas", SDF_CANVAS)
					utils.send(sdfShader, "height", brush.height)

					if nCircles > 0 then sdfShader:send("circles", circles_data, 0, nCircles * 4 * 4) end
					if nBoxes > 0 then sdfShader:send("boxes", boxes_data, 0, nBoxes * 4 * 8) end
					if nLines > 0 then sdfShader:send("lines", lines_data, 0, nLines * 4 * 8) end
					if nLights > 0 then sdfShader:send("lights", lights_data, 0, nLights * 4 * 8) end

					utils.send(sdfShader, "nCircles", nCircles)
					utils.send(sdfShader, "nBoxes", nBoxes * 2)
					utils.send(sdfShader, "nLines", nLines * 2)
					utils.send(sdfShader, "nLights", nLights * 2)

					-- Single buffer
					lg.draw(SDF_UNITPLANE)
					lg.setCanvas()
					lg.setCanvas(SDF_CANVAS)

					nCircles, nBoxes, nLines, nLights = 0, 0, 0, 0

					lg.setBlendMode("alpha")
					if humpstate.current() == editState then
						for o = 1, #editState.selection do
							local obj = editState.selection[o]

							if (Brush.isBrush(obj) and obj.height == brush.height) or
							   (Entity.isEntity(obj) and obj.pos.z == brush.height) then
								obj:draw("selection") end
						end
					end
					lg.setBlendMode("replace")
				end
			end
		lg.setCanvas()
		lg.setShader()

		lg.origin()
		lg.setBlendMode("alpha")
		lg.draw(SDF_CANVAS)
	lg.pop()
end

require "classes.brushes.circle"
require "classes.brushes.box"
require "classes.brushes.line"
