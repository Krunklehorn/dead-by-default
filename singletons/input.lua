local input = {
	players = {
		active = nil
	},
	empty = {
		adelta = vec2(),
		right = 0,
		left = 0,
		down = 0,
		up = 0,
		run = false,
		crouch = false,
		action = false,
		ability = false,
		drop = false
	},
	mouserate = 1 / 360,
	stickrate = 360
}

function input.__index(_, key)
	if type(key) == "number" then
		if key > #input.players then
			utils.formatError("Attempted to get input state for a player index out of bounds: %q", key) end

		return input.players[key]
	end
end

function input.__newindex(_, key, value)
	if type(key) == "number" then
		if key > #input.players then
			utils.formatError("Attempted to set input state for a player index out of bounds: %q", key) end

		input.players[key] = value
	else rawset(input, key, value) end
end

function input.init()
	local player = input.addPlayer{}

	-- Force default binds for now
	player:bind("a", "left")
	player:bind("d", "right")
	player:bind("w", "up")
	player:bind("s", "down")
	player:bind("q", "look_left")
	player:bind("e", "look_right")
	player:bind("lshift", "run")
	player:bind("lctrl", "crouch")
	player:bind("c", "crouch")
	player:bind("space", "action")
	player:bind("f", "ability")
	player:bind("r", "drop")

	input.players.active = player
end

function input.translate(tl)
	local commands = world.commands[world.curr()]

	for i, v in ipairs(commands) do -- TODO: sloppy, make this an ffi struct when Agent becomes one
		commands[i] = nil end

	for p = 1, #input.players do
		local player = input.players[p]

		if player.agentPtr and player.agentPtr() then
			local lookleft = player:down("look_left") and 1 or 0
			local lookright = player:down("look_right") and 1 or 0
			local adelta = receiver.mdelta * input.mouserate / tl

			adelta.x = adelta.x + math.rad(lookright - lookleft) * input.stickrate

			commands[player.agentId] = {
				adelta = adelta,
				right = player:down("right") and 1 or 0,
				left = player:down("left") and 1 or 0,
				down = player:down("down") and 1 or 0,
				up = player:down("up") and 1 or 0,
				run = player:down("run"),
				crouch = player:down("crouch"),
				action = player:press("action"),
				ability = player:press("ability"),
				drop = player:release("drop")
			}
		end
	end

	receiver.step()
end

function input.draw() input.players.active:draw() end

function input.addPlayer(params)
	utils.checkArg("params", params, "table", "input.addPlayer")

	local player = Player(params)
	input.players[#input.players + 1] = player

	return player
end

return setmetatable(input, input)
