Crow = Entity:extend("Crow", {
	model = nil,
	radius = nil,
	timer = nil
})

function Crow:init()
	self.model = CircleCollider{ radius = 5 }
	self.radius = 40
	self.timer = 0
end

function Crow:update(tl)
	self.model.pos = self.pos
	self.model.vel = self.vel * tl

	self.timer = utils.approach(self.timer, 0, tl)

	-- TODO: check for overlapping players
	-- TODO: if startle then ...
	-- self.timer = 15
	-- TODO: postMessage("noise_crow", self.pos)
end

function Crow:draw()
	if self.timer <= 0 then
		self.model:draw("magenta") end
end
