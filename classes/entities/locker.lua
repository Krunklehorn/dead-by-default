Locker = Entity:extend("Locker", {
	collider = nil,
	contents = nil
})

function Locker:init()
	self.collider = BoxCollider{ hwidth = 70, hlength = 30 }
end

function Locker:draw()
	self.collider:draw("magenta")
end

function Locker:check(player)
	if player:instanceOf(Agent) then
		return not not self.contents
	elseif player:instanceOf(Killer) then
		return self.contents
	end
end

function Locker:enter(agent, speed)
	-- TODO: postMessage("locker_enter", speed)
end

function Locker:exit(agent, speed)
	-- TODO: postMessage("locker_exit", agent, speed)
end
