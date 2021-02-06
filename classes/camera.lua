Camera = class("Camera")

function Camera:__index(key)
	local slf = rawget(self, "private")

	return (slf and slf[key]) or getmetatable(self)[key]
end

function Camera:__newindex(key, value)
	local slf = rawget(self, "private")

	if key == "pos" then
		slf[key] = self:checkSet(key, value, "vec2")

		self:checkBounds()
	elseif key == "angle" then slf[key] = self:checkSet(key, value, "number")
	elseif key == "scale" then slf[key] = self:checkSet(key, value, "number")
	elseif key == "origin" then slf[key] = self:checkSet(key, value, "vec2")
	elseif key == "ptarget" then
		if value and not utils.isVector(value) and type(value) ~= "table" then
			utils.formatError("Attempted to set 'ptarget' key of class 'Camera' to a value that isn't a vector or table: %q", value) end

		if utils.isVector(value) then
			slf.pkey = nil
			slf[key] = value.xy

			self:checkBounds()
		else slf[key] = value end
	elseif key == "atarget" then
		if value and type(value) ~= "number" and type(value) ~= "table" then
			utils.formatError("Attempted to set 'atarget' key of class 'Camera' to a value that isn't a number or table: %q", value) end

		if type(value) == "number" then
			value = utils.wrap(value, -math.pi, math.pi)
			slf.akey = nil end

		slf[key] = value
	elseif key == "starget" then
		if value and type(value) ~= "number" and type(value) ~= "table" then
			utils.formatError("Attempted to set 'starget' key of class 'Camera' to a value that isn't a number or table: %q", value) end

		if type(value) == "number" then
			slf.skey = nil end

		slf[key] = value
	elseif key == "otarget" then
		if value and not utils.isVector(value) and type(value) ~= "table" then
			utils.formatError("Attempted to set 'otarget' key of class 'Camera' to a value that isn't a vector or table: %q", value) end

		if utils.isVector(value) then
			slf.okey = nil
			slf[key] = value.xy
		else slf[key] = value end
	elseif key == "pkey" then slf[key] = (slf.ptarget and not vec2.isVec2(slf.ptarget)) and self:checkSet(key, value, "string", true) or nil
	elseif key == "akey" then slf[key] = (slf.atarget and type(slf.atarget) ~= "number") and self:checkSet(key, value, "string", true) or nil
	elseif key == "skey" then slf[key] = (slf.starget and type(slf.starget) ~= "number") and self:checkSet(key, value, "string", true) or nil
	elseif key == "okey" then slf[key] = (slf.otarget and not vec2.isVec2(slf.otarget)) and self:checkSet(key, value, "string", true) or nil
	elseif key == "pblend" or key == "ablend" or key == "sblend" or key == "oblend" then slf[key] = utils.clamp01(self:checkSet(key, value, "number"))
	elseif key == "smin" or key == "smax" then slf[key] = self:checkSet(key, value, "number")
	elseif key == "bounds" then
		self:checkSet(key, value, "table", true)

		if value then
			self:checkSet("bounds.p1", value.p1, "vec2")
			self:checkSet("bounds.p2", value.p2, "vec2")

			if not (value.p1 < value.p2) then
				utils.formatError("Attempted to set 'bounds' key of class 'Camera' with invalid 'p1' or 'p2' values: %q, %q", value.p1, value.p2) end
		end

		slf[key] = utils.copy(value)
	else rawset(self, key, value) end
end

