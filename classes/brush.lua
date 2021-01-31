local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Brush {
		double height;
		const char* color;
	} Brush;
]]

Brush = {
	uniform_circles_pos_radius = {},
	uniform_boxes_pos_hdims = {},
	uniform_boxes_invrot = {},
	uniform_boxes_radius = {},
	uniform_lines_pos_delta = {},
	uniform_lines_length2_radius = {}
}

for i = 0, SDF_MAX_BRUSHES - 1 do
	Brush.uniform_circles_pos_radius[i] = string.format("circles[%s].pos_radius", i)
	Brush.uniform_boxes_pos_hdims[i] = string.format("boxes[%s].pos_hdims", i)
	Brush.uniform_boxes_invrot[i] = string.format("boxes[%s].invrot", i)
	Brush.uniform_boxes_radius[i] = string.format("boxes[%s].radius", i)
	Brush.uniform_lines_pos_delta[i] = string.format("lines[%s].pos_delta", i)
	Brush.uniform_lines_length2_radius[i] = string.format("lines[%s].length2_radius", i)
end

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
			utils.send(sdfShader, "line_width", LINE_WIDTH)

			local camera = humpstate.current().camera
			local scale = camera:getNormalizedScale()

			--TODO: ffi data objects may yield better performance: utils.send(sdfShader, name, data, offset, size)
			--TODO: why didn't double buffering work properly?

			local nCircles, nBoxes, nLines, nLights = 0, 0, 0, 0

			for b = 1, #brushes do
				local brush = brushes[b]
				local next = brushes[b + 1]

				if nCircles >= SDF_MAX_BRUSHES or nBoxes >= SDF_MAX_BRUSHES or nLines >= SDF_MAX_BRUSHES or nLights >= SDF_MAX_LIGHTS then
					utils.formatError("Brush.batchSDF() exceeded a maximum for one or more payloads: %s, %s, %s", nCircles, nBoxes, nLines, nLights) end

				if brush:instanceOf(CircleBrush) then
					local pos = camera:toScreen(brush.pos)

					utils.send(sdfShader, Brush.uniform_circles_pos_radius[nCircles], { pos.x, pos.y, brush.radius * scale })
					nCircles = nCircles + 1
				elseif brush:instanceOf(BoxBrush) then
					local pos = camera:toScreen(brush.pos)
					local hdims = brush.hdims:scaled(scale)

					utils.send(sdfShader, Brush.uniform_boxes_pos_hdims[nBoxes], { pos.x, pos.y, hdims.x, hdims.y })
					utils.send(sdfShader, Brush.uniform_boxes_invrot[nBoxes], utils.glslRotator(camera.angle - brush.angle))
					utils.send(sdfShader, Brush.uniform_boxes_radius[nBoxes], brush.radius * scale)
					nBoxes = nBoxes + 1
				elseif brush:instanceOf(LineBrush) then
					local pos = camera:toScreen(brush.p1)
					local delta = brush.delta:scaled(scale):rotated(-camera.angle)

					utils.send(sdfShader, Brush.uniform_lines_pos_delta[nLines], { pos.x, pos.y, delta.x, delta.y })
					utils.send(sdfShader, Brush.uniform_lines_length2_radius[nLines], { delta.x * delta.x + delta.y * delta.y, brush.radius * scale })
					nLines = nLines + 1
				end

				if next == nil or next.height > brush.height then
					for e = 1, #entities do
						local entity = entities[e]

						if entity:instanceOf(Light) and entity.pos.z == brush.height then
							local pos = camera:toScreen(entity.pos.xy)
							local color = Light.applyLuminance(entity.color, entity.intensity)

							utils.send(sdfShader, Light.uniform_lights_pos_range_radius[nLights], { pos.x, pos.y, entity.range * scale, entity.radius * scale })
							utils.send(sdfShader, Light.uniform_lights_color[nLights], { color.x, color.y, color.z, 1 }) -- Alpha unused, handled by shader
							nLights = nLights + 1
						end
					end

					utils.send(sdfShader, "canvas", SDF_CANVAS)
					utils.send(sdfShader, "height", brush.height)

					utils.send(sdfShader, "nCircles", nCircles)
					utils.send(sdfShader, "nBoxes", nBoxes)
					utils.send(sdfShader, "nLines", nLines)
					utils.send(sdfShader, "nLights", nLights)

					-- Single buffer
					lg.draw(SDF_UNITPLANE)
					lg.setCanvas()
					lg.setCanvas(SDF_CANVAS)

					nCircles, nBoxes, nLines, nLights = 0, 0, 0, 0

					if humpstate.current() == editState then
						if editState.selection then
							lg.setBlendMode("alpha")
							editState.selection:draw("selection")
							lg.setBlendMode("replace")
						end
					end
				end
			end
		lg.setCanvas()
		lg.setShader(noiseShader)
			lg.origin()
			lg.setBlendMode("alpha")
			utils.send(noiseShader, "realtime", stopwatch.realtime)
			lg.draw(SDF_CANVAS)
		lg.setShader()
	lg.pop()
end

require "classes.brushes.circle"
require "classes.brushes.box"
require "classes.brushes.line"
