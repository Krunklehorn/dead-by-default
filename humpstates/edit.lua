editState = {
	camera = nil,
	grid = nil,
	selection = {},
	handles = {},
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

	if (self.toolState or self.activeTool ~= "none") and
		not isDownPrimary() and not self.pickHandle and
		not isDownTertiary() and lk.isDown("lctrl") then
			self:drawCrosshair()
	elseif isDownPrimary() and not self.pickHandle and
		   self.toolState and self.toolState.type == "select" then
			   self:drawSelection()
	end
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

		self.pmwpos = mwpos
	elseif isButtonSecondary(button) and not self.toolState then
		local delete

		for h = 1, #self.handles do
			local handle = self.handles[h]

			if handle:instanceOf(PointHandle) and
			   handle:pick(mwpos, scale, "delete") then
				   delete = handle.target end
		end

		if delete then
			self:delete(delete)
		elseif self.activeTool ~= "none" then
			local height = nil
			local obj = nil

			if lk.isDown("lctrl") then
				mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush:pick(mwpos) <= 0 and (not height or brush.height > height) then
					height = brush.height end
			end

			height = height and height + 16 or 128

			if self.activeTool == "circle" then obj = world.addBrush(CircleBrush, { pos = mwpos, radius = 25, height = height })
			elseif self.activeTool == "box" then obj = world.addBrush(BoxBrush, { pos = mwpos, hwidth = 25, height = height})
			elseif self.activeTool == "line" then obj = world.addBrush(LineBrush, { p1 = mwpos, p2 = mwpos, radius = 25, height = height})
			elseif self.activeTool == "light" then obj = world.addEntity(Light, { pos = vec3(mwpos.x, mwpos.y, height), color = vec3(lmth.random(), lmth.random(), lmth.random()), range = 25 })
			elseif self.activeTool == "vault" then obj = world.addEntity(Vault, { pos = vec3(mwpos.x, mwpos.y, height) }) end

			self.toolState = { type = self.activeTool, obj = obj  }
			self:setSelect(obj)
			self.pmwpos = mwpos
		else
			-- TODO: widget menu goes here!
			self:deselect()
		end
	elseif isButtonTertiary(button) then
		lm.setRelativeMode(true)
		self.pmwpos = mwpos
	end
end

function editState:mousereleased(x, y, button)
	if isButtonPrimary(button) then
		if not self.pickHandle and not self.toolState then
			local mwpos = self.camera:toWorld(x, y)
			local height = nil
			local selection = nil

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush:pick(mwpos) <= 0 and (not height or brush.height >= height) then
					height = brush.height
					selection = brush
				end
			end

			height = nil

			for e = 1, #world.entities do
				local entity = world.entities[e]

				if not entity:instanceOf(Light) and entity:pick(mwpos) <= 0 and (not height or entity.pos.z >= height) then
					height = entity.pos.z
					selection = entity
				end
			end

			if lk.isDown("lctrl") then self:flipSelect(selection)
			else self:setSelect(selection) end
		end

		self:clearState()
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
		if toolType ~= "select" and lk.isDown("lctrl") then
			mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

		local toolType = self.toolState.type
		local delta = mwpos - self.pmwpos

		if toolType == "select" then
			local selection = {}
			local p1 = vec2(math.min(self.pmwpos.x, mwpos.x), math.min(self.pmwpos.y, mwpos.y))
			local p2 = vec2(math.max(self.pmwpos.x, mwpos.x), math.max(self.pmwpos.y, mwpos.y))

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush:instanceOf(CircleBrush) or brush:instanceOf(BoxBrush) then
					if utils.AABBContains(p1, p2, brush.pos) then
						selection[#selection + 1] = brush end
				elseif brush:instanceOf(LineBrush) then
					if utils.AABBContains(p1, p2, brush.p1) or
					   utils.AABBContains(p1, p2, brush.p2) then
						   selection[#selection + 1] = brush end
				end
			end

			for e = 1, #world.entities do
				local entity = world.entities[e]

				if entity:instanceOf(Light) or entity:instanceOf(Vault) then
					if utils.AABBContains(p1, p2, entity.pos) then
						selection[#selection + 1] = entity end
				end
			end

			self:setSelect(selection)
		elseif toolType == "circle" then self.toolState.obj.radius = math.max(delta.length, 25)
		elseif toolType == "box" then self.toolState.obj.star = delta
		elseif toolType == "line" then self.toolState.obj.p2 = self.pmwpos + delta
		elseif toolType == "light" then self.toolState.obj.range = math.max(delta.length, 25)
		elseif toolType == "vault" then self.toolState.obj.bow = delta end
	elseif lm.isDown(1) then
		self.toolState = { type = "select" }
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
	elseif key == "5" then self.activeTool = "light"
	elseif key == "6" then self.activeTool = "vault"
	elseif key == "delete" then self:delete()
	elseif key == "j" then world.save()
	elseif key == "k" then
		world.load()
		self:deselect()
	elseif key == "backspace" then
		utils.switch(titleState)
	elseif key == "return" then
		humpstate.switch(playState)
	elseif key == "escape" then
		if #self.selection ~= 0 then self:deselect()
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

function editState:drawSelection()
	local mwpos = self.camera:getMouseWorld(true)
	local mspos, pmspos

	mspos = self.camera:toScreen(mwpos)
	pmspos = self.camera:toScreen(self.pmwpos)

	lg.push("all")
		stache.setColor("white", 1)
		lg.rectangle("line", pmspos.x, pmspos.y, (mspos - pmspos):split())
		stache.setColor("white", 0.5)
		lg.rectangle("fill", pmspos.x, pmspos.y, (mspos - pmspos):split())
	lg.pop()
end

function editState:select(obj)
	utils.checkArg("obj", obj, "indexable", "editState:select", true)

	if obj then
		if Brush.isBrush(obj) or Entity.isEntity(obj) then
			self:addHandles(obj)
			self.selection[#self.selection + 1] = obj
			self.selection[obj] = true
		else
			for o = 1, #obj do
				self:select(obj[o]) end
		end
	else self:deselect() end
end

function editState:deselect(obj)
	utils.checkArg("obj", obj, "indexable", "editState:deselect", true)

	if obj then
		if Brush.isBrush(obj) or Entity.isEntity(obj) then
			for o = 1, #self.selection do
				if obj == self.selection[o] then
					table.remove(self.selection, o)
					break
				end
			end

			self.selection[obj] = nil
			self:removeHandles(obj)
		else
			for o = 1, #obj do
				self:deselect(obj[o]) end
		end
	else
		self:clearHandles()
		utils.clear(self.selection)
	end
end

function editState:setSelect(obj)
	utils.checkArg("obj", obj, "indexable", "editState:setSelect", true)

	self:deselect()
	self:select(obj)
end

function editState:addSelect(obj)
	utils.checkArg("obj", obj, "indexable", "editState:addSelect", true)

	if obj then
		if Brush.isBrush(obj) or Entity.isEntity(obj) then
			local found = false

			for o = 1, #self.selection do
				if obj == self.selection[o] then
					found = true
					break
				end
			end

			if not found then
				self:select(obj) end
		else
			for o = 1, #obj do
				self:addSelect(obj[o]) end
		end
	end
end

function editState:flipSelect(obj)
	utils.checkArg("obj", obj, "indexable", "editState:flipSelect", true)

	if obj then
		if Brush.isBrush(obj) or Entity.isEntity(obj) then
			local found = false

			for o = 1, #self.selection do
				if obj == self.selection[o] then
					found = true
					break
				end
			end

			if found then self:deselect(obj)
			else self:select(obj) end
		else
			for o = 1, #obj do
				self:flipSelect(obj[o]) end
		end
	end
end

function editState:delete(obj)
	utils.checkArg("obj", obj, "indexable", "editState:delete", true)

	if obj then
		if Brush.isBrush(obj) then
			world.removeBrush(obj)
			self:deselect(obj)
		elseif Entity.isEntity(obj) then
			world.removeEntity(obj)
			self:deselect(obj)
		else
			for o = 1, #obj do
				self:delete(obj[o]) end
		end
	else
		for o = 1, #self.selection do
			self:delete(self.selection[o]) end

		self:deselect()
	end
end

function editState:addHandles(obj)
	utils.checkArg("obj", obj, "indexable", "editState:addHandles")

	if Brush.isBrush(obj) then
		if obj:instanceOf(CircleBrush) then
			self.handles[#self.handles + 1] = PointHandle(obj, "pos")
		elseif obj:instanceOf(BoxBrush) then
			self.handles[#self.handles + 1] = PointHandle(obj, "pos")
			self.handles[#self.handles + 1] = VectorHandle(obj, "pos", "bow")
			self.handles[#self.handles + 1] = VectorHandle(obj, "pos", "star")
		elseif obj:instanceOf(LineBrush) then
			self.handles[#self.handles + 1] = PointHandle(obj, "p1")
			self.handles[#self.handles + 1] = PointHandle(obj, "p2")
		end

		self.handles[#self.handles + 1] = RadiusHandle(obj, "radius")
	elseif Entity.isEntity(obj) then
		self.handles[#self.handles + 1] = PointHandle(obj, "pos")

		if obj:instanceOf(Light) then
			self.handles[#self.handles + 1] = RadiusHandle(obj, "range")
		elseif obj:instanceOf(Vault) then
			self.handles[#self.handles + 1] = VectorHandle(obj, "pos", "bow")
			self.handles[#self.handles + 1] = VectorHandle(obj, "pos", "star")
		end
	end
end

function editState:removeHandles(obj)
	utils.checkArg("obj", obj, "indexable", "editState:removeHandles")

	local h = 1

	while h <= #self.handles do
		if obj == self.handles[h].target then
			table.remove(self.handles, h)
		else h = h + 1 end
	end
end

function editState:clearHandles()
	utils.clear(self.handles)
end

function editState:clearState()
	if self.pickHandle then
		self.pickHandle.state = "idle"
		self.pickHandle = nil
	end

	self.toolState = nil
	self.pmwpos = nil
end
