editState = {
	camera = nil,
	grid = nil,
	selection = {},
	handles = {},
	history = {},
	cursor = 1,
	roll = 0,
	pickHandle = nil,
	pickValue = nil,
	activeTool = "none",
	toolState = nil,
	pmspos = nil,
	pmwpos = nil,
	sensitivity = 1,
	zoomToCursor = true
}

local function onlyDownPrimary() return lm.isDown(1) and not lm.isDown(2) and not lm.isDown(3) end
local function onlyDownSecondary() return lm.isDown(2) and not lm.isDown(1) and not lm.isDown(3) end
local function onlyDownTertiary() return lm.isDown(3) and not lm.isDown(1) and not lm.isDown(2) end
local function onlyButtonPrimary(button) return button == 1 and not lm.isDown(2) and not lm.isDown(3) end
local function onlyButtonSecondary(button) return button == 2 and not lm.isDown(1) and not lm.isDown(3) end
local function onlyButtonTertiary(button) return button == 3 and not lm.isDown(1) and not lm.isDown(2) end

local function wrap(i) return utils.wrap(i, 1, EDIT_RING_ACTIONS + 1) end
local function curr() return wrap(editState.cursor - editState.roll) end
local function prev() return wrap(editState.cursor - editState.roll - 1) end

function editState:init()
	self.camera = Camera{scale = 0.5 * 0.8 ^ 3, pblend = 0.75, ablend = 0.75, sblend = 0.75}

	self.grid = editgrid.grid(self.camera, {
		size = 100,
		subdivisions = 10,
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
		self.camera.origin = playState.camera.origin
		self.camera.ptarget = playState.camera.pos
		self.camera.atarget = 0
		self.camera.starget = 0.5 * 0.8 ^ 3
		self.camera.otarget = vec2(0.5, 0.5)
	end
end

function editState:leave(to)
	self:deselect()
	utils.clear(self.history)
	self.cursor = 1
	self.roll = 0
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

	if self.toolState and self.toolState.type == "select" then
		self:drawSelection()
	elseif lk.isDown("lctrl") and not lm.isDown(3) and self.activeTool ~= "none" then
		self:drawCrosshair()
	end
end

function editState:mousepressed(x, y, button)
	local scale = self.camera:getNormalizedScale()
	local mspos = vec2(x, y)
	local mwpos = self.camera:toWorld(x, y)

	if onlyButtonPrimary(button) and not self.pickHandle then
		for h = 1, #self.handles do
			local handle = self.handles[h]:pick(mwpos, scale, "select")

			if handle then
				self.pickHandle = handle
				self.pickValue = handle:getValue()
				break
			end
		end

		self.pmspos = mspos
		self.pmwpos = mwpos
	elseif onlyButtonSecondary(button) and not self.toolState then
		local delete

		for h = 1, #self.handles do
			local handle = self.handles[h]

			if handle:instanceOf(PointHandle) and
			   handle:pick(mwpos, scale, "delete") then
				   delete = handle.target end
		end

		if delete then
			self:record("delete", delete)
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

			if self.activeTool == "circle" then obj = world.addObject(CircleBrush, { pos = mwpos, radius = 20, height = height })
			elseif self.activeTool == "box" then obj = world.addObject(BoxBrush, { pos = mwpos, hwidth = 20, height = height})
			elseif self.activeTool == "line" then obj = world.addObject(LineBrush, { p1 = mwpos, p2 = mwpos, radius = 20, height = height})
			elseif self.activeTool == "light" then obj = world.addObject(Light, { pos = vec3(mwpos.x, mwpos.y, height), color = vec3(lmth.random(), lmth.random(), lmth.random()), range = UNIT_TILE / 2 })
			elseif self.activeTool == "vault" then obj = world.addObject(Vault, { pos = vec3(mwpos.x, mwpos.y, height) }) end

			self:record("add", obj)
			self.toolState = { type = self.activeTool, obj = obj  }
			self:setSelect(obj)
		else
			-- TODO: widget menu goes here!
			self:deselect()
		end

		self.pmspos = mspos
		self.pmwpos = mwpos
	elseif onlyButtonTertiary(button) then
		lm.setRelativeMode(true)
		self.pmspos = mspos
		self.pmwpos = mwpos
	end
end

function editState:mousereleased(x, y, button)
	if onlyButtonPrimary(button) then
		if self.pickHandle then
			self:record("modify", self.pickHandle)
		elseif not self.toolState then
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

				if not entity:instanceOf(Decal) and not entity:instanceOf(Light) and
				   entity:pick(mwpos) <= 0 and (not height or entity.pos.z >= height) then
					height = entity.pos.z
					selection = entity
				end
			end

			if lk.isDown("lctrl") then self:flipSelect(selection)
			else self:setSelect(selection) end
		end

		self:clearState()
	elseif onlyButtonSecondary(button) then self:clearState()
	elseif onlyButtonTertiary(button) then
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
		local toolType = self.toolState.type
		local delta

		if toolType ~= "select" and lk.isDown("lctrl") then
			mwpos = mwpos:snapped(self.grid:minorInterval(true)) end

		delta = mwpos - self.pmwpos

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

				if utils.AABBContains(p1, p2, entity.pos) then
					selection[#selection + 1] = entity end
			end

			self:setSelect(selection)
		elseif toolType == "circle" then self.toolState.obj.radius = math.max(delta.length, 20)
		elseif toolType == "box" then self.toolState.obj.star = delta
		elseif toolType == "line" then self.toolState.obj.p2 = self.pmwpos + delta
		elseif toolType == "light" then self.toolState.obj.range = math.max(delta.length, UNIT_TILE / 2)
		elseif toolType == "vault" then self.toolState.obj.bow = delta end
	elseif onlyDownPrimary() and self.pmspos then
		local mspos = vec2(lm.getPosition())
		local dspos = mspos - self.pmspos

		if dspos.length >= 5 then
			self.toolState = { type = "select" } end
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
	elseif key == "delete" then
		self:record("delete")
		self:delete()
	elseif key == "j" then world.save()
	elseif key == "k" then
		world.load()
		self:deselect()
	elseif key == "z" and lk.isDown("lctrl") then
		if lk.isDown("lshift") then self:redo()
		else self:undo() end
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

	if y ~= 0 then
		self.camera:zoom(y < 0 and 0.8 or 1.25) end

	if self.zoomToCursor then
		mwpos = self.camera:getMouseWorld(true) - mwpos
		self.camera:move(-mwpos)
	end

	self:mousemoved(lm.getX(), lm.getY(), 0, 0, false)
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
	local dspos = vec2(lm.getPosition()) - self.pmspos

	lg.push("all")
		lg.translate(self.pmspos:split())
		stache.setColor("white", 1)
		if dspos.nearZero then
			lg.circle("fill", 0, 0, LINE_WIDTH)
		elseif utils.nearZero(dspos.x) or utils.nearZero(dspos.y) then
			lg.line(0, 0, dspos:split())
		else
			lg.rectangle("line", 0, 0, dspos:split())
			stache.setColor("white", 0.5)
			lg.rectangle("fill", 0, 0, dspos:split())
		end
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
		if Brush.isBrush(obj) or Entity.isEntity(obj) then
			world.removeObject(obj)
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

function editState:record(action, obj)
	utils.checkArg("action", action, "string", "editState:record")

	if action == "add" then
		self.history[curr()] = { action = action, obj = obj }
	elseif action == "delete" then
		if not obj then
			obj = {}
			for o = 1, #self.selection do
				obj[#obj + 1] = self.selection[o] end
		end

		self.history[curr()] = { action = action, obj = obj }
	elseif action == "modify" then
		self.history[curr()] = { action = action, obj = obj.target, key = obj:getKey(), old = self.pickValue, new = obj:getValue() }
	end

	editState.cursor = wrap(editState.cursor - editState.roll + 1)
	editState.roll = 0
end

function editState:undo()
	if self.history[prev()] and editState.roll < EDIT_RING_ACTIONS then
		self:deselect()

		local history = self.history[prev()]
		local action = history.action
		local obj = history.obj

		if action == "add" then
			self:delete(obj)
		elseif action == "delete" then
			world.insertObject(obj)
		elseif action == "modify" then
			obj[history.key] = history.old
		end

		editState.roll = editState.roll + 1
	end
end

function editState:redo()
	if editState.roll > 0 then
		local history = self.history[curr()]
		local action = history.action
		local obj = history.obj

		if action == "add" then
			world.insertObject(obj)
		elseif action == "delete" then
			self:delete(obj)
		elseif action == "modify" then
			obj[history.key] = history.new
		end

		editState.roll = editState.roll - 1
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

		if obj:instanceOf(Decal) then
			self.handles[#self.handles + 1] = VectorHandle(obj, "pos", "bow")
			self.handles[#self.handles + 1] = VectorHandle(obj, "pos", "star")
		elseif obj:instanceOf(Light) then
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

	self.pickValue = nil
	self.toolState = nil
	self.pmspos = nil
	self.pmwpos = nil
end
