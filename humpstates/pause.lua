pauseState = {
	camera = nil
}

function pauseState:enter(from)
	self.camera = from.camera
end

function pauseState:draw(rt)
	local width, height = lg.getDimensions()

	Background.drawEach(playState.backgrounds, playState.camera)

	playState.camera:attach()

	world.draw(rt)
	utils.drawDebug()

	playState.camera:detach()

	lg.push("all")
		stache.setColor("black", 0.5)
		lg.rectangle("fill", 0, 0, width, height)

		stache.setColor("white", 0.8)
		stache.setFont("btnfont_rls")
		stache.printf{50 * UI_SCALE_FLOORED, "Paused", width / 2, height / 2, xalign = "center", yalign = "center"}
	lg.pop()
end

function pauseState:keypressed(key)
	if key == "p" then
		humpstate.pop()
	elseif key == "escape" then
		le.quit()
	end
end
