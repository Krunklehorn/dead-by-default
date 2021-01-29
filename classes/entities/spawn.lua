Spawn = Entity:extend("Spawn", {
	agent = nil,
	killer = nil
})

function Spawn:init(params)
	local agent = utils.checkArg("agent", params[1] or params.agent, "boolean", "Spawn:init", true)
	local killer = utils.checkArg("killer", params[2] or params.killer, "boolean", "Spawn:init", true)

	self.agent = agent or true
	self.killer = killer or true
end

function Spawn:draw()
	if self.agent then
		utils.drawCircle(self.pos, 45, "cyan", 0.25) end

	if self.killer then
		utils.drawCircle(self.pos, 60, "red", 0.25) end

	utils.drawCircle(self.pos, 10, "magenta", 0.5)
	utils.drawLine(self.pos, self.pos + self.forward * 100, "magenta", 0.5)
end
