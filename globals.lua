LINE_WIDTH = 2
UI_SCALE = nil
UI_SCALE_FLOORED = nil
WINDOW_DIMS_VEC2 = nil
WINDOW_CENTER_VEC2 = nil
SDF_CANVAS = nil

DEBUG_DRAW = true
DEBUG_SLEEP = true
DEBUG_TRIGGERS = false
DEBUG_ENTITIES = true
DEBUG_LIGHTS = false
DEBUG_ROLLBACK = false
DEBUG_STATECHANGES = false
DEBUG_ACTIONCHANGES = false
DEBUG_COLLISION_FALLBACK = true
DEBUG_PRINT_TABLE = function(table)
	io.write("---------------------", table, "---------------------------------------------\n")
	for k in pairs(table) do
		io.write("", string.format("%-16s", k), rawget(table, k), "\n") end

	local private = rawget(table, "private")
	local header = false

	if private then
		for k in pairs(private) do
			if not header then
				io.write("Private --- " .. tostring(private) .. " ---------------------------------------------\n")
				header = true
			end

			io.write("", string.format("%-16s", k), rawget(private, k), "\n")
		end
	end

	io.write("\n")
end