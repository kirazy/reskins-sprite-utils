---@using data

---@namespace Reskins.SpriteUtils

--- Provides methods for manipulating icons.
---
---### Examples
---```lua
---local _icons = require("__reskins-sprite-utils__.icons")
---```
---@class Icons
local _icons = {}

local default_icon_sizes = {
	["space-location"] = 512,
	["technology"] = 256,
	["achievement"] = 128,
	["item-group"] = 128,
	["shortcut"] = 32,
	["shortcut-small"] = 24,
}

---Gets an empty icon.
---
---### Examples
---```lua
---local icon_data = _icons.empty_icon()
---```
---
---### Parameters
---@param icon_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData.scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@return IconData
---@nodiscard
function _icons.empty_icon(icon_type)
	local expected_icon_size
	if icon_type and type(icon_type) == "string" then
		expected_icon_size = default_icon_sizes[icon_type] or defines.default_icon_size
	else
		expected_icon_size = defines.default_icon_size
	end

	return {
		icon = "__core__/graphics/empty.png",
		icon_size = 1,
		scale = expected_icon_size / 2,
	}
end

---
---Scales the given `icon_data` by the given `scalar`.
---
---### Examples
---```lua
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    },
---    {
---        icon = "__base__/graphics/icons/copper-wire.png",
---        icon_size = 64,
---        scale = 0.25,
---        shift = { -16, 16 }
---    },
---}
---
----- Increase the size of the icon by a factor of 2.
---icon_data = _icons.scale_icon(icon_data, 2)
---```
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects to scale.
---@param scalar double # The scalar to rescale the icon by.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconData[] # A copy of `icon_data` rescaled by the given `scalar`.
---@nodiscard
function _icons.scale_icon(icon_data, scalar, defaults_type)
	local icon_data_copy = _icons.add_missing_icons_defaults(icon_data, defaults_type)

	for _, icon_datum in pairs(icon_data_copy) do
		icon_datum.scale = icon_datum.scale * scalar
		icon_datum.shift = icon_datum.shift and util.mul_shift(icon_datum.shift, scalar) or nil
	end

	return icon_data_copy
end

---
---Clears all icon fields from the given `prototype` object.
---
---Warning! This leaves the prototype in an invalid state!
---Be sure to set a new icon after calling this function.
---
---### Examples
---```lua
---_icons.clear_icon_from_prototype(data.raw.item["iron-plate"])
---```
---
---### Parameters
---@param prototype PrototypeWithIcons # The prototype object.
function _icons.clear_icon_from_prototype(prototype)
	if prototype then
		prototype.icons = nil
		prototype.icon = nil
		prototype.icon_size = nil
	end
end

---
---Clears all icon fields from the prototype object with the given `name` and `type_name`.
---
---Warning! This leaves the prototype in an invalid state!
---Be sure to set a new icon after calling this function.
---
---### Examples
---```lua
---_icons.clear_icon_from_named_prototype("iron-plate", "item")
---```
---
---### Parameters
---@param name string # The name of the prototype.
---@param type_name string # The type name of the prototype.
function _icons.clear_icon_from_named_prototype(name, type_name)
	_icons.clear_icon_from_prototype(data.raw[type_name][name])
end

