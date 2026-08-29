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

local V = require("validation")
local Common = require("validation.common")

---@type table<string, Reskins.SpriteUtils.Validation.Validator<any>>
local existing_prototype_validators = {}

---Reports whether `name` names a prototype registered under `type_name`.
---
---A cross-argument rule rather than a parameter validator, since whether a name
---exists depends on the type name beside it.
---
---`Common.prototypes.existing_prototype` bakes the type in, so it is a factory
---rather than a validator, and the type is only known at the call. Its result is
---held per type name so a by-name guard does not rebuild one every time.
---
---### Parameters
---@param name string # The prototype name to check.
---@param type_name string # The registered prototype type to look the name up in.
---
---### Returns
---@return boolean # Whether the prototype exists.
---@return string? # What was wanted, when it does not.
local function name_exists_under_type(name, type_name)
	local validator = existing_prototype_validators[type_name]

	if not validator then
		validator = Common.prototypes.existing_prototype(type_name)
		existing_prototype_validators[type_name] = validator
	end

	local result = validator:validate(name, { path = "name" })

	return result.ok, result.errors[1] and result.errors[1].message
end

---The cross-argument rule shared by every guard that takes a name and a type.
---@type Reskins.SpriteUtils.Validation.SignatureRule[]
local names_an_existing_prototype = {
	{ parameter = "name", arguments = { "name", "type_name" }, check = name_exists_under_type },
}

---The expected icon size for `SpaceLocationPrototype::starmap_icon`.
---
---Keyed as `"starmap"` rather than `"space-location"`: the latter is a real
---prototype type whose regular `icon` field takes the default size, and
---`get_icon_from_prototype` keys `default_icon_sizes` with `prototype.type`.
local STARMAP_ICON_SIZE = 512

local default_icon_sizes = {
	["technology"] = 256,
	["achievement"] = 128,
	["item-group"] = 128,
	["shortcut"] = 32,
	["shortcut-small"] = 24,
	["starmap"] = STARMAP_ICON_SIZE,
}

---The `icon_size` an icon assigned to a prototype of the given type is expected to have, when `icon_size` is not
---explicitly provided.
---@param defaults_type? IconDefaultsType # The type-specific defaults to resolve.
---@return SpriteSizeType # The expected icon size, in pixels.
---@nodiscard
local function resolve_expected_icon_size(defaults_type)
	return default_icon_sizes[defaults_type or ""] or defines.default_icon_size
end

