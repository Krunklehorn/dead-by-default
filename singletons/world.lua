local ffi = require "ffi"

local world = {
	ids = {},
	commands = {},
	states = {},
	pointers = setmetatable({}, { __mode = "kv" }),
	nextID = OBJ_ID_BASE,
	cursor = 1,
	roll = 0
}

for i = 1, NET_RING_FRAMES do
	world.commands[i] = {}
	world.states[i] = {
		brushes = {},
		triggers = {},
		agents = {},
		entities = {}
	}
end

function world.wrap(i) return utils.wrap(i, 1, NET_RING_FRAMES + 1) end
function world.curr() return world.wrap(world.cursor - world.roll) end
function world.prev() return world.wrap(world.cursor - world.roll - 1) end

function world.__index(_, key)
	if key == "brushes" or key == "triggers" or
	   key == "agents" or key == "entities" then
		   return world.states[world.curr()][key] end
end

function world.__newindex(_, key, value)
	if key == "brushes" or key == "triggers" or
	   key == "agents" or key == "entities" then
		   world.states[world.curr()][key] = value
	else rawset(world, key, value) end
end

function world.init()
	world.addObject(BoxBrush, { hwidth = UNIT_TILE, height = 128 })

	--[[local function randVec(hl)
		return vec2(lmth.random(-hl, hl), lmth.random(-hl, hl)) end

	local l = 1
	io.write("SDF_MAX_BRUSHES: "..SDF_MAX_BRUSHES.."\n")
	io.write("HEIGHT LEVELS: "..l.."\n")
	io.write("TOTAL BRUSHES: "..l * SDF_MAX_BRUSHES.."\n")

	for h = 1, l do
		for i = 1, SDF_MAX_BRUSHES do
			local type = lmth.random(1, 3)
			local height = 128 + h * 16

			if type == 1 then
				local p = randVec(UNIT_TILE)
				local d = p.normalized * (UNIT_TILE - p.length) * 0.5
				world.addObject(CircleBrush, { pos = p + d,
											  radius = lmth.random(25, 100),
											  height = height })
			elseif type == 2 then
				local p = randVec(UNIT_TILE)
				local d = p.normalized * (UNIT_TILE - p.length) * 0.5
				world.addObject(BoxBrush, { pos = p + d,
										   radius = lmth.random(0, 20),
										   hwidth = lmth.random(25, 100),
										   hlength = lmth.random(25, 100),
										   height = height })
			elseif type == 3 then
				local c = randVec(UNIT_TILE) - vec2(400)
				local o1 = vec2(lmth.random(0, 400), lmth.random(0, 400))
				local o2 = vec2(lmth.random(0, 400), lmth.random(0, 400))
				local d = c.normalized * (UNIT_TILE - c.length) * 0.5
				world.addObject(LineBrush, { p1 = c + o1 + d,
											p2 = c + o2 + d,
											radius = 20,
											height = height })
			end
		end
	end]]

	world.addObject(BoxTrigger, { hwidth = UNIT_TILE * 2, height = 0, onOverlap = function()
		local agent = Trigger.agent
		agent.pos = agent.pos:clamped(-(UNIT_TILE - 100), UNIT_TILE - 100)
		agent.pos.z = 128
		agent.vel = vec3()
		agent:changeState("air")
	end})

	world.addObject(Agent, { pos = vec3(0, 0, 128), radius = 35, color = "cyan" })

	world.addObject(Light, { pos = vec3(200, 0, 144), color = vec3(1, 0, 1), intensity = 1 })
	world.addObject(Light, { pos = vec3(-200, 0, 144), color = vec3(0, 1, 1), intensity = 1 })

	world.addObject(Decal, { pos = vec3(-200, -200, 144), tex = "parallax_floor", hwidth = 200 })
	world.addObject(Decal, { pos = vec3(200, -200, 144), tex = "parallax_floor", hwidth = 200 })
	world.addObject(Decal, { pos = vec3(-200, 200, 144), tex = "parallax_floor", hwidth = 200 })
	world.addObject(Decal, { pos = vec3(200, 200, 144), tex = "parallax_floor", hwidth = 200 })

	--world.load()
	--world.save()
end

function world.update(tl)
	for a = 1, #world.agents do
		local agent = world.agents[a]
		agent:input(world.commands[world.curr()][agent.id] or input.empty)
	end

	utils.updateEach(world.agents, tl)
	utils.updateEach(world.entities, tl)
	utils.updateEach(world.triggers, tl)
end

function world.draw(rt)
	-- TODO: BLEND CURRENT WITH PREVIOUS
	Brush.batchSDF(world.brushes, world.entities)
	utils.drawEach(world.agents)
	utils.drawEach(world.entities)
end

function world.newID()
	world.nextID = world.nextID + 1

	while world.ids[world.nextID] do
		world.nextID = world.nextID + 1 end

	return world.nextID