---
---Adds default values to missing fields from the given `icon_datum`.\
---`icon_data` is not modified.
---
---Note: this method does not set `IconData.draw_background` or `IconData.floating`.
---These represent an advanced use case and should be handled directly.
---
---### Examples
---```lua
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
---icon_datum = _icons.add_missing_icon_defaults(icon_datum)
---```
---
---### Parameters
---@param icon_datum IconData # An `IconData` object.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconData # A copy of `icon_datum` with missing fields set to default values.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_dataum` is `nil`\
---*@throws* `string` — Thrown when `icon_dataum.icon` is not a mod-prefixed absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_dataum.icon_size` is not a positive integer.
---@nodiscard
function _icons.add_missing_icon_defaults(icon_datum, defaults_type)
	-- stylua: ignore start
	assert(icon_datum, "Missing required parameter: 'icon_datum' must not be nil.")
	assert(not (icon_datum[1] and icon_datum[1].icon), "Invalid parameter type: 'icon_datum' must be IconData, but was IconData[].")
	assert(not icon_datum[1], "Invalid parameter type: 'icon_datum' must be IconData, and not an array.")

	-- Validate icon file path.
	assert(icon_datum.icon and icon_datum.icon ~= "",  "Missing required field: 'icon' must not be nil or empty.")
	assert(icon_datum.icon:find("^__[%a%d%-%_-]+__"), "Invalid filename: 'icon' must be an absolute file path, but was '" .. icon_datum.icon .. "'.")
	assert(icon_datum.icon:match("%.([%a%d]+)$"), "Invalid filename: 'icon' must have a valid file extension, but was '" .. icon_datum.icon .. "'.")

	-- Set icon_size to default for the type, if not explicitly provided.
	local expected_icon_size = default_icon_sizes[defaults_type or ""] or defines.default_icon_size
	local icon_size = icon_datum.icon_size or expected_icon_size

	assert(type(icon_size) == "number", "Invalid type: 'icon_size' must be a number, but was a '" .. type(icon_size) .. "'.")
	assert(icon_size > 0 and icon_size % 1 == 0, "Invalid value: 'icon_size' must be an integer greater than zero, but was '" .. icon_size .. "'.")
	-- stylua: ignore end

	return {
		icon = icon_datum.icon,
		icon_size = icon_size,
		scale = icon_datum.scale or ((expected_icon_size / 2) / icon_size),
		shift = icon_datum.shift or nil,
		tint = icon_datum.tint or nil,
		draw_background = icon_datum.draw_background,
		floating = icon_datum.floating,
	}
end

---
---Adds default values to missing fields from each element of the given `icon_data` array.\
---`icon_data` is not modified.
---
---Note: this method does not set `IconData.draw_background` or `IconData.floating`.
---These represent an advanced use case and should be handled directly.
---
---### Examples
---```lua
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    },
---    {
---        icon = "__base__/graphics/icons/copper-wire.png",
---        icon_size = 64,
---        scale = 0.25,
---        shift = { -16, 16 }
---    },
---}
---
---icon_data = _icons.add_missing_icons_defaults(icon_data)
---```
---
---### Parameters
---@param icon_data IconData[] # An icon represented by an array of `IconData` objects.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconData[] # A copy of `icon_data` with missing fields on each element set to default values.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `icon_data[n].icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_data[n].icon_size` is not a positive integer.
---@nodiscard
function _icons.add_missing_icons_defaults(icon_data, defaults_type)
	assert(icon_data, "Invalid parameter: 'icon_data' must not be nil.")

	local new_icon_data = {}
	for n = 1, #icon_data do
		new_icon_data[n] = _icons.add_missing_icon_defaults(icon_data[n], defaults_type)
	end

	return new_icon_data
end

---@param icon FileName # The file name of the icon to use.
---@param icon_size SpriteSizeType # The size of the icon.
---@param scale? double # The scale of the icon.
---@param shift? Vector # The shift of the icon.
---@param tint? Color # The tint of the icon.
---@return IconData # An `IconData` object representing the packed icon
---@nodiscard
local function pack_as_icon_datum(icon, icon_size, scale, shift, tint)
	---@type IconData
	local icon_datum = {
		icon = icon,
		icon_size = icon_size,
		scale = scale,
		shift = shift,
		tint = tint,
	}

	return icon_datum
end

---
---Creates an entity, item or recipe `IconData` object with the specified parameters.
---
---### Examples
---```lua
---local icon_data = _icons.create_icon("__base__/graphics/icons/iron-plate.png", 64, 4, 0.5)
---```
---
---### Parameters
---@param icon FileName # The file name of the icon to use.
---@param icon_size SpriteSizeType # The size of the icon.
---@param scale? double # The scale of the icon. Default `32 / icon_size`.
---@param shift? Vector # The shift of the icon. Default `nil`.
---@param tint? Color # The tint of the icon. Default `nil`.
---
---### Returns
---@return IconData # An `IconData` object representing the created icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon` is not a mod-prefixed absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_size` is not a positive integer.
---@nodiscard
function _icons.create_icon(icon, icon_size, scale, shift, tint)
	return _icons.add_missing_icon_defaults(pack_as_icon_datum(icon, icon_size, scale, shift, tint))
end

---
---Creates a technology `IconData` object with the specified parameters.
---
---### Examples
---```lua
---local icon_data = _icons.create_technology_icon("__base__/graphics/technology/logistics-1.png", 256, 4)
---```
---
---### Parameters
---@param icon FileName # The file name of the icon to use.
---@param icon_size SpriteSizeType # The size of the icon.
---@param scale? double # The scale of the icon. Default `256 / icon_size`.
---@param shift? Vector # The shift of the icon. Default `nil`.
---@param tint? Color # The tint of the icon. Default `nil`.
---
---### Returns
---@return IconData # An `IconData` object representing the created technology icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon` is not a mod-prefixed absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_size` is not a positive integer.
---@nodiscard
function _icons.create_technology_icon(icon, icon_size, scale, shift, tint)
	return _icons.add_missing_icon_defaults(pack_as_icon_datum(icon, icon_size, scale, shift, tint), "technology")
end

---
---Gets the icon as an array of `IconData` objects directly from the given `prototype`.
---
---### Remarks
---- If `prototype` is a `RecipePrototype` object, the `icon` or `icons` field must be defined,
---  otherwise an exception is thrown.
---- Missing icon fields are set to default values as appropriate.
---- `prototype` is not modified.
---
---### Examples
---```lua
---local icon_data = _icons.get_icon_from_prototype(data.raw.item["iron-plate"])
---```
---
---### Parameters
---@param prototype PrototypeWithIcons # The prototype to get the icon from.
---
---### Returns
---@return IconData[] # A copy of the icon retrieved from the prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when `prototype` is `nil`.\
---*@throws* `string` — Thrown when `prototype` has no defined field `icon` or `icons`.
---@nodiscard
function _icons.get_icon_from_prototype(prototype)
	assert(prototype, "Invalid parameter: 'prototype' must not be nil.")

	-- Recipes must have an icon or icons field if being passed to this function.
	---
	-- NOTE: the motivation for this was that it avoids trying to figure out what the recipe product is and fetching the
	-- item from that (e.g. the recipe has no icon and inherits it). With the removal of normal/expensive, this is less
	-- cumbersome and it may be reasonable to add logic to retrieve the inherited icon.
	-- stylua: ignore start
	assert((prototype.type ~= "recipe" or (prototype.icons or prototype.icon)), "Invalid parameter: 'prototype' must not be a RecipePrototype with an undefined 'icon' or 'icons' field.")	
	assert(prototype.icons or prototype.icon, "Invalid parameter: 'prototype' must have a defined 'icon' or 'icons' field.")
	-- stylua: ignore end

	---@type IconData[]
	local icons

	-- Give precedence to an existing icons field.
	local default_icon_size = default_icon_sizes[prototype.type] or defines.default_icon_size--[[@as SpriteSizeType]]
	if prototype.icons then
		---@type IconData[]
		icons = util.copy(prototype.icons)

		-- Ensure icon_size is set for all elements before adding defaults.
		for n = 1, #icons do
			icons[n].icon_size = icons[n].icon_size or prototype.icon_size or default_icon_size
		end
	else
		---@cast prototype.icon -?
		---@type IconData[]
		icons = {
			{
				icon = prototype.icon,
				icon_size = prototype.icon_size or default_icon_size,
			},
		}
	end

	return _icons.add_missing_icons_defaults(icons, prototype.type)
end

---
---Gets the icon as an array of `IconData` objects from the prototype with the given `name` and `type_name`.\
---
---### Remarks
---- If `type_name` is `"recipe"`, the `icon` or `icons` field on the `RecipePrototype` object must be defined.
---- Missing icon fields are set to default values as appropriate.
---- The prototype is not modified.
---
---### Examples
---```lua
---local icon_data = _icons.get_icon_from_named_prototype("iron-plate", "item")
---```
---
---### Parameters
---@param name string # The name of the prototype.
---@param type_name string # The type name of the prototype.
---
---### Returns
---@return IconData[] # A copy of the icon retrieved from the prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is not a non-empty string.\
---*@throws* `string` — Thrown when `type_name` is not a non-empty string.\
---*@throws* `string` — Thrown when `type_name` is not a known prototype type.\
---*@throws* `string` — Thrown when the prototype does not exist.\
---*@throws* `string` — Thrown when the prototype has no defined field `icon` or `icons`.
---@nodiscard
function _icons.get_icon_from_named_prototype(name, type_name)
	assert(type(name) == "string" and name ~= "", "Invalid parameter: 'name' must be a non-empty string.")
	assert(type(type_name) == "string" and type_name ~= "", "Invalid parameter: 'type_name' must be a non-empty string.")
	assert(data.raw[type_name], "Invalid parameter: '" .. type_name .. "' is not a valid prototype type name.")
	assert(data.raw[type_name][name], "Prototype not found: " .. name .. " (" .. type_name .. ")")

	return _icons.get_icon_from_prototype(data.raw[type_name][name])
end

---
---Gets the dark-background icon as an array of `IconData` objects directly from the given `item_prototype`.
---
---Missing icon fields are set to default values as appropriate.
---The `prototype` is not modified.
---
---### Examples
---```lua
---local item = data.raw.item["coal"]
---local dark_background_icon_data = _icons.get_dark_background_icon_from_prototype(item)
---```
---
---### Parameters
---@param item_prototype ItemPrototype # The item prototype to get the icon from.
---
---### Returns
---@return IconData[]|nil # A copy of the dark-background icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined dark-background icon.
---
---### Exceptions
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `dark_background` icon.
---@nodiscard
function _icons.get_dark_background_icon_from_prototype(item_prototype)
	if not (item_prototype and (item_prototype.dark_background_icons or item_prototype.dark_background_icon)) then
		return
	end

	---@type IconData[]
	local icons

	-- Give precedence to an existing icons field.
	if item_prototype.dark_background_icons then
		icons = util.copy(item_prototype.dark_background_icons)

		-- Ensure icon_size is set for all elements before adding defaults.
		for n = 1, #icons do
			icons[n].icon_size = icons[n].icon_size or item_prototype.icon_size or defines.default_icon_size--[[@as SpriteSizeType]]
		end
	else
		---@cast item_prototype.dark_background_icon -?
		---@type IconData[]
		icons = {
			{
				icon = item_prototype.dark_background_icon,
				icon_size = item_prototype.dark_background_icon_size or defines.default_icon_size --[[@as SpriteSizeType]],
			},
		}
	end

	return _icons.add_missing_icons_defaults(icons, item_prototype.type)
end

---
---Gets the dark-background icon as an array of `IconData` objects from the item prototype with the given `name` and
---`type_name`.
---
---Missing icon fields are set to default values as appropriate.
---The prototype is not modified.
---
---### Examples
---```lua
---local dark_background_icon_data = _icons.get_dark_background_icon_from_named_prototype("coal", "item")
---```
---
---### Parameters
---@param name string # The name of the item prototype.
---@param type_name string # The type name of the item prototype.
---
---### Returns
---@return IconData[]|nil # A copy of the dark-background icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined dark-background icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `type_name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `dark_background` icon.
---@nodiscard
function _icons.get_dark_background_icon_from_named_prototype(name, type_name)
	assert(name and name ~= "", "Invalid parameter: 'name' must not be nil or an empty string.")
	assert(type_name and type_name ~= "", "Invalid parameter: 'type_name' must not be nil or an empty string.")

	return _icons.get_dark_background_icon_from_prototype(data.raw[type_name][name])
