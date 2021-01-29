local ffi = require "ffi"
local cos45, sin45 = math.cos(45), math.sin(45)

ffi.cdef[[
	typedef struct _vec2 {
		double x;
		double y;
	} vec2;
]]

local vec2 = {}
local new = ffi.typeof("vec2")

function formatError(msg, ...)
	local args = { n = select('#', ...), ...}
	local strings = {}

	for i = 1, args.n do
		strings[#strings + 1] = tostring(args[i] or "nil") end

	error(msg:format(unpack(strings)), 1)
end

function vec2:__index(key)
	if key == "z" then return 0
	elseif key == "length" then return math.sqrt(self.x * self.x + self.y * self.y)
	elseif key == "length2" then return self.x * self.x + self.y * self.y
	elseif key == "normalized" then
		local length = math.sqrt(self.x * self.x + self.y * self.y)
		return length == 0 and new() or new(self.x / length, self.y / length)
	elseif key == "normal" then
		local length = math.sqrt(self.x * self.x + self.y * self.y)
		return length == 0 and new() or new(-self.y / length, self.x / length)
	elseif key == "tangent" then
		local length = math.sqrt(self.x * self.x + self.y * self.y)
		return length == 0 and new() or new(self.y / length, -self.x / length)
	elseif key == "angle" then return math.atan2(self.y, self.x)
	elseif key == "inverse" then return new(1 / self.x, 1 / self.y)
	elseif key == "abs" then return new(math.abs(self.x), math.abs(self.y))
	elseif key == "floor" then return new(math.floor(self.x), math.floor(self.y))
	elseif key == "ceil" then return new(math.ceil(self.x), math.ceil(self.y))
	elseif key == "round" then return new(math.floor(self.x + 0.5), math.floor(self.y + 0.5))
	elseif key == "sign" then return new(self.x < 0 and -1 or (math.abs(self.x) <= FLOAT_THRESHOLD and 0 or 1),
										 self.y < 0 and -1 or (math.abs(self.y) <= FLOAT_THRESHOLD and 0 or 1))
	elseif key == "nearZero" then return math.abs(self.x) <= FLOAT_THRESHOLD and
										 math.abs(self.y) <= FLOAT_THRESHOLD
	elseif key == "eqZero" then return self.x == 0 and self.y == 0
	elseif key == "table" then return { self.x, self.y }
	elseif key == "xy" or key == "copy" then return new(self)
	else return rawget(vec2, key) end
end

function vec2:__newindex(key, value)
	if key == "length" then
		local x, y
		local length = math.sqrt(self.x * self.x + self.y * self.y)

		if length == 0 then x = 0
							y = 0
		else x = self.x / length * value
			 y = self.y / length * value end

		self.x = x
		self.y = y
	elseif key == "angle" then
		local x, y
		local length = math.sqrt(self.x * self.x + self.y * self.y)

		if length == 0 then x = 0
							y = 0
		else x = math.cos(angle) * length
			 y = math.sin(angle) * length end

		self.x = x
		self.y = y
	elseif self == vec2 then rawset(vec2, key, value)
	else formatError("Attempted to write new index '%s' to instance of 'vec2': %q", key, value) end
end

function vec2.__add(obj, other)
	if type(obj) == "number" or type(other) == "number" then
		formatError("vec2 addition by number: %q, %q", obj, other)
	else return new(obj.x + other.x, obj.y + other.y) end
end

function vec2.__sub(obj, other)
	if type(obj) == "number" or type(other) == "number" then
		formatError("vec2 subtraction by number: %q, %q", obj, other)
	else return new(obj.x - other.x, obj.y - other.y) end
end

function vec2.__mul(obj, other)
	if type(obj) == "number" then return new(obj * other.x, obj * other.y)
	elseif type(other) == "number" then return new(obj.x * other, obj.y * other)
	else return new(obj.x * other.x, obj.y * other.y) end
end

function vec2.__div(obj, other)
	if type(other) == "number" then
		if other == 0 then formatError("vec2 division by zero: %q, %q", obj, other)
		else return new(obj.x / other, obj.y / other) end
	elseif other.x == 0 or other.y == 0 then formatError("vec2 division by zero: %q, %q", obj, other)
	elseif type(obj) == "number" then return new(obj / other.x, obj / other.y)
	else return new(obj.x / other.x, obj.y / other.y) end
end

function vec2.__mod(obj, other)
	if type(other) == "number" then
		if other == 0 then formatError("vec2 modulo of zero: %q, %q", obj, other)
		else return new(obj.x % other, obj.y % other) end
	elseif other.x == 0 or other.y == 0 then formatError("vec2 modulo of zero: %q, %q", obj, other)
	elseif type(obj) == "number" then return new(obj % other.x, obj % other.y)
	else return new(obj.x % other.x, obj.y % other.y) end
end

function vec2.__pow(obj, other)
	if type(obj) == "number" then return new(obj ^ other.x, obj ^ other.y)
	elseif type(other) == "number" then return new(obj.x ^ other, obj.y ^ other)
	else return new(obj.x ^ other.x, obj.y ^ other.y) end
end

function vec2.__eq(obj, other)
	if ffi.istype("vec2", obj) and ffi.istype("vec2", other) then
		return math.abs(obj.x - other.x) < FLOAT_THRESHOLD and
			   math.abs(obj.y - other.y) < FLOAT_THRESHOLD
	else return false end
end

function vec2.__lt(obj, other) return obj.x < other.x and obj.y < other.y end
function vec2.__le(obj, other) return obj.x <= other.x and obj.y <= other.y end
function vec2.__unm(vec) return new(-vec.x, -vec.y) end
function vec2.__tostring(vec) return string.format("vec2 { %.4f, %.4f }", vec.x, vec.y) end
function vec2.__concat(obj, other) return tostring(obj) .. tostring(other) end

function vec2.isVec2(obj) return ffi.istype("vec2", obj) end
function vec2.dot(obj, other) return obj.x * other.x + obj.y * other.y end
function vec2.cross(obj, other) return obj.x * other.y - obj.y * other.x end
function vec2.split(obj) return obj.x, obj.y end
function vec2.min(vec, other) return new(math.min(vec.x, other), math.min(vec.y, other)) end
function vec2.max(vec, other) return new(math.max(vec.x, other), math.max(vec.y, other)) end

function vec2.translated(vec, other)
	if type(other) == "number" then return new(vec.x + other, vec.y + other)
	else return new(vec.x + other.x, vec.y + other.y) end
end

function vec2.scaled(vec, other)
	if type(other) == "number" then return new(vec.x * other, vec.y * other)
	else return new(vec.x * other.x, vec.y * other.y) end
end

function vec2.rotated(vec, ang)
	local length = math.sqrt(vec.x * vec.x + vec.y * vec.y)

	ang = math.atan2(vec.y, vec.x) + ang

	return new(math.cos(ang) * length, math.sin(ang) * length)
end

function vec2.CW(vec, cos, sin)
	return new(vec.x * cos - vec.y * sin,
			   vec.y * cos + vec.x * sin)
end

function vec2.CCW(vec, cos, sin)
	return new(vec.x * cos + vec.y * sin,
			   vec.y * cos - vec.x * sin)
end

function vec2.trimmed(vec, mag)
	local length = math.sqrt(vec.x * vec.x + vec.y * vec.y)

	mag = math.abs(mag)

	if length == 0 or mag == 0 then return new()
	elseif length <= mag then return new(vec)
	else return new(vec.x / length * mag, vec.y / length * mag) end
end

function vec2.clamped(vec, lower, upper)
	return new(math.min(math.max(lower, vec.x), upper),
			   math.min(math.max(lower, vec.y), upper))
end

function vec2.wrapped(vec, lower, upper)
	local divisor = upper - lower

	return new(lower + (vec.x - lower) % divisor,
			   lower + (vec.y - lower) % divisor)
end

function vec2.snapped(vec, interval)
	return new(math.floor(vec.x / interval + 0.5) * interval,
			   math.floor(vec.y / interval + 0.5) * interval)
end

function vec2.up() return new(0, -1) end
function vec2.down() return new(0, 1) end
function vec2.left() return new(-1, 0) end
function vec2.right() return new(1, 0) end
function vec2.upleft() return new(-cos45, -sin45) end
function vec2.upright() return new(cos45, -sin45) end
function vec2.downleft() return new(-cos45, sin45) end
function vec2.downright() return new(cos45, sin45) end

ffi.metatype("vec2", vec2)

local _vec2 = { new = new }
local string = tostring(_vec2)

return setmetatable(_vec2, {
	__call = function(_, x, y)
		return new(x or 0, y or x or 0)
	end,
	__index = vec2,
	__tostring = function(_) return string.format("Module 'vec2' (%s)", string) end
})
