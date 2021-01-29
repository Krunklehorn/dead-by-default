introState = {
	splash = nil
}

function introState:enter(from)
	self.splash = o_ten_one{background = stache.colors.black}
	self.splash.onDone = function() utils.switch(titleState) end
end

function introState:update(tl)
	self.splash:update(tl)
end

function introState:draw(rt)
	self.splash:draw()
end

function introState:mousepressed(x, y, button)
	if button == 1 then
		self.splash:skip() end
end

function introState:keypressed(key)
	if key == "return" or key == "space" then
		self.splash:skip() end
end