end

---
---Gets the starmap icon as an array of `IconData` objects directly from the given `space_location_prototype`.
---
---Missing icon fields are set to default values as appropriate.
---The `prototype` is not modified.
---
---### Examples
---```lua
---local planet = data.raw["starmap-location"]["shattered-planet"]
---local planet_starmap_icon_data = _icons.get_starmap_icon_from_prototype(planet)
---```
---
---### Parameters
---@param space_location_prototype SpaceLocationPrototype # The space location prototype to get the icon from.
---
---### Returns
---@return IconData[]|nil # A copy of the starmap icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined starmap.
---
---### Exceptions
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `starmap` icon.
---@nodiscard
function _icons.get_starmap_icon_from_prototype(space_location_prototype)
	if
		not (space_location_prototype and (space_location_prototype.starmap_icons or space_location_prototype.starmap_icon))
	then
		return
	end

	---@type IconData[]
	local icons

	-- Give precedence to an existing icons field.
	if space_location_prototype.starmap_icons then
		---@type IconData[]
		icons = util.copy(space_location_prototype.starmap_icons)

		-- Ensure icon_size is set for all elements before adding defaults.
		for n = 1, #icons do
			icons[n].icon_size = icons[n].icon_size
				or space_location_prototype.icon_size
				or default_icon_sizes["space-location"]
		end
	else
		---@cast space_location_prototype.starmap_icon -?
		---@type IconData[]
		icons = {
			{
				icon = space_location_prototype.starmap_icon,
				icon_size = space_location_prototype.starmap_icon_size or default_icon_sizes["space-location"],
			},
		}
	end

	return _icons.add_missing_icons_defaults(icons, space_location_prototype.type)
end

---
---Gets the starmap icon as an array of `IconData` objects from the prototype with the given `name` and `type_name`.
---
---Missing icon fields are set to default values as appropriate.
---The prototype is not modified.
---
---### Examples
---```lua
---local starmap_icon_data = _icons.get_starmap_icon_from_named_prototype("shattered-planet", "space-location")
---```
---
---### Parameters
---@param name string # The name of the prototype with a starmap.
---@param type_name string # The type name of the prototype with a starmap.
---
---### Returns
---@return IconData[]|nil # A copy of the starmap icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined starmap.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `type_name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `starmap` icon.
---@nodiscard
function _icons.get_starmap_icon_from_named_prototype(name, type_name)
	assert(name and name ~= "", "Invalid parameter: 'name' must not be nil or an empty string.")
	assert(type_name and type_name ~= "", "Invalid parameter: 'type_name' must not be nil or an empty string.")

	return _icons.get_starmap_icon_from_prototype(data.raw[type_name][name])
end

local related_prototypes = {
	["item"] = true,
	["item-with-entity-data"] = true,
	["explosion"] = true,
	["corpse"] = true,
}

