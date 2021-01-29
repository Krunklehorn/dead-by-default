--[[
Copyright (c) 2010-2013 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

local function __NULL__() end

 -- default gamestate produces error on every callback
local state_init = setmetatable({leave = __NULL__},
		{__index = function() error("Gamestate not initialized. Use Gamestate.switch()") end})
local stack = {state_init}
local initialized_states = setmetatable({}, {__mode = "k"})
--local state_is_dirty = true -- Krunk: Removed, see bottom of document...

local GS = {}
function GS.new(t) return t or {} end -- constructor - deprecated!

local function change_state(stack_offset, to, ...)
	local pre = stack[#stack]

	-- initialize only on first call
	;(initialized_states[to] or to.init or __NULL__)(to)
	initialized_states[to] = __NULL__

	stack[#stack+stack_offset] = to
	--state_is_dirty = true -- Krunk: Removed, see bottom of document...
	return (to.enter or __NULL__)(to, pre, ...)
end

function GS.switch(to, ...)
	assert(to, "Missing argument: Gamestate to switch to")
	assert(to ~= GS, "Can't call switch with colon operator")
	;(stack[#stack].leave or __NULL__)(stack[#stack])
	return change_state(0, to, ...)
end

function GS.push(to, ...)
	assert(to, "Missing argument: Gamestate to switch to")
	assert(to ~= GS, "Can't call push with colon operator")
	;(stack[#stack].pause or __NULL__)(stack[#stack]) -- Krunk: Added because why not...
	return change_state(1, to, ...)
end

function GS.pop(...)
	assert(#stack > 1, "No more states to pop!")
	local pre, to = stack[#stack], stack[#stack-1]
	stack[#stack] = nil
	;(pre.leave or __NULL__)(pre)
	--state_is_dirty = true -- Krunk: Removed, see bottom of document...
	return (to.resume or __NULL__)(to, pre, ...)
end

function GS.current()
	return stack[#stack]
end

-- XXX: don't overwrite love.errorhandler by default:
--      this callback is different than the other callbacks
--      (see http://love2d.org/wiki/love.errorhandler)
--      overwriting thi callback can result in random crashes (issue #95)
local def_callbacks = { 'draw', 'update' } -- Krunk: Changed to represent "default" callbacks instead, see below...

function GS.registerEvents(add_callbacks)
	local registry = {}
	-------------------------------------------------------------------
	-- Krunk: Moved the fetch loop in here so that GS.registerEvents()
	-- now adds to the callbacks list instead of overwriting it...
	local callbacks = def_callbacks -- Changed to use "default" callbacks instead...

	-- Also added single string option and error checking...
	add_callbacks = add_callbacks or {}
	if type(add_callbacks) == "string" then add_callbacks = { add_callbacks }
	elseif type(add_callbacks) ~= "table" then error("Cannot register event from parameter of type: ", type(add_callbacks)) end

	for k, v in pairs(add_callbacks) do callbacks[#callbacks+1] = v end
	for k in pairs(love.handlers) do callbacks[#callbacks+1] = k end
	-------------------------------------------------------------------

	for _, f in ipairs(callbacks) do
		registry[f] = love[f] or __NULL__

		love[f] = function(...)
			registry[f](...)
			return GS[f](...)
		end
	end
end

-- forward any undefined functions
setmetatable(GS, {__index = function(_, func)
	-- call function only if at least one 'update' was called beforehand
	-- (see issue #46)
	---------------------------------------------------------------
	-- Krunk: Reverted this dirty check because it actually skips
	-- drawing and event callbacks for an entire frame! Not cool.
	--if not state_is_dirty or func == 'update' then
		--state_is_dirty = false
		return function(...)
			return (stack[#stack][func] or __NULL__)(stack[#stack], ...)
		end
	--end
	--return __NULL__
	---------------------------------------------------------------
end})

return GS