function Camera:init(params)
	local pos = utils.checkArg("pos", params[1] or params.pos, "vec2", "Camera:init", true)
	local angle = utils.checkArg("angle", params[2] or params.angle, "number", "Camera:init", true)
	local scale = utils.checkArg("scale", params[3] or params.scale, "number", "Camera:init", true)
	local origin = utils.checkArg("origin", params[4] or params.origin, "vec2", "Camera:init", true)
	local ptarget = params[5] or params.ptarget
	local atarget = params[6] or params.atarget
	local starget = params[7] or params.starget
	local otarget = params[8] or params.otarget
	local pkey, akey, skey, okey

	if ptarget then
		if not utils.isVector(ptarget) and type(ptarget) ~= "table" then
			utils.formatError("Camera:init() called with a 'ptarget' key that isn't a vector or table: %q", ptarget) end

		if not utils.isVector(ptarget) then
			pkey = utils.checkArg("pkey", params[9] or params.pkey, "string", "Camera:init")

			if not utils.isVector(ptarget[pkey]) then
				utils.formatError("Camera:init() called with a 'pkey' argument that doesn't point to a vector: %q, %q", ptarget, pkey) end
		end
	end

	if atarget then
		if type(atarget) ~= "number" and type(atarget) ~= "table" then
			utils.formatError("Camera:init() called with an 'atarget' key that isn't a number or table: %q", atarget) end

		if type(atarget) ~= "number" then
			akey = utils.checkArg("akey", params[10] or params.akey, "string", "Camera:init")

			if type(atarget[akey]) ~= "number" then
				utils.formatError("Camera:init() called with a 'akey' argument that doesn't point to a number: %q, %q", atarget, akey) end
		end
	end

	if starget then
		if type(starget) ~= "number" and type(starget) ~= "table" then
			utils.formatError("Camera:init() called with an 'starget' key that isn't a number or table: %q", starget) end

		if type(starget) ~= "number" then
			skey = utils.checkArg("skey", params[11] or params.skey, "string", "Camera:init")

			if type(starget[skey]) ~= "number" then
				utils.formatError("Camera:init() called with a 'skey' argument that doesn't point to a number: %q, %q", starget, skey) end
		end
	end

	if otarget then
		if not utils.isVector(otarget) and type(otarget) ~= "table" then
			utils.formatError("Camera:init() called with a 'otarget' key that isn't a vector or table: %q", otarget) end

		if not utils.isVector(otarget) then
			okey = utils.checkArg("okey", params[12] or params.okey, "string", "Camera:init")

			if not utils.isVector(otarget[okey]) then
				utils.formatError("Camera:init() called with a 'okey' argument that doesn't point to a vector: %q, %q", otarget, okey) end
		end
	end

	local pblend = utils.checkArg("pblend", params[13] or params.pblend, "number", "Camera:init", true)
	local ablend = utils.checkArg("ablend", params[14] or params.ablend, "number", "Camera:init", true)
	local sblend = utils.checkArg("sblend", params[15] or params.sblend, "number", "Camera:init", true)
	local oblend = utils.checkArg("oblend", params[16] or params.oblend, "number", "Camera:init", true)
	local smin = utils.checkArg("smin", params[17] or params.smin, "number", "Camera:init", true)
	local smax = utils.checkArg("smax", params[18] or params.smax, "number", "Camera:init", true)
	local bounds = utils.checkArg("bounds", params[19] or params.bounds, "table", "Camera:init", true)

	if bounds then
		utils.checkArg("bounds.p1", bounds.p1, "vec2", "Camera:init")
		utils.checkArg("bounds.p2", bounds.p2, "vec2", "Camera:init")

		if not (bounds.p1 < bounds.p2) then
			utils.formatError("Camera:init() called with a 'bounds' argument with invalid 'p1' or 'p2' values: %q, %q", bounds.p1, bounds.p2) end
	end

	self.private = {
		pos = pos or (ptarget and ptarget[pkey].xy or vec2()),
		angle = angle or (atarget and atarget[akey] or 0),
		scale = scale or (starget and starget[skey] or 1),
		origin = origin or vec2(0.5, 0.5),
		ptarget = (utils.isVector(ptarget) and ptarget.xy or ptarget) or nil,
		atarget = atarget or nil,
		starget = starget or nil,
		otarget = otarget or nil,
		pkey = pkey or nil,
		akey = akey or nil,
		skey = skey or nil,
		okey = okey or nil,
		pblend = pblend or 0,
		ablend = ablend or 0,
		sblend = sblend or 0,
		oblend = oblend or pblend or 0,
		smin = smin or 0.01,
		smax = smax or 10,
		bounds = bounds or nil
	}

	self:checkBounds()
