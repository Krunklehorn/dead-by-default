local ffi = require "ffi"
local voidptr = ffi.new("void*")

ffi.cdef[[
	typedef struct _CircleTrigger {
		CircleCollider;
		Trigger;
	} CircleTrigger;
]]

CircleTrigger = {
	new = ffi.typeof("CircleTrigger"),
	callbacks = {}
}

function CircleTrigger.__new(obj, ...)
	local obj = ffi.new("CircleTrigger", ...)

	if obj.onOverlap ~= voidptr then
		local addr = utils.addr(obj.onOverlap)

		if not CircleTrigger.callbacks[addr] then CircleTrigger.callbacks[addr] = 1
		else CircleTrigger.callbacks[addr] = CircleTrigger.callbacks[addr] + 1 end
	end

	return obj
end

function CircleTrigger:__call(params)
	if ffi.istype("CircleTrigger", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "CircleTrigger:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "CircleTrigger:__call", true)
	local radius = utils.checkArg("radius", params[3] or params.radius, "number", "CircleTrigger:__call", true)
	local height = utils.checkArg("height", params[4] or params.height, "number", "CircleTrigger:__call", true)
	local onOverlap = utils.checkArg("onOverlap", params[5] or params.onOverlap, "function", "Trigger:__call", true)

	pos = pos or vec2.new()
	vel = vel or vec2.new()
	radius = radius or 0
	height = height or 0
	onOverlap = onOverlap or nil

	return CircleTrigger.new("circle", pos, vel, radius, height, onOverlap)
end

function CircleTrigger:__gc()
	if self.onOverlap ~= voidptr then
		local addr = utils.addr(self.onOverlap)

		if CircleTrigger.callbacks[addr] then
			CircleTrigger.callbacks[addr] = CircleTrigger.callbacks[addr] - 1

			if CircleTrigger.callbacks[addr] == 0 then
				CircleTrigger.callbacks[addr] = nil
				self.onOverlap:free()
			end end end
end

function CircleTrigger:__index(key)
	if key == "ppos" then return self.pos - self.vel * stopwatch.ticklength
	elseif key == "onOverlap" then return self._onOverlap
	elseif key == "copy" then return CircleCollider.new(self)
	else return rawget(CircleTrigger, key) end
end

function CircleTrigger:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos")

	if key == "onOverlap" then
		if type(value) ~= "function" then
			utils.formatError("Attempted to set 'onOverlap' key of class 'CircleTrigger' to a value that isn't a function: %q", value) end

		if self._onOverlap then self._onOverlap:set(value)
		else self._onOverlap = value end
	elseif self == CircleTrigger then rawset(CircleTrigger, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'CircleTrigger': %q", key, value) end
end

function CircleTrigger:__tostring()
	if self == CircleTrigger then return string.format("Class 'CircleTrigger' (%s)", CircleTrigger.string)
	else return string.format("Instance of 'CircleTrigger' (%s)", utils.addrString(self)) end
end

function CircleTrigger:instanceOf(class) return class == CircleTrigger end

CircleTrigger.update = Trigger.update

function CircleTrigger:draw()
	if DEBUG_DRAW and DEBUG_TRIGGERS then
		CircleCollider.draw(self, "trigger") end
end

CircleTrigger.getCastBounds = CircleCollider.getCastBounds
CircleTrigger.pick = CircleCollider.pick
CircleTrigger.overlap = CircleCollider.overlap
CircleTrigger.cast = CircleCollider.cast
CircleTrigger.circ_contact = CircleCollider.circ_contact
CircleTrigger.box_contact = CircleCollider.box_contact
CircleTrigger.line_contact = CircleCollider.line_contact

setmetatable(CircleTrigger, CircleTrigger)
ffi.metatype("CircleTrigger", CircleTrigger)
