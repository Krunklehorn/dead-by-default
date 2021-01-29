Lever = Entity:extend("Lever", { -- TODO: THIS SHOULD BE THE ENTIRE TILE, NOT AN ENTITY
	model = nil,
	progress = nil,
	holder = nil,
	lever = nil
})

function Lever:init()
	self.model = BoxCollider{ hwidth = 30, hlength = 5 }
	self.progress = 0
end

function Lever:update(tl)
	self.model.pos = self.pos
	self.model.vel = self.vel * tl
	self.model.forward = self.forward

	if self.progress >= 100 then
		self.progress = 100
		-- TODO: postMessage("lever_complete", self)
	end
end

function Lever:draw()
	self.model:draw("magenta")
end
