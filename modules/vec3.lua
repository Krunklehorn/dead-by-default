local ffi = require "ffi"
local cos45, sin45 = math.cos(45), math.sin(45)

ffi.cdef[[
	typedef struct _vec3 {
		double x;
		double y;
		double z;
	} vec3;
]]

local vec3 = {}
local new = ffi.typeof("vec3")

function vec3:__index(key)
	if key == "length" then return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
	elseif key == "length2" then return self.x * self.x + self.y * self.y + self.z * self.z
	elseif key == "normalized" then
		local length = math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
		return length == 0 and new() or new(self.x / length, self.y / length, self.z / length)
	elseif key == "inverse" then return new(1 / self.x, 1 / self.y, 1 / self.z)
	elseif key == "abs" then return new(math.abs(self.x), math.abs(self.y), math.abs(self.z))
	elseif key == "floor" then return new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
	elseif key == "ceil" then return new(math.ceil(self.x), math.ceil(self.y), math.ceil(self.z))
	elseif key == "round" then return new(math.floor(self.x + 0.5), math.floor(self.y + 0.5), math.floor(self.z + 0.5))
	elseif key == "sign" then return new(self.x < 0 and -1 or (math.abs(self.x) <= FLOAT_THRESHOLD and 0 or 1),
										 self.y < 0 and -1 or (math.abs(self.y) <= FLOAT_THRESHOLD and 0 or 1),
										 self.z < 0 and -1 or (math.abs(self.z) <= FLOAT_THRESHOLD and 0 or 1))
	elseif key == "nearZero" then return math.abs(self.x) <= FLOAT_THRESHOLD and
										 math.abs(self.y) <= FLOAT_THRESHOLD and
										 math.abs(self.z) <= FLOAT_THRESHOLD
	elseif key == "eqZero" then return self.x == 0 and self.y == 0 and self.z == 0
	elseif key == "ltZero" then return self.x < 0 and self.y < 0 and self.z < 0
	elseif key == "leZero" then return self.x <= 0 and self.y <= 0 and self.z <= 0
	elseif key == "table" then return { self.x, self.y, self.z }
	elseif key == "xy" then return vec2.new(self.x, self.y)
	elseif key == "copy" then return new(self)
	else return rawget(vec3, key) end
end

