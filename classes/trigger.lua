local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Trigger {
		double height;
		void (*_onOverlap)();
	} Trigger;
]]

Trigger = {
	agent = nil
}

function Trigger:__index(key)
	if key == "onOverlap" then return self._onOverlap
	else return rawget(Trigger, key) end
end

function Trigger:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos")

	if key == "onOverlap" then
		if type(value) ~= "function" then
			utils.formatError("Attempted to set 'onOverlap' key of class 'Trigger' to a value that isn't a function: %q", value) end

		if self._onOverlap then self._onOverlap:set(value)
		else self._onOverlap = value end
	elseif self == Trigger then rawset(Trigger, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'Trigger': %q", key, value) end
end

function Trigger.isTrigger(obj)
	return ffi.istype("CircleTrigger", obj) or
		   ffi.istype("BoxTrigger", obj) or
		   ffi.istype("LineTrigger", obj)
end

function Trigger.update(trigger, tl)
	local agents = world.agents

	if trigger.onOverlap then -- discrete response
		for a = 1, #agents do
			if trigger.height < agents[a].pos.z then
				goto continue end

			if trigger:overlap(agents[a].collider) >= 0 then
				Trigger.agent = agents[a]
				trigger.onOverlap()
				Trigger.agent = nil
			end

			::continue::
		end
	end
end

setmetatable(Trigger, Trigger)
ffi.metatype("Trigger", Trigger)

require "classes.triggers.circle"
require "classes.triggers.box"
require "classes.triggers.line"
