local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Collider {
		unsigned int id;
	} Collider;
]]

Collider = {}

function Collider.isCollider(obj)
	return ffi.istype("CircleCollider", obj) or
		   ffi.istype("BoxCollider", obj) or
		   ffi.istype("LineCollider", obj) or
		   Brush.isBrush(obj) or
		   Trigger.isTrigger(obj)
end

function Collider.isCircleCollider(obj)
	return ffi.istype("CircleCollider", obj) or
		   ffi.istype("CircleBrush", obj) or
		   ffi.istype("CircleTrigger", obj)
end

function Collider.isBoxCollider(obj)
	return ffi.istype("BoxCollider", obj) or
		   ffi.istype("BoxBrush", obj) or
		   ffi.istype("BoxTrigger", obj)
end

function Collider.isLineCollider(obj)
	return ffi.istype("LineCollider", obj) or
		   ffi.istype("LineBrush", obj) or
		   ffi.istype("LineTrigger", obj)
end

function Collider:checkCastBounds(other)
	local b1 = self:getCastBounds()
	local b2 = other:getCastBounds()

	return b1.left < b2.right and
		   b1.right > b2.left and
		   b1.top < b2.bottom and
		   b1.bottom > b2.top
end

function Collider:circ_circ(other)
	-- https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
	-- make SELF a point and OTHER a circle
	local radii = self.radius + other.radius
	local offset = self.pos - other.pos

	if offset.eqZero then
		return radii, vec2()
	else
		local length = offset.length
		return radii - length, offset / length
	end
end

function Collider:circ_box(other)
	-- https://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
	-- make SELF a point and OTHER a box
	local cos = math.cos(other.angle)
	local sin = math.sin(other.angle)
	local pos = vec2.CCW(self.pos - other.pos, cos, sin)
	local abs = pos.abs
	local hdims = other.hdims
	local delta = abs - hdims
	local dist = utils.clamp(delta.x, delta.y, 0)
	local normal

	if delta.x > 0 or delta.y > 0 then
		local clip = delta:max(0)
		local length = clip.length

		dist = dist + length
		normal = clip / length
	elseif delta.x >= delta.y then
		normal = vec2.right()
	else normal = vec2.down() end

	return self.radius + other.radius - dist,
		   vec2.CW(normal * pos.sign, cos, sin)
end

function Collider:circ_line(other)
	local radii = self.radius + other.radius
	local offset1, offset2, scalar, sign, dist, dir

	offset1 = self.pos - other.p1
	offset2 = self.pos - other.p2

	if offset1.eqZero or offset2.eqZero then
		return radii, vec2() end

	scalar = other.delta:dot(offset1) / other.delta.length2

	if scalar < 0 then
		dist = offset1.length
		dir = offset1 / dist
	elseif scalar > 1 then
		dist = offset2.length
		dir = offset2 / dist
	else
		dist = (self.pos - (other.p1 + other.delta * scalar)).length
		dir = other.normal * utils.sign(other.delta:cross(offset1))
	end

	return radii - dist, dir
end

function Collider:box_box(other)
	utils.formatError("Collider:box_box has not been implemented yet!")
end

function Collider:box_line(other)
	utils.formatError("Collider:box_line has not been implemented yet!")
end

function Collider:line_line(other)
	local radii = self.radius + other.radius
	local invLen2
	local offset11, offset12
	local offset21, offset22
	local offsetA, offsetB
	local scalar1, scalar2
	local dist1, dist2
	local depth, normal

	offset11 = self.p1 - other.p1
	offset12 = self.p1 - other.p2
	offset21 = self.p2 - other.p1
	offset22 = self.p2 - other.p2

	if offset11.eqZero or offset12.eqZero or
	   offset21.eqZero or offset22.eqZero then
		return radii, vec2() end

	-- Calculate distance relative to the first point
	offsetA = offset11
	invLen2 = 1 / other.delta.length2
	scalar1 = other.delta:dot(offset11) * invLen2

	if scalar1 < 0 then
		dist1 = offset11.length
	elseif scalar1 > 1 then
		offsetA = offset12
		dist1 = offset12.length
	else dist1 = (self.p1 - (other.p1 + other.delta * scalar1)).length end

	-- Calculate distance relative to the second point
	offsetB = offset21
	scalar2 = other.delta:dot(offset21) * invLen2

	if scalar2 < 0 then
		dist2 = offset21.length
	elseif scalar2 > 1 then
		offsetB = offset22
		dist2 = offset22.length
	else dist2 = (self.p1 - (other.p1 + other.delta * scalar2)).length end

	if dist1 <= dist2 then
		depth = radii - dist1

		if scalar1 > 0 and scalar1 < 1 then
			normal = other.normal * utils.sign(other.delta:cross(offsetA))
		else normal = offsetA / dist1 end
	else
		depth = radii - dist2

		if scalar2 > 0 and scalar2 < 1 then
			normal = other.normal * utils.sign(other.delta:cross(offsetB))
		else normal = offsetB / dist2 end
	end

	return depth, normal
end

require "classes.colliders.circle"
require "classes.colliders.box"
require "classes.colliders.line"
