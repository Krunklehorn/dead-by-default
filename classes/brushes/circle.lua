local ffi = require "ffi"

ffi.cdef[[
	typedef struct _CircleBrush {
		CircleCollider;
		Brush;
	} CircleBrush;
]]

CircleBrush = {
	new = ffi.typeof("CircleBrush")
}

function CircleBrush:__call(params)
	if ffi.istype("CircleBrush", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "CircleBrush:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "CircleBrush:__call", true)
	local radius = utils.checkArg("radius", params[3] or params.radius, "number", "CircleBrush:__call", true)
	local height = utils.checkArg("height", params[4] or params.height, "number", "CircleBrush:__call", true)
	local color = utils.checkArg("color", params[5] or params.color, "vec3", "CircleBrush:__call", true)

	pos = pos or vec2()
	vel = vel or vec2()
	radius = radius or 0
	height = height or 0
	color = color or vec3()

	return CircleBrush.new(OBJ_ID_BASE, pos, vel, radius, height, color)
end

function CircleBrush:__index(key)
	if key == "ppos" then return self.pos - self.vel * stopwatch.ticklength
	elseif key == "copy" then return CircleBrush.new(self)
	else return rawget(CircleBrush, key) end
end

function CircleBrush:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos")

	if self == CircleBrush then rawset(CircleBrush, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'CircleBrush': %q", key, value) end
end

function CircleBrush:__tostring()
	if self == CircleBrush then return string.format("Class 'CircleBrush' (%s)", CircleBrush.string)
	else return string.format("Instance of 'CircleBrush' (%s)", utils.addrString(self)) end
end

function CircleBrush:setID(id) self.id = utils.checkArg("id", id, "ID", "CircleBrush:setID") end
function CircleBrush:instanceOf(class) return class == CircleBrush end

function CircleBrush:payload(ptr, index, camera, scale)
	local pos = camera:toScreen(self.pos)

	ptr[index + 0] = pos.x
	ptr[index + 1] = pos.y
	ptr[index + 2] = self.radius * scale
end

CircleBrush.draw = CircleCollider.draw
CircleBrush.getCastBounds = CircleCollider.getCastBounds
CircleBrush.pick = CircleCollider.pick
CircleBrush.overlap = CircleCollider.overlap
CircleBrush.cast = CircleCollider.cast
CircleBrush.circ_contact = CircleCollider.circ_contact
CircleBrush.box_contact = CircleCollider.box_contact
CircleBrush.line_contact = CircleCollider.line_contact

setmetatable(CircleBrush, CircleBrush)
ffi.metatype("CircleBrush", CircleBrush)
