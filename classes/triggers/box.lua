local ffi = require "ffi"
local voidptr = ffi.new("void*")

ffi.cdef[[
	typedef struct _BoxTrigger {
		BoxCollider;
		Trigger;
	} BoxTrigger;
]]

BoxTrigger = {
	new = ffi.typeof("BoxTrigger"),
	callbacks = {}
}

function BoxTrigger.__new(obj, ...)
	local obj = ffi.new("BoxTrigger", ...)

	if obj.onOverlap ~= voidptr then
		local addr = utils.addr(obj.onOverlap)

		if not BoxTrigger.callbacks[addr] then BoxTrigger.callbacks[addr] = 1
		else BoxTrigger.callbacks[addr] = BoxTrigger.callbacks[addr] + 1 end
	end

	return obj
end

function BoxTrigger:__call(params)
	if ffi.istype("BoxTrigger", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "BoxTrigger:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "BoxTrigger:__call", true)
	local radius = utils.checkArg("radius", params[3] or params.radius, "number", "BoxTrigger:__call", true)
	local angle = utils.checkArg("angle", params[4] or params.angle, "number", "BoxTrigger:__call", true)
	local forward = utils.checkArg("forward", params.forward, "vec2", "BoxTrigger:__call", true)
	local right = utils.checkArg("right", params.right, "vec2", "BoxTrigger:__call", true)
	local hwidth = utils.checkArg("hwidth", params[5] or params.hwidth, "number", "BoxTrigger:__call", true)
	local hlength = utils.checkArg("hlength", params[6] or params.hlength, "number", "BoxTrigger:__call", true)
	local height = utils.checkArg("height", params[7] or params.height, "number", "BoxTrigger:__call", true)
	local onOverlap = utils.checkArg("onOverlap", params[8] or params.onOverlap, "function", "Trigger:__call", true)

	if forward and (right or angle) or (right and angle) then
		utils.formatError("BoxTrigger:init() can only be called with one 'angle', 'forward' or 'right' argument exclusively: %q, %q, %q", angle, forward, right) end

	if not hwidth and not hlength then
		utils.formatError("BoxTrigger:__call() cannot be called without an 'hwidth' or 'hlength' argument: %q, %q", hwidth, hlength) end

	pos = pos or vec2.new()
	vel = vel or vec2.new()
	radius = radius or 0
	angle = angle or (right and math.atan2(right.y, right.x)) or (forward and math.atan2(forward.x, -forward.y)) or 0
	hwidth = hwidth or hlength
	hlength = hlength or hwidth
	height = height or 0
	onOverlap = onOverlap or nil

	return BoxTrigger.new("box", pos, vel, radius, angle, hwidth, hlength, height, onOverlap)
end

function BoxTrigger:__gc()
	if self.onOverlap ~= voidptr then
		local addr = utils.addr(self.onOverlap)

		if BoxTrigger.callbacks[addr] then
			BoxTrigger.callbacks[addr] = BoxTrigger.callbacks[addr] - 1

			if BoxTrigger.callbacks[addr] == 0 then
				BoxTrigger.callbacks[addr] = nil
				self.onOverlap:free()
			end end end
end

function BoxTrigger:__index(key)
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
	elseif key == "onOverlap" then return self._onOverlap
	elseif key == "copy" then return BoxTrigger.new(self)
	else return rawget(BoxTrigger, key) end
end

function BoxTrigger:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos", "p1", "p2", "p3", "p4", "pp1", "pp2", "pp3", "pp4", "hdims")

	if key == "forward" then self.angle = math.atan2(value.x, -value.y)
	elseif key == "right" then self.angle = math.atan2(value.y, value.x)
	elseif key == "bow" then
		self.hlength = value.length
		self.angle = math.atan2(value.x, -value.y)
	elseif key == "star" then
		self.hwidth = value.length
		self.angle = math.atan2(value.y, value.x)
	elseif key == "onOverlap" then
		if type(value) ~= "function" then
			utils.formatError("Attempted to set 'onOverlap' key of class 'BoxTrigger' to a value that isn't a function: %q", value) end

		if self._onOverlap then self._onOverlap:set(value)
		else self._onOverlap = value end
	elseif self == BoxTrigger then rawset(BoxTrigger, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'BoxTrigger': %q", key, value) end
end

function BoxTrigger:__tostring()
	if self == BoxTrigger then return string.format("Class 'BoxTrigger' (%s)", BoxTrigger.string)
	else return string.format("Instance of 'BoxTrigger' (%s)", utils.addrString(self)) end
end

function BoxTrigger:instanceOf(class) return class == BoxTrigger end

BoxTrigger.update = Trigger.update

function BoxTrigger:draw()
	if DEBUG_DRAW and DEBUG_TRIGGERS then
		BoxCollider.draw(self, "trigger") end
end

BoxTrigger.getCastBounds = BoxCollider.getCastBounds
BoxTrigger.pick = BoxCollider.pick
BoxTrigger.overlap = BoxCollider.overlap

setmetatable(BoxTrigger, BoxTrigger)
ffi.metatype("BoxTrigger", BoxTrigger)
