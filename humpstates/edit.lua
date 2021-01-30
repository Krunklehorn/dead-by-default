editState = {
	camera = nil,
	grid = nil,
	handles = {},
	pickHandle = nil,
	activeTool = "circle",
	toolState = nil,
	pmwpos = nil,
	sensitivity = 1,
	zoomToCursor = true
}

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

	self:refreshHandles()
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
	if playState.camera then playState.camera:draw() end
	utils.drawDebug()

	self.grid:pop()

	self:drawCrosshair()
end

function editState:mousemoved(x, y, dx, dy, istouch)
	local scale = self.camera:getNormalizedScale()
	local mwpos = self.camera:toWorld(x, y)
	local delta = vec2(dx, dy) / scale

	if lm.isDown(1) and not lm.isDown(2) and not lm.isDown(3) and self.pickHandle then
		self.pickHandle:drag(mwpos, self.grid:minorInterval(true))
	elseif lm.isDown(2) and not lm.isDown(1) and not lm.isDown(3) and self.toolState then
		if lk.isDown("lctrl") then
			mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

		local delta = mwpos - self.pmwpos

		if self.toolState.type == "circle" then
			self.toolState.brush.radius = math.max(delta.length, 10)
		elseif self.toolState.type == "box" then
			self.toolState.brush.star = delta
		elseif self.toolState.type == "line" then
			self.toolState.brush.p2 = self.pmwpos + delta
		end
	elseif lm.isDown(3) and not lm.isDown(1) and not lm.isDown(2) then
		self.camera:move(-delta * self.sensitivity)
	else
		for h = 1, #self.handles do
			self.handles[h]:pick(mwpos, scale, "hover") end
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

function editState:mousepressed(x, y, button)
	local scale = self.camera:getNormalizedScale()
	local mwpos = self.camera:toWorld(x, y)

	if button == 1 and not lm.isDown(2) and not lm.isDown(3) and not self.pickHandle then
		for h = 1, #self.handles do
			local handle = self.handles[h]

			if not self.pickHandle then
				self.pickHandle = handle:pick(mwpos, scale, "pick")
			else handle:pick(mwpos, scale, "idle") end
		end
	elseif button == 2 and not lm.isDown(1) and not lm.isDown(3) and not self.toolState then
		local delete = nil

		for h = 1, #self.handles do
			local handle = self.handles[h]

			if not handle:instanceOf(PointHandle) then
				goto continue end

			if not delete then
				if handle:pick(mwpos, scale, "delete") then
					delete = handle end
			else handle:pick(mwpos, scale, "idle") end

			::continue::
		end

		if delete then
			world.removeBrush(delete.target)
			self:refreshHandles()
		else
			local height = nil
			local brush = nil

			if lk.isDown("lctrl") then
				mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush:pick(mwpos) and (not height or brush.height > height) then
					height = brush.height end
			end

			height = height and height + 16 or 128

			if self.activeTool == "circle" then brush = world.addBrush(CircleBrush, { pos = mwpos, radius = 25, height = height })
			elseif self.activeTool == "box" then brush = world.addBrush(BoxBrush, { pos = mwpos, hwidth = 25, height = height})
			elseif self.activeTool == "line" then brush = world.addBrush(LineBrush, { p1 = mwpos, p2 = mwpos, radius = 25, height = height}) end

			self.toolState = { type = self.activeTool, brush = brush  }
			self:addHandles(brush)
			self.pmwpos = mwpos
		end
	elseif button == 3 and not lm.isDown(1) and not lm.isDown(2) then
		self.pmwpos = mwpos
		lm.setRelativeMode(true)
	end
end

function editState:mousereleased(x, y, button)
	if button == 1 and not lm.isDown(2) and not lm.isDown(3) and self.pickHandle then
		self.pickHandle.state = "idle"
		self.pickHandle = nil
	elseif button == 2 and not lm.isDown(1) and not lm.isDown(3) and self.toolState then
		self.toolState = nil
	elseif button == 3 and not lm.isDown(1) and not lm.isDown(2) then
		lm.setRelativeMode(false)
		lm.setPosition(self.camera:toScreen(self.pmwpos):split())
	end
end

function editState:keypressed(key)
	if key == "1" then self.activeTool = "circle"
	elseif key == "2" then self.activeTool = "box"
	elseif key == "3" then self.activeTool = "line"
	elseif key == "j" then world.save()
	elseif key == "k" then
		world.load()
		self:refreshHandles()
	elseif key == "backspace" then
		utils.switch(titleState)
	elseif key == "return" then
		humpstate.switch(playState)
	end
end

function editState:drawCrosshair()
	local mwpos = self.camera:getMouseWorld(true)

	if lk.isDown("lctrl") then
		mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

	lg.push("all")
		lg.translate(self.camera:toScreen(mwpos):split())
		stache.setColor("white", 0.5)
		lg.line(-10, 0, 10, 0)
		lg.line(0, -10, 0, 10)
	lg.pop()
end

function editState:addHandles(brush)
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
end

function editState:refreshHandles()
	self.handles = utils.clear(self.handles)

	for b = 1, #world.brushes do
		self:addHandles(world.brushes[b]) end
end
