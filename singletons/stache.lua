local stache = {
	fonts = {
		[-1] = {},
		[0] = {},
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {}
	},
	sfx = {},
	music = {},
	colors = {
		white = { 1, 1, 1 },
		grey = { 0.5, 0.5, 0.5 },
		black = { 0, 0, 0 },
		red = { 1, 0, 0 },
		green = { 0, 1, 0 },
		blue = { 0, 0, 1 },
		cyan = { 0, 1, 1 },
		magenta = { 1, 0, 1 },
		yellow = { 1, 1, 0 },
		trigger = { 1, 1, 0, 0.1 },
		selection = { 1, 1, 1, 0.05 }
	},
	shaders = {},
	sprites = {}
}

function stache.__index(_, key)
	if key == "ticklength" then return 1 / rawget(stache, "tickrate")
	elseif key == "framelength" then return 1 / rawget(stache, "framerate")
	else return rawget(stache, key) end
end

function stache.__newindex(_, key, value)
	if key == "ticklength" then rawset(stache, "tickrate", 1 / value)
	elseif key == "framerate" then rawset(stache, "framerate", 1 / value)
	else rawset(stache, key, value) end
end

function stache.load()
	local filestrings, subDir, sheet, width, height

	local function makeDir(dir, subdir)
		dir[subdir] = {}
		return dir[subdir]
	end

	lg.setDefaultFilter("nearest", "nearest")
	lg.setLineWidth(LINE_WIDTH)

	stache.fonts.default = lg.setNewFont(FONT_BLOWUP)
	stache.fonts.default:setLineHeight(FONT_BLOWUP / stache.fonts.default:getHeight())
	bitser.register("fonts.default", stache.fonts.default)

	filestrings = lfs.getDirectoryItems("fonts")
	for f = 1, #filestrings do
		local fs = filestrings[f]
		local name, extension = string.match(fs, "(.+)%.(.+)")

		if extension == "ttf" then
			local font = lg.newFont("fonts/"..fs, FONT_BLOWUP)
			font:setLineHeight(FONT_BLOWUP / font:getHeight())
			bitser.register("fonts."..name, font)
			stache.fonts[name] = font
		elseif extension == "png" then
			for i = -1, 4 do
				local font = lg.newImageFont("fonts/"..fs, FONT_CHARACTERS, i)
				font:setLineHeight(12 / 14)
				bitser.register(string.format("fonts.%d.%s", i, name), font)
				stache.fonts[i][name] = font
			end
		else utils.formatError("Attempted to load font '%s' with an extension that hasn't been setup for proccessing yet: %q", name, extension) end
	end

	filestrings = lfs.getDirectoryItems("sounds/sfx")
	for f = 1, #filestrings do
		local fs = filestrings[f]
		local name, extension = string.match(fs, "(.+)%.(.+)")
		stache.sfx[name] = la.newSource("sounds/sfx/"..fs, "static")
		bitser.register("sfx."..name, stache.sfx[name])
	end

	filestrings = lfs.getDirectoryItems("sounds/music")
	for f = 1, #filestrings do
		local fs = filestrings[f]
		local name, extension = string.match(fs, "(.+)%.(.+)")
		stache.music[name] = la.newSource("sounds/music/"..fs, "stream")
		bitser.register("music."..name, stache.music[name])
	end

	filestrings = lfs.getDirectoryItems("sprites")
	for f = 1, #filestrings do
		local fs = filestrings[f]
		local name, extension = string.match(fs, "(.+)%.(.+)")
		stache.sprites[name] = lg.newImage("sprites/"..fs)
		bitser.register("sprites."..name, stache.sprites[name])
	end

	filestrings = lfs.getDirectoryItems("shaders")
	for f = 1, #filestrings do
		local fs = filestrings[f]
		local name, extension = string.match(fs, "(.+)%.(.+)")
		if extension == "frag" then
			stache.shaders[name] = lg.newShader(lfs.read(string.format("shaders/%s.frag", name)),
												lfs.read(string.format("shaders/%s.vert", name)))
			bitser.register("shaders."..name, stache.shaders[name])
		end
	end
end

function stache.getAsset(arg, asset, table, func, copy)
	if type(asset) == "string" then
		if not table[asset] then
			utils.formatError("%s() called with a '%s' argument that does not correspond to a loaded %s in table '%s': %q", func, arg, arg, table, asset)
		end

		asset = table[asset]
	end

	return copy and utils.copy(asset) or asset
end

function stache.getFontSpacing(font)
	font = utils.checkArg("font", font, "asset", "stache.getFontSpacing", true, lg.getFont())

	for i = -1, 4 do
		for _, v in pairs(stache.fonts[i]) do
			if font == v then
				return i end end
	end

	return 0
end

