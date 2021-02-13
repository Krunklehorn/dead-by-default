local ffi = require "ffi"

ffi.cdef[[
	typedef struct _LineBrush {
		LineCollider;
		Brush;
	} LineBrush;
]]

LineBrush = {
	new = ffi.typeof("LineBrush")
}

function LineBrush:__call(params)
	if ffi.istype("LineBrush", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local p1 = utils.checkArg("p1", params[1] or params.p1, "vec2", "LineBrush:__call", true)
	local p2 = utils.checkArg("p2", params[2] or params.p2, "vec2", "LineBrush:__call", true)
	local vel = utils.checkArg("vel", params[3] or params.vel, "vec2", "LineBrush:__call", true)
	local radius = utils.checkArg("radius", params[4] or params.radius, "number", "LineBrush:__call", true)
	local height = utils.checkArg("height", params[5] or params.height, "number", "LineBrush:__call", true)
	local color = utils.checkArg("color", params[5] or params.color, "vec3", "LineBrush:__call", true)

	p1 = p1 or vec2()
	p2 = p2 or vec2()
	vel = vel or vec2()
	radius = radius or 0
	height = height or 0
	color = color or vec3()

	return LineBrush.new(OBJ_ID_BASE, p1, p2, vel, radius, height, color)
end

function LineBrush:__index(key)
	if key == "pp1" then return self.p1 - self.vel * stopwatch.ticklength
	elseif key == "pp2" then return self.p2 - self.vel * stopwatch.ticklength
	elseif key == "delta" then return self.p2 - self.p1
	elseif key == "direction" then return self.delta.normalized
	elseif key == "normal" then return self.delta.normal
	elseif key == "copy" then return LineBrush.new(self)
	else return rawget(LineBrush, key) end
end

function LineBrush:__newindex(key, value)
	utils.readOnly(tostring(self), key, "pp1", "pp2", "delta", "direction", "normal")

	if self == LineBrush then rawset(LineBrush, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'LineBrush': %q", key, value) end
end

function LineBrush:__tostring()
	if self == LineBrush then return string.format("Class 'LineBrush' (%s)", LineBrush.string)
	else return string.format("Instance of 'LineBrush' (%s)", utils.addrString(self)) end
end

function LineBrush:setID(id) self.id = utils.checkArg("id", id, "ID", "LineBrush:setID") end
function LineBrush:instanceOf(class) return class == LineBrush end

function LineBrush:payload(ptr, index, camera, scale)
	local pos = camera:toScreen(self.p1)
	local delta = self.delta
	local angle = -(delta.angle - camera.angle)

	ptr[index + 0] = pos.x
	ptr[index + 1] = pos.y
	ptr[index + 2] = math.cos(angle)
	ptr[index + 3] = math.sin(angle)
	ptr[index + 4] = delta.length * scale
	ptr[index + 5] = self.radius * scale
end

LineBrush.draw = LineCollider.draw
LineBrush.getCastBounds = LineCollider.getCastBounds
LineBrush.pick = LineCollider.pick
LineBrush.overlap = LineCollider.overlap
LineBrush.point_determinant = LineCollider.point_determinant
LineBrush.line_contact = LineCollider.line_contact

setmetatable(LineBrush, LineBrush)
ffi.metatype("LineBrush", LineBrush)