end

function world.getObjectArray(obj)
	utils.checkArg("obj", obj, "indexable", "world.getObjectArray")

	return Brush.isBrush(obj) and world.brushes or
		   (Trigger.isTrigger(obj) and world.triggers or
		   (Agent.isAgent(obj) and world.agents or
		   (Entity.isEntity(obj) and world.entities or nil)))
end

function world.addObject(ctor, params)
	utils.checkArg("ctor", ctor, "table", "world.addObject")
	utils.checkArg("params", params, "table", "world.addObject")

	local obj = ctor(params)
	world.insertObject(obj)

	return obj
end

function world.insertObject(obj)
	utils.checkArg("obj", obj, "indexable", "world.insertObject")

	local array = world.getObjectArray(obj)

	if array then
		local id = world.newID()

		obj:setID(id)

		if Brush.isBrush(obj) or Trigger.isTrigger(obj) then
			local i = 1

			while i <= #array do
				if obj.height < array[i].height then
					break end

				i = i + 1
			end

			table.insert(array, i, obj)
		elseif Agent.isAgent(obj) or Entity.isEntity(obj) then
			array[#array + 1] = obj
		end

		array[id] = obj
		world.ids[id] = obj
	else
		for o = 1, #obj do
			world.insertObject(obj[o]) end
	end
end

function world.removeObject(obj)
	utils.checkArg("obj", obj, "indexable", "world.removeObject")

	local array = world.getObjectArray(obj)

	if array then
		for i = 1, #array do
			if obj == array[i] then
				table.remove(array, i)
				array[obj.id] = nil
				return
			end
		end
	else
		for o = 1, #obj do
			world.removeObject(obj[o]) end

		return
	end

	utils.formatError("world.removeObject() called with a reference that should not exist: %q", obj)
end

function world.rollback(n)
	n = utils.checkArg("n", n, "number", "world.rollback", true, NET_ROLLBACK_FRAMES)

	if n < 1 or n > NET_ROLLBACK_FRAMES then
		utils.formatError("world.rollback() called with an invalid 'n' argument: %q", n)
	elseif world.roll > 0 then
		utils.formatError("Attempted to call world.rollback() during a rollback: %q", world.roll) end

	world.roll = n

	world.copy()
end

function world.step()
	if world.roll > 0 then world.roll = world.roll - 1
	else world.cursor = world.wrap(world.cursor + 1) end

	world.copy()
end

local function overwrite(prev, curr)
	for k, v in pairs(curr) do
		if k > OBJ_ID_BASE then
			curr[k] = nil end end

	for i = 1, math.max(#prev, #curr) do
		if i <= #prev then
			local obj = prev[i].copy

			curr[i] = obj
			curr[obj.id] = obj
		else curr[i] = nil end
	end
end

function world.copy() -- ugly, but performant
	local prev = world.states[world.prev()]
	local curr = world.states[world.curr()]

	overwrite(prev.brushes, curr.brushes)
	overwrite(prev.triggers, curr.triggers)
	overwrite(prev.agents, curr.agents)
	overwrite(prev.entities, curr.entities)

	world.dirty()
end

function world.dirty()
	for _, pointer in pairs(world.pointers) do
		pointer.dirty() end
end

function world.save()
	local objects = {}

	for b = 1, #world.brushes do objects[#objects + 1] = world.brushes[b] end
	for b = 1, #world.entities do objects[#objects + 1] = world.entities[b] end

	local string = bitser.dumps(objects)
	local success, msg = lfs.write("brushes.dat", string)

	if not success then
		error(msg) end
end

function world.load()
	if lfs.getInfo("brushes.dat") then
		local string, msg = lfs.read("brushes.dat")

		if not string then
			error(msg) end

		utils.clear(world.brushes)
		utils.clear(world.entities)
		world.insertObject(bitser.loads(string))
	end
end

function world.isPointer(obj) return not not world.pointers[obj] end

function world.pointer(path)
	utils.checkArg("path", path, "table", "world.pointer")

	local value = nil
	local pointer = {}
	local string = tostring(pointer)

	pointer.__call = function()
		if not value then
			value = world

			for k = 1, #path do
				if not value then
					local strings = { "Failed to resolve a pointer path: %q" }

					for k = 1, #path do
						strings[#strings + 1] = ", %q" end

					utils.formatError(table.concat(strings), world, unpack(path))
				else value = value[path[k]] end
			end
		end

		return value
	end

	pointer.__index = function(self, key)
		return self()[key] end

	pointer.__tostring = function(self)
		return string.format("Pointer (%s) -> %s", string, self()) end

	pointer.dirty = function()
		value = nil end

	world.pointers[pointer] = pointer

	return setmetatable(pointer, pointer)
end

return setmetatable(world, world)
