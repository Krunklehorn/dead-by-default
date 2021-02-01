editState = {
	camera = nil,
	grid = nil,
	handles = {},
	selection = nil,
	pickHandle = nil,
	activeTool = "none",
	toolState = nil,
	pmwpos = nil,
	sensitivity = 1,
	zoomToCursor = true
}

local function isDownPrimary() return lm.isDown(1) and not lm.isDown(2) and not lm.isDown(3) end
local function isDownSecondary() return lm.isDown(2) and not lm.isDown(1) and not lm.isDown(3) end
local function isDownTertiary() return lm.isDown(3) and not lm.isDown(1) and not lm.isDown(2) end
local function isButtonPrimary(button) return button == 1 and not lm.isDown(2) and not lm.isDown(3) end
local function isButtonSecondary(button) return button == 2 and not lm.isDown(1) and not lm.isDown(3) end
local function isButtonTertiary(button) return button == 3 and not lm.isDown(1) and not lm.isDown(2) end

function editState:init()
	self.camera = Camera{scale = 0.5 * 0.8 ^ 3, pblend = 0.75, ablend = 0.75, sblend = 0.75}

	self.grid = editgrid.grid(self.camera, {
		size = 100,
		subdivisions = 8,
		color = { 0.25, 0.25, 0.25 },
		drawScale = false,
		xColor = { 0, 1, 1 },
		yColor = { 1, 0, 1 },
		fadeFactor = 0.5,
		textFadeFactor = 1,
		hideOrigin = true,
		style = "smooth"
	})
end

function editState:enter(from)
	utils.fadeIn()

	if playState.camera then
		self.camera.pos = playState.camera.pos
		self.camera.angle = playState.camera.angle
		self.camera.scale = playState.camera.scale
		self.camera.ptarget = playState.camera.pos
		self.camera.atarget = 0
		self.camera.starget = 0.5 * 0.8 ^ 3
	end
end

function editState:leave(to)
	self:deselect()
end

function editState:update(tl)
	self.camera:update(tl)
end

function editState:draw(rt)
	self.grid:draw()

	self.grid:push("all")

	world.draw(rt)
	utils.drawEach(world.triggers)
	utils.drawEach(self.handles, self.camera:getNormalizedScale())

	if playState.camera then
		playState.camera:draw() end

	if DEBUG_DRAW then
		utils.drawDebug() end

	self.grid:pop()

	if lk.isDown("lctrl") and
		not (isDownPrimary() and self.pickHandle) and
		not isDownTertiary() then
			self:drawCrosshair() end
end

function editState:mousepressed(x, y, button)
	local scale = self.camera:getNormalizedScale()
	local mwpos = self.camera:toWorld(x, y)

	if isButtonPrimary(button) and not self.pickHandle then
		for h = 1, #self.handles do
			local handle = self.handles[h]:pick(mwpos, scale, "select")

			if handle then
				self.pickHandle = handle
				break
			end
		end

		if not self.pickHandle then
			local height = nil
			local selection = nil

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush:pick(mwpos) <= 0 and (not height or brush.height > height) then
					height = brush.height
					selection = brush
				end
			end

			self:select(selection)
			self.pmwpos = mwpos
		end
	elseif isButtonSecondary(button) and not self.toolState then
		local delete = false

		for h = 1, #self.handles do
			local handle = self.handles[h]

			if handle:instanceOf(PointHandle) and
			   handle:pick(mwpos, scale, "delete") then
				   delete = true end
		end

		if delete then
			self:delete()
		elseif self.activeTool ~= "none" then
			local height = nil
			local brush = nil

			if lk.isDown("lctrl") then
				mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush:pick(mwpos) <= 0 and (not height or brush.height > height) then
					height = brush.height end
			end

			height = height and height + 16 or 128

			if self.activeTool == "circle" then brush = world.addBrush(CircleBrush, { pos = mwpos, radius = 25, height = height })
			elseif self.activeTool == "box" then brush = world.addBrush(BoxBrush, { pos = mwpos, hwidth = 25, height = height})
			elseif self.activeTool == "line" then brush = world.addBrush(LineBrush, { p1 = mwpos, p2 = mwpos, radius = 25, height = height}) end

			self.toolState = { type = self.activeTool, brush = brush  }
			self:select(brush)
			self.pmwpos = mwpos
		else
			self:deselect()
		end
	elseif isButtonTertiary(button) then
		lm.setRelativeMode(true)
		self.pmwpos = mwpos
	end