---
---Sets the given `icon_data` on the prototype with the given `name` and `type_name`, and the
---related prototypes that follow standard naming conventions, such as the item, explosion and
---remnant prototypes.
---
---Optionally sets the `pictures` field as appropriate with the given `pictures`.
---
---### Remarks
---This method assumes that recipes with the same `name` as the target prototype, having a single result that is the
---target prototype, should use the same icon. If this behavior is undesirable, handle assignment of icons to related
---entities directly.
---
---### Examples
---```lua
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/assembling-machine-1.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
-----Get a sprite for display in-world without tier labels.
---local unlabeled_pictures = sprite_tools.create_sprite_from_icon(icon_datum, 1.0)
---
-----Add tier labels to the assembling machine icon.
---local labeled_icon = tier_tools.add_tier_labels_to_icon(1, icon_datum)
---
-----Update the tier-1 assembly machine prototype and its related prototypes.
---_icons.assign_icons_to_prototype_and_related_prototypes("assembling-machine-1", "assembling-machine", labeled_icon, unlabeled_pictures)
---```
---
---### Parameters
---@param name string # The name of the prototype.
---@param type_name? string # The type name of the prototype.
---@param icon_data IconData[] # An icon represented by an array of `IconData` objects.
---@param pictures? SpriteVariations # A `SpriteVariations` object to use as the in-world sprite. Typical use is when `icon_data` has e.g., tier labels, and the in-world sprite should not.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `icon_data[n].icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_data[n].icon_size` is not a positive integer.
function _icons.assign_icons_to_prototype_and_related_prototypes(name, type_name, icon_data, pictures)
	assert(name and name ~= "", "Invalid parameter: 'name' must not be nil or an empty string.")

	local icon_data_copy = _icons.add_missing_icons_defaults(icon_data, type_name)

	local prototype = (type_name and not related_prototypes[type_name]) and data.raw[type_name][name] or nil

	-- Exclude technologies and recipes from related-prototype updates.
	if type_name ~= "technology" and type_name ~= "recipe" then
		local item = data.raw["item"][name]
		if item then
			_icons.clear_icon_from_prototype(item)
			item.icons = icon_data_copy
			item.pictures = pictures
		end

		local item_with_entity_data = data.raw["item-with-entity-data"][name]
		if item_with_entity_data then
			_icons.clear_icon_from_prototype(item_with_entity_data)
			item_with_entity_data.icons = icon_data_copy

			-- The pictures field is ignored as of 1.0, this has been left active
			-- in the hopes the default behavior is adjusted.
			item_with_entity_data.pictures = pictures
		end

		-- Clear out recipes of the same name so that the item icon is inherited properly.
		-- Possibly a dangerous assumption that all recipes with the same name as the item
		-- are intended to inherit the icon directly and do not use a custom icon.

		local recipe = data.raw["recipe"][name]
		if recipe and recipe.results and #recipe.results == 1 and recipe.results[1].name == name then
			_icons.clear_icon_from_prototype(recipe)

			-- icon is required if the recipe does not have a main product.
			if not recipe.main_product then
				recipe.icons = icon_data_copy
			end
		end
	end

	if prototype then
		_icons.clear_icon_from_prototype(prototype)
		prototype.icons = icon_data_copy

		-- Try to grab the explosion name from the prototype directly, to ensure it is picked up in the
		-- event it does not follow the expected pattern.
		local dying_explosion_name
		if prototype.dying_explosion then
			if prototype.dying_explosion.name then
				dying_explosion_name = prototype.dying_explosion
			elseif prototype.dying_explosion[1] and prototype.dying_explosion[1].name then
				dying_explosion_name = prototype.dying_explosion[1].name
			end
		end

		local explosion_names = {
			[name .. "-explosion"] = true,
			["ar-" .. name .. "-explosion"] = true,
		}

		if dying_explosion_name then
			explosion_names[dying_explosion_name] = true
		end

		for explosion_name, _ in pairs(explosion_names) do
			local explosion = data.raw["explosion"][explosion_name]
			if explosion then
				_icons.clear_icon_from_prototype(explosion)
				explosion.icons = icon_data_copy
			end
		end

		-- Try to grab the corpse name from the prototype directly, to ensure it is picked up in the
		-- event it does not follow the expected pattern.
		local corpse_name
		if type(prototype.corpse) == "string" then
			corpse_name = prototype.corpse
		elseif type(prototype.corpse) == "table" and type(prototype.corpse[1]) == "string" then
			corpse_name = prototype.corpse[1]
		end

		local remnants_names = {
			[name .. "-remnants"] = true,
			["ar-" .. name .. "-remnants"] = true,
		}

		if corpse_name then
			remnants_names[corpse_name] = true
		end

		for remnants_name, _ in pairs(remnants_names) do
			local remnants = data.raw["corpse"][remnants_name]
			if remnants then
				_icons.clear_icon_from_prototype(remnants)
				remnants.icons = icon_data_copy
			end
		end
	end
end

---
---Assigns the given `deferrable_icon` to the associated prototype.
---
---### Examples
---```lua
------@type DeferrableIconData
---local deferrable_icon = {
---    name = "iron-plate",
---    type_name = "item",
---    icon_data = { {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    } },
---}
---
---_icons.assign_deferrable_icon(deferrable_icon)
---```
---
---### Parameters
---@param deferrable_icon DeferrableIconData|DeferrableIconDatum # An icon configured for deferrable assignment to a prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when a deferred icon's `name` field is `nil` or an empty string.\
---*@throws* `string` — Thrown when a deferred icon's `type_name` field is `nil` or an empty string.\
---*@throws* `string` — Thrown when a deferred icon's `icon_data` field is `nil`\
---*@throws* `string` — Thrown when a deferred icon's `icon_data[n].icon` field is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when a deferred icon's `icon_data[n].icon_size` field is not a positive integer.
---
---### See Also
---@see Icons.assign_icons_to_prototype_and_related_prototypes
function _icons.assign_deferrable_icon(deferrable_icon)
	if deferrable_icon.icon_datum then
		_icons.assign_icons_to_prototype_and_related_prototypes(
			deferrable_icon.name,
			deferrable_icon.type_name,
			{ deferrable_icon.icon_datum }
		)
	elseif deferrable_icon.icon_data then
		_icons.assign_icons_to_prototype_and_related_prototypes(
			deferrable_icon.name,
			deferrable_icon.type_name,
			deferrable_icon.icon_data,
			deferrable_icon.pictures
		)
	end
