Handle = class("Handle", {
	colors = {
		idle = { 1, 1, 1 },
		hover = { 1, 1, 0 },
		pick = { 1, 0.5, 0 }
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
			if state == "pick" then
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
			if state == "pick" then
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
