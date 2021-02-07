local ffi = require "ffi"

ffi.cdef[[
	typedef struct _LineCollider {
		Collider;
		vec2 p1;
		vec2 p2;
		vec2 vel;
		double radius;
	} LineCollider;
]]

LineCollider = {
	new = ffi.typeof("LineCollider")
}

function LineCollider:__call(params)
	if ffi.istype("LineCollider", self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local p1 = utils.checkArg("p1", params[1] or params.p1, "vec2", "LineCollider:__call", true)
	local p2 = utils.checkArg("p2", params[2] or params.p2, "vec2", "LineCollider:__call", true)
	local vel = utils.checkArg("vel", params[3] or params.vel, "vec2", "LineCollider:__call", true)
	local radius = utils.checkArg("radius", params[4] or params.radius, "number", "LineCollider:__call", true)

	p1 = p1 or vec2()
	p2 = p2 or vec2()
	vel = vel or vec2()
	radius = radius or 0

	return LineCollider.new(utils.newID(), p1, p2, vel, radius)
end

function LineCollider:__index(key)
	if key == "pp1" then return self.p1 - self.vel * stopwatch.ticklength
	elseif key == "pp2" then return self.p2 - self.vel * stopwatch.ticklength
	elseif key == "delta" then return self.p2 - self.p1
	elseif key == "direction" then return self.delta.normalized
	elseif key == "normal" then return self.delta.normal
	elseif key == "copy" then return LineCollider.new(self)
	else return rawget(LineCollider, key) end
end

function LineCollider:__newindex(key, value)
	utils.readOnly(tostring(self), key, "pp1", "pp2", "delta", "direction", "normal")

	if self == LineCollider then rawset(LineCollider, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'LineCollider': %q", key, value) end
end

function LineCollider:__tostring()
	if self == LineCollider then return string.format("Class 'LineCollider' (%s)", LineCollider.string)
	else return string.format("Instance of 'LineCollider' (%s)", utils.addrString(self)) end
end

function LineCollider:instanceOf(class) return class == LineCollider end

function LineCollider:draw(color, scale)
	local shader = stache.shaders.line
	local camera = humpstate.current().camera

	utils.checkArg("color", color, "asset", "LineCollider:draw", true)
	utils.checkArg("scale", scale, "number", "LineCollider:draw", true)

	color = color or "white"
	scale = scale or 1

	lg.push("all")
		lg.setShader(shader)
			stache.setColor(color)
			shader:send("LINE_WIDTH", LINE_WIDTH)

			local delta = self.delta
			local angle = -(delta.angle - camera.angle)

			shader:send("pos", camera:toScreen(self.p1).table)
			shader:send("cosa", math.cos(angle))
			shader:send("sina", math.sin(angle))
			shader:send("len", delta.length * scale * camera:getNormalizedScale())
			shader:send("radius", self.radius * scale * camera:getNormalizedScale())

			lg.draw(SDF_UNITPLANE)
		lg.setShader()
	lg.pop()
end

function LineCollider:getCastBounds()
	return {
		left = math.min(self.p1.x, self.p2.x, self.pp1.x, self.pp2.x) - self.radius,
		right = math.max(self.p1.x, self.p2.x, self.pp1.x, self.pp2.x) + self.radius,
		top = math.min(self.p1.y, self.p2.y, self.pp1.y, self.pp2.y) - self.radius,
		bottom = math.max(self.p1.y, self.p2.y, self.pp1.y, self.pp2.y) + self.radius
	}
end

function LineCollider:pick(point)
	utils.checkArg("point", point, "vec2", "LineCollider:pick")

	local offset = point - self.p1

	if offset.eqZero or (point - self.p2).eqZero then
		return 0 end

	offset = offset:rotated(-self.delta.angle)
	offset.x = offset.x - utils.clamp(offset.x, 0, self.delta.length);

	return offset.length - self.radius
end

function LineCollider:overlap(other)
	utils.checkArg("other", other, "collider", "LineCollider:overlap")

	if Collider.isCircleCollider(other) then return Collider.circ_line(other, self)
	elseif Collider.isBoxCollider(other) then return Collider.box_line(other, self)
	elseif Collider.isLineCollider(other) then return Collider.line_line(self, other) end

	utils.formatError("LineCollider:overlap() called with an unsupported subclass combination: %q, %q", self, other)
end

function LineCollider:point_determinant(point, out)
	utils.checkArg("point", point, "vec2", "LineCollider:point_determinant")
	utils.checkArg("out", out, "table", "LineCollider:point_determinant", true)

	local offset1 = point - self.p1
	local offset2 = point - self.p2
	local result = out or {}

	result.scalar = self.delta:dot(offset1) / self.delta.length2
	result.sign = utils.sign(self.delta:cross(offset1))
	result.projected = self.p1 + self.delta * result.scalar
	result.projdist = (point - result.projected).length
	result.projdir = self.normal * result.sign

	if result.scalar <= 0 then
		result.clamped = self.p1
		result.clmpdist = offset1.length
		result.clmpdir = offset1.normalized
		result.sextant = "lesser"
	elseif result.scalar >= 1 then
		result.clamped = self.p2
		result.clmpdist = offset2.length
		result.clmpdir = offset2.normalized
		result.sextant = "greater"
	else
		result.clamped = self.p1 + self.delta * utils.clamp01(result.scalar)
		result.clmpdist = (point - result.clamped).length
		result.clmpdir = result.projdir
		result.sextant = "medial"
	end

	result.slipdist = (result.projected - result.clamped).length

	return result
end

function LineCollider:line_contact(arg1, arg2)
	if not arg2 then
		utils.checkArg("arg1", arg1, LineCollider, "LineCollider:line_contact")
	else
		utils.checkArg("arg1", arg1, "vec2", "LineCollider:line_contact")
		utils.checkArg("arg2", arg2, "vec2", "LineCollider:line_contact")
	end

	local offset = self.p1 - (arg2 and arg1 or arg1.p1)
	local otherdelta = arg2 and (arg2 - arg1) or arg1.delta
	local deno = self.delta:cross(otherdelta)
	local result = {}

	result.deno = deno
	result.parallel = deno.nearZero

	if result.parallel == false then
		result.scalar1 = self.delta:cross(offset) / deno
		result.scalar2 = otherdelta:cross(offset) / deno

		result.sextant1 = result.scalar1 <= 0 and "lesser" or (result.scalar1 >= 1 and "greater" or "medial")
		result.sextant2 = result.scalar2 <= 0 and "lesser" or (result.scalar2 >= 1 and "greater" or "medial")

		if result.sextant1 == "medial" and
		   result.sextant2 == "medial" then
			result.overlap = true
		else
			result.overlap = false end

		result.point = self.p1 + result.scalar1 * self.delta
	end

	return result
end

setmetatable(LineCollider, LineCollider)
ffi.metatype("LineCollider", LineCollider)