function vec3:__newindex(key, value)
	if key == "length" then
		local x, y, z
		local length = math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)

		if length == 0 then x = 0
							y = 0
							z = 0
		else x = self.x / length * value
			 y = self.y / length * value
			 z = self.z / length * value end

		self.x = x
		self.y = y
		self.z = z
	elseif key == "xy" then
		self.x = value.x
		self.y = value.y
	elseif self == vec3 then rawset(vec3, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'vec3': %q", key, value) end
end

function vec3.__add(obj, other)
	if type(obj) == "number" or type(other) == "number" then
		utils.formatError("vec3 addition by number: %q, %q", obj, other)
	else return new(obj.x + other.x, obj.y + other.y, obj.z + other.z) end
end

function vec3.__sub(obj, other)
	if type(obj) == "number" or type(other) == "number" then
		utils.formatError("vec3 subtraction by number: %q, %q", obj, other)
	else return new(obj.x - other.x, obj.y - other.y, obj.z - other.z) end
end

function vec3.__mul(obj, other)
	if type(obj) == "number" then return new(obj * other.x, obj * other.y, obj * other.z)
	elseif type(other) == "number" then return new(obj.x * other, obj.y * other, obj.z * other)
	else return new(obj.x * other.x, obj.y * other.y, obj.z * other.z) end
end

function vec3.__div(obj, other)
	if type(other) == "number" then
		if other == 0 then utils.formatError("vec3 division by zero: %q, %q", obj, other)
		else return new(obj.x / other, obj.y / other, obj.z / other) end
	elseif other.x == 0 or other.y == 0 then utils.formatError("vec3 division by zero: %q, %q", obj, other)
	elseif type(obj) == "number" then return new(obj / other.x, obj / other.y, obj / other.z)
	else return new(obj.x / other.x, obj.y / other.y, obj.z / other.z) end
end

function vec3.__mod(obj, other)
	if type(other) == "number" then
		if other == 0 then utils.formatError("vec3 modulo by zero: %q, %q", obj, other)
		else return new(obj.x % other, obj.y % other, obj.z % other) end
	elseif other.x == 0 or other.y == 0 then utils.formatError("vec3 modulo by zero: %q, %q", obj, other)
	elseif type(obj) == "number" then return new(obj % other.x, obj % other.y, obj % other.z)
	else return new(obj.x % other.x, obj.y % other.y, obj.z % other.z) end
end

function vec3.__pow(obj, other)
	if type(obj) == "number" then return new(obj ^ other.x, obj ^ other.y, obj ^ other.z)
	elseif type(other) == "number" then return new(obj.x ^ other, obj.y ^ other, obj.z ^ other)
	else return new(obj.x ^ other.x, obj.y ^ other.y, obj.z ^ other.z) end
end

function vec3.__eq(obj, other)
	if utils.isVector(obj) and utils.isVector(other) then
		return math.abs(obj.x - other.x) < FLOAT_THRESHOLD and
			   math.abs(obj.y - other.y) < FLOAT_THRESHOLD and
			   math.abs(obj.z - other.z) < FLOAT_THRESHOLD
	else return false end
end

function vec3.__lt(obj, other) return obj.x < other.x and obj.y < other.y and obj.z < other.z end
function vec3.__le(obj, other) return obj.x <= other.x and obj.y <= other.y and obj.z <= other.z end
function vec3.__unm(vec) return new(-vec.x, -vec.y, -vec.z) end
function vec3.__tostring(vec) return string.format("vec3 { %.4f, %.4f, %.4f }", vec.x, vec.y, vec.z) end
function vec3.__concat(obj, other) return tostring(obj) .. tostring(other) end

function vec3.isVec3(obj) return ffi.istype("vec3", obj) end
function vec3.dot(obj, other) return obj.x * other.x + obj.y * other.y + obj.z * other.z end
function vec3.cross(obj, other) return vec3(obj.y * other.z - obj.z * other.y,
											obj.z * other.x - obj.x * other.z,
											obj.x * other.y - obj.y * other.x) end
function vec3.split(obj) return obj.x, obj.y, obj.z end
function vec3.min(vec, ...) return new(math.min(vec.x, ...), math.min(vec.y, ...), math.min(vec.z, ...)) end
function vec3.max(vec, ...) return new(math.max(vec.x, ...), math.max(vec.y, ...), math.max(vec.z, ...)) end

function vec3.translated(vec, other)
	if type(other) == "number" then return new(vec.x + other, vec.y + other, vec.z + other)
	else return new(vec.x + other.x, vec.y + other.y, vec.z + other.z) end
end

function vec3.scaled(vec, other)
	if type(other) == "number" then return new(vec.x * other, vec.y * other, vec.z * other)
	else return new(vec.x * other.x, vec.y * other.y, vec.z * other.z) end
end

function vec3.trimmed(vec, mag)
	local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)

	mag = math.abs(mag)

	if length == 0 or mag == 0 then return new()
	elseif length <= mag then return new(vec)
	else return new(vec.x / length * mag, vec.y / length * mag, vec.z / length * mag) end
end

function vec3.clamped(vec, lower, upper)
	return new(math.min(math.max(lower, vec.x), upper),
			   math.min(math.max(lower, vec.y), upper),
			   math.min(math.max(lower, vec.z), upper))
end

function vec3.wrapped(vec, lower, upper)
	local divisor = upper - lower

	return new(lower + (vec.x - lower) % divisor,
			   lower + (vec.y - lower) % divisor,
			   lower + (vec.z - lower) % divisor)
end

function vec3.snapped(vec, interval)
	return new(math.floor(vec.x / interval + 0.5) * interval,
			   math.floor(vec.y / interval + 0.5) * interval,
			   math.floor(vec.z / interval + 0.5) * interval)
end

function vec3.up() return new(0, -1, 0) end
function vec3.down() return new(0, 1, 0) end
function vec3.left() return new(-1, 0, 0) end
function vec3.right() return new(1, 0, 0) end
function vec3.upleft() return new(-cos45, -sin45, 0) end
function vec3.upright() return new(cos45, -sin45, 0) end
function vec3.downleft() return new(-cos45, sin45, 0) end
function vec3.downright() return new(cos45, sin45, 0) end

ffi.metatype("vec3", vec3)

local _vec3 = { new = new }
local string = tostring(_vec3)

return setmetatable(_vec3, {
	__call = function(_, x, y, z)
		utils.checkArg("x", x, "number", "vec3:__call", true)
		utils.checkArg("y", y, "number", "vec3:__call", true)
		utils.checkArg("z", z, "number", "vec3:__call", true)

		return new(x or 0, y or x or 0, z or x or 0)
	end,
	__index = vec3,
	__tostring = function(_) return string.format("Module 'vec3' (%s)", string) end
})