end

---@alias DeferredIconStore { [Stage]: (DeferrableIconData|DeferrableIconDatum)[] }

---
---Performs validation and sanitization of the given `deferrable_icon`, and adds it to the
---given `deferred_icon_store` dictionary of `DeferrableIconData` for later assignment in the
---given `stage`.
---
---Pass the same `deferrable_icon` table to the method `_icons.assign_icons_deferred_to_stage` with
---the same `stage` during appropriate stage, to assign the deferred icons to the associated prototypes.
---
---### Examples
---```lua
----- To store an icon created in the data stage for later assignment in the data-updates stage.
---
----- Create the empty table to hold the stored icons. No pre-configuration is required.
----- The lifetime of this variable must continue between stages.
---globals.deferred_icon_store = {}
---
----- Create the icon data (or use a pre-existing one).
------@type DeferrableIconsData
---local deferrable_icon = {
---    name = "iron-plate",
---    type_name = "item",
---    icon_data = { {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    } },
---}
---
----- Store the icon for deferred assignment in the data-updates stage.
---_icons.store_icon_for_deferred_assignment_in_stage(deferred_icon_store, reskins.defines.stage.data_updates, deferrable_icon)
---```
---
---### Parameters
---@param deferred_icon_store DeferredIconStore # The dictionary of deferrable icons, indexed by stage, to add the deferrable icon to.
---@param stage Stage # The key to the data stage to store the deferrable icon in.
---@param deferrable_icon DeferrableIconData|DeferrableIconDatum # The icon data to store for deferred assignment.
---
---### Exceptions
---*@throws* `string` — Thrown when `deferred_icon_store` is `nil`.\
---*@throws* `string` — Thrown when `stage` is `nil` \
---*@throws* `string` — Thrown when `deferrable_icon` is `nil`.\
---*@throws* `string` — Thrown when `deferrable_icon.name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `deferrable_icon.type_name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when both `deferrable_icon.icon_data` and `deferrable_icon.icon_datum` is `nil`, or `deferrable_icon.icon_data` is not an array of `IconData` objects, or the `IconData` objects are invalid.
---
---### See Also
---@see Icons.assign_icons_deferred_to_stage
function _icons.store_icon_for_deferred_assignment_in_stage(deferred_icon_store, stage, deferrable_icon)
	-- stylua: ignore start
	assert(deferred_icon_store, "Invalid parameter: 'deferred_icon_store' must not be nil.")
	assert(stage, "Invalid parameter: 'stage' must not be nil.")

	-- Validate the deferred icon.
	assert(deferrable_icon, "Invalid parameter: 'deferrable_icon' must not be nil.")
	assert(deferrable_icon.name and deferrable_icon.name ~= "", "Invalid operation: 'deferrable_icon.name' must not be nil or an empty string.")
	assert(deferrable_icon.type_name and deferrable_icon.type_name ~= "", "Invalid operation: 'deferrable_icon.type_name' must not be nil or an empty string.")
	assert(deferrable_icon.icon_data or deferrable_icon.icon_datum, "Invalid operation: 'deferrable_icon.icon_data' or `deferrable_icon.icon_datum` are required.")
	assert(deferrable_icon.icon_data and deferrable_icon.icon_data[1], "Invalid operation: 'deferrable_icon.icon_data' must not be an empty array.")
	-- stylua: ignore end

	-- Validate the icon data and add missing defaults.
	deferrable_icon.icon_data = _icons.add_missing_icons_defaults(deferrable_icon.icon_data, deferrable_icon.type_name)

	if not deferred_icon_store[stage] then
		deferred_icon_store[stage] = {}
	end

	table.insert(deferred_icon_store[stage], deferrable_icon)
end

---
---Assigns the deferrable icons in `deferred_icon_store[stage]` to the associated prototypes.
---
---### Examples
---```lua
----- Using the variable created earlier to store deferrable icons.
---reskins._internal.assign_icons_deferred_to_stage(globals.deferred_icon_store, reskins.defines.stage.data_updates)
---```
---
---### Parameters
---@param deferred_icon_store DeferredIconStore # The dictionary of deferrable icons, indexed by stage, to assign the deferrable icons from.
---@param stage Stage # The index of the data stage to source deferrable icons from.
---
---### Exceptions
---*@throws* `string` — Thrown when a deferred icon's `name` field is `nil` or an empty string.\
---*@throws* `string` — Thrown when a deferred icon's `type_name` field is `nil` or an empty string.\
---*@throws* `string` — Thrown when a deferred icon's `icon_data` field is `nil`\
---*@throws* `string` — Thrown when a deferred icon's `icon_data[n].icon` field is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when a deferred icon's `icon_data[n].icon_size` field is not a positive integer.
---
---### See Also
---@see Icons.store_icon_for_deferred_assignment_in_stage
---@see Icons.assign_deferrable_icon
function _icons.assign_icons_deferred_to_stage(deferred_icon_store, stage)
	if not deferred_icon_store[stage] then
		return
	end

	for _, deferrable_icon in pairs(deferred_icon_store[stage]) do
		_icons.assign_deferrable_icon(deferrable_icon)
	end
end

---
---Composes the given set of icons defined by `IconData` objects or arrays of `IconData` objects
---into a single icon, with the first icon at the base of the stack and the last icon at the top.
---
---### Remarks
---- Missing icon fields are set to default values as appropriate.
---- Inputs are not modified.
---
---### Parameters
---@param defaults_type IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---@param ... IconData|IconData[]|nil # A variable set of `IconData` or `IconData` arrays to combine.
---
---### Returns
---@return IconData[] # A single icon built from combining the input icons.
---
---### See Also
---@see Icons.add_missing_icon_defaults
---@nodiscard
function _icons.compose_icons(defaults_type, ...)
	---@type IconData[]
	local combined_icon_data = {}

	for _, input_icon in pairs({ ... }) do
		if input_icon then
			if input_icon.icon then
				-- It's an IconData object.
				table.insert(combined_icon_data, _icons.add_missing_icon_defaults(input_icon, defaults_type))
			elseif input_icon[1] and input_icon[1].icon then
				-- It's an array of IconData objects.
				for _, icon_datum in pairs(input_icon) do
					table.insert(combined_icon_data, _icons.add_missing_icon_defaults(icon_datum, defaults_type))
				end
			end
		end
	end

	return combined_icon_data
