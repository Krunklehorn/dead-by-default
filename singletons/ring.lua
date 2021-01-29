local ring = {
	private = {
		cursor = 1,
		roll = 0,
		handles = setmetatable({}, { __mode = "v" })
	}
}

function ring.__index(_, key)
	local ring = rawget(ring, "private")

	if key == "private" then return ring
	else return rawget(ring, key) end
end

ring.private = setmetatable(ring.private, { __index = ring.private })

function ring.__newindex(_, key, value)
	local ring = rawget(ring, "private")

	utils.readOnly("ring", key, "cursor", "roll", "handles")
	utils.formatError("Attempted to write new index '%s' to ring: %q", key, value)
end

function ring.wrap(i) return utils.wrap(i, 1, NET_RING_FRAMES + 1) end
function ring.frame(i) return ring.wrap(ring.cursor - ring.roll - (i - 1)) end
function ring.curr() return ring.wrap(ring.cursor - ring.roll) end
function ring.prev() return ring.wrap(ring.cursor - ring.roll - 1) end

function ring.rollback(n)
	n = utils.checkArg("n", n, "number", "ring.rollback", true, NET_ROLLBACK_FRAMES)

	if n < 1 or n > NET_ROLLBACK_FRAMES then
		utils.formatError("ring.rollback() called with an invalid 'n' argument: %q", n)
	elseif ring.roll > 0 then
		utils.formatError("Attempted to call ring.rollback() during a rollback: %q", ring.roll) end

	ring.private.roll = n

	world.copy()
	ring.dirty()
end

function ring.step()
	if ring.roll > 0 then ring.private.roll = ring.roll - 1
	else ring.private.cursor = ring.wrap(ring.cursor + 1) end

	world.copy()
	ring.dirty()
end

function ring.isHandle(obj) return not not ring.handles[obj] end
function ring.dirty()
	for _, handle in pairs(ring.handles) do
		handle.dirty() end
end

function ring.handle(anchor, path)
	utils.checkArg("anchor", anchor, "table", "ring.handle")
	utils.checkArg("path", path, "table", "ring.handle")

	local value = nil

	local handle = {
		__call = function()
			if not value then
				value = anchor

				for k = 1, #path do
					if not value then
						local strings = { "Failed to resolve a handle path: %q" }

						for k = 1, #path do
							strings[#strings + 1] = ", %q" end

						utils.formatError(table.concat(strings), anchor, unpack(path))
					else value = value[path[k]] end
				end
			end

			return value
		end,
		__index = function(self, key)
			return self()[key] end,
		dirty = function()
			value = nil end
	}

	ring.handles[#ring.handles + 1] = handle

	return setmetatable(handle, handle)
end

return setmetatable(ring, ring)
