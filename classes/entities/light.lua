local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Light {
		Entity;
		vec2 vel;
		vec3 color;
		double intensity;
		double range;
		double radius;
	} Light;
]]

Light = {
	new = ffi.typeof("Light")
}

function Light:__call(params)
	if Light.isLight(self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec3", "Light:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "Light:__call", true)
	local color = utils.checkArg("color", params[3] or params.color, "vec3", "Light:__call", true)
	local intensity = utils.checkArg("intensity", params[4] or params.intensity, "number", "Light:__call", true)
	local range = utils.checkArg("range", params[5] or params.range, "number", "Light:__call", true)
	local radius = utils.checkArg("radius", params[6] or params.radius, "number", "Light:__call", true)

	pos = pos or vec3(0, 0, 128)
	vel = vel or vec2()
	color = color or vec3(1)
	intensity = intensity or 1
	range = range or UNIT_TILE
	radius = radius or 6

	return Light.new(OBJ_ID_BASE, pos, vel, color, intensity, range, radius)
end

function Light:__index(key)
	if key == "copy" then return Light.new(self)
	else return rawget(Light, key) end
end

function Light:__newindex(key, value)
	if self == Light then rawset(Light, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'Light': %q", key, value) end
end

function Light:__tostring()
	if self == Light then return string.format("Class 'Light' (%s)", Light.string)
else return string.format("Instance of 'Light' (%s)", utils.addrString(self)) end
end

function Light:setID(id) self.id = utils.checkArg("id", id, "ID", "Light:setID") end
function Light:instanceOf(class) return class == Light end
function Light.isLight(obj) return ffi.istype("Light", obj) end

function Light:draw()
	if humpstate.current() == editState and DEBUG_DRAW and DEBUG_ENTITIES and DEBUG_LIGHTS then
		utils.drawCircle(self.pos.xy, self.range, "magenta", 0.25)
		utils.drawCircle(self.pos.xy, self.radius, "magenta", 0.5)
	end
end

function Light:payload(ptr, index, camera, scale)
	local pos = camera:toScreen(self.pos.xy)

	ptr[index + 0] = pos.x
	ptr[index + 1] = pos.y
	ptr[index + 2] = self.range * scale
	ptr[index + 3] = self.radius * scale
	ptr[index + 4] = self.color.x
	ptr[index + 5] = self.color.y
	ptr[index + 6] = self.color.z
	ptr[index + 7] = self.intensity
end

function Light:pick(point)
	utils.checkArg("point", point, "vec2", "Light:pick")

	return (point - self.pos).length - self.range
end

setmetatable(Light, Light)
ffi.metatype("Light", Light)