end

---
---Adds the icon from the given `prototype` to a copy the given `icon_data` array, and applies any
---of the optional transformations given by `scale`, `shift` or `tint`.
---
---### Remarks
---- This method assumes that `icon_data` is for a prototype of the same type as `prototype`, for purposes of setting
---  a missing icon_size to its default value.
---- Missing icon fields are set to default values as appropriate.
---- `icon_data` and `prototype` are not modified.
---
---### Examples
---```lua
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    },
---}
---
----- Add the copper wire icon at one-half scale to the bottom left corner of the icon.
---local prototype = data.raw["item"]["copper-wire"]
---local iron_plate_with_copper_wire = _icons.add_icons_from_prototype_to_icons(icon_data, prototype, 0.5, { -16, 16 })
---```
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects to receive the icon from `prototype`.
---@param prototype PrototypeWithIcons # The prototype to source the icon from.
---@param scale? double # The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector # The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color # The tint to apply to the sourced icon. Default `nil`.
---
---### Returns
---@return IconData[] # A copy of `icon_data` composed with the transformed icon data from `prototype`.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.
---*@throws* `string` — Thrown when `prototype` is `nil`.
---
---### See Also
---@see Icons.add_missing_icons_defaults
---@see Icons.get_icon_from_prototype
---@nodiscard
function _icons.add_icons_from_prototype_to_icons(icon_data, prototype, scale, shift, tint)
	assert(icon_data, "Invalid parameter: 'icon_data' must not be nil.")
	assert(prototype, "Invalid parameter: 'prototype' must not be nil.")

	local icon_data_copy = _icons.add_missing_icons_defaults(icon_data, prototype.type)
	local sourced_icon_data = _icons.get_icon_from_prototype(prototype)
	if not sourced_icon_data then
		return icon_data_copy
	end

	for _, icon_datum in pairs(sourced_icon_data) do
		table.insert(icon_data_copy, _icons.transform_icon(icon_datum, scale, shift, tint, prototype.type))
	end

	return icon_data_copy
end

---
---Adds the icon from the given `prototype` to a new `IconData[]` array with the given `icon_datum`
---as the base layer, and applies any of the optional transformations given by `scale`, `shift` or
---`tint`.
---
---### Remarks
---- This method assumes that `icon_datum` is for a technology icon for purposes of setting
---  missing defaults if `prototype.type == "technology"`.
---- Missing icon fields are set to default values as appropriate.
---- `icon_datum` and `prototype` are not modified.
---
---### Examples
---```lua
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
----- Add the copper wire icon at one-half scale to the bottom left corner of the icon.
---local prototype = data.raw["item"]["copper-wire"]
---local iron_plate_with_copper_wire = _icons.add_icons_from_prototype_to_icon(icon_datum, prototype, 0.5, { -16, 16 })
---```
---
---### Parameters
---@param icon_datum IconData # An `IconData` object to be combined with the icon from `prototype`.
---@param prototype PrototypeWithIcons # The prototype to source the icon from.
---@param scale? double # The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector # The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color # The tint to apply to the sourced icon. Default `nil`.
---
---### Returns
---@return IconData[] # An array of `IconData` with a copy of `icon_datum` as the base layer, and the added icon data from `prototype`.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is `nil`.\
---*@throws* `string` — Thrown when `icon_datum.icon` is `nil`.
---
---### See Also
---@see Icons.add_icons_from_prototype_to_icons
---@nodiscard
function _icons.add_icons_from_prototype_to_icon(icon_datum, prototype, scale, shift, tint)
	assert(icon_datum, "Invalid parameter: 'icon_datum' must not be nil.")
	assert(icon_datum.icon, "Invalid parameter: 'icon_datum.icon' must not be nil.")

	return _icons.add_icons_from_prototype_to_icons({ icon_datum }, prototype, scale, shift, tint)
end

---
---Adds the icon from the prototype with the given `name` and `type_name` a copy the given
---`icon_data` array, and applies any of the optional transformations given by `scale`, `shift` or
---`tint`.
---
---### Remarks
---- This method assumes that `icon_data` is for a technology icon for purposes of setting
---  missing defaults if the prototype has `type == "technology"`.
---- Missing icon fields are set to default values as appropriate.
---- `icon_data` and the prototype are not modified.
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects to receive the icon from `prototype`.
---@param name string # The name of the prototype to source the icon from.
---@param type_name string # The type name of the prototype to source the icon from.
---@param scale? double # The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector # The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color # The tint to apply to the sourced icon. Default `nil`.
---
---### Returns
---@return IconData[] # An icon with a copy of `icon_datum` as the base layer, composed with the transformed icon from the prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `type_name` is `nil` or an empty string.
---*@throws* `string` — Thrown when a prototype with the given `name` and `type_name` does not exist.\
---
---### See Also
---@see Icons.add_icons_from_prototype_to_icons
---@nodiscard
function _icons.add_icons_from_prototype_to_icons_by_name(icon_data, name, type_name, scale, shift, tint)
	assert(icon_data, "Invalid parameter: 'icon_data' must not be nil.")
	assert(name and name ~= "", "Invalid parameter: 'name' must not be nil or an empty string.")
	assert(type_name and type_name ~= "", "Invalid parameter: 'type_name' must not be nil or an empty string.")
	assert(
		data.raw[type_name] and data.raw[type_name][name],
		"Invalid operation: a prototype with the given name and type_name does not exist."
			.. serpent.block({ name = name, type_name = type_name })
	)

	return _icons.add_icons_from_prototype_to_icons(icon_data, data.raw[type_name][name], scale, shift, tint)
end

