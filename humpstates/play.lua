playState = {
	camera = nil,
	backgrounds = {}
}

function playState:init()
	local agentHndl = ring.handle(world, { "agents", 1 })
	input.players.active.agentHndl = agentHndl
	input.players.active.agentIndx = 1

	self.camera = Camera{scale = 0.5, pblend = 0.85}
	self.camera:setPTarget(agentHndl, "pos", true)
	self.camera:setATarget(agentHndl, "look", true)

	self:addBackground{"parallax_grid", alpha = 1 / 3.0}
end

function playState:enter(from)
	local agentHndl = ring.handle(world, { "agents", 1 })

	utils.fadeIn()

	lm.setRelativeMode(true)
	input.players.active.agentHndl = agentHndl
	input.players.active.agentIndx = 1

	if from == editState then
		self.camera.pos = editState.camera.pos
		self.camera.angle = editState.camera.angle
		self.camera.scale = editState.camera.scale
		self.camera:setPTarget(agentHndl, "pos")
		self.camera:setATarget(agentHndl, "look")
		self.camera.starget = 0.5
		self.camera.pblend = 1
		self.camera.ablend = 1
		self.camera.sblend = 1
		flux.to(self.camera, 0.5, { pblend = 0.85 }):ease("quadout")
		flux.to(self.camera, 0.5, { ablend = 0 }):ease("quadout")
		flux.to(self.camera, 0.5, { sblend = 0 }):ease("quadout")
	end
end

function playState:pause(to)
	lm.setRelativeMode(false)
	input.players.active.agentHndl = nil
	input.players.active.agentIndx = nil
end

function playState:resume(from)
	utils.fadeIn()

	lm.setRelativeMode(true)
	input.players.active.agentHndl = ring.handle(world, { "agents", 1 })
	input.players.active.agentIndx = 1
end

function playState:leave(to)
	lm.setRelativeMode(false)
	input.players.active.agentHndl = nil
	input.players.active.agentIndx = nil
end

function playState:update(tl)
	self.camera:update(tl)
end

function playState:draw(rt)
	Background.drawEach(self.backgrounds, self.camera)

	self.camera:attach()

	world.draw(rt)
	utils.drawDebug()

	self.camera:detach()

	if DEBUG_DRAW then
		input.draw()

		local scale = UI_SCALE_FLOORED
		stache.setFont(stache.fonts.consola)

		lg.translate(0, 5 * scale)
		stache.setColor("white", 0.8)
		stache.printf{40 * scale, Agent.enumToString(input.players.active.agentHndl.action), 5}

		if DEBUG_SLEEP and stopwatch.string then
			lg.push("all")
				lg.translate(lg.getWidth() - 510 * scale, 0)
				stache.setColor("white", 0.8)
				stache.printf{20 * scale, stopwatch.string, 5}
			lg.pop()
		end

		if stopwatch.lagging() then
			lg.push("all")
				lg.translate(lg.getWidth() - 35 * scale, 0)
				stache.setColor("yellow", 0.8)
				stache.printf{50 * scale, "!", 5}
			lg.pop()
		end

		if DEBUG_ROLLBACK then
			lg.push("all")
				lg.translate(lg.getWidth() - 40 * scale, 45 * scale)
				stache.setColor("red", 0.8)
				stache.printf{30 * scale, "<<", 5}
			lg.pop()
		end
	end
end

function playState:keypressed(key)
	if key == "backspace" then
		humpstate.switch(editState)
	elseif key == "p" then
		humpstate.push(pauseState)
	end
end

function playState:addBackground(params)
	utils.checkArg("params", params, "table", "playState:addBackground")

	local background = Background(params)
	self.backgrounds[#self.backgrounds + 1] = background

	return background
end