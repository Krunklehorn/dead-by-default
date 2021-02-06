local _class = {
	classes = setmetatable({}, { __mode = "k" }),
	instances = setmetatable({}, { __mode = "k" })
}

local _base = {}

-- original, strong checks where registration is required
--function _class.isClass(obj) return not not _class.classes[obj] end
--function _class.isInstance(obj) return not not _class.instances[obj] end

-- weaker but performant checks simply walk metatables
function _class.isClass(obj)
	if type(obj) ~= "table" or obj.class then
		return false end

	while obj do
		local meta = getmetatable(obj)

		if meta == _base then
			return true end

		obj = meta
	end

	return false
end

function _class.isInstance(obj)
	return type(obj) == "table" and (not not obj.class) and _class.isClass(obj.class)
end

function _class.deserialize(data, class)
	if class.deserialize then
		data = class:deserialize(data) end

	return class:register(data)
end

_base.string = tostring(_base)

local function _tostring(obj)
	if obj == _base then
		return string.format("Class 'Base' (%s)", _base.string)
	elseif _class.isClass(obj) then
		return string.format("Class '%s' (%s)", obj.name, _class.classes[obj])
	elseif _class.isInstance(obj) then
		return string.format("Instance of '%s' (%s)", obj.class.name, _class.instances[obj])
	else utils.formatError("Class function '__tostring' called on an object that isn't a class or instance: %q", class) end
end

_base.__index = _base
_base.__tostring = _tostring

function _base.__call(class, ...)
	if not _class.isClass(class) then
		utils.formatError("Attempted to create a new instance from an instance: %q", class) end

	local inst = class:register({ class = class })

	if class.init then
		class.init(inst, ...) end

	return inst
end

function _base.subclassOf(class, other)
	if not _class.isClass(class) then
		utils.formatError("Attempted to call function 'subclassOf' from an instance: %q", class)
	elseif not _class.isClass(other) then
		utils.formatError("%s.subclassOf() called with an 'other' argument that isn't a class: %q", class.name or "?", other) end

	local super = class.super

	while super do
		if super == other then
			return true end

		super = super.super
	end

	return false
end

local function inst_instanceOf(inst, other)
	if not _class.isInstance(inst) then
		utils.formatError("Attempted to call function 'instanceOf' from a class: %q", inst)
	elseif not _class.isClass(other) then
		utils.formatError("%s.instanceOf() called with an 'other' argument that isn't a class: %q", inst.class.name or "?", other) end

	local class = inst.class
	local forward = class.forward

	return class == other or class:subclassOf(other) or (type(forward) == "table" and inst[forward.key]:instanceOf(other))
end

function _base.create(_, name, vars)
	local class = {
		instances = setmetatable({}, { __mode = "k" }),
		name = name,
		instanceOf = inst_instanceOf
	}

	_class.classes[class] = tostring(class)

	if vars then
		for k, v in pairs(vars) do
			class[utils.copy(k)] = utils.copy(v) end end

	class.__index = class
	class.__tostring = _base.__tostring
	class.__call = _base.__call

	setmetatable(class, _base)

	bitser.registerClass(name, class, "class", _class.deserialize)
	bitser.register(name, class)

	return class
end

function _base.extend(class, name, vars)
	if not _class.isClass(class) then
		utils.formatError("Attempted to call function 'extend' from an instance: %q", class) end

	local sub = {
		instances = setmetatable({}, { __mode = "k" }),
		name = name,
		super = class,
		instanceOf = class.instanceOf
	}

	_class.classes[sub] = tostring(sub)

	if vars then
		for k, v in pairs(vars) do
			sub[utils.copy(k)] = utils.copy(v) end end

	sub.__index = class.__index ~= class and class.__index or sub
	sub.__newindex = class.__newindex
	sub.__tostring = class.__tostring
	sub.__call = class.__call

	return setmetatable(sub, class)
end

function _base.register(class, obj)
	if not _class.isClass(class) then
		utils.formatError("Attempted to call function 'register' from an instance: %q", class) end

	utils.checkArg("obj", obj, "table", class.name..":register")

	local string = tostring(obj)

	_class.instances[obj] = string
	class.instances[obj] = string

	return setmetatable(obj, class)
end

