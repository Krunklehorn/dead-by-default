local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Vault {
		vec3 pos;
		vec2 vel;
		double angle;
		unsigned int hwidth;
		bool oneway;
	} Vault;
]]

Vault = {
	new = ffi.typeof("Vault")
}

function Vault:__call(params)
	if Vault.isVault(self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec3", "Vault:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "Vault:__call", true)
	local angle = utils.checkArg("angle", params[3] or params.angle, "number", "Vault:__call", true)
	local forward = utils.checkArg("forward", params.forward, "vec2", "Vault:__call", true)
	local right = utils.checkArg("right", params.right, "vec2", "Vault:__call", true)
	local hwidth = utils.checkArg("hwidth", params[4] or params.hwidth, "number", "Vault:__call", true)
	local oneway = utils.checkArg("oneway", params[5] or params.oneway, "boolean", "Vault:__call", true)

	if forward and (right or angle) or (right and angle) then
		utils.formatError("Instances of class 'Vault' can only be created using one 'angle', 'forward' or 'right' argument exclusively: %q, %q, %q", angle, forward, right) end

	pos = pos or vec3(0, 0, 128)
	vel = vel or vec2()
	angle = angle or (right and math.atan2(right.y, right.x)) or (forward and math.atan2(-forward.x, -forward.y)) or 0
	hwidth = hwidth or 75
	oneway = oneway or false

	return Vault.new(pos, vel, angle, hwidth, oneway)
end

function Vault:__index(key)
	if key == "forward" then return vec2(math.sin(self.angle), -math.cos(self.angle))
	elseif key == "right" then return vec2(math.cos(self.angle), math.sin(self.angle))
	elseif key == "copy" then return Vault.new(self)
	else return rawget(Vault, key) end
end

function Vault:__newindex(key, value)
	if key == "forward" then self.angle = math.atan2(value.x, -value.y)
	elseif key == "right" then self.angle = math.atan2(value.y, value.x)
	elseif self == Vault then rawset(Vault, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'Vault': %q", key, value) end
end

function Vault:__tostring()
	if self == Vault then return string.format("Class 'Vault' (%s)", Vault.string)
else return string.format("Instance of 'Vault' (%s)", utils.addrString(self)) end
end

function Vault:instanceOf(class) return class == Vault end
function Vault.isVault(obj) return ffi.istype("Vault", obj) end

function Vault:draw()
	if DEBUG_DRAW and DEBUG_ENTITIES then
		utils.drawBox(self.pos, self.angle, self.hwidth, 10, 0, "magenta", 0.5)
		utils.drawLine(self.pos, self.pos + self.forward * 100, "magenta", 0.5)

		utils.drawLine(self.pos - self.right * self.hwidth, self.pos - self.right * self.hwidth - self.forward * 125, "magenta", 0.5)
		utils.drawLine(self.pos + self.right * self.hwidth, self.pos + self.right * self.hwidth - self.forward * 125, "magenta", 0.5)
		if not self.oneway then
			utils.drawLine(self.pos - self.right * self.hwidth, self.pos - self.right * self.hwidth + self.forward * 125, "magenta", 0.5)
			utils.drawLine(self.pos + self.right * self.hwidth, self.pos + self.right * self.hwidth + self.forward * 125, "magenta", 0.5)
		end
	end
end

setmetatable(Vault, Vault)
ffi.metatype("Vault", Vault)
