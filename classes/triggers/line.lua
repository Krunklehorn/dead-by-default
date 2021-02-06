local ffi = require "ffi"
local voidptr = ffi.new("void*")

ffi.cdef[[
	typedef struct _LineTrigger {
		LineCollider;
		Trigger;
	} LineTrigger;
]]

LineTrigger = {
	new = ffi.typeof("LineTrigger"),
	callbacks = {}
}
function LineTrigger.__new(obj, ...)
	local obj = ffi.new("LineTrigger", ...)

	if obj.onOverlap ~= voidptr then
		local addr = utils.addr(obj.onOverlap)

		if not LineTrigger.callbacks[addr] then LineTrigger.callbacks[addr] = 1
		else LineTrigger.callbacks[addr] = LineTrigger.callbacks[addr] + 1 end
	end

	return obj
end

function LineTrigger:__call(params)
	if ffi.istype("LineTrigger", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local p1 = utils.checkArg("p1", params[1] or params.p1, "vec2", "LineTrigger:__call", true)
	local p2 = utils.checkArg("p2", params[2] or params.p2, "vec2", "LineTrigger:__call", true)
	local vel = utils.checkArg("vel", params[3] or params.vel, "vec2", "LineTrigger:__call", true)
	local radius = utils.checkArg("radius", params[4] or params.radius, "number", "LineTrigger:__call", true)
	local height = utils.checkArg("height", params[5] or params.height, "number", "LineTrigger:__call", true)
	local onOverlap = utils.checkArg("onOverlap", params[6] or params.onOverlap, "function", "Trigger:__call", true)

	p1 = p1 or vec2()
	p2 = p2 or vec2()
	vel = vel or vec2()
	radius = radius or 0
	height = height or 0
	onOverlap = onOverlap or nil

	return LineTrigger.new(utils.newID(), p1, p2, vel, radius, height, onOverlap)
end

function LineTrigger:__gc()
	if self.onOverlap ~= voidptr then
		local addr = utils.addr(self.onOverlap)

		if LineTrigger.callbacks[addr] then
			LineTrigger.callbacks[addr] = LineTrigger.callbacks[addr] - 1

			if LineTrigger.callbacks[addr] == 0 then
				LineTrigger.callbacks[addr] = nil
				self.onOverlap:free()
			end end end
end

function LineTrigger:__index(key)
	if key == "pp1" then return self.p1 - self.vel * stopwatch.ticklength
	elseif key == "pp2" then return self.p2 - self.vel * stopwatch.ticklength
	elseif key == "delta" then return self.p2 - self.p1
	elseif key == "direction" then return self.delta.normalized
	elseif key == "normal" then return self.delta.normal
	elseif key == "onOverlap" then return self._onOverlap
	elseif key == "copy" then return LineTrigger.new(self)
	else return rawget(LineTrigger, key) end
end

function LineTrigger:__newindex(key, value)
	utils.readOnly(tostring(self), key, "pp1", "pp2", "delta", "direction", "normal")

	if key == "onOverlap" then
		if type(value) ~= "function" then
			utils.formatError("Attempted to set 'onOverlap' key of class 'LineTrigger' to a value that isn't a function: %q", value) end

		if self._onOverlap then self._onOverlap:set(value)
		else self._onOverlap = value end
	elseif self == LineTrigger then rawset(LineTrigger, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'LineTrigger': %q", key, value) end
end

function LineTrigger:__tostring()
	if self == LineTrigger then return string.format("Class 'LineTrigger' (%s)", LineTrigger.string)
	else return string.format("Instance of 'LineTrigger' (%s)", utils.addrString(self)) end
end

function LineTrigger:instanceOf(class) return class == LineTrigger end

LineTrigger.update = Trigger.update

function LineTrigger:draw()
	if DEBUG_DRAW and DEBUG_TRIGGERS then
		LineCollider.draw(self, "trigger") end
end

LineTrigger.getCastBounds = LineCollider.getCastBounds
LineTrigger.pick = LineCollider.pick
LineTrigger.overlap = LineCollider.overlap
LineTrigger.point_determinant = LineCollider.point_determinant
LineTrigger.line_contact = LineCollider.line_contact

setmetatable(LineTrigger, LineTrigger)
ffi.metatype("LineTrigger", LineTrigger)
