Generator = Entity:extend("Generator", {
	slotE = nil,
	slotN = nil,
	slotW = nil,
	slotS = nil,
	collider = nil,
	progress = nil
})

function Generator:init(params)
	local slotE = utils.checkArg("slotE", params[1] or params.slotE, "boolean", "Generator:init")
	local slotN = utils.checkArg("slotN", params[2] or params.slotN, "boolean", "Generator:init")
	local slotW = utils.checkArg("slotW", params[3] or params.slotW, "boolean", "Generator:init")
	local slotS = utils.checkArg("slotS", params[4] or params.slotS, "boolean", "Generator:init")

	self.slotE = slotE or false
	self.slotN = slotN or false
	self.slotW = slotW or false
	self.slotS = slotS or false
	self.collider = BoxCollider{ hwidth = 90, hlength = 60 }
	self.progress = 0
end

function Generator:update(tl)
	self.collider.pos = self.pos
	self.collider.vel = self.vel * tl
	self.collider.forward = self.forward

	if self.progress >= 100 then
		self.progress = 100
		-- TODO: postMessage("generator_complete", self.pos)
	end
end

function Generator:draw()
	self.collider:draw("magenta")
end

function Generator:pop(agent)
	-- TODO: postMessage("noise_loud", self.pos)
end

function Generator:damage(killer)
	-- TODO: postMessage("generator_damage", self, killer)
end
