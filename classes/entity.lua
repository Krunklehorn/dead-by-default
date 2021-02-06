local ffi = require "ffi"

ffi.cdef[[
	typedef struct _Entity {
		unsigned int id;
		vec3 pos;
	} Entity;
]]

Entity = {}

function Entity.isEntity(obj)
	return ffi.istype("Decal", obj) or
		   ffi.istype("Light", obj) or
		   ffi.istype("Vault", obj)
end

require "classes.entities.decal"
require "classes.entities.light"
require "classes.entities.vault"