end

function Camera:clone()
	if not self:instanceOf(Camera) then
		utils.formatError("Camera:clone() called for an instance that isn't a Camera: %q", self) end

	local slf = rawget(self, "private")

	return self.class:register({
		class = Camera,
		private = {
			pos = slf.pos.copy,
			angle = slf.angle,
			scale = slf.scale,
			ptarget = vec2.isVec2(slf.ptarget) and slf.ptarget.copy or slf.ptarget,
			atarget = slf.atarget,
			starget = slf.starget,
			otarget = slf.otarget,
			pkey = slf.pkey,
			akey = slf.akey,
			skey = slf.skey,
			okey = slf.okey,
			pblend = slf.pblend,
			ablend = slf.ablend,
			sblend = slf.sblend,
			oblend = slf.oblend,
			smin = slf.smin,
			smax = slf.smax,
			bounds = utils.copy(slf.bounds)
		}
	})
end

function Camera:update(tl)
	if self.ptarget then
		local target = vec2.isVec2(self.ptarget) and self.ptarget or self.ptarget[self.pkey]
		local delta = target - self.pos

		if utils.nearZero(delta.length) then self.pos = target
		else self.pos = self.pos + delta * (1 - self.pblend ^ (tl * 60)) end
	end

	if self.atarget then
		local target = utils.wrap(type(self.atarget) == "number" and self.atarget or self.atarget[self.akey], -math.pi, math.pi)
		local delta = target - utils.wrap(self.angle, -math.pi, math.pi)

		if utils.nearZero(delta) then self.angle = target
		else self.angle = self.angle + delta * (1 - self.ablend ^ (tl * 60)) end
	end

	if self.starget then
		local target = type(self.starget) == "number" and self.starget or self.starget[self.skey]
		target = utils.clamp(target, self.smin, self.smax)
		local delta = target - self.scale

		if utils.nearZero(delta) then self.scale = target
		else self.scale = self.scale + delta * (1 - self.sblend ^ (tl * 60)) end
	end

	if self.otarget then
		local target = vec2.isVec2(self.otarget) and self.otarget or self.otarget[self.okey]
		local delta = target - self.origin

		if utils.nearZero(delta.length) then self.origin = target
		else self.origin = self.origin + delta * (1 - self.oblend ^ (tl * 60)) end
	end

	self:checkBounds()
end

function Camera:draw()
	local w, h = lg.getDimensions()

	lg.push("all")
		lg.translate(self.pos.x, self.pos.y)
		lg.rotate(self.angle)
		lg.translate((-self:getWindowCenter()):split())
		stache.setColor("red", 1)
		lg.rectangle("line", 0, 0, w, h)
	lg.pop()
end

function Camera:attach()
	lg.push()
	lg.translate(self:getWindowCenter():split())
	lg.rotate(-self.angle)
	lg.scale(self:getNormalizedScale())
	lg.translate(-self.pos.x, -self.pos.y)
end

function Camera:detach()
	lg.pop()
end

function Camera:move(dx, dy)
	utils.checkArg("dx", dx, "number/vector", "Camera:move")
	utils.checkArg("dy", dy, "number", "Camera:move", true)

	local delta = utils.isVector(dx) and dx.xy or vec2(dx, dy)

	if self.ptarget then
		if not vec2.isVec2(self.ptarget) then
			self.ptarget = self.ptarget[self.pkey]
			self.pkey = nil
		end
	else self.ptarget = self.pos end

	self.ptarget = self.ptarget + delta
	self:checkBounds()
end

function Camera:rotate(angle)
	utils.checkArg("angle", angle, "number", "Camera:rotate")

	if self.atarget then
		if type(self.atarget) ~= "number" then
			self.atarget = self.atarget[self.akey]
			self.akey = nil
		end
	else self.atarget = self.angle end

	self.atarget = self.atarget + angle
end

