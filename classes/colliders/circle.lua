local ffi = require "ffi"

ffi.cdef[[
	typedef struct _CircleCollider {
		Collider;
		vec2 pos;
		vec2 vel;
		double radius;
	} CircleCollider;
]]

CircleCollider = {
	new = ffi.typeof("CircleCollider")
}

function CircleCollider:__call(params)
	if ffi.istype("CircleCollider", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "CircleCollider:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "CircleCollider:__call", true)
	local radius = utils.checkArg("radius", params[3] or params.radius, "number", "CircleCollider:__call", true)

	pos = pos or vec2.new()
	vel = vel or vec2.new()
	radius = radius or 0

	return CircleCollider.new("circle", pos, vel, radius)
end

function CircleCollider:__index(key)
	if key == "ppos" then return self.pos - self.vel * stopwatch.ticklength
	elseif key == "copy" then return CircleCollider.new(self)
	else return rawget(CircleCollider, key) end
end

function CircleCollider:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos")

	if self == CircleCollider then rawset(CircleCollider, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'CircleCollider': %q", key, value) end
end

function CircleCollider:__tostring()
	if self == CircleCollider then return string.format("Class 'CircleCollider' (%s)", CircleCollider.string)
	else return string.format("Instance of 'CircleCollider' (%s)", utils.addrString(self)) end
end

function CircleCollider:instanceOf(class) return class == CircleCollider end

function CircleCollider:draw(color, scale)
	local shader = stache.shaders.circle
	local camera = humpstate.current().camera

	utils.checkArg("color", color, "asset", "CircleCollider:draw", true)
	utils.checkArg("scale", scale, "number", "CircleCollider:draw", true)

	color = color or "white"
	scale = scale or 1

	lg.push("all")
		lg.setShader(shader)
			stache.setColor(color)
			shader:send("LINE_WIDTH", LINE_WIDTH)

			shader:send("pos", camera:toScreen(self.pos).table)
			shader:send("radius", self.radius * scale * camera:getNormalizedScale())

			lg.draw(SDF_UNITPLANE)
		lg.setShader()
	lg.pop()
end

function CircleCollider:getCastBounds()
	return {
		left = math.min(self.pos.x, self.ppos.x) - self.radius,
		right = math.max(self.pos.x, self.ppos.x) + self.radius,
		top = math.min(self.pos.y, self.ppos.y) - self.radius,
		bottom = math.max(self.pos.y, self.ppos.y) + self.radius
	}
end

function CircleCollider:pick(point)
	utils.checkArg("point", point, "vec2", "CircleCollider:pick")

	return (point - self.pos).length - self.radius <= 0
end

function CircleCollider:overlap(other)
	utils.checkArg("other", other, "collider", "CircleCollider:overlap")

	if Collider.isCircleCollider(other) then return Collider.circ_circ(self, other)
	elseif Collider.isBoxCollider(other) then return Collider.circ_box(self, other)
	elseif Collider.isLineCollider(other) then return Collider.circ_line(self, other) end

	utils.formatError("CircleCollider:overlap() called with an unsupported subclass combination: %q, %q", self, other)
end

function CircleCollider:cast(other)
	utils.checkArg("other", other, "collider", "CircleCollider:cast")

	local result

	if self:checkCastBounds(other) then
		local contact

		if Collider.isCircleCollider(other) then contact = self:circ_contact(other)
		elseif Collider.isBoxCollider(other) then contact = self:box_contact(other)
		elseif Collider.isLineCollider(other) then contact = self:line_contact(other) end

		result = contact.determ >= 0 and contact.t <= 1 and contact or nil
	end

	return result
end

function CircleCollider:circ_contact(other)
	utils.checkArg("other", other, CircleCollider, "CircleCollider:circ_contact")

	-- https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
	-- make SELF a ray and OTHER a stationary circle
	local offset = self.ppos - other.ppos
	local vel = self.vel - other.vel
	local radius = self.radius + other.radius
	local dot = offset:dot(vel)
	local determ = math.sqrt(dot.length2 - vel.length2 * (offset.length2 - radius * radius))
	local t = (-dot - determ)
	local contact = {}

	contact.t = t / (vel.length2 ~= 0 and vel.length2 or 1)
	contact.r = 1 - contact.t
	contact.self_t_pos = self.ppos + self.vel * contact.t
	contact.other_t_pos = other.ppos + other.vel * contact.t
	contact.delta = contact.self_t_pos - contact.other_t_pos
	contact.normal = contact.delta.normalized
	contact.tangent = contact.delta.tangent

	contact.determ = determ
	contact.sign = determ.sign
	contact.other = other

	return contact
end

function CircleCollider:box_contact(other)
	utils.formatError("Collider:box_box has not been implemented yet!") -- TODO: overlap works but casting is bugged!
	utils.checkArg("other", other, BoxCollider, "CircleCollider:box_contact")

	-- https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
	-- make SELF a ray and OTHER a stationary utils.rounded rectangle
	local offset = (self.ppos - other.ppos):rotated(-other.angle)
	local vel = (self.vel - other.vel):rotated(-other.angle)
	local determ = 1
	local t = -1
	local contact = {}

	local ro = offset
	local rd = vel
	local size = self.hdims
	local rad = self.radius + other.radius

	-- axis aligned box centered at the origin, with dimensions "size" and extruded by radious "rad"
	-- float utils.roundedboxIntersect( in vec3 ro, in vec3 rd, in vec3 size, in float rad )
	-- bounding box
	local m = vec2(rd.x ~= 0 and 1 / rd.x or 1, rd.y ~= 0 and 1 / rd.y or 1) -- vector  -- fixed division by zero when standing still
	local n = m * ro -- vector
	local k = math.abs(m) * (size + vec2(rad)) -- vector
	local t1 = -n - k -- vector
	local t2 = -n + k -- vector
	local tN = utils.clamp(t1.x, t1.y, 0) -- scalar
	local tF = utils.clamp(t2.x, t2.y, 0) -- scalar

	if tN <= tF and tF >= 0 then
		determ = 1
		t = tN -- scalar

		-- convert to first octant
		local pos = ro + rd * t -- vector
		local sign = vec2(utils.sign(pos.x), utils.sign(pos.y)) -- vector
		ro = ro * utils.sign -- vector
		rd = rd * utils.sign -- vector
		pos = pos * utils.sign -- vector

		-- faces
		pos = pos - size
		pos.x = math.max(pos.x, pos.y)
		pos.y = math.max(pos.y, 0)

		if math.min(min(pos.x, pos.y), 0) >= 0 then
			-- some precomputation
			local oc = ro - size -- vector
			local dd = rd * rd -- vector
			local oo = oc * oc -- vector
			local od = oc * rd -- vector
			local ra2 = rad * rad -- scalar

			t = math.huge

			-- corner
			do
				local b = od.x + od.y -- scalar
				local c = oo.x + oo.y - ra2 -- scalar
				local h = b * b - c -- scalar
				if h > 0 then t = -b - math.sqrt(h) end
			end

			-- edge X
			do
				local a = dd.y -- scalar
				local b = od.y -- scalar
				local c = oo.y - ra2 -- scalar
				local h = b * b - a * c -- scalar
				if h > 0 then
					h = (-b - math.sqrt(h)) / (a ~= 0 and a or 1) -- fixes division by zero when standing still
					if h > 0 and h < t and math.abs(ro.x + rd.x * h) < size.x then t = h end
				end
			end

			-- edge Y
			do
				local a = dd.x -- scalar
				local b = od.x -- scalar
				local c = oo.x - ra2 -- scalar
				local h = b * b - a * c -- scalar
				if h > 0 then
					h = (-b - math.sqrt(h)) / (a ~= 0 and a or 1) -- fixes division by zero when standing still
					if h > 0 and h < t and math.abs(ro.y + rd.y * h) < size.y then t = h end
				end
			end

			if t > math.huge - 1 then t = -1 end
		end
	end

	-- normal of a utils.rounded box
	-- vec3 utils.roundedboxNormal( in vec3 pos, in vec3 size, in float rad )
	-- return vec2(utils.sign(pos.x), utils.sign(pos.y) * vec2(max(abs(pos.x) - size.x, 0), math.max(abs(pos.y) - size.y, 0)).normalized

	contact.t = t / (vel.length ~= 0 and vel.length or 1)
	if utils.nearZero(contact.t) then contact.t = 0 end -- patch for miniscule negative ts when pushing on the sides
	contact.r = 1 - contact.t
	contact.self_t_pos = self.ppos + self.vel * contact.t
	contact.other_t_pos = other.ppos + other.vel * contact.t
	contact.delta = contact.self_t_pos - contact.other_t_pos
	contact.normal = contact.delta.normalized
	contact.tangent = contact.delta.tangent

	contact.determ = determ
	contact.sign = determ.sign
	contact.other = other

	return contact
end

function CircleCollider:line_contact(other)
	utils.checkArg("other", other, LineCollider, "CircleCollider:line_contact")

	-- https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
	-- make SELF a ray and OTHER a stationary capsule
	local offset = self.ppos - other.pp1
	local vel = self.vel - other.vel
	local radius = self.radius + other.radius
	local radius2 = radius * radius
	local t = -1
	local contact = {}

	local ba = other.delta
	local oa = self.ppos - other.pp1
	local rd = vel.normalized
	local baba = ba.length2
	local bard = ba:dot(rd)
	local baoa = ba:dot(oa)
	local rdoa = rd:dot(oa)
	local oaoa = oa.length2
	local a = baba - bard.length2
	local b = baba:dot(rdoa) - baoa:dot(bard)
	local c = baba:dot(oaoa) - baoa.length2 - radius2 * baba
	local determ = b.length2 - a:dot(c)

	if determ >= 0 then
		t = (-b - math.sqrt(determ)) / (a ~= 0 and a or 1) -- fixed division by zero when standing still
		local y = baoa + t * bard

		-- body
		if not (y > 0 and y < baba) then
			-- caps
			local oc = y <= 0 and oa or self.ppos - other.pp2
			b = rd:dot(oc)
			c = oc.length2 - radius2
			determ = b.length2 - c
			if determ > 0 then
				t = -b - math.sqrt(determ)
			end
		end
	end

	contact.t = t / (vel.length ~= 0 and vel.length or 1)
	if utils.nearZero(contact.t) then contact.t = 0 end -- patch for miniscule negative ts when pushing on the sides
	contact.r = 1 - contact.t
	contact.self_t_pos = self.ppos + self.vel * contact.t
	contact.other_t_p1 = other.pp1 + other.vel * contact.t
	contact.other_t_p2 = other.pp2 + other.vel * contact.t
	contact.delta = contact.self_t_pos - LineCollider{ p1 = contact.other_t_p1, p2 = contact.other_t_p2 }:point_determinant(contact.self_t_pos).clamped
	contact.normal = contact.delta.normalized
	contact.tangent = contact.delta.tangent

	contact.determ = determ
	contact.sign = determ.sign
	contact.other = other

	return contact
end

setmetatable(CircleCollider, CircleCollider)
ffi.metatype("CircleCollider", CircleCollider)