---
---Adds the icon from the prototype with the given `name` and `type_name` to a new `IconData[]`
---array with the given `icon_datum` as the base layer, and applies any of the optional
---transformations given by `scale`, `shift` or `tint`.
---
---### Remarks
---- This method assumes that `icon_datum` is for a technology icon for purposes of setting
---  missing defaults if the prototype has `type == "technology"`.
---- Missing icon fields are set to default values as appropriate.
---- `icon_datum` and the prototype are not modified.
---
---### Examples
---```lua
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
----- Add the copper wire icon at one-half scale to the bottom left corner of the icon.
---local iron_plate_with_copper_wire = _icons.add_icons_from_prototype_to_icon_by_name(icon_datum, "copper-wire", "item", 0.5, { -16, 16 })
---```
---
--- ### Parameters
---@param icon_datum IconData # An `IconData` object to be combined with the icon from `prototype`.
---@param name string # The name of the prototype to source the icon from.
---@param type_name string # The type name of the prototype to source the icon from.
---@param scale? double # The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector # The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color # The tint to apply to the sourced icon. Default `nil`.
---
---### Returns
---@return IconData[] # An icon with a copy of `icon_datum` as the base layer, composed with the transformed icon from the prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is `nil`.\
---*@throws* `string` — Thrown when `icon_datum.nil` is `nil`.\
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `type_name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when a prototype with the given `name` and `type_name` does not exist.
---
---### See Also
---@see Icons.add_icons_from_prototype_to_icons
---@nodiscard
function _icons.add_icons_from_prototype_to_icon_by_name(icon_datum, name, type_name, scale, shift, tint)
	assert(icon_datum, "Invalid parameter: 'icon_datum' must not be nil.")
	assert(icon_datum.icon, "Invalid parameter: 'icon_datum.icon' must not be nil.")
	assert(name and name ~= "", "Invalid parameter: 'name' must not be nil or an empty string.")
	assert(type_name and type_name ~= "", "Invalid parameter: 'type_name' must not be nil or an empty string.")
	assert(
		data.raw[type_name] and data.raw[type_name][name],
		"Invalid operation: a prototype with the given name and type_name does not exist."
			.. serpent.block({ name = name, type_name = type_name })
	)

	return _icons.add_icons_from_prototype_to_icons({ icon_datum }, data.raw[type_name][name], scale, shift, tint)
end

---
---Transforms the given `icon_data` array by applying the given `scale`, `shift` and `tint` to each
---element of the array.
---
---### Remarks
---- Missing icon fields are set to default values as appropriate.
---- `icon_data` is not modified.
---
---### Examples
---```lua
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    },
---    {
---        icon = "__base__/graphics/icons/copper-wire.png",
---        icon_size = 64,
---        scale = 0.25,
---        shift = { -16, 16 }
---    },
---}
---
----- Transform the icon by scaling it to 1.5 times its original size
----- and shifting it by 16 pixels to the right.
---local transformed_icon_data = _icons.transform_icon(icon_data, 1.5, { 16, 0 })
---```
---
---### Parameters
---@param icon_datum IconData # An array of `IconData` objects to be transformed.
---@param scale? double # The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector # The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color # The tint to apply to the sourced icon. Default `nil`.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconData # A copy of `icon_datum` with the transformations applied.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is `nil`.\
---*@throws* `string` — Thrown when `icon_datum.icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_datum.icon_size` is not a positive integer.
---@nodiscard
function _icons.transform_icon(icon_datum, scale, shift, tint, defaults_type)
	local copy = _icons.add_missing_icon_defaults(icon_datum, defaults_type)
	if not scale and not shift and not tint then
		return copy
	end

	---@type IconData
	local transformed = {
		icon = copy.icon,
		icon_size = copy.icon_size,
		scale = copy.scale * (scale or 1),
		shift = shift and util.add_shift(util.mul_shift(copy.shift or { 0, 0 }, scale or 1)--[[@cast -?]], shift) or copy.shift,
		tint = tint or copy.tint,
		draw_background = copy.draw_background,
		floating = copy.floating,
	}

	return transformed
end

---Transforms the given `icon_data` array by applying the given `scale`, `shift` and `tint` to each
---element of the array.
---
---### Remarks
---- Missing icon fields are set to default values as appropriate.
---- `icon_data` is not modified.
---
---### Examples
---```lua
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    },
---    {
---        icon = "__base__/graphics/icons/copper-wire.png",
---        icon_size = 64,
---        scale = 0.25,
---        shift = { -16, 16 }
---    },
---}
---
----- Transform the icon by scaling it to 1.5 times its original size
----- and shifting it by 16 pixels to the right.
---local transformed_icon_data = _icons.transform_icon(icon_data, 1.5, { 16, 0 })
---```
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects to be transformed.
---@param scale? double # The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector # The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color # The tint to apply to the sourced icon. Default `nil`.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconData[] # A copy of `icon_data` with the transformations applied.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `icon_data[n].icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_data[n].icon_size` is not a positive integer.
---@nodiscard
function _icons.transform_icons(icon_data, scale, shift, tint, defaults_type)
	if not scale and not shift and not tint then
		return _icons.add_missing_icons_defaults(icon_data, defaults_type)
	end

	local transformed_icon_data = {}
	for _, layer in pairs(icon_data) do
		table.insert(transformed_icon_data, _icons.transform_icon(layer, scale, shift, tint, defaults_type))
	end

	return transformed_icon_data
end

---
---Gets an `IconData` object from the given `source`.
---
---### Remarks
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist
---  will be replaced with a blank icon.
---- Missing icon fields are set to default values as appropriate.
---- `source` is not modified.
---
---### Examples
---```lua
------@type PrototypeIconSource
---local icon_datum_source = {
---    name = "iron-plate",
---    type_name = "item",
---}
---
----- Get the icon data from the source.
------@type IconData[]
---local icon_data = _icons.get_icon_from_source(icon_datum_source)
---```
---
---### Parameters
---@param source? IconSource # A source of `icon_data`.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconData[] # A copy of the icon data from `source`, if it exists; otherwise, a blank icon.
---@return boolean # When `true`, a blank icon was created.
---@nodiscard
local function get_icons_from_source(source, defaults_type)
	---@type IconData[]
	local icon_data

	if source and source.icon_data then
		---@cast source IconDataSource
		icon_data = _icons.add_missing_icons_defaults(source.icon_data, source.defaults_type)
	elseif source and source.icon_datum then
		---@cast source IconDatumSource
		icon_data = { _icons.add_missing_icon_defaults(source.icon_datum, source.defaults_type) }
	elseif source and source.name then
		local prototype = data.raw[source.type_name] and data.raw[source.type_name][source.name] or nil
		if prototype then
			icon_data = _icons.get_icon_from_prototype(prototype)
		end
	end

	local is_blank_icon = false
	if not icon_data then
		is_blank_icon = true
		icon_data = { _icons.empty_icon(defaults_type) }
	end

	return icon_data, is_blank_icon
end

---
---Adds the icons from the given `sources` to a copy of the given `icon_data` array, and applies any
---of the optional transformations.
---
---### Remarks
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist
---  will be replaced with a blank icon.
---- Missing icon fields are set to default values as appropriate.
---- `icon_data` and `sources` are not modified.
---
---### Parameters
---@param icon_data IconData[] # An `IconData` object to be combined with the sourced icons from `sources`.
---@param sources IconSources # An array of `IconData` sources to layer on `icon_data`.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`. Individual source types take precedence over this value.
---
---### Returns
---@return IconData[], boolean # A copy of `icon_data` with the sourced icons from `sources` transformed and layered on top, if any exist; otherwise, a straight, unmodified copy of `icon_data`. When the second return value is `true`, a blank icon layer was created.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `sources` is `nil`.
---
---### See Also
---@see Icons.add_missing_icons_defaults
---@see Icons.add_missing_icon_defaults
---@see Icons.get_icon_from_named_prototype
---@nodiscard
function _icons.add_icons_from_sources_to_icons(icon_data, sources, defaults_type)
	assert(icon_data, "Invalid parameter: 'icon_data' must not be nil.")
	assert(sources, "Invalid parameter: 'sources' must not be nil.")

	---@type IconData[]
	local combined_icon = _icons.add_missing_icons_defaults(icon_data, defaults_type)

	local has_blank_layers = false
	for _, source in pairs(sources) do
		-- Icon may be blank if the prototype did not exist.
		local icon, is_blank_icon = get_icons_from_source(source, defaults_type)
		has_blank_layers = has_blank_layers or is_blank_icon

		local transformed_icon = _icons.transform_icons(
			icon,
			source.scale,
			source.shift,
			source.tint,
			source.type_name or source.defaults_type or defaults_type
		)

		for _, icon_datum in pairs(transformed_icon) do
			table.insert(combined_icon, icon_datum)
		end
	end

	return combined_icon, has_blank_layers
