local ffi = require "ffi"
local voidptr = ffi.new("void*")

ffi.cdef[[
	typedef enum _AgentState { idle, move, vacuum, air } AgentState;
	typedef enum _AgentAction { stand, squat,
								walk, run, crouch, crawl,
								svault, mvault, fvault,
								upright } AgentAction;
	typedef enum _VacState { none, entity, position } VacState;

	typedef struct _Agent {
		unsigned int id;
		vec3 pos;
		vec3 vel;
		double angle;
		const char* color;
		CircleCollider collider;

		AgentState state;
		AgentAction action;
		vec2 axis;
		vec2 aim;
		double look;
		bool run;
		bool crouch;
		bool vault;
		bool throw;
		bool check;
		bool ability;
		bool drop;

		double grndMoveTime;
		double grndStepTime;

		VacState vacState;
		union {
			unsigned int vacIndex;
			vec3 vacPos;
		};
		double vacSpeed;
		double vacTime;
	} Agent;
]]

Agent = {
	new = ffi.typeof("Agent"),
	state = ffi.typeof("AgentState"),
	action = ffi.typeof("AgentAction"),
	states = { "idle", "move", "vacuum", "air" },
	actions = { "stand", "squat",
				"walk", "run", "crouch", "crawl",
				"svault", "mvault", "fvault",
				"upright" },
	grndPtrs = {},
	vacState = ffi.typeof("VacState"),
	vacStates = { "none", "entity", "position" },
	grv = -800,
	stepTimeWalk = 60 / 120,
	stepTimeRun = 60 / 180,
	stepTimeCrouch = 60 / 115,
	sfx = {}
}

function Agent:__call(params)
	if ffi.istype("Agent", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec3", "Agent:init", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec3", "Agent:init", true)
	local angle = utils.checkArg("angle", params[3] or params.angle, "number", "Agent:init", true)
	local forward = utils.checkArg("forward", params.forward, "vec2", "Agent:init", true)
	local right = utils.checkArg("right", params.right, "vec2", "Agent:init", true)
	local color = utils.checkArg("color", params[4] or params.color, "asset", "Agent:init", true)
	local radius = utils.checkArg("radius", params[5] or params.radius, "number", "Agent:init", true)

	if forward and (right or angle) or (right and angle) then
		utils.formatError("Agent constructor can only be called with one 'angle', 'forward' or 'right' argument exclusively: %q, %q, %q", angle, forward, right) end

	pos = pos or vec3()
	vel = vel or vec3()
	angle = angle or (right and math.atan2(right.y, right.x)) or (forward and math.atan2(forward.x, -forward.y)) or 0
	color = color or "cyan"
	radius = radius or 45

	return Agent.new(utils.newID(), pos, vel, angle, color, { utils.newID(), pos.xy, vel.xy * stopwatch.ticklength, radius }, "air", "upright")
end

function Agent:__index(key)
	if key == "copy" then return Agent.new(self)
	else return rawget(Agent, key) end
end

function Agent:__newindex(key, value)
	if key == "forward" then self.angle = math.atan2(value.x, -value.y)
	elseif key == "right" then self.angle = math.atan2(value.y, value.x)
	else rawset(self, key, value) end
end

function Agent:__tostring()
	if self == Agent then return string.format("Class 'Agent' (%s)", Agent.string)
	else return string.format("Instance of 'Agent' (%s)", utils.addrString(self)) end
end

function Agent:instanceOf(class) return class == Agent end
function Agent.isAgent(obj) return ffi.istype("Agent", obj) end

function Agent.enumToString(obj)
	if ffi.istype("AgentState", obj) then return Agent.states[tonumber(obj) + 1]
	elseif ffi.istype("AgentAction", obj) then return Agent.actions[tonumber(obj) + 1]
	else utils.formatError("Agent.enumToString() called with an 'obj' parameter that isn't an enum: %q", obj) end
end

function Agent:input(commands)
	self.axis = vec2(commands.right - commands.left, commands.down - commands.up).normalized
	self.aim = self.aim + commands.adelta * stopwatch.ticklength
	self.look = self.aim.x
	self.run = commands.run
	self.crouch = commands.crouch
	self.vault = commands.action
	self.throw = commands.action
	self.check = commands.action
	self.ability = commands.ability
	self.drop = commands.drop
end