function stache.getFontHeight(font, spacing)
	font = utils.checkArg("font", font, "asset", "stache.getFontHeight", true, lg.getFont())
	spacing = utils.checkArg("spacing", spacing, "number", "stache.getFontHeight", true, 0)

	font = stache.getAsset("font", font, stache.fonts[spacing], "stache.getFontHeight")

	return font:getHeight()
end

function stache.getFontBaseline(font, spacing)
	font = utils.checkArg("font", font, "asset", "stache.getFontBaseline", true, lg.getFont())
	spacing = utils.checkArg("spacing", spacing, "number", "stache.getFontBaseline", true, 0)

	font = stache.getAsset("font", font, stache.fonts[spacing], "stache.getFontBaseline")

	return font:getHeight() * font:getLineHeight()
end

function stache.setFont(font, spacing)
	font = utils.checkArg("font", font, "asset", "stache.setFont", true, lg.getFont())
	spacing = utils.checkArg("spacing", spacing, "number", "stache.setFont", true, 0)

	font = stache.getAsset("font", font, stache.fonts[spacing], "stache.setFont")

	lg.setFont(font)
end

function stache.printf(params)
	local font = lg.getFont()
	local size = utils.checkArg("size", params[1] or params.size, "number", "stache.printf")
	local text = params[2] or params.text
	local x = utils.checkArg("x", params[3] or params.x, "number", "stache.printf", true, 0)
	local y = utils.checkArg("y", params[4] or params.y, "number", "stache.printf", true, 0)
	local limit = utils.checkArg("limit", params[5] or params.limit, "number", "stache.printf", true, 100000)
	local xalign = utils.checkArg("xalign", params[6] or params.xalign, "string", "stache.printf", true, "left")
	local yalign = utils.checkArg("yalign", params[7] or params.yalign, "string", "stache.printf", true, "top")
	local r = utils.checkArg("r", params[8] or params.r, "number", "stache.printf", true, 0)
	local sx = utils.checkArg("sx", params[9] or params.sx, "number", "stache.printf", true, 1)
	local sy = utils.checkArg("sy", params[10] or params.sy, "number", "stache.printf", true, 1)
	local ox = utils.checkArg("ox", params[11] or params.ox, "number", "stache.printf", true, 0)
	local oy = utils.checkArg("oy", params[12] or params.oy, "number", "stache.printf", true, 0)

	size = size / (font == stache.fonts.default and FONT_BLOWUP or stache.getFontBaseline(font))

	limit = limit / size
	sx = sx * size
	sy = sy * size

	if xalign == "left" then ox = 0
	elseif xalign == "center" then
		ox = limit / 2
		ox = ox - stache.getFontSpacing() / 2 -- Fixes alignment issues with image fonts
	elseif xalign == "right" then ox = limit end

	if yalign == "top" then oy = 0
	elseif yalign == "center" then oy = stache.getFontHeight() / 2
	elseif yalign == "bottom" then oy = stache.getFontHeight() end

	lg.push("all")
		lg.printf(text, x, y, limit, xalign, r, sx, sy, ox, oy)
	lg.pop()
end

function stache.play(sound, amplitude, pitch, ampRange, pitRange)
	utils.checkArg("sound", sound, "string", "stache.play")
	utils.checkArg("amplitude", amplitude, "number", "stache.play", true)
	utils.checkArg("pitch", pitch, "number", "stache.play", true)
	utils.checkArg("ampRange", ampRange, "number", "stache.play", true)
	utils.checkArg("pitRange", pitRange, "number", "stache.play", true)

	if world.roll > 0 then
		return end

	amplitude = amplitude or 100
	pitch = pitch or 100
	ampRange = ampRange or 0
	pitRange = pitRange or 0

	amplitude = amplitude + lmth.random(0, ampRange) - (ampRange / 2)
	amplitude = amplitude / 100

	pitch = pitch + lmth.random(0, pitRange) - (pitRange / 2)
	pitch = pitch / 100

	if stache.sfx[sound] then
		stache.sfx[sound]:stop()
		stache.sfx[sound]:setVolume(amplitude)
		stache.sfx[sound]:setPitch(pitch)
		stache.sfx[sound]:play()
	elseif stache.music[sound] then
		stache.music[sound]:stop()
		stache.sfx[sound]:setVolume(amplitude)
		stache.sfx[sound]:setPitch(pitch)
		stache.music[sound]:play()
	else
		utils.formatError("stache.play() called with a 'sound' argument that does not correspond to a loaded sound: %q", sound)
	end
end

function stache.setColor(color, alpha)
	utils.checkArg("color", color, "asset", "stache.setColor")
	utils.checkArg("alpha", alpha, "number", "stache.setColor", true)

	color = stache.getAsset("color", color, stache.colors, "stache.setColor")
	alpha = alpha or 1

	lg.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
end

return setmetatable(stache, stache)
