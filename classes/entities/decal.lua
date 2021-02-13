local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Decal {
		Entity;
		unsigned int tex;
		double angle;
		double hwidth;
		double hlength;
		vec3 color;
		double alpha;
	} Decal;
]]

Decal = {
	new = ffi.typeof("Decal"),
	quads = {},
	textures = {}
}

function Decal:__call(params)
	if Decal.isDecal(self) then
		utils.formatError("Attempted to create a new instance from an instance: %q", self) end

	local pos = utils.checkArg("pos", params[1] or params.pos, "vec3", "Decal:__call", true)
	local tex = utils.checkArg("tex", params[2] or params.tex, "number/string", "Decal:__call")
	local angle = utils.checkArg("angle", params[3] or params.angle, "number", "Decal:__call", true)
	local forward = utils.checkArg("forward", params.forward, "vec2", "Decal:__call", true)
	local right = utils.checkArg("right", params.right, "vec2", "Decal:__call", true)
	local hwidth = utils.checkArg("hwidth", params[4] or params.hwidth, "number", "Decal:__call", true)
	local hlength = utils.checkArg("hlength", params[5] or params.hlength, "number", "Decal:__call", true)
	local color = utils.checkArg("color", params[6] or params.color, "vec3", "Decal:__call", true)
	local alpha = utils.checkArg("alpha", params[7] or params.alpha, "number", "Decal:__call", true)

	if forward and (right or angle) or (right and angle) then
		utils.formatError("Decal constructor can only be called with one 'angle', 'forward' or 'right' argument exclusively: %q, %q, %q", angle, forward, right) end

	local texture

	if type(tex) == "string" then
		local found

		texture = stache.sprites[tex]

		for t = 1, #Decal.textures do
			if texture == Decal.textures[t] then
				found = t
				break
			end
		end

		if found then tex = found
		else
			Decal.textures[#Decal.textures + 1] = texture
			tex = #Decal.textures
		end
	end

	texture = Decal.textures[tex]

	if not hwidth and not hlength then
		hwidth = texture:getWidth() / 2
		hlength = texture:getHeight() / 2
	elseif hwidth then hlength = texture:getHeight() * hwidth / texture:getWidth()
	elseif hlength then hwidth = texture:getWidth() * hlength / texture:getHeight() end

	pos = pos or vec3()
	angle = angle or (right and math.atan2(right.y, right.x)) or (forward and math.atan2(forward.x, -forward.y)) or 0
	color = color or vec3(1)
	alpha = alpha or 1

	return Decal.new(OBJ_ID_BASE, pos, tex, angle, hwidth, hlength, color, alpha)
end

function Decal:__index(key)
	if key == "p1" then return self.pos + vec2(self.hwidth, self.hlength)
	elseif key == "p2" then return self.pos + vec2(self.hwidth, -self.hlength)
	elseif key == "p3" then return self.pos + vec2(-self.hwidth, -self.hlength)
	elseif key == "p4" then return self.pos + vec2(-self.hwidth, self.hlength)
	elseif key == "forward" then return vec2(math.sin(self.angle), -math.cos(self.angle))
	elseif key == "right" then return vec2(math.cos(self.angle), math.sin(self.angle))
	elseif key == "bow" then return vec2(math.sin(self.angle), -math.cos(self.angle)) * self.hlength
	elseif key == "star" then return vec2(math.cos(self.angle), math.sin(self.angle)) * self.hwidth
	elseif key == "hdims" then return vec2(self.hwidth, self.hlength)
	elseif key == "texture" then return Decal.textures[self.tex]
	elseif key == "copy" then return Decal.new(self)
	else return rawget(Decal, key) end
end

function Decal:__newindex(key, value)
	utils.readOnly(tostring(self), key, "p1", "p2", "p3", "p4", "hdims")

	if key == "forward" then self.angle = math.atan2(value.x, -value.y)
	elseif key == "right" then self.angle = math.atan2(value.y, value.x)
	elseif key == "bow" then
		self.angle = math.atan2(value.x, -value.y)
		self.hlength = value.length
	elseif key == "star" then
		self.angle = math.atan2(value.y, value.x)
		self.hwidth = value.length
	elseif self == Decal then rawset(Decal, key, value)
	else utils.formatError("Attempted to write new index '%s' to instance of 'Decal': %q", key, value) end
end

function Decal:__tostring()
	if self == Decal then return string.format("Class 'Decal' (%s)", Decal.string)
else return string.format("Instance of 'Decal' (%s)", utils.addrString(self)) end
end

function Decal:setID(id)
	utils.checkArg("id", id, "ID", "Decal:setID")

	if Decal.quads[self.id] then
		Decal.quads[id] = Decal.quads[self.id]
		Decal.quads[self.id] = nil
	else
		local texture = Decal.textures[self.tex]
		Decal.quads[id] = lg.newQuad(0, 0, texture:getWidth(), texture:getHeight(), texture)
	end

	self.id = id
end

function Decal:instanceOf(class) return class == Decal end
function Decal.isDecal(obj) return ffi.istype("Decal", obj) end

function Decal:draw()
	if humpstate.current() == editState and DEBUG_DRAW and DEBUG_ENTITIES and DEBUG_DECALS then
		local texture = Decal.textures[self.tex]
		utils.drawBox(self.pos, self.angle, self.hwidth, self.hlength, 0, "magenta", 0.5) end
end

function Decal:payload(ptr, index, camera, scale)
	local pos = camera:toScreen(self.pos)
	local hdims = self.hdims:scaled(scale)
	local angle = -(self.angle - camera.angle)

	ptr[index + 0] = pos.x
	ptr[index + 1] = pos.y
	ptr[index + 2] = hdims.x
	ptr[index + 3] = hdims.y
	ptr[index + 4] = math.cos(angle)
	ptr[index + 5] = math.sin(angle)
	ptr[index + 6] = self.tex
end

function Decal:pick(point)
	utils.checkArg("point", point, "vec2", "Decal:pick")

	local delta = (point - self.pos):rotated(-self.angle).abs - self.hdims
	local clip = vec2.max(delta, 0)
	local sdist = clip.length + math.min(math.max(delta.x, delta.y), 0)

	return sdist
end

setmetatable(Decal, Decal)
ffi.metatype("Decal", Decal)