function Camera:zoom(scale)
	utils.checkArg("scale", scale, "number", "Camera:zoom")

	if self.starget then
		if type(self.starget) ~= "number" then
			self.starget = self.starget[self.skey]
			self.skey = nil
		end
	else self.starget = self.scale end

	scale = self.starget * scale

	if scale > self.smin and scale < self.smax then
		self.starget = scale end
end

function Camera:offset(dx, dy)
	utils.checkArg("dx", dx, "number/vector", "Camera:offset")
	utils.checkArg("dy", dy, "number", "Camera:offset", true)

	local delta = utils.isVector(dx) and dx.xy or vec2(dx, dy)

	if self.otarget then
		if not vec2.isVec2(self.otarget) then
			self.otarget = self.otarget[self.okey]
			self.okey = nil
		end
	else self.otarget = self.origin end

	self.otarget = self.otarget + delta
end

function Camera:checkBounds()
	if self.bounds then
		local bdims = self.bounds.p2 - self.bounds.p1
		local cwdims = self:getWindowCenter() / self.scale

		if bdims.x > cwdims.x then
			self.pos.x = utils.clamp(self.pos.x, self.bounds.p1.x + cwdims.x / 2, self.bounds.p2.x - cwdims.x / 2)

			if self.ptarget and vec2.isVec2(self.ptarget) then
				self.ptarget.x = utils.clamp(self.ptarget.x, self.bounds.p1.x + cwdims.x / 2, self.bounds.p2.x - cwdims.x / 2) end
		else
			self.pos.x = self.bounds.p1.x + (bdims.x / 2)
			if self.ptarget and vec2.isVec2(self.ptarget) then
				self.ptarget.x = self.bounds.p1.x + (bdims.x / 2) end
		end

		if bdims.y > cwdims.y then
			self.pos.y = utils.clamp(self.pos.y, self.bounds.p1.y + cwdims.y / 2, self.bounds.p2.y - cwdims.y / 2)

			if self.ptarget and vec2.isVec2(self.ptarget) then
				self.ptarget.y = utils.clamp(self.ptarget.y, self.bounds.p1.y + cwdims.y / 2, self.bounds.p2.y - cwdims.y / 2) end
		else
			self.pos.y = self.bounds.p1.y + (bdims.y / 2)
			if self.ptarget and vec2.isVec2(self.ptarget) then
				self.ptarget.y = self.bounds.p1.y + (bdims.y / 2) end
		end
	end
end

function Camera:getPosition(nolerp)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:getPosition", true)
	return nolerp and (self.ptarget and (vec2.isVec2(self.ptarget) and self.ptarget or self.ptarget[self.pkey])) or self.pos
end

function Camera:getAngle(nolerp)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:getAngle", true)
	return nolerp and (self.atarget and (type(self.atarget) == "number" and self.atarget or self.atarget[self.akey])) or self.angle
end

function Camera:getScale(nolerp)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:getScale", true)
	return nolerp and (self.starget and (type(self.starget) == "number" and self.starget or self.starget[self.skey])) or self.scale
end

function Camera:getOrigin(nolerp)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:getOrigin", true)
	return nolerp and (self.otarget and (vec2.isVec2(self.otarget) and self.otarget or self.otarget[self.okey])) or self.origin
end

function Camera:getWindowCenter(nolerp)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:getWindowCenter", true)
	return self:getOrigin(nolerp) * WINDOW_DIMS_VEC2
end

function Camera:getNormalizedScale()
	return self.scale * UI_SCALE
end

function Camera:setPTarget(ptarget, pkey, jump)
	utils.checkArg("ptarget", ptarget, "table", "Camera:setPTarget")
	utils.checkArg("pkey", pkey, "string", "Camera:setPTarget")
	utils.checkArg("jump", jump, "boolean", "Camera:setPTarget", true)

	local pos = ptarget[pkey]

	if not utils.isVector(pos) then
		utils.formatError("Camera:setPTarget() called with a 'pkey' argument that doesn't point to a vector: %q, %q", ptarget, pkey)
	end

	if jump then self.pos = pos.xy end
	self.ptarget = ptarget
	self.pkey = pkey
	self:checkBounds()