end

function editState:mousereleased(x, y, button)
	if isButtonPrimary(button) then self:clearState()
	elseif isButtonSecondary(button) then self:clearState()
	elseif isButtonTertiary(button) then
		lm.setRelativeMode(false)
		lm.setPosition(self.camera:toScreen(self.pmwpos):split())

		self:clearState()
	end
end

function editState:mousemoved(x, y, dx, dy, istouch)
	local scale = self.camera:getNormalizedScale()
	local mwpos = self.camera:toWorld(x, y)
	local delta = vec2(dx, dy) / scale

	if self.pickHandle then
		self.pickHandle:drag(mwpos, self.grid:minorInterval(true))
	elseif self.toolState then
		if lk.isDown("lctrl") then
			mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

		local delta = mwpos - self.pmwpos

		if self.toolState.type == "circle" then self.toolState.brush.radius = math.max(delta.length, 25)
		elseif self.toolState.type == "box" then self.toolState.brush.star = delta
		elseif self.toolState.type == "line" then self.toolState.brush.p2 = self.pmwpos + delta end
	elseif lm.isDown(3) then
		self.camera:move(-delta * self.sensitivity)
	else
		for h = 1, #self.handles do
			self.handles[h]:pick(mwpos, scale, "hover") end
	end
end

function editState:keypressed(key)
	if key == "1" then self.activeTool = "none"
	elseif key == "2" then self.activeTool = "circle"
	elseif key == "3" then self.activeTool = "box"
	elseif key == "4" then self.activeTool = "line"
	elseif key == "delete" then self:delete()
	elseif key == "j" then world.save()
	elseif key == "k" then world.load()
	elseif key == "backspace" then
		utils.switch(titleState)
	elseif key == "return" then
		humpstate.switch(playState)
	elseif key == "escape" then
		if self.selection then self:deselect()
		else le.quit() end
	end
end

function editState:wheelmoved(x, y)
	local mwpos = self.camera:getMouseWorld(true)
	local mspos = vec2(lm.getPosition())

	if y ~= 0 then
		self.camera:zoom(y < 0 and 0.8 or 1.25) end

	if self.zoomToCursor then
		mwpos = self.camera:toWorld(mspos.x, mspos.y, true) - mwpos
		self.camera:move(-mwpos)
	end

	self:mousemoved(mspos.x, mspos.y, 0, 0, false)
end

function editState:drawCrosshair()
	local mwpos = self.camera:getMouseWorld(true)

	mwpos = mwpos:snapped(self.grid:minorInterval(true))

	lg.push("all")
		lg.translate(self.camera:toScreen(mwpos):split())
		stache.setColor("white", 0.5)
		lg.line(-10, 0, 10, 0)
		lg.line(0, -10, 0, 10)
	lg.pop()
end

function editState:select(brush)
	utils.checkArg("brush", brush, "brush", "editState:select", true)

	if brush then
		self:setHandles(brush)
		self.selection = brush
	else self:deselect() end
end

function editState:deselect()
	self:clearHandles()
	self.selection = nil
end

function editState:delete()
	if self.selection then
		world.removeBrush(self.selection)
		self:deselect()
	end
end

function editState:addHandles(brush)
	utils.checkArg("brush", brush, "brush", "editState:addHandles")

	if brush:instanceOf(CircleBrush) then
		self.handles[#self.handles + 1] = PointHandle(brush, "pos")
	elseif brush:instanceOf(BoxBrush) then
		self.handles[#self.handles + 1] = VectorHandle(brush, "pos", "bow")
		self.handles[#self.handles + 1] = VectorHandle(brush, "pos", "star")
		self.handles[#self.handles + 1] = PointHandle(brush, "pos")
	elseif brush:instanceOf(LineBrush) then
		self.handles[#self.handles + 1] = PointHandle(brush, "p1")
		self.handles[#self.handles + 1] = PointHandle(brush, "p2")
	end

	self.handles[#self.handles + 1] = RadiusHandle(brush, "radius")
end

function editState:setHandles(brush)
	utils.checkArg("brush", brush, "brush", "editState:replaceHandles")

	self:clearHandles()
	self:addHandles(brush)
end

function editState:clearHandles()
	self.handles = utils.clear(self.handles)
end

function editState:clearState()
	if self.pickHandle then
		self.pickHandle.state = "idle"
		self.pickHandle = nil
	end

	self.toolState = nil
	self.pmwpos = nil
end
