Player = class("Player")

function Player:init(params)
	local binds = utils.checkArg("binds", params[1] or params.binds, "table", "Player:init", true)
	local agentPtr = utils.checkArg("agentPtr", params[2] or params.agentPtr, "handle", "Player:init", true)
	local agentId = utils.checkArg("agentId", params[3] or params.agentId, "number", "Player:init", true)

	self.binds = binds or {}
	self.agentPtr = agentPtr or nil
	self.agentId = agentId or nil
end

function Player:clone()
	if not self:instanceOf(Player) then
		utils.formatError("Player:clone() called for an instance that isn't a Player: %q", self) end

	return self.class:register({
		class = Player,
		binds = self.binds,
		agentPtr = self.agentPtr,
		agentId = self.agentId
	})
end

local sprites = stache.sprites

local function drawPushed(player, event, sprite, x, y)
	lg.translate(x, y)

	if player:down(event) then
		stache.setColor("white", 0.8)
		lg.draw(sprites[sprite.."_prs"])
	else
		stache.setColor("white", 0.4)
		lg.draw(sprites[sprite.."_rls"])
	end
end

function Player:draw()
	local scale = UI_SCALE_FLOORED

	lg.push("all")
		lg.scale(scale * 2)
		lg.translate(-8, -8)
		lg.translate(0, lg.getHeight() / (scale * 2))

		drawPushed(self, "up", "arrowbtn_up", 40, -55)
		drawPushed(self, "down", "arrowbtn_down", 0, 20)
		drawPushed(self, "left", "arrowbtn_left", -20, 0)
		drawPushed(self, "right", "arrowbtn_right", 40, 0)
		drawPushed(self, "action", "spacebtn", -44, 20)
		drawPushed(self, "crouch", "crouchbtn", 48, 0)
	lg.pop()
end

function Player:bind(key, event)
	local keys = self.binds[event]

	if not keys then
		keys = {}
		self.binds[event] = keys
	end

	keys[#keys + 1] = key
end

function Player:down(event)
	local keys = self.binds[event]

	for k = 1, #keys do
		if receiver.curr[keys[k]] then
			return true end end

	return false
end

function Player:press(event)
	local keys = self.binds[event]

	for k = 1, #keys do
		if receiver.curr[keys[k]] and
		   not receiver.prev[keys[k]] then
			   return true end end

	return false
end

function Player:release(event)
	local keys = self.binds[event]

	for k = 1, #keys do
		if receiver.prev[keys[k]] and not receiver.curr[keys[k]] then
			return true end end

	return false
end
