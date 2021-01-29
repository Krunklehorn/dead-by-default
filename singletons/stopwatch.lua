local stopwatch = {
	private = {
		tickrate = 60,
		framerate = 60,
		ticklength = nil,
		framelength = nil,
		timescale = 1,
		realtime = 0,
		ticktime = 0,
		ticks = 0,

		goal = 0,
		duration = 0,
		min = 9999,
		max = 0,
		frames = 0,
		lag = 0,
		string = nil,

		accu = nil,
		laps = nil,
		divisor = nil,
		delta = nil
	}
}

function stopwatch.__index(_, key)
	local stopwatch = rawget(stopwatch, "private")

	if key == "private" then return stopwatch
	elseif key == "tickrate" then rawset(stopwatch, key, 1 / stopwatch.ticklength)
	elseif key == "framerate" then rawset(stopwatch, key, 1 / stopwatch.framelength)
	elseif key == "ticklength" then rawset(stopwatch, key, 1 / stopwatch.tickrate)
	elseif key == "framelength" then rawset(stopwatch, key, 1 / stopwatch.framerate) end

	return rawget(stopwatch, key)
end

stopwatch.private = setmetatable(stopwatch.private, { __index = stopwatch.__index })

function stopwatch.__newindex(_, key, value)
	local stopwatch = rawget(stopwatch, "private")

	utils.readOnly("stopwatch", key, "ticktime", "ticks", "realtime", "goal", "duration", "min", "max", "frames", "lag", "string")

	if key == "tickrate" then stopwatch.ticklength = nil
	elseif key == "framerate" then stopwatch.framelength = nil
	elseif key == "ticklength" then stopwatch.tickrate = nil
	elseif key == "framelength" then stopwatch.framerate = nil
	elseif key ~= "timescale" then
		utils.formatError("Attempted to write new index '%s' to stopwatch: %q", key, value) end

	stopwatch[key] = value
end

function stopwatch.begin()
	stopwatch.private.realtime = lt.getTime()
end

function stopwatch.update(dt)
	stopwatch.private.realtime = stopwatch.private.realtime + dt;
end

function stopwatch.tick()
	local stopwatch = stopwatch.private

	stopwatch.ticktime = stopwatch.ticktime + stopwatch.ticklength
	stopwatch.ticks = stopwatch.ticks + 1
end

function stopwatch.sleep()
	local stopwatch = stopwatch.private
	local ct = lt.getTime()

	if ct > stopwatch.goal then
		stopwatch.duration = 0
		stopwatch.min = 9999
		stopwatch.max = 0
		stopwatch.frames = 0
		stopwatch.lag = stopwatch.framerate
		stopwatch.string = string.format("Overshoot   Amt: %4.1f  Min:       Max:      ",
			(ct - stopwatch.goal) * 1000)
	else
		local length = stopwatch.goal - ct

		stopwatch.duration = stopwatch.duration + length
		stopwatch.frames = stopwatch.frames + 1
		if length < stopwatch.min then stopwatch.min = length end
		if length > stopwatch.max then stopwatch.max = length end

		if stopwatch.frames >= stopwatch.framerate then
			stopwatch.string = string.format("Sleep       Avg: %4.1f  Min: %4.1f  Max: %4.1f",
				stopwatch.duration / stopwatch.frames * 1000,
				stopwatch.min * 1000,
				stopwatch.max * 1000)
			stopwatch.duration = 0
			stopwatch.min = 9999
			stopwatch.max = 0
			stopwatch.frames = 0
		end

		lt.sleep(length)
	end

	stopwatch.goal = lt.getTime() + stopwatch.framelength
end

function stopwatch.lagging()
	local stopwatch = stopwatch.private

	if stopwatch.lag > 0 then
		stopwatch.lag = stopwatch.lag - 1
		return true
	else return false end
end

function stopwatch.profile(divisor)
	utils.checkArg("divisor", divisor, "number", "stopwatch.profile")

	local stopwatch = rawget(stopwatch, "private")

	if stopwatch.delta == nil then
		stopwatch.accu = 0
		stopwatch.laps = 0
		stopwatch.divisor = divisor
	end

	stopwatch.delta = lt.getTime()
end

function stopwatch.lap()
	local stopwatch = stopwatch.private

	stopwatch.accu = stopwatch.accu + lt.getTime() - stopwatch.delta
	stopwatch.laps = stopwatch.laps + 1

	if stopwatch.laps >= stopwatch.divisor then
		io.write(stopwatch.accu / stopwatch.laps * 1000, "\n")
		stopwatch.accu = 0
		stopwatch.laps = 0
	end
end

return setmetatable(stopwatch, stopwatch)
