local ffi = require "ffi"
local voidptr_t = ffi.typeof("void*")
local intptr_t = ffi.typeof("intptr_t")
local intptr_t1 = ffi.typeof("intptr_t[1]")

local utils = {
	fade = 0,
	private = {
		counters = {}
	}
}

function utils.__index(_, key)
	local utils = rawget(utils, "private")

	if key == "private" then return utils end

	return rawget(utils, key)
end

function utils.__newindex(_, key, value)
	local stopwatch = rawget(stopwatch, "private")

	utils.readOnly("utils", key, "counters")

	if key ~= "fade" then
		utils.formatError("Attempted to write new index '%s' to utils: %q", key, value) end

	utils[key] = value
end

function utils.formatError(msg, ...)
	local args = { n = select('#', ...), ...}
	local strings = {}

	for i = 1, args.n do
		strings[#strings + 1] = tostring(args[i] or "nil") end

	error(msg:format(unpack(strings)), 1)
end

function utils.checkArg(key, arg, query, func, nillable, default)
	if arg == nil and nillable == true then
		return default
	else
		if query == "number" or query == "string" or query == "boolean" or query == "table" or query == "function" or query == "cdata" then
			if type(arg) ~= query then
				utils.formatError("%s() called with a '%s' argument that isn't a %s: %q", func, key, query, arg)
			end
		elseif query == "indexable" then
			if type(arg) ~= "table" and type(arg) ~= "cdata" then
				utils.formatError("%s() called with a '%s' argument that isn't indexable: %q", func, key, arg)
			end
		elseif query == "vec2" then
			if not vec2.isVec2(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a vec2: %q", func, key, arg)
			end
		elseif query == "vec3" then
			if not vec3.isVec3(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a vec3: %q", func, key, arg)
			end
		elseif query == "vector" then
			if not utils.isVector(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a vector: %q", func, key, arg)
			end
		elseif query == "number/vector" then
			if type(arg) ~= "number" and not vec2.isVec2(arg) and not vec3.isVec3(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a scalar or vector: %q", func, key, arg)
			end
		elseif query == "collider" then
			if not Collider.isCollider(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a collider: %q", func, key, arg)
			end
		elseif query == "brush" then
			if not Brush.isBrush(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a brush: %q", func, key, arg)
			end
		elseif query == "trigger" then
			if not Trigger.isTrigger(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a trigger: %q", func, key, arg)
			end
		elseif query == "entity" then
			if not Entity.isEntity(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't an entity: %q", func, key, arg)
			end
		elseif query == "handle" then
			if not ring.isHandle(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a handle: %q", func, key, arg)
			end
		elseif query == "asset" then
			if type(arg) ~= "string" and type(arg) ~= "table" and type(arg) ~= "userdata" then
				utils.formatError("%s() called with a '%s' argument that isn't a string, table or userdata: %q", func, key, arg)
			end
		elseif query == "ctype" then
			query = type(arg) == "string" and ffi.typeof(arg) or arg
			if tostring(query):sub(1, 5) ~= "ctype" then
				utils.formatError("%s() called with a '%s' argument that isn't a string or ctype: %q", func, key, arg)
			end
			arg = query
		elseif query == "class" then
			if not class.isClass(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't a class: %q", func, key, arg)
			end
		elseif query == "instance" then
			if not class.isInstance(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't an instance: %q", func, key, arg)
			end
		elseif query == "index/instance" then
			if type(arg) ~= "number" and not class.isInstance(arg) and not Brush.isBrush(arg) and not Entity.isEntity(arg) then
				utils.formatError("%s() called with a '%s' argument that isn't an index or instance: %q", func, key, arg)
			end
		elseif class.isClass(query) then
			query = class.isClass(query) and query or query.class

			if not arg:instanceOf(query) then
				utils.formatError("%s() called with a '%s' argument that isn't an instance of class '%s': %q", func, key, query.name, arg)
			end
		else
			utils.formatError("checkArg() called with a 'query' argument that hasn't been setup for type-checking yet: %q", query)
		end
	end

	return arg
end

local function addr32(p) return tonumber(ffi.cast(intptr_t, ffi.cast(voidptr_t, p))) end
local function addr64(p)
	local np = ffi.cast(intptr_t, ffi.cast(voidptr_t, p))
	local n = tonumber(np)

	if ffi.cast(intptr_t, n) ~= np then
		return ffi.string(intptr_t1(np), 8)
	else return n end
end

utils.addr = ffi.abi("64bit") and addr64 or addr32

function utils.addrString(obj)
	return string.format("cdata: 0x%08x", utils.addr(obj)) end

function utils.clear(table)
	if table then
		for key in next, table do
			rawset(table, key, nil) end
	end

	return table or {}
end

function utils.pool(initial, create, destroy)
	initial = initial or 0
	destroy = destroy or utils.clear

	local pool = {}
	local num = 0

	while num < initial do
		num = num + 1
		pool[num] = create and create() or {}
	end

	local function alloc()
		local table = pool[num]

		if table then
			pool[num] = false
			num = num - 1
		end

		return table or (create or {})
	end

	local function free(table)
		destroy(table)
		num = num + 1
		pool[num] = table
	end

	return alloc, free
end

utils.alloc, utils.free = utils.pool()

local function recursive_copy(obj, seen)
	if seen[obj] then
		return seen[obj]
	elseif type(obj) == "cdata" then
		seen[obj] = obj.copy
		return seen[obj]
	elseif class.isInstance(obj) then
		seen[obj] = obj:clone()
		return seen[obj]
	elseif class.isClass(obj) then
		seen[obj] = obj
		return obj
	elseif type(obj) == "table" then
		local table = {}
		seen[obj] = table

		for k, v in next, obj, nil do
			table[recursive_copy(k, seen)] = recursive_copy(v, seen) end

		return setmetatable(table, recursive_copy(getmetatable(obj), seen))
	else return obj end
end

local function stack_copy(obj)
	if type(obj) == "cdata" then return obj.copy
	elseif class.isInstance(obj) then return obj:clone()
	elseif class.isClass(obj) or
		   type(obj) ~= "table" then
			   return obj end

	-- stacks
	local o_stack = {} -- objects
	local c_stack = {} -- copies
	local k_stack = {} -- keys
	local v_stack = {} -- values
	local m_stack = {} -- metatables
	local ks_stack = {} -- key set flags
	local vs_stack = {} -- value set flags
	local ms_stack = {} -- metatable set flags
	local r_stack = {} -- return actions
	local height = 0

	-- registers
	local o = obj
	local c = {}
	local k, v = next(o)
	local m = getmetatable(o)
	local ks = false
	local vs = false
	local ms = false

	local seen = {}

	local function push(obj, r)
		height = height + 1
		o_stack[height] = o
		c_stack[height] = c
		k_stack[height] = k
		v_stack[height] = v
		m_stack[height] = m
		ks_stack[height] = ks
		vs_stack[height] = vs
		ms_stack[height] = ms
		r_stack[height] = r

		o = obj
		c = {}
		k, v = next(o)
		m = getmetatable(o)
		ks, vs, ms = false, false, false
	end

	local function pop()
		if height == 0 then
			return nil end

		local r = r_stack[height]

		k = k_stack[height]
		v = v_stack[height]
		m = m_stack[height]
		ks = ks_stack[height]
		vs = vs_stack[height]
		ms = ms_stack[height]

		if r == "k" then
			seen[k] = c
			k = c
			ks = true
		elseif r == "v" then
			seen[v] = c
			v = c
			vs = true
		elseif r == "m" then
			seen[m] = c
			m = c
			ms = true
		end

		o = o_stack[height]
		c = c_stack[height]
		height = height - 1

		return r
	end

	while true do
		if seen[o] then
			o = seen[o]

			if not pop() then
				break end
		elseif not k and not v then -- end of traversal
			if ms then
				setmetatable(c, m) end

			if not pop() then
				break end
		elseif not ks and type(k) == "table" and
						  not class.isClass(k) and
						  not class.isInstance(k) then -- don't push instances or classes
			if seen[k] then
				k = seen[k]
				ks = true
			else push(k, "k") end
		elseif not vs and type(v) == "table" and
						  not class.isClass(v) and
						  not class.isInstance(v) then -- don't push instances or classes
			if seen[v] then
				v = seen[v]
				vs = true
			else push(v, "v") end
		elseif not ms and m and not class.isClass(m) and not class.isInstance(m) then
			if seen[m] then
				m = seen[m]
				ms = true
			else push(m, "m") end
		else
			local nk, nv

			if type(k) == "cdata" then nk = k.copy
			elseif class.isInstance(k) then nk = k:clone()
			else nk = k end

			if type(v) == "cdata" then nv = v.copy
			elseif class.isInstance(v) then nv = v:clone()
			else nv = v end

			c[nk] = nv
			k, v = next(o, k)
			ks, vs = false, false
		end
	end

	return c
end

--function utils.copy(obj) return recursive_copy(obj, {}) end
function utils.copy(obj) return stack_copy(obj) end

-- o = 160
-- recursive_copy up to 20% slower than stack_copy
-- cache issues and overshooting frametime targets probably skewed the results
-- recursive_copy STRONG: 0.1097
-- recursive_copy WEAK: 0.1000
-- stack_copy STRONG: 0.1033
-- stack_copy WEAK: 0.0828

-- o = 128
-- recursive_copy up to 33% slower than stack_copy
-- recursive_copy STRONG: 0.0935
-- recursive_copy WEAK: 0.0935
-- stack_copy STRONG: 0.0848
-- stack_copy WEAK: 0.0701

-- o = 96
-- recursive_copy up to 18% slower than stack_copy
-- recursive_copy STRONG: 0.07289
-- recursive_copy WEAK: 0.0685
-- stack_copy STRONG: 0.06790
-- stack_copy WEAK: 0.05796

-- o = 32
-- recursive_copy only up to 4%, but still slower than stack_copy
-- disparity between weak and strong type checking is much less pronounced
-- recursive_copy STRONG: 0.042128
-- recursive_copy WEAK: 0.039935
-- stack_copy STRONG: 0.040997
-- stack_copy WEAK: 0.038278

function utils.readOnly(name, key, ...)
	utils.checkArg("name", name, "string", "utils.readOnly")
	utils.checkArg("key", key, "string", "utils.readOnly")

	for q, query in ipairs({...}) do
		utils.checkArg(string.format("vararg[%s]", q), query, "string", "readOnly")

		if key == query then
			utils.formatError("Attempted to set key of indexable '%s' that is read-only: %q", name, key) end
	end
end

function utils.switch(to)
	flux.to(utils, 0.25, { fade = 1 }):ease("quadout"):oncomplete(function()
		humpstate.switch(to) end)
end

function utils.fadeIn()
	flux.to(utils, 0.25, { fade = 0 }):ease("quadout")
end

function utils.draw()
	lg.push("all")
		stache.setColor("black", utils.fade)
		lg.rectangle("fill", 0, 0, lg.getDimensions())
	lg.pop()
end

function utils.drawDebug()
	if DEBUG_POINT then utils.drawCircle(DEBUG_POINT, 4, "yellow") end
	if DEBUG_LINE then utils.drawLine(DEBUG_LINE.p1, DEBUG_LINE.p2, "yellow") end
	if DEBUG_NORM then utils.drawNormal(DEBUG_NORM.pos, DEBUG_NORM.normal, "yellow") end
	if DEBUG_CIRC then utils.drawCircle(DEBUG_CIRC.pos, DEBUG_CIRC.radius, "yellow") end
end

function utils.sendColor(shader, uniform, ...)
	if shader:hasUniform(uniform) then
		shader:sendColor(uniform, ...) end
end

function utils.send(shader, uniform, ...)
	if shader:hasUniform(uniform) then
		shader:send(uniform, ...) end
end

function utils.glslRotator(angle)
	utils.checkArg("angle", angle, "number", "utils.glslRotator")

	local c = math.cos(angle)
	local s = math.sin(angle)

	return { c, -s, s, c }
end

function utils.drawCircle(pos, radius, color, alpha)
	utils.checkArg("pos", pos, "vector", "utils.drawCircle")
	utils.checkArg("radius", radius, "number", "utils.drawCircle", true)
	utils.checkArg("color", color, "asset", "utils.drawCircle", true)
	utils.checkArg("alpha", alpha, "number", "utils.drawCircle", true)

	radius = radius or 1
	color = color or "white"
	alpha = alpha or 1

	lg.push("all")
		lg.translate(pos.x, pos.y)
		stache.setColor(color, alpha)
		lg.circle("line", 0, 0, radius)
		stache.setColor(color, 0.4 * alpha)
		lg.circle("fill", 0, 0, radius)
		stache.setColor(color, 0.8 * alpha)
		lg.circle("fill", 0, 0, 1)
	lg.pop()
end

function utils.drawBox(pos, angle, hwidth, hlength, radius, color, alpha)
	utils.checkArg("pos", pos, "vector", "utils.drawBox")
	utils.checkArg("angle", angle, "number", "utils.drawBox")
	utils.checkArg("hwidth", hwidth, "number", "utils.drawBox")
	utils.checkArg("hlength", hlength, "number", "utils.drawBox")
	utils.checkArg("radius", radius, "number", "utils.drawBox", true)
	utils.checkArg("color", color, "asset", "utils.drawBox", true)
	utils.checkArg("alpha", alpha, "number", "utils.drawBox", true)

	radius = radius or 0
	color = color or "white"
	alpha = alpha or 1

	lg.push("all")
		lg.translate(pos.x, pos.y)
		lg.rotate(angle)

		stache.setColor(color, 0.5 * alpha)
		lg.rectangle("line", -hwidth, -hlength, hwidth * 2, hlength * 2)

		hwidth = hwidth + radius
		hlength = hlength + radius

		stache.setColor(color, alpha)
		lg.rectangle("line", -hwidth, -hlength, hwidth * 2, hlength * 2, radius, radius)
		stache.setColor(color, 0.4 * alpha)
		lg.rectangle("fill", -hwidth, -hlength, hwidth * 2, hlength * 2, radius, radius)
		stache.setColor(color, 0.8 * alpha)
		lg.circle("fill", 0, 0, 1)
	lg.pop()
end

function utils.drawLine(p1, p2, color, alpha)
	utils.checkArg("p1", p1, "vector", "utils.drawLine")
	utils.checkArg("p2", p2, "vector", "utils.drawLine")
	utils.checkArg("color", color, "asset", "utils.drawLine", true)
	utils.checkArg("alpha", alpha, "number", "utils.drawLine", true)

	color = color or "white"
	alpha = alpha or 1

	lg.push("all")
		stache.setColor(color, alpha)
		lg.line(p1.x, p1.y, p2.x, p2.y)
	lg.pop()
end

function utils.drawNormal(orig, norm, color, alpha)
	utils.checkArg("orig", orig, "vector", "utils.drawNormal")
	utils.checkArg("norm", norm, "vector", "utils.drawNormal")
	utils.checkArg("color", color, "asset", "utils.drawNormal", true)
	utils.checkArg("alpha", alpha, "number", "utils.drawNormal", true)

	color = color or "white"
	alpha = alpha or 1

	lg.push("all")
		lg.translate(orig.x, orig.y)
		stache.setColor(color, alpha)
		lg.line(0, 0, norm.x, norm.y)
	lg.pop()
end

function utils.drawTangent(orig, tan, color, alpha)
	utils.checkArg("orig", orig, "vector", "utils.drawTangent")
	utils.checkArg("tan", tan, "vector", "utils.drawTangent")
	utils.checkArg("color", color, "asset", "utils.drawTangent", true)
	utils.checkArg("alpha", alpha, "number", "utils.drawTangent", true)

	color = color or "white"
	alpha = alpha or 1

	lg.push("all")
		lg.translate(orig.x, orig.y)
		stache.setColor(color, alpha)
		lg.line(-tan.x, -tan.y, tan.x, tan.y)
	lg.pop()
end

function utils.drawBounds(bounds, color, alpha)
	utils.checkArg("color", color, "asset", "utils.drawBounds", true)
	utils.checkArg("alpha", alpha, "number", "utils.drawBounds", true)

	color = color or "white"
	alpha = alpha or 1

	lg.push("all")
		stache.setColor(color, alpha)
		lg.rectangle("line", bounds.left, bounds.top, bounds.right - bounds.left, bounds.bottom - bounds.top)
	lg.pop()
end

function utils.updateEach(table, ...)
	for t = 1, #table do
		if table[t].update then
			table[t]:update(...) end end
end

function utils.drawEach(table, ...)
	for t = 1, #table do
		if table[t].draw then
			table[t]:draw(...) end end
end

function utils.AABBContains(p1, p2, point)
	utils.checkArg("p1", p1, "vec2", "utils.AABBContains")
	utils.checkArg("p2", p2, "vec2", "utils.AABBContains")
	utils.checkArg("point", point, "vector", "utils.AABBContains")

	return point.x >= p1.x and point.x <= p2.x and
		   point.y >= p1.y and point.y <= p2.y
end

function utils.isVector(obj)
	return vec2.isVec2(obj) or vec3.isVec3(obj) end

function utils.floatEquality(a, b)
	utils.checkArg("a", a, "number", "utils.floatEquality")
	utils.checkArg("b", b, "number", "utils.floatEquality")

	return math.abs(a - b) <= FLOAT_THRESHOLD
end

function utils.nearZero(x)
	utils.checkArg("x", x, "number", "utils.nearZero")

	return math.abs(x) <= FLOAT_THRESHOLD
end

function utils.sign(x) return math.abs(x) <= FLOAT_THRESHOLD and 0 or (x < 0 and -1 or 1) end
function utils.round(x) return math.floor(x + 0.5) end
function utils.clamp(value, lower, upper) return math.min(math.max(lower, value), upper) end
function utils.clamp01(value) return math.min(math.max(0, value), 1) end
function utils.wrap(value, lower, upper) return lower + (value - lower) % (upper - lower) end
function utils.snap(value, interval) return math.floor(value / interval + 0.5) * interval end
function utils.isNaN(x) return x ~= x end

function utils.approach(value, target, rate, callback)
	utils.checkArg("value", value, "number", "utils.approach")
	utils.checkArg("target", target, "number", "utils.approach")
	utils.checkArg("rate", rate, "number", "utils.approach")
	utils.checkArg("callback", callback, "function", "utils.approach", true)

	if value > target then
		value = value - rate
		if value < target then
			value = target
			if callback then callback() end
		end
	elseif value < target then
		value = value + rate
		if value > target then
			value = target
			if callback then callback() end
		end
	end

	return value
end

return setmetatable(utils, utils)
