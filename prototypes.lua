---Provides methods for working with all the sprites and related properties that a prototype contains.
---
---### Examples
---```lua
---local prototype_utils = require("__reskins-sprite_utils__.prototypes")
---```
---@class Reskins.SpriteUtils.Prototypes
local prototype_utils = {}

-- Filtering tables for rescale_entity
local included_fields = {
	["shift"] = true,
	["scale"] = true,
	["collision_box"] = true,
	["selection_box"] = true,
	["north_position"] = true,
	["south_position"] = true,
	["east_position"] = true,
	["west_position"] = true,
	["position"] = true,
	["window_bounding_box"] = true,
	["circuit_wire_connection_points"] = true,
}

local excluded_fields = {
	["fluid_boxes"] = true,
	["fluid_box"] = true,
	["energy_source"] = true,
	["input_fluid_box"] = true,
}

---Resizes the given `prototype` by the given `scalar`.
---
---Recursively iterates through the given `prototype` and applies the given `scalar` to all the numeric values
---in the fields listed in `included_fields`.
---
---### Remarks
---`scalar` is recommended to be the ratio of the new tile and the original tile size.
---For example, if rescaling a 5 x 5 tile entity to a 3 x 3 tile entity, `scalar` should be `3 / 5`.
---
---### Examples
---```lua
----- Rescale the "big-electric-pole" by a factor of 2.
----- The resulting entity will have a 4 x 4 tile footprint, and sprite to match.
---prototype_tools.rescale_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---
----- Rescale the "oil-refinery" by a factor of 3 / 5.
----- The resulting entity will have a 3 x 3 tile footprint, and sprite to match.
---prototype_tools.rescale_prototype(data.raw["assembling-machine"]["oil-refinery"], 3 / 5)
---```
---
---### Parameters
---@param entity_prototype any # The entity prototype to rescale.
---@param scalar double # The scale factor to resize the prototype by.
function prototype_utils.rescale_prototype(entity_prototype, scalar)
	---
	---Recursively scales all numeric values in the given `table`, regardless of depth.
	---
	---### Returns
	---@return table # The rescaled table.
	---
	---### Parameters
	---@param table table # The table to rescale.
	local function rescale_table_recursively(table)
		for key, value in pairs(table) do
			if type(value) == "table" then
				table[key] = rescale_table_recursively(value)
			elseif type(value) == "number" then
				table[key] = value * scalar
			else
				-- Do nothing.
			end
		end

		return table
	end

	for key, value in pairs(entity_prototype) do
		-- Because Factorio assumes the value of the scale field if left undefined,
		-- we need to ensure it's defined. Use canon-typical violence.
		if entity_prototype.filename or entity_prototype.stripes or entity_prototype.filenames then
			entity_prototype.scale = entity_prototype.scale or 0.5
		end

		if included_fields[key] then
			if type(value) == "table" then
				entity_prototype[key] = rescale_table_recursively(util.copy(value))
			elseif type(value) == "number" then
				entity_prototype[key] = value * scalar
			else
				-- Do nothing.
			end
		elseif excluded_fields[key] then
			-- Do nothing.
		elseif type(value) == "table" then
			prototype_utils.rescale_prototype(value, scalar)

			-- Scale is not a supported property of stripes, but will be added in child tables.
			-- FIXME: This is a hacky solution to a problem of unused prototypes, and it would be better
			-- to provide some context to the recursive calls so that scale is not added in the first place.
			if key == "stripes" then
				for _, stripe in pairs(value) do
					stripe.scale = nil
				end
			end
		end
	end
end

---Resizes a copy of the `CorpsePrototype` associated with the given `prototype` by the given
---`scalar`, and assigns the rescaled copy to `prototype`. The name of the rescaled copy is
---prefixed with "rescaled-".
---
---### Remarks
---`scalar` is recommended to be the ratio of the new tile and the original tile size.
---For example, if rescaling a 5 x 5 tile entity to a 3 x 3 tile entity, `scalar` should be `3 / 5`.
---
---### Examples
---```lua
----- Rescale the remnants of the "big-electric-pole" by a factor of 2.
----- The resulting entity will have a 4 x 4 tile footprint, and sprite to match.
---prototype_tools.rescale_remnants_of_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---```
---
---### Parameters
---@param prototype data.EntityWithHealthPrototype # The entity with the remnants to rescale.
---@param scalar double # The scale factor to resize the prototype by.
---
---### See Also
---@see Reskins.Lib.Prototypes.rescale_prototype
function prototype_utils.rescale_remnants_of_prototype(prototype, scalar)
	-- Check the entity exists
	if not prototype then
		return
	end

	-- Fetch remnant
	local remnant_name = prototype.corpse

	-- Create, rescale, and assign rescaled remnant
	if remnant_name then
		local remnant = data.raw.corpse[remnant_name]

		if remnant then
			local rescaled_remnant = util.copy(remnant)
			rescaled_remnant.name = "rescaled-" .. rescaled_remnant.name

			prototype_utils.rescale_prototype(rescaled_remnant, scalar)
			data:extend({ rescaled_remnant })

			prototype.corpse = rescaled_remnant.name
		end
	end
end

return prototype_utils
