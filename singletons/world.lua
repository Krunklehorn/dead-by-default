local ffi = require "ffi"

local world = {
	commands = {},
	states = {}
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

function world.__index(_, key)
	if key == "brushes" or key == "triggers" or
	   key == "agents" or key == "entities" then
		   return world.states[ring.curr()][key] end
end

function world.__newindex(_, key, value)
	if key == "brushes" or key == "triggers" or
	   key == "agents" or key == "entities" then
		   world.states[ring.curr()][key] = value
	else rawset(world, key, value) end
end

function world.init()
	world.addBrush(BoxBrush, { hwidth = UNIT_TILE, height = 128 })

	local function randVec(hl)
		return vec2(lmth.random(-hl, hl), lmth.random(-hl, hl)) end

	local l = 4
	io.write("SDF_MAX_BRUSHES: "..SDF_MAX_BRUSHES.."\n")
	io.write("HEIGHT LEVELS: "..l.."\n")
	io.write("TOTAL BRUSHES: "..l * SDF_MAX_BRUSHES.."\n")

	--[[for h = 1, l do
		for i = 1, SDF_MAX_BRUSHES do
			local type = lmth.random(1, 3)
			local height = 128 + h * (128 / l)

			if type == 1 then
				local p = randVec(UNIT_TILE)
				world.addBrush(CircleBrush, { pos = p,
											  radius = lmth.random(25, 100),
											  height = height })
			elseif type == 2 then
				local p = randVec(UNIT_TILE)
				world.addBrush(BoxBrush, { pos = p,
										   radius = lmth.random(0, 20),
										   hwidth = lmth.random(25, 100),
										   hlength = lmth.random(25, 100),
										   height = height })
			elseif type == 3 then
				local c = randVec(UNIT_TILE) - vec2(200)
				local o1 = vec2(lmth.random(0, 400), lmth.random(0, 400))
				local o2 = vec2(lmth.random(0, 400), lmth.random(0, 400))
				world.addBrush(LineBrush, { p1 = c + o1,
											p2 = c + o2,
											radius = 20,
											height = height })
			end
		end
	end]]

	world.load()
	--world.save()

	world.addTrigger(BoxTrigger, { hwidth = UNIT_TILE * 2, height = 0, onOverlap = function()
		local agent = Trigger.agent
		agent.pos = agent.pos:clamped(-(UNIT_TILE - 100), UNIT_TILE - 100)
		agent.pos.z = 128
		agent.vel = vec3()
		agent:changeState("air")
	end})

	world.addAgent{ pos = vec3(0, 0, 128), radius = 35, color = "cyan" }
	world.addAgent{ pos = vec3(-200, 0, 128), radius = 45, angle = math.rad(85), color = "red" }

	--world.addAgent{ pos = vec3(-200, 0, 128), radius = 40, color = "cyan" }
	--world.addAgent{ pos = vec3(200, 0, 128), radius = 60, color = "red" }

	world.addEntity(Light, { pos = vec3(-125, -150, 160), color = vec3(1, 1, 0), intensity = 0.2, range = 800 })
	world.addEntity(Light, { pos = vec3(-125, -150, 160), color = vec3(1, 0.5, 0), intensity = 0.8, range = 70 })
	world.addEntity(Light, { pos = vec3(-4000, -4000, 160), color = vec3(1, 1, 2 / 3), intensity = 0.2, range = 12000, radius = 400 })
	world.addEntity(Light, { pos = vec3(0, 0, 176), color = vec3(0, 1, 0), intensity = 0.1, range = 4000 })

	world.addEntity(Vault, { pos = vec3(300, -50, 128), angle = math.rad(90) })
end

function world.update(tl)
	for a, agent in ipairs(world.agents) do
		agent:input(world.commands[ring.curr()][a] or input.empty) end

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

function world.copy() -- ugly, but performant
	local prev = world.states[ring.prev()]
	local curr = world.states[ring.curr()]
	local p, c

	p = prev.brushes
	c = curr.brushes
	for i = 1, math.max(#p, #c) do
		c[i] = i <= #p and p[i].copy or nil end

	p = prev.triggers
	c = curr.triggers
	for i = 1, math.max(#p, #c) do
		c[i] = i <= #p and p[i].copy or nil end

	p = prev.agents
	c = curr.agents
	for i = 1, math.max(#p, #c) do
		c[i] = i <= #p and p[i].copy or nil end

	p = prev.entities
	c = curr.entities
	for i = 1, math.max(#p, #c) do
		c[i] = i <= #p and p[i].copy or nil end
end

function world.save()
	local string = bitser.dumps(world.brushes)
	local success, msg = lfs.write("brushes.dat", string)

	if not success then
		error(msg) end
end

function world.load()
	if lfs.getInfo("brushes.dat") then
		local string, msg = lfs.read("brushes.dat")

		if not string then
			error(msg) end

		world.brushes = bitser.loads(string)
	end
end

function world.addBrush(ctor, params)
	utils.checkArg("ctor", ctor, "table", "world.addBrush")
	utils.checkArg("params", params, "table", "world.addBrush")

	local brush = ctor(params)
	local b = 1

	while b <= #world.brushes do
		if brush.height < world.brushes[b].height then
			break end

		b = b + 1
	end

	table.insert(world.brushes, b, brush)

	return brush, b
end

function world.addTrigger(ctor, params)
	utils.checkArg("ctor", ctor, "table", "world.addTrigger")
	utils.checkArg("params", params, "table", "world.addTrigger")

	local trigger = ctor(params)
	local t = 1

	while t <= #world.triggers do
		if trigger.height < world.triggers[t].height then
			break end

		t = t + 1
	end

	table.insert(world.triggers, t, trigger)

	return trigger, t
end

function world.addAgent(params)
	utils.checkArg("params", params, "table", "world.addAgent")

	local agent = Agent(params)
	world.agents[#world.agents + 1] = agent

	return agent
end

function world.addEntity(ctor, params)
	utils.checkArg("ctor", ctor, "table", "world.addEntity")
	utils.checkArg("params", params, "table", "world.addEntity")

	if ctor == Agent then
		utils.formatError("Attempted to add an Agent to the array of entities!") end

	local entity = ctor(params)
	world.entities[#world.entities + 1] = entity

	return entity
end

function world.removeBrush(this)
	utils.checkArg("this", this, "brush", "world.removeBrush")

	if type(this) == "number" then
		return table.remove(world.brushes, this)
	else
		if not Brush.isBrush(this) then
			stache.formatError("world.removeBrush() called with a 'this' argument that isn't a brush: %q", this) end

		for b = 1, #world.brushes do
			if this == world.brushes[b] then
				return table.remove(world.brushes, b) end end

		stache.formatError("world.removeBrush() called with a reference that should not exist: %q", this)
	end
end

function world.removeTrigger(this)
	utils.checkArg("this", this, "trigger", "world.removeTrigger")

	if type(this) == "number" then
		return table.remove(world.triggers, this)
	else
		if not this:instanceOf(Trigger) then
			stache.formatError("world.removeTrigger() called with a 'this' argument that isn't of type 'Trigger': %q", this) end

		for t, that in ipairs(world.triggers) do
			if this == that then
				return table.remove(world.triggers, t) end end

		stache.formatError("world.removeTrigger() called with a reference that should not exist: %q", this)
	end
end

function world.removeAgent(this)
	utils.checkArg("this", this, "index/reference", "world.removeAgent")

	if type(this) == "number" then
		return table.remove(world.agents, this)
	else
		if not this:instanceOf(Agent) then
			stache.formatError("world.removeAgent() called with a 'this' argument that isn't of type 'Agent': %q", this) end

		for a, that in ipairs(world.agents) do
			if this == that then
				return table.remove(world.agents, a) end end

		stache.formatError("world.removeAgent() called with a reference that should not exist: %q", this)
	end
end

function world.removeEntity(this)
	utils.checkArg("this", this, "index/reference", "world.removeEntity")

	if type(this) == "number" then
		return table.remove(world.entities, this)
	else
		if not this:instanceOf(Entity) then
			stache.formatError("world.removeEntity() called with a 'this' argument that isn't of type 'Entity': %q", this) end

		for e, that in ipairs(world.entities) do
			if this == that then
				return table.remove(world.entities, e) end end

		stache.formatError("world.removeEntity() called with a reference that should not exist: %q", this)
	end
end

return setmetatable(world, world)