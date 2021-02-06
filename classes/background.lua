Background = class("Background", {
	overdraw = nil,
	canvas = nil
})

function Background:init(params)
	local sprite = utils.checkArg("sprite", params[1] or params.sprite, "asset", "Background:init")
	local offset = utils.checkArg("offset", params[2] or params.offset, "vec2", "Background:init", true)
	local scale = utils.checkArg("scale", params[3] or params.scale, "vec2", "Background:init", true)
	local scroll = utils.checkArg("scroll", params[4] or params.scroll, "vec2", "Background:init", true)
	local color = utils.checkArg("color", params[5] or params.color, "asset", "Background:init", true)
	local alpha = utils.checkArg("alpha", params[6] or params.alpha, "number", "Background:init", true)

	self.sprite = stache.getAsset("sprite", sprite, stache.sprites, "Background:init")
	self.offset = offset or vec2()
	self.scale = scale or vec2(1)
	self.scroll = scroll or vec2(1)
	self.color = color or "white"
	self.alpha = alpha or 1
	self.quad = lg.newQuad(0, 0, 0, 0, 0, 0)
end

function Background:clone()
	if not self:instanceOf(Background) then
		utils.formatError("Background:clone() called for an instance that isn't a Background: %q", self) end

	return self.class:register({
		class = Background,
		sprite = self.sprite,
		offset = self.offset.copy,
		scale = self.scale.copy,
		scroll = self.scroll.copy,
		color = self.color,
		alpha = self.alpha,
		quad = lg.newQuad(0, 0, 0, 0, 0, 0)
	})
end

function Background:draw(camera)
	local center = camera:getWindowCenter()
	local overdraw = Background.overdraw / camera.scale / UI_SCALE * 2
	local sdw = self.sprite:getWidth() * self.scale.x
	local sdh = self.sprite:getHeight() * self.scale.y

	if not camera.pos then
		utils.formatError("Background:draw() called with an invalid 'camera' argument: %q", camera) end

	local pos = camera.pos
	pos = pos * self.scroll
	pos = pos - self.offset * self.scale

	self.quad:setViewport(pos.x - center.x * overdraw + sdw / 2,
						  pos.y - center.y * overdraw + sdh / 2,
						  WINDOW_DIMS_VEC2.x * overdraw, WINDOW_DIMS_VEC2.y * overdraw,
						  sdw, sdh)

	lg.push("all")
		lg.setCanvas(Background.canvas)
		lg.clear()

		lg.translate(center:split())
		lg.rotate(-camera.angle)
		lg.scale(camera:getNormalizedScale())
		lg.translate((-center * overdraw):split())

		stache.setColor(self.color, self.alpha)
		self.sprite:setFilter("linear", "linear")
		self.sprite:setWrap("repeat", "repeat")
		lg.draw(self.sprite, self.quad)

		lg.setCanvas()
		lg.origin()
		lg.draw(Background.canvas)
	lg.pop()
end

function Background.drawEach(array, camera)
	for i = 1, #array do
			Background.draw(array[i], camera) end
end
