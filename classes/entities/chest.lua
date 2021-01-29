Chest = Entity:extend("Chest", {
	collider = nil,
	progress = nil,
	contents = nil
})

function Chest:init(contents)
	self.contents = utils.checkArg("contents", contents, "asset", "Chest:init")

	self.collider = BoxCollider{ hwidth = 60, hlength = 30 }
	self.progress = 0
end

function Chest:draw()
	self.collider:draw("magenta")
end

function Chest:pilfer(agent, item)
	local contents = self.contents

	self.contents = item

	return contents
end