end

function Camera:setATarget(atarget, akey, jump)
	utils.checkArg("atarget", atarget, "table", "Camera:setATarget")
	utils.checkArg("akey", akey, "string", "Camera:setATarget")
	utils.checkArg("jump", jump, "boolean", "Camera:setATarget", true)

	if type(atarget[akey]) ~= "number" then
		utils.formatError("Camera:setATarget() called with an 'akey' argument that doesn't point to a number: %q, %q", atarget, akey)
	end

	if jump then self.angle = atarget[akey] end
	self.atarget = atarget
	self.akey = akey
end

function Camera:setSTarget(starget, skey, jump)
	utils.checkArg("starget", starget, "table", "Camera:setSTarget")
	utils.checkArg("skey", skey, "string", "Camera:setSTarget")
	utils.checkArg("jump", jump, "boolean", "Camera:setSTarget", true)

	if type(starget[skey]) ~= "number" then
		utils.formatError("Camera:setSTarget() called with an 'skey' argument that doesn't point to a number: %q, %q", starget, skey)
	end

	if jump then self.scale = starget[skey] end
	self.starget = starget
	self.skey = skey
end

function Camera:setOTarget(otarget, okey, jump)
	utils.checkArg("otarget", otarget, "table", "Camera:setOTarget")
	utils.checkArg("okey", okey, "string", "Camera:setOTarget")
	utils.checkArg("jump", jump, "boolean", "Camera:setOTarget", true)

	local pos = otarget[okey]

	if not utils.isVector(pos) then
		utils.formatError("Camera:setOTarget() called with a 'okey' argument that doesn't point to a vector: %q, %q", otarget, okey)
	end

	if jump then self.pos = pos.xy end
	self.otarget = otarget
	self.okey = okey
end

function Camera:setBounds(p1, p2)
	utils.checkArg("p1", p1, "vector", "Camera:setBounds")
	utils.checkArg("p2", p2, "vector", "Camera:setBounds")

	if not (p1 < p2) then
		utils.formatError("Camera:setBounds() called with invalid 'p1' or 'p2' arguments: %q, %q", p1, p2) end

	self.bounds = {
		p1 = p1,
		p2 = p2
	}
end

function Camera:clearPTarget()
	self.ptarget = nil
	self.pkey = nil
end

function Camera:clearATarget()
	self.atarget = nil
	self.akey = nil
end

function Camera:clearSTarget()
	self.starget = nil
	self.skey = nil
end

function Camera:clearBounds()
	self.bounds = nil
end

function Camera:toWorld(x, y, nolerp)
	utils.checkArg("x", x, "number/vector", "Camera:toWorld")
	utils.checkArg("y", y, "number", "Camera:toWorld", true)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:toWorld", true)

	local point = utils.isVector(x) and x.xy or vec2(x, y)
	local pos = self:getPosition(nolerp)
	local angle = self:getAngle(nolerp)
	local scale = self:getScale(nolerp)

	point = point - self:getWindowCenter()
	point = point:rotated(angle) / (scale * UI_SCALE)
	point = point + pos

	return point
end

function Camera:toScreen(x, y, nolerp)
	utils.checkArg("x", x, "number/vector", "Camera:toScreen")
	utils.checkArg("y", y, "number", "Camera:toScreen", true)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:toScreen", true)

	local point = utils.isVector(x) and x.xy or vec2(x, y)
	local pos = self:getPosition(nolerp)
	local angle = self:getAngle(nolerp)
	local scale = self:getScale(nolerp)

	point = point - pos
	point = point:rotated(-angle) * (scale * UI_SCALE)
	point = point + self:getWindowCenter()

	return point
end

function Camera:getMouseWorld(nolerp)
	utils.checkArg("nolerp", nolerp, "boolean", "Camera:getMouseWorld", true)

	return self:toWorld(lm.getX(), lm.getY(), nolerp)
end
