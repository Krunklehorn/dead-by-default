require "constants"
require "globals"
require "includes"

function love.load()
	love.resize(lg.getDimensions())
	profi:setGetTimeMethod(lt.getTime)
	humpstate.registerEvents()

	stache.load()
	receiver.init()
	input.init()
	world.init()

	humpstate.switch(playState)
end

function love.run()
	local dt = 0
	local accu = 0

	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	if lt then
		stopwatch.begin()
		dt = lt.step() end

	return function()
		if love.event then
			le.pump()

			for name, a,b,c,d,e,f in le.poll() do
				if name == "quit" then
					profi:writeReport()

					if not love.quit or not love.quit() then
						return a or 0
					end
				end

				love.handlers[name](a,b,c,d,e,f)
			end
		end

		if humpstate.current() == playState and DEBUG_ROLLBACK then
			ring.rollback() end

		while humpstate.current() == playState and ring.roll > 0 do
			world.update(stopwatch.ticklength * stopwatch.timescale)
			ring.step()
		end

		if lt then
			dt = lt.step()
			stopwatch.update(dt)
			accu = accu + dt
		end

		while accu >= stopwatch.ticklength do -- TODO: MAKE THIS >= ZERO ONCE WE ADD STATE BLENDING?
			--profi:start("once")
			--stopwatch.profile(75)

			input.translate(stopwatch.ticklength)

			if humpstate.current() == playState then
				world.update(stopwatch.ticklength * stopwatch.timescale) end

			love.update(stopwatch.ticklength * stopwatch.timescale)

			if humpstate.current() == playState then
				ring.step() end

			accu = accu - stopwatch.ticklength

			if humpstate.current() == playState then
				stopwatch.tick() end

			--profi:stop()
			--stopwatch.lap()
		end

		if lg and lg.isActive() then
			lg.clear()
			lg.origin()

			if love.draw then
				--profi:start("once")
				love.draw(accu / dt)
				--profi:stop()
				utils.draw()
			end

			lg.present()
		end

		if lt then
			stopwatch.sleep() end
	end
end

function love.update(tl)
	flux.update(tl)
end

function love.keypressed(key)
	if key == "m" and humpstate.current() ~= introState then
		if not lw.getFullscreen() then lw.updateMode(0, 0, { fullscreen = true })
		else lw.updateMode(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT, { fullscreen = false }) end

		love.resize(lg.getDimensions()) -- Force the resize callback
	elseif key == "kp0" and stopwatch.ticks > NET_ROLLBACK_FRAMES then
		DEBUG_ROLLBACK = not DEBUG_ROLLBACK
	elseif key == "kp*" then
		stopwatch.timescale = stopwatch.timescale * 2
	elseif key == "kp/" then
		stopwatch.timescale = stopwatch.timescale / 2
	elseif key == "escape" then
		le.quit()
	end
end

function love.resize(w, h)
	UI_SCALE = w <= h and w / WINDOW_MIN_WIDTH or h / WINDOW_MIN_HEIGHT
	UI_SCALE_FLOORED = math.floor(UI_SCALE)
	WINDOW_DIMS_VEC2 = vec2(w, h)
	WINDOW_CENTER_VEC2 = vec2(w / 2, h / 2)
	SDF_CANVAS = lg.newCanvas()

	Background.overdraw = math.sqrt((w / h) ^ 2 + 1)
	Background.canvas = lg.newCanvas()

	if not lw.getFullscreen() then
		local dw, dh = lw.getDesktopDimensions()
		lw.setPosition(dw - w - 40, 40)
	end
end
