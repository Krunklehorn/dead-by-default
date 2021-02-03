local ffi = require "ffi"

ffi.cdef[[
	typedef struct _BoxCollider {
		Collider;
		vec2 pos;
		vec2 vel;
		double radius;
		double angle;
		double hwidth;
		double hlength;
	} BoxCollider;
]]

BoxCollider = {
	new = ffi.typeof("BoxCollider")
}

function BoxCollider:__call(params)
	if ffi.istype("BoxCollider", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "BoxCollider:__call", true)
	local vel = utils.checkArg("vel", params[2] or params.vel, "vec2", "BoxCollider:__call", true)
	local radius = utils.checkArg("radius", params[3] or params.radius, "number", "BoxCollider:__call", true)
	local angle = utils.checkArg("angle", params[4] or params.angle, "number", "BoxCollider:__call", true)
	local forward = utils.checkArg("forward", params.forward, "vec2", "BoxCollider:__call", true)
	local right = utils.checkArg("right", params.right, "vec2", "BoxCollider:__call", true)
	local hwidth = utils.checkArg("hwidth", params[5] or params.hwidth, "number", "BoxCollider:__call", true)
	local hlength = utils.checkArg("hlength", params[6] or params.hlength, "number", "BoxCollider:__call", true)

	if forward and (right or angle) or (right and angle) then
		utils.formatError("BoxCollider:init() can only be called with one 'angle', 'forward' or 'right' argument exclusively: %q, %q, %q", angle, forward, right) end

	if not hwidth and not hlength then
		utils.formatError("BoxCollider:__call() cannot be called without an 'hwidth' or 'hlength' argument: %q, %q", hwidth, hlength) end

	pos = pos or vec2.new()
	vel = vel or vec2.new()
	radius = radius or 0
	angle = angle or (right and math.atan2(right.y, right.x)) or (forward and math.atan2(forward.x, -forward.y)) or 0
	hwidth = hwidth or hlength
	hlength = hlength or hwidth

	return BoxCollider.new("box", pos, vel, radius, angle, hwidth, hlength)
end

function BoxCollider:__index(key)
	if key == "ppos" then return self.pos - self.vel * stopwatch.ticklength
	elseif key == "p1" then return self.pos + vec2(self.hwidth, self.hlength)
	elseif key == "p2" then return self.pos + vec2(self.hwidth, -self.hlength)
	elseif key == "p3" then return self.pos + vec2(-self.hwidth, -self.hlength)
	elseif key == "p4" then return self.pos + vec2(-self.hwidth, self.hlength)
	elseif key == "pp1" then return self.ppos + vec2(self.hwidth, self.hlength)
	elseif key == "pp2" then return self.ppos + vec2(self.hwidth, -self.hlength)
	elseif key == "pp3" then return self.ppos + vec2(-self.hwidth, -self.hlength)
	elseif key == "pp4" then return self.ppos + vec2(-self.hwidth, self.hlength)
	elseif key == "forward" then return vec2(math.sin(self.angle), -math.cos(self.angle))
	elseif key == "right" then return vec2(math.cos(self.angle), math.sin(self.angle))
	elseif key == "bow" then return vec2(math.sin(self.angle), -math.cos(self.angle)) * self.hlength
	elseif key == "star" then return vec2(math.cos(self.angle), math.sin(self.angle)) * self.hwidth
	elseif key == "hdims" then return vec2(self.hwidth, self.hlength)
	elseif key == "copy" then return BoxCollider.new(self)
	else return rawget(BoxCollider, key) end
end

function BoxCollider:__newindex(key, value)
	utils.readOnly(tostring(self), key, "ppos", "p1", "p2", "p3", "p4", "pp1", "pp2", "pp3", "pp4", "hdims")

	if key == "forward" then self.angle = math.atan2(value.x, -value.y)
	elseif key == "right" then self.angle = math.atan2(value.y, value.x)
	elseif key == "bow" then
		self.angle = math.atan2(value.x, -value.y)
		self.hlength = value.length
	elseif key == "star" then
		self.angle = math.atan2(value.y, value.x)
		self.hwidth = value.length
	elseif self == BoxCollider then rawset(BoxCollider, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'BoxCollider': %q", key, value) end
end

function BoxCollider:__tostring()
	if self == BoxCollider then return string.format("Class 'BoxCollider' (%s)", BoxCollider.string)
	else return string.format("Instance of 'BoxCollider' (%s)", utils.addrString(self)) end
end

function BoxCollider:instanceOf(class) return class == BoxCollider end

function BoxCollider:draw(color, scale)
	local shader = stache.shaders.box
	local camera = humpstate.current().camera

	utils.checkArg("color", color, "asset", "BoxCollider:draw", true)
	utils.checkArg("scale", scale, "number", "BoxCollider:draw", true)

	color = color or "white"
	scale = scale or 1

	lg.push("all")
		lg.setShader(shader)
			stache.setColor(color)
			shader:send("LINE_WIDTH", LINE_WIDTH)

			local angle = -(self.angle - camera.angle)

			shader:send("pos", camera:toScreen(self.pos).table)
			shader:send("cosa", math.cos(angle))
			shader:send("sina", math.sin(angle))
			shader:send("hdims", self.hdims:scaled(camera:getNormalizedScale()).table)
			shader:send("radius", self.radius * scale * camera:getNormalizedScale())

			lg.draw(SDF_UNITPLANE)
		lg.setShader()
	lg.pop()
end

function BoxCollider:getCastBounds()
	return {
		left = math.min(self.p1.x, self.p2.x, self.p3.x, self.p4.x, self.pp1.x, self.pp2.x, self.pp3.x, self.pp4.x) - self.radius,
		right = math.max(self.p1.x, self.p2.x, self.p3.x, self.p4.x, self.pp1.x, self.pp2.x, self.pp3.x, self.pp4.x) + self.radius,
		top = math.min(self.p1.y, self.p2.y, self.p3.y, self.p4.y, self.pp1.y, self.pp2.y, self.pp3.y, self.pp4.y) - self.radius,
		bottom = math.max(self.p1.y, self.p2.y, self.p3.y, self.p4.y, self.pp1.y, self.pp2.y, self.pp3.y, self.pp4.y) + self.radius
	}
end

function BoxCollider:pick(point)
	utils.checkArg("point", point, "vec2", "BoxCollider:pick")

	local delta = (point - self.pos):rotated(-self.angle).abs - self.hdims
	local clip = vec2.max(delta, 0)
	local sdist = clip.length + math.min(math.max(delta.x, delta.y), 0) - self.radius

	return sdist
end

function BoxCollider:overlap(other)
	utils.checkArg("other", other, "collider", "BoxCollider:overlap")

	if Collider.isCircleCollider(other) then return Collider.circ_box(other, self)
	elseif Collider.isBoxCollider(other) then return Collider.box_box(self, other)
	elseif Collider.isLineCollider(other) then return Collider.box_line(self, other) end

	utils.formatError("BoxCollider:overlap() called with an unsupported subclass combination: %q, %q", self, other)
end

setmetatable(BoxCollider, BoxCollider)
ffi.metatype("BoxCollider", BoxCollider)