function _base.abstract(class, ...)
	if not _class.isClass(class) then
		utils.formatError("Attempted to call function 'abstract' from an instance: %q", class) end

	for f, func in ipairs({...}) do
		utils.checkArg(string.format("vararg[%s]", f), func, "string", "abstract")

		class[func] = function()
			utils.formatError("Abstract function %s:%s() called!", class.name, func) end
	end

	return class
end

function _base.forward(class, key, members)
	if not _class.isClass(class) then
		utils.formatError("Attempted to call function 'forward' from an instance: %q", class) end

	utils.checkArg("key", key, "string", class.name..":forward")
	utils.checkArg("members", members, "table", class.name..":forward")

	class.forward = {
		key = key,
		members = {}
	}

	for m = 1, #members do
		class.forward.members[members[m]] = true end

	return class
end

function _base.readOnly(class, key, ...)
	if not _class.isClass(class) then
		utils.formatError("Attempted to call function 'readOnly' from an instance: %q", class) end

	utils.checkArg("key", key, "string", class.name..":readOnly")

	for q, query in ipairs({...}) do
		utils.checkArg(string.format("vararg[%s]", q), query, "string", class.name..":readOnly")

		if key == query then
			utils.formatError("Attempted to set a key of class '%s' that is read-only: %q", class.name, key) end
	end
end

function _base.checkSet(obj, key, value, query, nillable, copy)
	local class = _class.isClass(obj) and obj or obj.class

	if value == nil and nillable == true then
		return
	else
		if query == "number" or query == "string" or query == "boolean" or query == "table" or query == "function" or query == "cdata" then
			if type(value) ~= query then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a %s: %q", key, class, query, value)
			end
		elseif query == "indexable" then
			if type(value) ~= "table" and type(value) ~= "cdata" then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't indexable: %q", key, class, value)
			end
		elseif query == "vec2" then
			if not vec2.isVec2(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a vec2: %q", key, class, value)
			end

			copy = true
		elseif query == "vec3" then
			if not vec3.isVec3(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a vec3: %q", key, class, value)
			end

			copy = true
		elseif query == "vector" then
			if not utils.isVector(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a vector: %q", key, class, value)
			end

			copy = true
		elseif query == "number/vector" then
			if type(value) ~= "number" and not vec2.isVec2(value) and not vec3.isVec3(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a scalar or vector: %q", key, class, value)
			end

			copy = true
		elseif query == "collider" then
			if not Collider.isCollider(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a collider: %q", key, class, value)
			end

			copy = true
		elseif query == "brush" then
			if not Brush.isBrush(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a brush: %q", key, class, value)
			end

			copy = true
		elseif query == "trigger" then
			if not Trigger.isTrigger(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a trigger: %q", key, class, value)
			end

			copy = true
		elseif query == "agent" then
			if not Agent.isAgent(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't an agent: %q", key, class, value)
			end

			copy = true
		elseif query == "entity" then
			if not Entity.isEntity(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't an entity: %q", key, class, value)
			end

			copy = true
		elseif query == "pointer" then
			if not world.isPointer(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a pointer: %q", key, class, value)
			end
		elseif query == "asset" then
			if type(value) ~= "string" and type(value) ~= "table" and type(value) ~= "userdata" then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a string, table or userdata: %q", key, class, value)
			end
		elseif query == "ctype" then
			query = type(value) == "string" and ffi.typeof(value) or value
			if tostring(query):sub(1, 5) ~= "ctype" then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a string or ctype: %q", key, class, value)
			end
			value = query
		elseif query == "class" then
			if not _class.isClass(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't a class: %q", key, class, value)
			end
		elseif query == "instance" then
			if not _class.isInstance(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't an instance: %q", key, class, value)
			end
		elseif query == "index/instance" then
			if type(value) ~= "number" and not _class.isInstance(value) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't an index or instance: %q", key, class, value)
			end
		elseif _class.isClass(query) or _class.isClass(instance) then
			query = _class.isClass(query) and query or query.class

			if not value:instanceOf(query) then
				utils.formatError("Attempted to set '%s' key of class '%s' to a value that isn't an instance of class '%s': %q", key, class, query.name, value)
			end
		else
			utils.formatError("checkSet() called with a query that hasn't been setup for type-checking yet: %q", query)
		end
	end

	return copy and utils.copy(value) or value
end

setmetatable(_base, { __tostring = _tostring })

return setmetatable(_class, { __call = _base.create } )
