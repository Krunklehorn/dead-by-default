local ffi = require "ffi"

ffi.cdef[[
	typedef struct _BoxBrush {
		BoxCollider;
		Brush;
	} BoxBrush;
]]

BoxBrush = {
	new = ffi.typeof("BoxBrush")
}

function BoxBrush:__call(params)
	if ffi.istype("BoxBrush", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "BoxBrush:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "BoxBrush:__call", true)
	local radius = utils.checkArg("radius", params[3] or params.radius, "number", "BoxBrush:__call", true)
	local angle = utils.checkArg("angle", params[4] or params.angle, "number", "BoxBrush:__call", true)
	local forward = utils.checkArg("forward", params.forward, "vec2", "BoxBrush:__call", true)
	local right = utils.checkArg("right", params.right, "vec2", "BoxBrush:__call", true)
	local hwidth = utils.checkArg("hwidth", params[5] or params.hwidth, "number", "BoxBrush:__call", true)
	local hlength = utils.checkArg("hlength", params[6] or params.hlength, "number", "BoxBrush:__call", true)
	local height = utils.checkArg("height", params[7] or params.height, "number", "BoxBrush:__call", true)
	local color = utils.checkArg("color", params[8] or params.color, "vec3", "BoxBrush:__call", true)

	if forward and (right or angle) or (right and angle) then
		utils.formatError("BoxBrush constructor can only be called with one 'angle', 'forward' or 'right' argument exclusively: %q, %q, %q", angle, forward, right) end

	if not hwidth and not hlength then
		utils.formatError("BoxBrush constructor cannot be called without an 'hwidth' or 'hlength' argument: %q, %q", hwidth, hlength) end

	pos = pos or vec2()
	vel = vel or vec2()
	radius = radius or 0
	angle = angle or (right and math.atan2(right.y, right.x)) or (forward and math.atan2(forward.x, -forward.y)) or 0
	hwidth = hwidth or hlength
	hlength = hlength or hwidth
	height = height or 0
	color = color or vec3()

	return BoxBrush.new(OBJ_ID_BASE, pos, vel, radius, angle, hwidth, hlength, height, color)
end

function BoxBrush:__index(key)
	if key == "ppos" then return self.pos - self.vel * stopwatch.ticklength
	elseif key == "p1" then return self.pos + vec2(self.hwidth, self.hlength)
	elseif key == "p2" then return self.pos + vec2(self.hwidth, -self.hlength)
	elseif key == "p3" then return self.pos + vec2(-self.hwidth, -self.hlength)
	elseif key == "p4" then return self.pos + vec2(-self.hwidth, self.hlength)
	elseif key == "pp1" then return self.ppos + vec2(self.hwidth, self.hlength)
	elseif key == "pp2" then return self.ppos + vec2(self.hwidth, -self.hlength)
	elseif key == "pp3" then return self.ppos + vec2(-self.hwidth, -self.hlength)
	elseif key == "pp4" then return self.ppos + vec2(-self.hwidth, self.hlength)
	elseif key == "forward" then return vec2(math.sin(self.angle), -math.cos(self.angle))
	elseif key == "right" then return vec2(math.cos(self.angle), math.sin(self.angle))
	elseif key == "bow" then return vec2(math.sin(self.angle), -math.cos(self.angle)) * self.hlength
	elseif key == "star" then return vec2(math.cos(self.angle), math.sin(self.angle)) * self.hwidth
	elseif key == "hdims" then return vec2(self.hwidth, self.hlength)
	elseif key == "copy" then return BoxBrush.new(self)
	else return rawget(BoxBrush, key) end
end

function BoxBrush:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos", "p1", "p2", "p3", "p4", "pp1", "pp2", "pp3", "pp4", "hdims")

	if key == "forward" then self.angle = math.atan2(value.x, -value.y)
	elseif key == "right" then self.angle = math.atan2(value.y, value.x)
	elseif key == "bow" then
		self.hlength = value.length
		self.angle = math.atan2(value.x, -value.y)
	elseif key == "star" then
		self.hwidth = value.length
		self.angle = math.atan2(value.y, value.x)
	elseif self == BoxBrush then rawset(BoxBrush, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'BoxBrush': %q", key, value) end
end

function BoxBrush:__tostring()
	if self == BoxBrush then return string.format("Class 'BoxBrush' (%s)", BoxBrush.string)
	else return string.format("Instance of 'BoxBrush' (%s)", utils.addrString(self)) end
end

function BoxBrush:setID(id) self.id = utils.checkArg("id", id, "ID", "BoxBrush:setID") end
function BoxBrush:instanceOf(class) return class == BoxBrush end

function BoxBrush:payload(ptr, index, camera, scale)
	local pos = camera:toScreen(self.pos)
	local hdims = self.hdims:scaled(scale)
	local angle = -(self.angle - camera.angle)

	ptr[index + 0] = pos.x
	ptr[index + 1] = pos.y
	ptr[index + 2] = hdims.x
	ptr[index + 3] = hdims.y
	ptr[index + 4] = math.cos(angle)
	ptr[index + 5] = math.sin(angle)
	ptr[index + 6] = self.radius * scale
end

BoxBrush.draw = BoxCollider.draw
BoxBrush.getCastBounds = BoxCollider.getCastBounds
BoxBrush.pick = BoxCollider.pick
BoxBrush.overlap = BoxCollider.overlap

setmetatable(BoxBrush, BoxBrush)
ffi.metatype("BoxBrush", BoxBrush)