---One layer of an icon, with icon_size and scale explicitly set. Icon layering follows the following rules:
---
---* The rendering order of the individual icon layers follows the array order: Later added icon layers (higher index) are drawn on top of previously added icon layers (lower index).
---
---* By default the first icon layer will draw an outline (or shadow in GUI), other layers will draw it only if they have `draw_background` explicitly set to `true`. There are caveats to this though. See [the doc](https://lua-api.factorio.com/latest/types/IconData.html%23draw_background#draw_background).
---
---* When the final icon is displayed with transparency (e.g. a faded out alert), the icon layer overlap may look [undesirable](https://forums.factorio.com/viewtopic.php?p=575844#p575844).
---
---* When the final icon is displayed with a shadow (e.g. an item on the ground or on a belt when item shadows are turned on), each icon layer will [cast a shadow](https://forums.factorio.com/84888) and the shadow is cast on the layer below it.
---
---* The final icon will always be resized and centered in GUI so that all its layers (except the [`floating`](https://lua-api.factorio.com/latest/types/IconData.html%23floating#floating) ones) fit the target slot, but won't be resized when displayed on machines in alt-mode. For example: recipe first icon layer is size 128, scale 1, the icon group will be displayed at resolution /4 to fit the 32px GUI boxes, but will be displayed 4 times as large on buildings.
---
---* Shift values are based on [`expected_icon_size / 2`](https://lua-api.factorio.com/latest/types/IconData.html%23scale#scale).
---
---The game automatically generates [icon mipmaps](https://factorio.com/blog/post/fff-291) for all icons. However, icons can have custom mipmaps defined. Custom mipmaps may help to achieve clearer icons at reduced size (e.g. when zooming out) than auto-generated mipmaps. If an icon file contains mipmaps then the game will automatically infer the icon's mipmap count. Icon files for custom mipmaps must contain half-size images with a geometric-ratio, for each mipmap level. Each next level is aligned to the upper-left corner, with no extra padding. Example sequence: `128x128@(0,0)`, `64x64@(128,0)`, `32x32@(192,0)` is three mipmaps.
---
---[View Documentation](https://lua-api.factorio.com/latest/types/IconData.html)
---@class SafeIconData : IconData
---The size of the square icon, in pixels. E.g. `32` for a 32px by 32px icon. Must be larger than `0`.
---
---[View Documentation](https://lua-api.factorio.com/latest/types/IconData.html%23icon_size#icon_size)
---@field icon_size SpriteSizeType
---Defaults to `(expected_icon_size / 2) / icon_size`.
---
---Specifies the scale of the icon on the GUI scale. A scale of `2` means that the icon will be two times bigger on screen (and thus more pixelated).
---
---Expected icon sizes:
---
---* `512` for [SpaceLocationPrototype::starmap\_icon](https://lua-api.factorio.com/latest/prototypes/SpaceLocationPrototype.html%23starmap_icon#starmap_icon).
---
---* `256` for [TechnologyPrototype](https://lua-api.factorio.com/latest/prototypes/TechnologyPrototype.html).
---
---* `128` for [AchievementPrototype](https://lua-api.factorio.com/latest/prototypes/AchievementPrototype.html) and [ItemGroup](https://lua-api.factorio.com/latest/prototypes/ItemGroup.html).
---
---* `32` for [ShortcutPrototype::icons](https://lua-api.factorio.com/latest/prototypes/ShortcutPrototype.html%23icons#icons) and `24` for [ShortcutPrototype::small\_icons](https://lua-api.factorio.com/latest/prototypes/ShortcutPrototype.html%23small_icons#small_icons).
---
---* `64` for the rest of the prototypes that use icons.
---
---[View Documentation](https://lua-api.factorio.com/latest/types/IconData.html%23scale#scale)
---@field scale double

---Fills in the defaults for one icon layer.
---
---The working half of `add_missing_icon_defaults`, without the validation.
---Everything public validates its own arguments and then comes here, so an
---array is checked once against its own indices rather than once per element
---with no idea which element it was.
---@param icon_datum IconData # A valid `IconData` object.
---@param defaults_type? IconDefaultsType # The type-specific defaults to apply.
---@return SafeIconData # A copy with the missing fields filled in.
---@nodiscard
local function apply_icon_defaults(icon_datum, defaults_type)
	-- Every size this can resolve to is one of this module's own constants or
	-- an already-validated icon_size, so the result needs no further checking.
	local expected_icon_size = resolve_expected_icon_size(defaults_type)
	local icon_size = icon_datum.icon_size or expected_icon_size

	return {
		icon = icon_datum.icon,
		icon_size = icon_size,
		scale = icon_datum.scale or ((expected_icon_size / 2) / icon_size),
		shift = icon_datum.shift and util.copy(icon_datum.shift),
		tint = icon_datum.tint and util.copy(icon_datum.tint),
		draw_background = icon_datum.draw_background,
		floating = icon_datum.floating,
	}
end

---Fills in the defaults for every layer of an icon.
---
---The working half of `add_missing_icons_defaults`, without the validation.
---@param icon_data IconData[] # A valid array of `IconData` objects.
---@param defaults_type? IconDefaultsType # The type-specific defaults to apply.
---@return SafeIconData[] # A copy with the missing fields on each layer filled in.
---@nodiscard
local function apply_icons_defaults(icon_data, defaults_type)
	local new_icon_data = {}
	for index = 1, #icon_data do
		new_icon_data[index] = apply_icon_defaults(icon_data[index], defaults_type)
	end

	return new_icon_data
end

---Applies a scale, shift, and tint to one icon layer.
---
---The working half of `transform_icon`, without the validation.
---@param icon_datum IconData # A valid `IconData` object.
---@param scale? double # The scale to apply.
---@param shift? Vector # The shift to apply.
---@param tint? Color # The tint to apply.
---@param defaults_type? IconDefaultsType # The type-specific defaults to apply.
---@return SafeIconData # A copy with the transformations applied.
---@nodiscard
local function apply_icon_transform(icon_datum, scale, shift, tint, defaults_type)
	local copy = apply_icon_defaults(icon_datum, defaults_type)
	if not scale and not shift and not tint then
		return copy
	end

	local scaled_shift = copy.shift and util.mul_shift(copy.shift, scale or 1) or nil
	---@type SafeIconData
	local transformed = {
		icon = copy.icon,
		icon_size = copy.icon_size,
		scale = copy.scale * (scale or 1),
		shift = shift and util.add_shift(scaled_shift or { 0, 0 }, shift) or scaled_shift,
		tint = tint or copy.tint,
		draw_background = copy.draw_background,
		floating = copy.floating,
	}

	return transformed
end

---Applies a scale, shift, and tint to every layer of an icon.
---
---The working half of `transform_icons`, without the validation.
---@param icon_data IconData[] # A valid array of `IconData` objects.
---@param scale? double # The scale to apply.
---@param shift? Vector # The shift to apply.
---@param tint? Color # The tint to apply.
---@param defaults_type? IconDefaultsType # The type-specific defaults to apply.
---@return SafeIconData[] # A copy with the transformations applied to each layer.
---@nodiscard
local function apply_icons_transform(icon_data, scale, shift, tint, defaults_type)
	if not scale and not shift and not tint then
		return apply_icons_defaults(icon_data, defaults_type)
	end

	local transformed_icon_data = {}
	for index = 1, #icon_data do
		transformed_icon_data[index] = apply_icon_transform(icon_data[index], scale, shift, tint, defaults_type)
	end

	return transformed_icon_data
end

local check_get_expected_icon_size = V.signature("get_expected_icon_size", {
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Gets the `icon_size` an icon assigned to a prototype of the given type is expected to have, when `icon_size` is not
---explicitly provided.
---
---This is the assumed size of an icon that does not define the `icon_size` field. As a result, this
---also governs both `scale` and `shift`, where shift is described relative to `expected_icon_size /
---2`.
---
---### Examples
---```lua
---local expected_icon_size = _icons.get_expected_icon_size("technology") -- 256
---
----- The span a shift is measured against.
---local shift_span = expected_icon_size / 2 -- 128
---```
---
---### Parameters
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SpriteSizeType # The expected icon size, in pixels.
---@nodiscard
function _icons.get_expected_icon_size(defaults_type)
	check_get_expected_icon_size(defaults_type)

	return resolve_expected_icon_size(defaults_type)
end

local check_empty_icon = V.signature("empty_icon", {
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Gets an empty icon.
---
---### Examples
---```lua
---local icon_data = _icons.empty_icon()
---```
---
---### Parameters
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@return SafeIconData
---@nodiscard
function _icons.empty_icon(defaults_type)
	check_empty_icon(defaults_type)

	local expected_icon_size = resolve_expected_icon_size(defaults_type)

	return {
		icon = "__core__/graphics/empty.png",
		icon_size = 1,
		scale = expected_icon_size / 2,
	}
end

local check_scale_icon = V.signature("scale_icon", {
	{ "icon_data", Common.icon_data },
	{ "scalar", Common.positive_number },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SafeIconData[] # A copy of `icon_data` rescaled by the given `scalar`.
---@nodiscard
function _icons.scale_icon(icon_data, scalar, defaults_type)
	check_scale_icon(icon_data, scalar, defaults_type)

	local icon_data_copy = apply_icons_defaults(icon_data, defaults_type)

	for _, icon_datum in pairs(icon_data_copy) do
		icon_datum.scale = icon_datum.scale * scalar
		icon_datum.shift = icon_datum.shift and util.mul_shift(icon_datum.shift, scalar) or nil
	end

	return icon_data_copy
end

---
---Clears the icon fields from the given `prototype` object.
---
---Warning! This leaves the prototype in an invalid state!
---Be sure to set a new icon after calling this function.
---
---### Remarks
---- The dark-background icon fields are cleared alongside the main ones. Leaving
---  them would show the prototype's original artwork on dark backgrounds while
---  the replacement icon shows everywhere else.
---- `SpaceLocationPrototype::starmap_icon` is left alone. A starmap icon is
---  unrelated artwork at its own size, not a variant of the icon being replaced.
---
---### Examples
---```lua
---_icons.clear_icon_from_prototype(data.raw.item["iron-plate"])
---```
---
---### Parameters
---@param prototype PrototypeWithIcons # The prototype object.
function _icons.clear_icon_from_prototype(prototype)
	if prototype ~= nil then
		prototype.icons = nil
		prototype.icon = nil
		prototype.icon_size = nil

		prototype.dark_background_icons = nil
		prototype.dark_background_icon = nil
		prototype.dark_background_icon_size = nil
	end
end

local check_clear_icon_from_named_prototype = V.signature("clear_icon_from_named_prototype", {
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototypes.is_registered_type },
})

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
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is not a non-empty string.\
---*@throws* `string` — Thrown when `type_name` is not a registered prototype type name.
function _icons.clear_icon_from_named_prototype(name, type_name)
	check_clear_icon_from_named_prototype(name, type_name)

	_icons.clear_icon_from_prototype(data.raw[type_name][name])
end

local check_add_missing_icon_defaults = V.signature("add_missing_icon_defaults", {
	{ "icon_datum", Common.icon_datum },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Adds default values to missing fields from the given `icon_datum`.\
---`icon_data` is not modified.
---
---Note: `IconData.draw_background` and `IconData.floating` are carried through
---as given, never defaulted. These represent an advanced use case and should be
---handled directly.
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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SafeIconData # A copy of `icon_datum` with missing fields set to default values.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is not a valid `IconData` object.
---@nodiscard
function _icons.add_missing_icon_defaults(icon_datum, defaults_type)
	check_add_missing_icon_defaults(icon_datum, defaults_type)

	return apply_icon_defaults(icon_datum, defaults_type)
end

local check_add_missing_icons_defaults = V.signature("add_missing_icons_defaults", {
	{ "icon_data", Common.icon_data },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Adds default values to missing fields from each element of the given `icon_data` array.\
---`icon_data` is not modified.
---
---Note: `IconData.draw_background` and `IconData.floating` are carried through
---as given, never defaulted. These represent an advanced use case and should be
---handled directly.
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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SafeIconData[] # A copy of `icon_data` with missing fields on each element set to default values.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is not a non-empty array of valid `IconData` objects.
---@nodiscard
function _icons.add_missing_icons_defaults(icon_data, defaults_type)
	check_add_missing_icons_defaults(icon_data, defaults_type)

	return apply_icons_defaults(icon_data, defaults_type)
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

--- The parameters `create_icon` and `create_technology_icon` share. Checked at
--- each of them rather than left to `add_missing_icon_defaults`, so a failure
--- blames the call that was actually written.
local create_icon_params = {
	{ "icon", Common.mod_file_path },
	{ "icon_size", Common.sprite_size:optional() },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
}

local check_create_icon = V.signature("create_icon", create_icon_params)

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
---@return SafeIconData # An `IconData` object representing the created icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon` is not a mod-prefixed absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_size` is not a positive integer.
---@nodiscard
function _icons.create_icon(icon, icon_size, scale, shift, tint)
	check_create_icon(icon, icon_size, scale, shift, tint)

	return apply_icon_defaults(pack_as_icon_datum(icon, icon_size, scale, shift, tint))
end

local check_create_technology_icon = V.signature("create_technology_icon", create_icon_params)

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
---@param scale? double # The scale of the icon. Default `128 / icon_size`.
---@param shift? Vector # The shift of the icon. Default `nil`.
---@param tint? Color # The tint of the icon. Default `nil`.
---
---### Returns
---@return SafeIconData # An `IconData` object representing the created technology icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon` is not a mod-prefixed absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_size` is not a positive integer.
---@nodiscard
function _icons.create_technology_icon(icon, icon_size, scale, shift, tint)
	check_create_technology_icon(icon, icon_size, scale, shift, tint)

	return apply_icon_defaults(pack_as_icon_datum(icon, icon_size, scale, shift, tint), "technology")
end

local check_get_icon_from_prototype = V.signature("get_icon_from_prototype", {
	{ "prototype", Common.prototypes.prototype_with_icons },
})

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
---@return SafeIconData[] # A copy of the icon retrieved from the prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when `prototype` is `nil`.\
---*@throws* `string` — Thrown when `prototype` has no defined field `icon` or `icons`.
---@nodiscard
function _icons.get_icon_from_prototype(prototype)
	check_get_icon_from_prototype(prototype)

	-- Recipes must have an icon or icons field if being passed to this function.
	---
	-- NOTE: the motivation for this was that it avoids trying to figure out what the recipe product is and fetching the
	-- item from that (e.g. the recipe has no icon and inherits it). With the removal of normal/expensive, this is less
	-- cumbersome and it may be reasonable to add logic to retrieve the inherited icon.

	---@type IconData[]
	local icons

	-- Give precedence to an existing icons field.
	local default_icon_size = default_icon_sizes[prototype.type] or defines.default_icon_size--[[@as SpriteSizeType]]
	if prototype.icons and prototype.icons[1] then
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

local check_get_icon_from_named_prototype = V.signature("get_icon_from_named_prototype", {
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototypes.is_registered_type },
}, names_an_existing_prototype)

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
---@return SafeIconData[] # A copy of the icon retrieved from the prototype.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is not a non-empty string.\
---*@throws* `string` — Thrown when `type_name` is not a non-empty string.\
---*@throws* `string` — Thrown when `type_name` is not a known prototype type.\
---*@throws* `string` — Thrown when the prototype does not exist.\
---*@throws* `string` — Thrown when the prototype has no defined field `icon` or `icons`.
---@nodiscard
function _icons.get_icon_from_named_prototype(name, type_name)
	check_get_icon_from_named_prototype(name, type_name)

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
---@return SafeIconData[]|nil # A copy of the dark-background icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined dark-background icon.
---
---### Exceptions
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `dark_background` icon.
---@nodiscard
function _icons.get_dark_background_icon_from_prototype(item_prototype)
	if not item_prototype then
		return
	end

	local dark_background_icons = item_prototype.dark_background_icons

	---@type IconData[]
	local icons

	-- Give precedence to an existing icons field. An empty array is not one:
	-- it is truthy, and taking it would mask a defined dark_background_icon.
	if dark_background_icons and dark_background_icons[1] then
		icons = util.copy(dark_background_icons)

		-- Ensure icon_size is set for all elements before adding defaults. The
		-- dark-background art matches the main icon's dimensions, so icon_size
		-- stands in when nothing more specific is set.
		-- stylua: ignore
		for n = 1, #icons do
			icons[n].icon_size = icons[n].icon_size
				or item_prototype.dark_background_icon_size
				or item_prototype.icon_size
				or defines.default_icon_size--[[@as SpriteSizeType]]
		end
	elseif item_prototype.dark_background_icon then
		---@type IconData[]
		icons = {
			{
				icon = item_prototype.dark_background_icon,
				icon_size = item_prototype.dark_background_icon_size or item_prototype.icon_size or defines.default_icon_size --[[@as SpriteSizeType]],
			},
		}
	else
		return
	end

	return _icons.add_missing_icons_defaults(icons, item_prototype.type)
end

local check_get_dark_background_icon_from_named_prototype =
	V.signature("get_dark_background_icon_from_named_prototype", {
		{ "name", Common.prototype_name },
		{ "type_name", Common.prototypes.is_registered_type },
	})

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
---@return SafeIconData[]|nil # A copy of the dark-background icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined dark-background icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `type_name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `dark_background` icon.
---@nodiscard
function _icons.get_dark_background_icon_from_named_prototype(name, type_name)
	check_get_dark_background_icon_from_named_prototype(name, type_name)

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
---@return SafeIconData[]|nil # A copy of the starmap icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined starmap.
---
---### Exceptions
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `starmap` icon.
---@nodiscard
function _icons.get_starmap_icon_from_prototype(space_location_prototype)
	if not space_location_prototype then
		return
	end

	local starmap_icons = space_location_prototype.starmap_icons

	---@type IconData[]
	local icons

	-- Give precedence to an existing icons field. An empty array is not one:
	-- it is truthy, and taking it would mask a defined starmap_icon.
	if starmap_icons and starmap_icons[1] then
		---@type IconData[]
		icons = util.copy(starmap_icons)

		-- Ensure icon_size is set for all elements before adding defaults.
		for n = 1, #icons do
			icons[n].icon_size = icons[n].icon_size or space_location_prototype.starmap_icon_size or STARMAP_ICON_SIZE
		end
	elseif space_location_prototype.starmap_icon then
		---@type IconData[]
		icons = {
			{
				icon = space_location_prototype.starmap_icon,
				icon_size = space_location_prototype.starmap_icon_size or STARMAP_ICON_SIZE,
			},
		}
	else
		return
	end

	return _icons.add_missing_icons_defaults(icons, "starmap")
end

local check_get_starmap_icon_from_named_prototype = V.signature("get_starmap_icon_from_named_prototype", {
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototypes.is_registered_type },
})

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
---@return SafeIconData[]|nil # A copy of the starmap icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined starmap.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `type_name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when an `icon` field is invalid on the resolved `starmap` icon.
---@nodiscard
function _icons.get_starmap_icon_from_named_prototype(name, type_name)
	check_get_starmap_icon_from_named_prototype(name, type_name)

	return _icons.get_starmap_icon_from_prototype(data.raw[type_name][name])
end

local related_prototypes = {
	["item"] = true,
	["item-with-entity-data"] = true,
	["explosion"] = true,
	["corpse"] = true,
}

---The default `IconAssignmentOptions`, applied when a caller passes no `options` at all.
local default_icon_assignment_options = {
	infer_item = true,
	infer_recipe = true,
	infer_explosion = true,
	infer_corpse = true,
	explosion_by_convention = true,
	corpse_by_convention = true,
}

---Fills in the defaults for an `IconAssignmentOptions` table, applying `strict` if set.
---
---`strict` is applied here rather than left to the callers of the resolved table, so there is exactly
---one place that decides what `strict` means.
---@param options IconAssignmentOptions? # The options to resolve.
---@return IconAssignmentOptions # A copy with every field set to `true` or `false`.
---@nodiscard
local function resolve_icon_assignment_options(options)
	if not options then
		return default_icon_assignment_options
	end

	if options.strict then
		return {
			infer_item = false,
			infer_recipe = false,
			infer_explosion = false,
			infer_corpse = false,
			explosion_by_convention = false,
			corpse_by_convention = false,
		}
	end

	return {
		infer_item = options.infer_item ~= false,
		infer_recipe = options.infer_recipe ~= false,
		infer_explosion = options.infer_explosion ~= false,
		infer_corpse = options.infer_corpse ~= false,
		explosion_by_convention = options.explosion_by_convention ~= false,
		corpse_by_convention = options.corpse_by_convention ~= false,
	}
end

---Gets the entity name carried by an `EntityID` or an `ExplosionDefinition`.
---
---### Parameters
---@param definition string|{ name: string? }|nil # The definition to read a name from.
---
---### Returns
---@return string? # The entity name, or `nil` if the definition does not carry one.
---@nodiscard
local function get_explosion_name(definition)
	if type(definition) == "string" then
		return definition
	elseif type(definition) == "table" and type(definition.name) == "string" then
		return definition.name
	end

	return nil
end

local check_assign_icons_to_prototype_and_related_prototypes =
	V.signature("assign_icons_to_prototype_and_related_prototypes", {
		{ "name", Common.prototype_name },
		{ "type_name", Common.prototypes.is_registered_type:optional() },
		{ "icon_data", Common.icon_data },
		{ "pictures", V.table():optional() },
		{ "options", Common.icon_assignment_options:optional() },
	})

---
---Sets the given `icon_data` on the prototype with the given `name` and `type_name`, and the
---related prototypes that follow standard naming conventions, such as the item, explosion and
---remnant prototypes.
---
---Sets the `pictures` field on the related item prototypes to the given
---`pictures`, clearing it when none is given. An item's `pictures` is drawn in
---place of its icon when the item is in the world, so leaving a previous one in
---place would keep showing the artwork this call is replacing.
---
---### Remarks
---- This method assumes that recipes with the same `name` as the target prototype, having a single result that is
---  the target prototype, should use the same icon. If this behavior is undesirable, pass `infer_recipe = false` in
---  `options`, or handle assignment of icons to related entities directly.
---- `options` never affects the named prototype itself: it is always assigned the icon. It only controls whether
---  the item, recipe, explosion, and corpse cascades run, and whether the explosion/corpse cascades accept a match
---  found only by naming convention.
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
---
-----A variant entity that shares its corpse and explosion with another prototype should not have this
-----call push its own icon onto that shared corpse/explosion.
---_icons.assign_icons_to_prototype_and_related_prototypes("assembling-machine-1-penalty", "assembling-machine", labeled_icon, nil, {
---    infer_explosion = false,
---    infer_corpse = false,
---})
---```
---
---### Parameters
---@param name string # The name of the prototype.
---@param type_name? string # The type name of the prototype.
---@param icon_data IconData[] # An icon represented by an array of `IconData` objects.
---@param pictures? SpriteVariations # A `SpriteVariations` object to use as the in-world sprite, or `nil` to clear any existing one so the icon is used instead. Typical use is when `icon_data` has e.g., tier labels, and the in-world sprite should not. Ignored when `infer_item` is `false`.
---@param options? IconAssignmentOptions # Controls which related prototypes the icon cascades to. Defaults apply as per `IconAssignmentOptions`.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is `nil` or an empty string.\
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `icon_data[n].icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_data[n].icon_size` is not a positive integer.
function _icons.assign_icons_to_prototype_and_related_prototypes(name, type_name, icon_data, pictures, options)
	check_assign_icons_to_prototype_and_related_prototypes(name, type_name, icon_data, pictures, options)

	local resolved_options = resolve_icon_assignment_options(options)

	local icon_data_copy = apply_icons_defaults(icon_data, type_name)

	local prototype = (type_name and not related_prototypes[type_name]) and data.raw[type_name][name] or nil

	-- Exclude technologies and recipes from related-prototype updates.
	if type_name ~= "technology" and type_name ~= "recipe" then
		if resolved_options.infer_item then
			local item = data.raw["item"][name]
			if item ~= nil then
				_icons.clear_icon_from_prototype(item)
				item.icons = icon_data_copy
				item.pictures = pictures
			end

			local item_with_entity_data = data.raw["item-with-entity-data"][name]
			if item_with_entity_data ~= nil then
				_icons.clear_icon_from_prototype(item_with_entity_data)
				item_with_entity_data.icons = icon_data_copy

				-- The pictures field is ignored as of 1.0, this has been left active
				-- in the hopes the default behavior is adjusted.
				item_with_entity_data.pictures = pictures
			end
		end

		-- Clear out recipes of the same name so that the item icon is inherited properly.
		-- Possibly a dangerous assumption that all recipes with the same name as the item
		-- are intended to inherit the icon directly and do not use a custom icon.
		if resolved_options.infer_recipe then
			local recipe = data.raw["recipe"][name]
			if recipe and recipe.results and #recipe.results == 1 and recipe.results[1].name == name then
				_icons.clear_icon_from_prototype(recipe)

				-- icon is required if the recipe does not have a main product.
				if not recipe.main_product then
					recipe.icons = icon_data_copy
				end
			end
		end
	end

	if prototype then
		_icons.clear_icon_from_prototype(prototype)
		prototype.icons = icon_data_copy

		-- Technologies and recipes have no dying_explosion or corpse of their own; the naming-convention
		-- lookups below are for entity-like prototypes only.
		if type_name ~= "technology" and type_name ~= "recipe" then
			if resolved_options.infer_explosion then
				-- Try to grab the explosion name from the prototype directly, to ensure it is picked up in the
				-- event it does not follow the expected pattern.
				--
				-- `dying_explosion` is an `EntityID`, an `ExplosionDefinition`, or an
				-- array of either. A bare `EntityID` is the common case in vanilla.
				local dying_explosion = prototype.dying_explosion
				local dying_explosion_name = get_explosion_name(dying_explosion)
					or (type(dying_explosion) == "table" and get_explosion_name(dying_explosion[1]))
					or nil

				local explosion_names = {}

				if resolved_options.explosion_by_convention then
					explosion_names[name .. "-explosion"] = true
					explosion_names["ar-" .. name .. "-explosion"] = true
				end

				if dying_explosion_name then
					explosion_names[dying_explosion_name] = true
				end

				for explosion_name, _ in pairs(explosion_names) do
					local explosion = data.raw["explosion"][explosion_name]
					if explosion ~= nil then
						_icons.clear_icon_from_prototype(explosion)
						explosion.icons = icon_data_copy
					end
				end
			end

			if resolved_options.infer_corpse then
				-- Try to grab the corpse name from the prototype directly, to ensure it is picked up in the
				-- event it does not follow the expected pattern.
				local corpse_name
				if type(prototype.corpse) == "string" then
					corpse_name = prototype.corpse
				elseif type(prototype.corpse) == "table" and type(prototype.corpse[1]) == "string" then
					corpse_name = prototype.corpse[1]
				end

				local remnants_names = {}

				if resolved_options.corpse_by_convention then
					remnants_names[name .. "-remnants"] = true
					remnants_names["ar-" .. name .. "-remnants"] = true
				end

				if corpse_name then
					remnants_names[corpse_name] = true
				end

				for remnants_name, _ in pairs(remnants_names) do
					local remnants = data.raw["corpse"][remnants_name]
					if remnants ~= nil then
						_icons.clear_icon_from_prototype(remnants)
						remnants.icons = icon_data_copy
					end
				end
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
	-- `icon_data` first, following the engine: where a prototype sets both
	-- `icon` and `icons`, `icons` is the one it takes. An empty array defines
	-- nothing, so it is not the array being present.
	if deferrable_icon.icon_data and deferrable_icon.icon_data[1] then
		_icons.assign_icons_to_prototype_and_related_prototypes(
			deferrable_icon.name,
			deferrable_icon.type_name,
			deferrable_icon.icon_data,
			deferrable_icon.pictures,
			deferrable_icon.options
		)
	elseif deferrable_icon.icon_datum then
		_icons.assign_icons_to_prototype_and_related_prototypes(
			deferrable_icon.name,
			deferrable_icon.type_name,
			{ deferrable_icon.icon_datum },
			nil,
			deferrable_icon.options
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

local check_compose_icons = V.signature("compose_icons", {
	{ "defaults_type", Common.icon_defaults_type },
})

---One argument to `compose_icons`: a single icon, or an array of them.
---
---Checked rather than sniffed. Deciding by looking for an `icon` field and then
---for an `icon` field on the first element leaves anything else — an empty
---table, a typo'd field, an array of something other than icons — dropped from
---the composition with nothing said about it.
local composable_icon = V.any_of(Common.icon_datum, Common.icon_data)
	:describe_as("an IconData object or an array of IconData objects")

---
---Composes the given set of icons defined by `IconData` objects or arrays of `IconData` objects
---into a single icon, with the first icon at the base of the stack and the last icon at the top.
---
---### Remarks
---- Missing icon fields are set to default values as appropriate.
---- Inputs are not modified.
---
---### Parameters
---@param defaults_type IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@param ... IconData|IconData[]|nil # A variable set of `IconData` or `IconData` arrays to combine.
---
---### Returns
---@return SafeIconData[] # A single icon built from combining the input icons.
---
---### See Also
---@see Icons.add_missing_icon_defaults
---@nodiscard
function _icons.compose_icons(defaults_type, ...)
	check_compose_icons(defaults_type)

	---@type IconData[]
	local combined_icon_data = {}

	-- The position is the key rather than a counter: a nil argument is absent
	-- from the packed table entirely, so counting would misname everything
	-- after one. Offset by the leading `defaults_type`.
	for position, input_icon in pairs({ ... }) do
		composable_icon:assert(input_icon, string.format("argument %d", position + 1), "compose_icons")

		if input_icon.icon then
			-- It's an IconData object.
			table.insert(combined_icon_data, apply_icon_defaults(input_icon, defaults_type))
		else
			-- It's an array of IconData objects.
			for _, icon_datum in pairs(input_icon) do
				table.insert(combined_icon_data, apply_icon_defaults(icon_datum, defaults_type))
			end
		end
	end

	return combined_icon_data
end

---Layers the icon of `prototype` on top of `icon_data`.
---
---The working half shared by the four `add_icons_from_prototype_to_*`
---functions, without the validation. The sourced icon arrives from
---`get_icon_from_prototype` already checked and defaulted.
---@param icon_data IconData[] # A valid array of `IconData` objects to layer onto.
---@param prototype PrototypeWithIcons # The prototype to source the icon from.
---@param scale? double # The scale to apply to the sourced icon.
---@param shift? Vector # The shift to apply to the sourced icon.
---@param tint? Color # The tint to apply to the sourced icon.
---@return SafeIconData[] # A copy of `icon_data` with the sourced icon layered on top.
---@nodiscard
local function apply_icons_from_prototype(icon_data, prototype, scale, shift, tint)
	local icon_data_copy = apply_icons_defaults(icon_data, prototype.type)

	-- The prototype is the boundary where foreign data enters, so its layers
	-- are validated on the way out of `get_icon_from_prototype`.
	local sourced_icon_data = _icons.get_icon_from_prototype(prototype)

	for index = 1, #sourced_icon_data do
		table.insert(icon_data_copy, apply_icon_transform(sourced_icon_data[index], scale, shift, tint, prototype.type))
	end

	return icon_data_copy
end

local check_add_icons_from_prototype_to_icons = V.signature("add_icons_from_prototype_to_icons", {
	{ "icon_data", Common.icon_data },
	{ "prototype", Common.prototypes.prototype_with_icons },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
})

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
---@return SafeIconData[] # A copy of `icon_data` composed with the transformed icon data from `prototype`.
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
	check_add_icons_from_prototype_to_icons(icon_data, prototype, scale, shift, tint)

	return apply_icons_from_prototype(icon_data, prototype, scale, shift, tint)
end

local check_add_icons_from_prototype_to_icon = V.signature("add_icons_from_prototype_to_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "prototype", Common.prototypes.prototype_with_icons },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
})

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
---@return SafeIconData[] # An array of `IconData` with a copy of `icon_datum` as the base layer, and the added icon data from `prototype`.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is `nil`.\
---*@throws* `string` — Thrown when `icon_datum.icon` is `nil`.
---
---### See Also
---@see Icons.add_icons_from_prototype_to_icons
---@nodiscard
function _icons.add_icons_from_prototype_to_icon(icon_datum, prototype, scale, shift, tint)
	check_add_icons_from_prototype_to_icon(icon_datum, prototype, scale, shift, tint)

	return apply_icons_from_prototype({ icon_datum }, prototype, scale, shift, tint)
end

local check_add_icons_from_prototype_to_icons_by_name = V.signature("add_icons_from_prototype_to_icons_by_name", {
	{ "icon_data", Common.icon_data },
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototypes.is_registered_type },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
}, names_an_existing_prototype)

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
---@return SafeIconData[] # An icon with a copy of `icon_datum` as the base layer, composed with the transformed icon from the prototype.
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
	check_add_icons_from_prototype_to_icons_by_name(icon_data, name, type_name, scale, shift, tint)

	return apply_icons_from_prototype(icon_data, data.raw[type_name][name], scale, shift, tint)
end

local check_add_icons_from_prototype_to_icon_by_name = V.signature("add_icons_from_prototype_to_icon_by_name", {
	{ "icon_datum", Common.icon_datum },
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototypes.is_registered_type },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
}, names_an_existing_prototype)

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
---@return SafeIconData[] # An icon with a copy of `icon_datum` as the base layer, composed with the transformed icon from the prototype.
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
	check_add_icons_from_prototype_to_icon_by_name(icon_datum, name, type_name, scale, shift, tint)

	return apply_icons_from_prototype({ icon_datum }, data.raw[type_name][name], scale, shift, tint)
end

local check_transform_icon = V.signature("transform_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SafeIconData # A copy of `icon_datum` with the transformations applied.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is `nil`.\
---*@throws* `string` — Thrown when `icon_datum.icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_datum.icon_size` is not a positive integer.
---@nodiscard
function _icons.transform_icon(icon_datum, scale, shift, tint, defaults_type)
	check_transform_icon(icon_datum, scale, shift, tint, defaults_type)

	return apply_icon_transform(icon_datum, scale, shift, tint, defaults_type)
end

local check_transform_icons = V.signature("transform_icons", {
	{ "icon_data", Common.icon_data },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SafeIconData[] # A copy of `icon_data` with the transformations applied.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `icon_data[n].icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_data[n].icon_size` is not a positive integer.
---@nodiscard
function _icons.transform_icons(icon_data, scale, shift, tint, defaults_type)
	check_transform_icons(icon_data, scale, shift, tint, defaults_type)

	return apply_icons_transform(icon_data, scale, shift, tint, defaults_type)
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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return SafeIconData[] icon_data # A copy of the icon data from `source`, if it exists; otherwise, a blank icon.
---@return boolean is_blank_icon When `true`, a blank icon was created.
---@nodiscard
local function get_icons_from_source(source, defaults_type)
	---@type IconData[]
	local icon_data

	if source and source.icon_data then
		---@cast source IconDataSource
		icon_data = apply_icons_defaults(source.icon_data, source.defaults_type or defaults_type)
	elseif source and source.icon_datum then
		---@cast source IconDatumSource
		icon_data = { apply_icon_defaults(source.icon_datum, source.defaults_type or defaults_type) }
	elseif source and source.name then
		local prototype = data.raw[source.type_name] and data.raw[source.type_name][source.name] or nil
		if prototype ~= nil then
			icon_data = _icons.get_icon_from_prototype(prototype--[[@as Prototype]])
		end
	end

	local is_blank_icon = false
	if not icon_data then
		is_blank_icon = true
		icon_data = { _icons.empty_icon(defaults_type) }
	end

	return icon_data, is_blank_icon
end

local check_add_icons_from_sources_to_icons = V.signature("add_icons_from_sources_to_icons", {
	{ "icon_data", Common.icon_data },
	{ "sources", V.array(Common.icon_source) },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Layers the icons named by `sources` on top of `icon_data`.
---
---The working half of `add_icons_from_sources_to_icons`, without the
---validation.
---@param icon_data IconData[] # A valid array of `IconData` objects to layer onto.
---@param sources IconSources # Valid sources to layer on top.
---@param defaults_type? IconDefaultsType # The type-specific defaults to apply.
---@return SafeIconData[] # A copy of `icon_data` with the sourced icons on top.
---@return boolean # Whether a blank layer stood in for a source that did not resolve.
---@nodiscard
local function apply_icons_from_sources(icon_data, sources, defaults_type)
	---@type IconData[]
	local combined_icon = apply_icons_defaults(icon_data, defaults_type)

	local has_blank_layers = false
	for _, source in pairs(sources) do
		-- Icon may be blank if the prototype did not exist.
		local icon, is_blank_icon = get_icons_from_source(source, defaults_type)
		has_blank_layers = has_blank_layers or is_blank_icon

		local transform = source.transform or source
		local transformed_icon = apply_icons_transform(
			icon,
			transform.scale,
			transform.shift,
			transform.tint,
			source.type_name or source.defaults_type or defaults_type
		)

		for index = 1, #transformed_icon do
			local icon_datum = transformed_icon[index]

			-- Flags rather than transformations. A layer already setting one
			-- keeps it, so neither can be switched off from out here.
			icon_datum.floating = icon_datum.floating or transform.floating

			-- The first layer alone: the outline belongs to the sourced icon as
			-- a whole rather than to each layer it is built from.
			if index == 1 then
				icon_datum.draw_background = icon_datum.draw_background or transform.draw_background
			end

			table.insert(combined_icon, icon_datum)
		end
	end

	return combined_icon, has_blank_layers
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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`. Individual source types take precedence over this value.
---
---### Returns
---@return SafeIconData[] combined_icon A copy of `icon_data` with the sourced icons from `sources` transformed and layered on top, if any exist.
---@return boolean has_blank_layers  When the second return value is `true`, a blank icon layer was created.
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
	check_add_icons_from_sources_to_icons(icon_data, sources, defaults_type)

	return apply_icons_from_sources(icon_data, sources, defaults_type)
end

local check_create_icons_from_sources = V.signature("create_icons_from_sources", {
	{ "sources", V.array(Common.icon_source):not_empty() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

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
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`. Individual source types take precedence over this value.
---
---### Returns
---@return SafeIconData[] icon A new icon created from the sources, with the base icon from the first source, and icons from the remaining sources layered on top.
---@return boolean has_blank_layers When `true`, a blank icon layer was created.
---
---### Exceptions
---*@throws* `string` — Thrown when `sources` is `nil`.\
---*@throws* `string` — Thrown when `sources` is empty.
---@nodiscard
function _icons.create_icons_from_sources(sources, defaults_type)
	check_create_icons_from_sources(sources, defaults_type)

	---@type IconSources
	local sources_copy = util.copy(sources)

	local has_blank_layers = false

	-- Get the base icon from the first source,
	local base_source = table.remove(sources_copy, 1)
	local base_icon_data, is_blank_icon = get_icons_from_source(base_source, defaults_type)

	has_blank_layers = (has_blank_layers or is_blank_icon)

	-- Apply only a tint transformation on the base layer. Scale and shift are not applicable.
	--
	-- Read from the copy rather than the original: assigning the caller's tint
	-- would leave it shared with the icon this returns.
	local base_transform = base_source.transform or base_source

	for _, icon_datum in pairs(base_icon_data) do
		icon_datum.tint = base_transform.tint or icon_datum.tint
	end

	local icon_data, added_blank_layers = apply_icons_from_sources(base_icon_data, sources_copy, defaults_type)
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
---@param recipe_icon_source_map { [string]: IconSources }|table<string, IconSources> # A map of recipe names to the icon sources used to create a combined icon. The first entry in each IconSources is the first layer of the created icon.
function _icons.create_and_assign_composed_icons_from_sources_to_recipe(recipe_icon_source_map)
	for recipe_name, sources in pairs(recipe_icon_source_map) do
		local icon_data = _icons.create_icons_from_sources(sources)
		_icons.assign_icons_to_prototype_and_related_prototypes(recipe_name, "recipe", icon_data)
	end
end

return _icons
