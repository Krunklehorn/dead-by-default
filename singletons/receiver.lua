local receiver = {
	mdelta = nil,
	curr = nil,
	prev = nil,
	mouseToKey = { "mouse1", "mouse2", "mouse3", "mouse4", "mouse5" }
}

function receiver.init()
	receiver.mdelta = vec2.new()
	receiver.curr = {}
	receiver.prev = {}

	for _, func in ipairs({ "mousemoved", "mousepressed", "mousereleased", "keypressed", "keyreleased" }) do
		if love[func] then
			local old = love[func]
			love[func] = function(...)
				old(...)
				receiver[func](...)
			end
		else
			love[func] = function(...)
				receiver[func](...) end
		end
	end
end

function receiver.step()
	receiver.prev = utils.copy(receiver.curr)
	receiver.mdelta = vec2.new()
end

function receiver.mousemoved(x, y, dx, dy, istouch) receiver.mdelta = receiver.mdelta + vec2(dx, dy) end
function receiver.mousepressed(x, y, button) receiver.curr[receiver.mouseToKey[button]] = true end
function receiver.mousereleased(x, y, button) receiver.curr[receiver.mouseToKey[button]] = false end
function receiver.keypressed(key) receiver.curr[key] = true end
function receiver.keyreleased(key) receiver.curr[key] = false end

return setmetatable(receiver, receiver)