end

---
---Creates an icon from the given `source`, with the first element providing the base icon layer,
---and the remaining elements layered on top sequentially. Optional transformations are applied to
---each source, though only `tint` is applied to the base icon.
---
---### Remarks
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist
---  will be replaced with a blank icon, including the base layer.
---- Missing icon fields are set to default values as appropriate.
---- `sources` is not modified.
---
---### Examples
---```lua
----- Define sources for an icon with an iron plate as the base, with two half-size icons sourced
----- from copper wire and copper plate layered on top and shifted to the left and right, respectively.
------@type (IconDatumSource|PrototypeIconSource)[]
---local sources = {
---    -- Define an icon directly.
---    {
---        icon_datum = {
---            icon = "__base__/graphics/icons/iron-plate.png",
---            icon_size = 64,
---            scale = 0.5,
---        },
---    },
---    -- Retrieve from existing item prototypes.
---    { name = "copper-wire", type_name = "item", scale = 0.5, shift = { -8, -8 } },
---    { name = "copper-plate", type_name = "item", scale = 0.5, shift = { 8, -8 } },
---}
---
----- Create the icon from the sources.
---local icon_data = _icons.create_icons_from_sources(sources)
---```
---
---### Parameters
---@param sources IconSources # An array of `IconData` sources to layer on `icon_data`.
---
---### Returns
---@return IconData[] icon A new icon created from the sources, with the base icon from the first source, and icons from the remaining sources layered on top.
---@return boolean has_blank_layers When `true`, a blank icon layer was created.
---
---### Exceptions
---*@throws* `string` — Thrown when `sources` is `nil`.
---@nodiscard
function _icons.create_icons_from_sources(sources)
	assert(sources, "Invalid parameter: 'sources' must not be nil.")

	---@type IconSources
	local sources_copy = util.copy(sources)

	local has_blank_layers = false

	-- Get the base icon from the first source,
	local base_source = table.remove(sources_copy, 1)
	local base_icon_data, is_blank_icon = get_icons_from_source(base_source)

	has_blank_layers = (has_blank_layers or is_blank_icon)

	-- Apply only a tint transformation on the base layer. Scale and shift are not applicable.
	for _, icon_datum in pairs(base_icon_data) do
		icon_datum.tint = sources[1].tint or icon_datum.tint
	end

	local icon_data, added_blank_layers = _icons.add_icons_from_sources_to_icons(base_icon_data, sources_copy)
	has_blank_layers = (has_blank_layers or added_blank_layers)

	return icon_data, has_blank_layers
end

---
---Assigns the given `icon_data` to the prototype with the given `name` and `type_name`, and to any
---related prototypes, such as items, entities, or recipes.
---
---### Remarks
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist
---  will be replaced with a blank icon.
---- Missing icon fields are set to default values as appropriate.
---
---### Examples
---```lua
----- A dictionary of recipe names and the icon sources to use to create a combined icon.
----- The first entry in each IconSources is the first layer of the created icon.
------@type { [string]: IconSources }
---local recipe_icon_source_map = {
---    ["bio-resin-wood-reprocessing"] = {
---        { name = "resin", type_name = "item" },
---        { name = "wood", type_name = "item", scale = 0.5, shift = { -8, -8 } },
---    },
---}
---
---_icons.assign_combined_icons_from_sources_to_recipe(recipe_icon_source_map)
---```
---
---### Parameters
---@param recipe_icon_source_map { [string]: IconSources } # A map of recipe names to the icon sources used to create a combined icon. The first entry in each IconSources is the first layer of the created icon.
function _icons.create_and_assign_composed_icons_from_sources_to_recipe(recipe_icon_source_map)
	for recipe_name, sources in pairs(recipe_icon_source_map) do
		local icon_data = _icons.create_icons_from_sources(sources)
		_icons.assign_icons_to_prototype_and_related_prototypes(recipe_name, "recipe", icon_data)
	end
end

return _icons