function Agent:update(tl)
	-- Check for state changes based on input...
	if self:isGrounded() then
		if self.state ~= "vacuum" then
			for e = 1, #world.entities do
				local entity = world.entities[e]

				if entity:instanceOf(Chest) then
				elseif entity:instanceOf(Generator) then
				elseif entity:instanceOf(Lever) then
				elseif entity:instanceOf(Locker) then
				elseif entity:instanceOf(Pallet) then
				elseif entity:instanceOf(Vault) then
					local p1 = entity.pos.xy - entity.right * entity.hwidth
					local p2 = entity.pos.xy + entity.right * entity.hwidth
					local delta = p2 - p1
					local normal = delta.normal
					local offset = self.pos.xy - p1
					local scalar = delta:dot(offset) / delta.length2
					local sign = utils.sign(delta:cross(offset))
					local projdist = (self.pos.xy - (p1 + delta * scalar)).length
					local ang = (entity.right * sign).angle

					while math.abs(ang - self.angle) > math.pi do
						self.angle = self.angle + math.pi * 2 * utils.sign(ang - self.angle) end

					local fast = utils.floatEquality(self.vel.length, 400) and math.abs(math.deg(ang - self.angle)) <= 45
					local dist = fast and Vault.fdist or Vault.mdist

					if scalar > 0 and scalar < 1 and projdist < dist and (not entity.oneway and true or sign == 1) then
						-- TODO: postMessage("ui_prompt_vault", fast)
						if self.vault then
							self.vacState = "entity"
							self.vacIndex = e
							self.vacSpeed = fast and 400 or 600
							self.vacTime = 0
							self:changeState("vacuum")
							self:changeAction((self.crouch or not self.run) and "svault" or ((self.run and fast) and "fvault" or "mvault"))
						end
					end
				end
			end
		end

		if self.state == "idle" then
			if not utils.nearZero(self.axis.length) then
				self:changeState("move")
			else
				if self.action == "stand" and self.crouch then
					self:changeAction("squat")
				elseif self.action == "squat" and not self.crouch then
					self:changeAction("stand")
				end
			end
		elseif self.state == "move" then
			self:changeAction(self.crouch and "crouch" or (self.run and "run" or "walk"))
		end
	end

	-- Iterate physics variables based on current state...
	if self:isGrounded() then
		if self.state == "idle" then
			local top

			if self.action == "stand" then top = 400
			elseif self.action == "squat" then top = 113 end

			self.vel.length = utils.approach(self.vel.length, 0, top * 6.2 * tl)

			self.pos = self.pos + self.vel * tl
			self:updateCollider(tl)
		elseif self.state == "move" then
			local axis = self.axis:rotated(self.look)
			local top

			if self.action == "walk" then top = 226
			elseif self.action == "run" then top = 400
			elseif self.action == "crouch" then top = 113
			elseif self.action == "crawl" then top = 70 end

			if axis.nearZero then
				self.vel.length = utils.approach(self.vel.length, 0, top * 6.2 * tl)
			else
				local target = self.look + self.axis.normal.angle

				while math.abs(target - self.angle) > math.pi do
					self.angle = self.angle + math.pi * 2 * utils.sign(target - self.angle) end

				self.angle = utils.approach(self.angle, target, math.rad(360) * tl)

				self.vel.xy = self.vel + axis * top * 6.2 * tl
			end

			self.vel = self.vel:trimmed(top)

			self.pos = self.pos + self.vel * tl
			self:updateCollider(tl)
		elseif self.state == "vacuum" then
			local vacTarget, posTarget, delta

			if self.vacState == "none" then
				utils.formatError("Agent attempted to vacuum without a target!")
			elseif self.vacState == "entity" then
				vacTarget = world.entities[self.vacIndex]

				if vacTarget:instanceOf(Vault) then
					posTarget = vacTarget.pos + vacTarget.forward * -utils.sign(vacTarget.forward:dot(vacTarget.pos.xy - self.pos)) * 50
				end
			elseif self.vacState == "position" then
				posTarget = self.vacPos
			end

			delta = posTarget.xy - self.pos

			if delta.length < self.vacSpeed * tl then
				self.pos.xy = posTarget

				if self.vacState == "entity" then
					if vacTarget:instanceOf(Vault) then
						local dist

						if self.action == "svault" then
							self.vacSpeed = 113 * (1.25 / 1.5)
							self.vacTime = 1.5 / 2
						elseif self.action == "mvault" then
							self.vacSpeed = 113
							self.vacTime = 1.25 / 2
						elseif self.action == "fvault" then
							self.vacSpeed = 400
							self.vacTime = 0.5 / 2
						end

						dist = self.vacSpeed * self.vacTime

						self.vacState = "position"
						self.vacPos.xy = vacTarget.pos + vacTarget.forward * utils.sign(vacTarget.forward:dot(vacTarget.pos.xy - self.pos)) * dist
					end
				elseif self.vacState == "position" then
					self:changeState("move")
				end
			else
				local angTarget

				if self.vacState == "entity" then
					if vacTarget:instanceOf(Vault) then
						angTarget = (vacTarget.right * vacTarget.forward:dot(vacTarget.pos.xy - self.pos)).angle
					end
				elseif self.vacState == "position" then
					angTarget = math.atan2(delta.x, -delta.y)
				end

				while math.abs(angTarget - self.angle) > math.pi do
					self.angle = self.angle + math.pi * 2 * utils.sign(angTarget - self.angle) end

				self.angle = utils.approach(self.angle, angTarget, math.rad(360 * 5) * tl)

				self.vel.xy = delta.normalized * self.vacSpeed
				self.vel.z = 0

				self.pos = self.pos + self.vel * tl
				self:updateCollider(tl)

				if self.vacTime ~= 0 then
					if (self.action == "mvault" and self.vacTime <= 1.4 / 4) or
					   (self.action == "fvault" and self.vacTime <= 0.75 / 4) then
						   --stache.play(Agent.sfx.vault[lmth.random(1, 4)], 50, 100, 10, 10)
						   self.vacTime = 0
					else self.vacTime = utils.approach(self.vacTime, 0, tl) end
				end
			end
		end
	else
		if self.state == "air" then
			self.vel.z = self.vel.z + Agent.grv * tl
			self.pos = self.pos + self.vel * tl
			self.pos.z = math.max(0, self.pos.z)
			self:updateCollider(tl)
		end
	end

	-- Check for ground interactions...
	if self:isGrounded() then
		local ground = Agent.grndPtrs[self.id]()

		if self.collider:overlap(ground) < 0 then
			local floor

			for b = 1, #world.brushes do
				local brush = world.brushes[b]

				if brush ~= ground and
				   self.pos.z == brush.height and
				   self.collider:overlap(brush) >= 0 then
					floor = brush
					break
				end
			end

			if floor then self:setGround(floor)
			else self:changeState("air") end
		end
	else
		for b = 1, #world.brushes do
			local brush = world.brushes[b]

			if self.pos.z <= brush.height and
			   self.pos.z - self.vel.z * tl >= brush.height and
			   self.collider:overlap(brush) >= 0 then
				self.pos.z = brush.height
				self.vel.z = 0
				self:setGround(brush)
				self:changeState(utils.nearZero(self.vel.length) and "idle" or "move")

				break
			end
		end
	end

	self:updateCollider(tl)

	-- Check for and resolve contacts...
	if self.state ~= "vacuum" then
		local skip = utils.alloc()

		if DEBUG_COLLISION_FALLBACK then
			repeat -- discrete response
				local overlap, depth, normal

				for b = 1, #world.brushes do
					local brush = world.brushes[b]

					if skip[brush] or self.pos.z >= brush.height then
						goto continue end

					d, n = self.collider:overlap(brush)

					if d >= 0 and (not overlap or d > depth) then
						overlap = brush
						depth = d
						normal = n
					end

					::continue::
				end

				if overlap then
					self.vel.xy = normal.tangent * normal.tangent:dot(self.vel)
					self.pos.xy = self.pos + normal * depth
					self:updateCollider(tl)

					skip[overlap] = true
				end
			until not overlap
		end--[[else
			repeat -- continuous response, unused for now
				local cast

				for b = 1, #world.brushes do
					local brush = world.brushes[b]

					if skip[brush] or self.pos.z >= brush.height then
						goto continue end

					local result = self.collider:cast(brush)

					if result and result.t >= 0 and (not cast or result.t < cast.t) then
						cast = result end

					::continue::
				end

				if cast then
					self.vel.xy = cast.tangent * cast.tangent:dot(self.vel)
					self.pos.xy = cast.self_t_pos + self.vel * cast.r * tl
					self:updateCollider(tl)

					skip[cast.other] = true
				end
			until not cast
		end]]

		utils.free(skip)
	end

	-- Check for state changes based on velocity...
	if self:isGrounded() then
		if self.state == "idle" and not utils.nearZero(self.vel.length) then
			self:changeState("move")
		elseif self.state == "move" and utils.nearZero(self.vel.length) then
			self:changeState("idle")
		end
	end

	self:updateCollider(tl)

	-- Play sfx based on state...
	if self:isGrounded() then
		if self.state == "move" then
			if tl ~= 0 then
				self.grndMoveTime = self.grndMoveTime + tl
				self.grndStepTime = self.grndStepTime + tl
			end

			--[[if self.action == "walk" then
				local stepTime = Agent.stepTimeWalk * 226 / self.vel.length

				if self.grndStepTime >= stepTime then
					stache.play(Agent.sfx.footsteps_walk[lmth.random(1, 10)], 50, 100, 10, 10)
					self.grndStepTime = self.grndStepTime - stepTime
				end
			elseif self.action == "run" then
				local stepTime = Agent.stepTimeRun * 400 / self.vel.length

				if self.grndStepTime >= stepTime then
					stache.play(Agent.sfx.footsteps_run[lmth.random(1, 10)], 50, 100, 10, 10)
					self.grndStepTime = self.grndStepTime - stepTime
				end
			elseif self.action == "crouch" then
				local stepTime = Agent.stepTimeCrouch * 113 / self.vel.length

				if self.grndStepTime >= stepTime then
					stache.play(Agent.sfx.footsteps_walk[lmth.random(1, 10)], 50, 100, 10, 10)
					self.grndStepTime = self.grndStepTime - stepTime
				end
			end]]
		end
	end

	-- Clear input commands...
	self.axis.x = 0
	self.axis.y = 0
	self.run = false
	self.crouch = false
	self.vault = false
	self.throw = false
	self.check = false
	self.ability = false
	self.drop = false
