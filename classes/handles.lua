Handle = class("Handle", {
	colors = {
		idle = { 1, 1, 1 },
		hover = { 1, 1, 0 },
		select = { 1, 0.5, 0 }
	},
	radius = 16,
	scaleMin = 2,
	scaleMax = 8,
	ppos = nil,
	pdelta = nil,
	pmwpos = nil
}):abstract("init", "draw" , "drag", "pick")

PointHandle = Handle:extend("PointHandle")

function PointHandle:init(target, pkey)
	utils.checkArg("target", target, "indexable", "PointHandle:init")
	utils.checkArg("pkey", pkey, "string", "PointHandle:init")

	if not vec2.isVec2(target[pkey]) then
		utils.formatError("PointHandle:init() called with a 'pkey' argument that doesn't point to a vector: %q, %q", target, pkey)
	end

	self.state = "idle"
	self.target = target
	self.pkey = pkey
end

function PointHandle:draw(scale)
	scale = utils.clamp(scale, Handle.scaleMin, Handle.scaleMax)

	local pos = self.target[self.pkey]
	local color = Handle.colors[self.state]
	local radius = Handle.radius / scale
	local x, y, d

	x = pos.x - radius
	y = pos.y - radius
	d = 2 * radius

	lg.push("all")
		lg.setLineWidth(LINE_WIDTH / scale)
		stache.setColor("white", self.state == "idle" and 0.5 or 1)
		lg.circle("fill", pos.x, pos.y, LINE_WIDTH * 2 / scale)
		stache.setColor(color, self.state == "idle" and 0.5 or 1)
		lg.rectangle("line", x, y, d, d)
		stache.setColor(color, self.state == "idle" and 0.25 or 0.5)
		lg.rectangle("fill", x, y, d, d)
	lg.pop()
end

function PointHandle:drag(mwpos, interval)
	local pos = Handle.ppos + mwpos - Handle.pmwpos

	if lk.isDown("lctrl") then
		pos = pos:snapped(interval) end

	self.target[self.pkey] = pos
end

function PointHandle:pick(mwpos, scale, state)
	scale = utils.clamp(scale, Handle.scaleMin, Handle.scaleMax)

	local pos = self.target[self.pkey]
	local hlength = Handle.radius / scale
	local left = pos.x - hlength
	local right = pos.x + hlength
	local top = pos.y - hlength
	local bottom = pos.y + hlength

	if mwpos.x >= left and mwpos.x <= right and
	   mwpos.y >= top and mwpos.y <= bottom then
		if state then
			if state == "select" then
				Handle.ppos = pos.copy
				Handle.pmwpos = mwpos
			end

			self.state = state
		end

		return self
	else
		self.state = "idle"

		return nil
	end
end

VectorHandle = Handle:extend("VectorHandle")

function VectorHandle:init(target, pkey, dkey)
	utils.checkArg("target", target, "indexable", "VectorHandle:init")
	utils.checkArg("pkey", pkey, "string", "VectorHandle:init")
	utils.checkArg("dkey", dkey, "string", "VectorHandle:init")

	local pos = target[pkey]
	local delta = target[dkey]

	if not vec2.isVec2(pos) then
		utils.formatError("VectorHandle:init() called with a 'pkey' argument that doesn't point to a vector: %q, %q", target, pkey)
	elseif not vec2.isVec2(delta) then
		utils.formatError("VectorHandle:init() called with a 'dkey' argument that doesn't point to a vector: %q, %q", target, dkey)
	end

	self.state = "idle"
	self.target = target
	self.pkey = pkey
	self.dkey = dkey
end

function VectorHandle:draw(scale)
	scale = utils.clamp(scale, Handle.scaleMin, Handle.scaleMax)

	local pos = self.target[self.pkey]
	local tip = pos + self.target[self.dkey]
	local color = Handle.colors[self.state]
	local radius = Handle.radius / scale

	lg.push("all")
		lg.setLineWidth(LINE_WIDTH / scale)
		stache.setColor("white", self.state == "idle" and 0.5 or 1)
		lg.circle("fill", tip.x, tip.y, LINE_WIDTH * 2 / scale)
		stache.setColor(color, self.state == "idle" and 0.5 or 1)
		lg.circle("line", tip.x, tip.y, radius)
		lg.line(pos.x, pos.y, tip.x, tip.y)
		stache.setColor(color, self.state == "idle" and 0.25 or 0.5)
		lg.circle("fill", tip.x, tip.y, radius)
	lg.pop()
end

function VectorHandle:drag(mwpos, interval)
	local delta = Handle.pdelta + mwpos - Handle.pmwpos

	if lk.isDown("lctrl") then
		delta = delta:snapped(interval) end

	self.target[self.dkey] = delta
end

function VectorHandle:pick(mwpos, scale, state)
	scale = utils.clamp(scale, Handle.scaleMin, Handle.scaleMax)

	local pos = self.target[self.pkey]
	local delta = self.target[self.dkey]
	local radius = Handle.radius / scale

	if (pos + delta - mwpos).length <= radius then
		if state then
			if state == "select" then
				Handle.pdelta = delta.copy
				Handle.pmwpos = mwpos
			end

			self.state = state
		end

		return self
	else
		self.state = "idle"

		return nil
	end
end

RadiusHandle = Handle:extend("RadiusHandle")

function RadiusHandle:init(target)
	utils.checkArg("target", target, "indexable", "RadiusHandle:init")

	self.state = "idle"
	self.target = target
end

function RadiusHandle:draw(scale)
	scale = utils.clamp(scale, Handle.scaleMin, Handle.scaleMax)

	local target = self.target
	local radius = target.radius

	lg.push("all")
		stache.setColor(Handle.colors[self.state], 1)
		lg.setLineWidth(LINE_WIDTH / scale)

		if self.target:instanceOf(CircleBrush) then
			local pos = target.pos

			lg.circle("line", pos.x, pos.y, radius)
		elseif self.target:instanceOf(BoxBrush) then
			local pos = target.pos
			local hwidth = target.hwidth + radius
			local hlength = target.hlength + radius

			lg.translate(pos.x, pos.y)
			lg.rotate(target.angle)
			lg.rectangle("line", -hwidth, -hlength, hwidth * 2, hlength * 2, radius, radius)
		elseif self.target:instanceOf(LineBrush) then
			local p1, p2 = target.p1, target.p2
			local length = target.delta.length
			local angle = target.direction.angle

			lg.push("all")
				lg.translate(p1.x, p1.y)
				lg.rotate(angle)

				lg.line(0, radius, length, radius)
				lg.arc("line", "open", 0, 0, radius, 3 * math.pi / 2, math.pi / 2)
			lg.pop()

			lg.push("all")
				lg.translate(p2.x, p2.y)
				lg.rotate(angle)

				lg.line(0, -radius, -length, -radius)
				lg.arc("line", "open", 0, 0, radius, -math.pi / 2, math.pi / 2)
			lg.pop()
		end
	lg.pop()
end

function RadiusHandle:drag(mwpos, interval)
	if lk.isDown("lctrl") then
		mwpos = mwpos:snapped(interval) end

	self.target.radius = math.max(self.target:pick(mwpos) + self.target.radius, 1)
end

function RadiusHandle:pick(mwpos, scale, state)
	scale = utils.clamp(scale, Handle.scaleMin, Handle.scaleMax)

	if math.abs(self.target:pick(mwpos)) <= LINE_WIDTH * 16 / scale then
		if state then
			self.state = state
		end

		return self
	else
		self.state = "idle"

		return nil
	end
end
