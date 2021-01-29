Pallet = Entity:extend("Pallet", {
	slotE = nil,
	slotN = nil,
	slotW = nil,
	slotS = nil,
	state = nil,
	collider = nil
})

function Pallet:init(params)
	local slotE = utils.checkArg("slotE", params[1] or params.slotE, "boolean", "Pallet:init")
	local slotN = utils.checkArg("slotN", params[2] or params.slotN, "boolean", "Pallet:init")
	local slotW = utils.checkArg("slotW", params[3] or params.slotW, "boolean", "Pallet:init")
	local slotS = utils.checkArg("slotS", params[4] or params.slotS, "boolean", "Pallet:init")

	self.slotE = slotE or false
	self.slotN = slotN or false
	self.slotW = slotW or false
	self.slotS = slotS or false
	self.state = "up"
	self.collider = BoxCollider{ hwidth = 90, hlength = 60 }
end

function Pallet:draw()
	if self.state ~= "broken" then
		self.collider:draw("magenta") end
end

function Pallet:drop(agent)
	if self.state == "up" then
		-- TODO: push all overlapping players out, stun any overlapping killers
		-- TODO: postMessage("noise_loud", self.pos)
		self.state = "down"
	end
end

function Pallet:kick(killer)
	if self.state == "down" then
		-- TODO: postMessage("kick", killer)
		self.state = "broken"
	end
end
