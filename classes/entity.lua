local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Entity {
		vec3 pos;
	} Entity;
]]

Entity = {}

function Entity.isEntity(obj)
	return ffi.istype("Light", obj) or
		   ffi.istype("Vault", obj)
end

require "classes.entities.light"
require "classes.entities.vault"