end

function Agent:draw()
	lg.push("all")
		lg.translate(self.pos.x, self.pos.y)
		lg.rotate(self.angle)
		stache.setColor("white", 0.2)
		lg.circle("fill", 0, 0, 1)
		lg.line(0, 0, 0, -self.collider.radius)
		--stache.printf{40 * UI_SCALE_FLOORED, utils.round(self.vel.length), xalign = "center"}
	lg.pop()

	self.collider:draw(self.color == "cyan" and { 0, 0.5, 0.5 } or { 0.5, 0, 0 }, (self.action == "squat" or self.action == "crouch") and 0.8 or 1)

	lg.push("all")
		stache.setColor("white", 0.2)
		lg.circle("line", self.pos.x, self.pos.y, self.collider.radius)
	lg.pop()
end

function Agent:changeState(next)
	utils.checkArg("next", next, "string", "Agent:changeState")

	if next == self.state then
		return end -- Do not allow state re-entry

	if DEBUG_STATECHANGES then
		io.write("Agent:changeState()", Agent.enumToString(self.state), next, "\n") end

	if self.state == "vacuum" then
		self:clearVacTarget()
	end--elseif self.state == "air" and (next == "idle" or "move") then
		--stache.play(Agent.sfx.footsteps_land[lmth.random(1, 6)], 50, 100, 10, 10) end

	self.state = next

	if self.state == "idle" then
		self:changeAction(self.crouch and "squat" or "stand")
	elseif self.state == "move" then
		self:changeAction(self.run and "run" or (self.crouch and "crouch" or "walk"))
	elseif self.state == "air" then
		self:clearGround()
		self:changeAction("upright")
	end
end

function Agent:changeAction(next)
	utils.checkArg("next", next, "string", "Agent:changeAction", true)

	if next == self.action then
		return end -- Do not allow action re-entry

	if DEBUG_ACTIONCHANGES then
		io.write("Agent:changeAction()", Agent.enumToString(self.action), next, "\n") end

	self.action = next
end

function Agent:updateCollider(tl)
	self.collider.pos = self.pos.xy
	self.collider.vel = self.vel.xy * tl
end

function Agent:isGrounded()
	return Agent.grndPtrs[self.id] and Agent.grndPtrs[self.id]()
end

function Agent:setGround(brush)
	Agent.grndPtrs[self.id] = world.pointer{ "brushes", brush.id }
end

function Agent:clearGround()
	Agent.grndPtrs[self.id] = nil
	self.grndMoveTime = 0
	self.grndStepTime = 0
end

function Agent:clearVacTarget()
	self.vacState = "none"
	self.vacPos = vec3()
	self.vacSpeed = 0
	self.vacTime = 0
end

setmetatable(Agent, Agent)
ffi.metatype("Agent", Agent)
