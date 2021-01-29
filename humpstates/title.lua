titleState = {}

function titleState:enter(from)
	utils.fadeIn()
end

function titleState:draw(rt)
	lg.push("all")
		stache.setColor("white", 0.8)
		stache.setFont("btnfont_rls")

		local ui = UI_SCALE_FLOORED
		local padding = 16 * ui
		local font = lg.getFont()
		local height = stache.getFontBaseline(font)
		local scale = 2 * ui
		local text = "A top-down 2D exploration of the asymmetrical multiplayer genre primarily based on Behaviour Interactive's Dead by Daylight."
		local width, lines = font:getWrap(text, 400 * ui / scale)

		lg.translate(padding, lg.getHeight() - padding)
		lg.translate(0, -height * scale * #lines)
		lg.printf(text, 0, 0, 400 * ui / scale, "left", 0, scale, scale)

		stache.setFont("btnfont_rls", 2)
		scale = 5 * ui
		text = "Dead by Default"
		lg.translate(0, -height * scale)
		lg.print(text, 0, 0, 0, scale, scale)
	lg.pop()
end

function titleState:mousepressed(x, y, button)
	if button == 1 then
		utils.switch(playState) end
end

function titleState:keypressed(key)
	if key == "return" or key == "space" then
		utils.switch(playState) end
end
