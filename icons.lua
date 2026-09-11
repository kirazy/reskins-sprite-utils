---@using data

---@namespace Reskins.SpriteUtils

---Provides methods for manipulating icons.
---
---#### Examples
---```lua
---local _icons = require("__reskins-sprite-utils__.icons")
---```
---@class Icons
local _icons = {}

local V = require("validation")
local Common = require("validation.common")
local Colors = require("colors")

---The expected icon size for `SpaceLocationPrototype::starmap_icon`.
local STARMAP_ICON_SIZE = 512

---The expected icon sizes for each type, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale).
local default_icon_sizes = {
	["technology"] = 256,
	["achievement"] = 128,
	["item-group"] = 128,
	["shortcut"] = 32,
	["shortcut-small"] = 24,
	["starmap"] = STARMAP_ICON_SIZE,
}

---Gets the `icon_size` an icon assigned to a prototype of the given `defaults_type` is expected to have when
---`icon_size` is not set.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults.
---@return SpriteSizeType # The expected icon size, in pixels.
---@nodiscard
local function resolve_expected_icon_size(defaults_type)
	return default_icon_sizes[defaults_type or ""] or defines.default_icon_size
end

---Represents one layer of an icon, with `icon_size` and `scale` set. Icon layering follows the following rules:
---
---* The rendering order of the individual icon layers follows the array order: Later added icon layers (higher index) are drawn on top of previously added icon layers (lower index).
---
---* By default the first icon layer will draw an outline (or shadow in GUI), other layers will draw it only if they have `draw_background` explicitly set to `true`. There are caveats to this though. See [the doc](https://lua-api.factorio.com/latest/types/IconData.html#draw_background).
---
---* When the final icon is displayed with transparency (e.g. a faded out alert), the icon layer overlap may look [undesirable](https://forums.factorio.com/viewtopic.php?p=575844#p575844).
---
---* When the final icon is displayed with a shadow (e.g. an item on the ground or on a belt when item shadows are turned on), each icon layer will [cast a shadow](https://forums.factorio.com/84888) and the shadow is cast on the layer below it.
---
---* The final icon will always be resized and centered in GUI so that all its layers (except the [`floating`](https://lua-api.factorio.com/latest/types/IconData.html#floating) ones) fit the target slot, but won't be resized when displayed on machines in alt-mode. For example: recipe first icon layer is size 128, scale 1, the icon group will be displayed at resolution /4 to fit the 32px GUI boxes, but will be displayed 4 times as large on buildings.
---
---* Shift values are based on [`expected_icon_size / 2`](https://lua-api.factorio.com/latest/types/IconData.html#scale).
---
---The game automatically generates [icon mipmaps](https://factorio.com/blog/post/fff-291) for all icons. However, icons can have custom mipmaps defined. Custom mipmaps may help to achieve clearer icons at reduced size (e.g. when zooming out) than auto-generated mipmaps. If an icon file contains mipmaps then the game will automatically infer the icon's mipmap count. Icon files for custom mipmaps must contain half-size images with a geometric-ratio, for each mipmap level. Each next level is aligned to the upper-left corner, with no extra padding. Example sequence: `128x128@(0,0)`, `64x64@(128,0)`, `32x32@(192,0)` is three mipmaps.
---
---[View Documentation](https://lua-api.factorio.com/latest/types/IconData.html)
---@class SafeIconData : IconData
---The size of the square icon, in pixels, such as 32 for a 32px by 32px icon. The size must be larger than 0.
---
---[View Documentation](https://lua-api.factorio.com/latest/types/IconData.html#icon_size)
---@field icon_size SpriteSizeType
---Defaults to `(expected_icon_size / 2) / icon_size`.
---
---Specifies the scale of the icon on the GUI scale. A scale of `2` means that the icon will be two times bigger on screen (and thus more pixelated).
---
---Expected icon sizes:
---
---* `512` for [SpaceLocationPrototype::starmap\_icon](https://lua-api.factorio.com/latest/prototypes/SpaceLocationPrototype.html#starmap_icon).
---
---* `256` for [TechnologyPrototype](https://lua-api.factorio.com/latest/prototypes/TechnologyPrototype.html).
---
---* `128` for [AchievementPrototype](https://lua-api.factorio.com/latest/prototypes/AchievementPrototype.html) and [ItemGroup](https://lua-api.factorio.com/latest/prototypes/ItemGroup.html).
---
---* `32` for [ShortcutPrototype::icons](https://lua-api.factorio.com/latest/prototypes/ShortcutPrototype.html#icons) and `24` for [ShortcutPrototype::small\_icons](https://lua-api.factorio.com/latest/prototypes/ShortcutPrototype.html#small_icons).
---
---* `64` for the rest of the prototypes that use icons.
---
---[View Documentation](https://lua-api.factorio.com/latest/types/IconData.html#scale)
---@field scale double

---Sets the missing fields of the given `icon_datum` to default values.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon_datum IconData A valid `IconData` object.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults.
---@return SafeIconData # A copy of `icon_datum` with missing fields set to default values.
---@nodiscard
local function apply_icon_defaults(icon_datum, defaults_type)
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

---Sets the missing fields of every layer of the given `icon_data` to default values.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon_data IconData[] A valid array of `IconData` objects.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults.
---@return SafeIconData[] # A copy of `icon_data` with missing fields on each layer set to default values.
---@nodiscard
local function apply_icons_defaults(icon_data, defaults_type)
	local new_icon_data = {}
	for index = 1, #icon_data do
		new_icon_data[index] = apply_icon_defaults(icon_data[index], defaults_type)
	end

	return new_icon_data
end

---Indicates whether the given `icon_datum` has an additive tint.
---
---A tint with an alpha of zero is blended additively by the game.
---@param icon_datum IconData A valid `IconData` object.
---@return boolean # `true` if the tint has an alpha of zero; otherwise, `false`.
---@nodiscard
local function has_additive_tint(icon_datum)
	local tint = icon_datum.tint
	return tint ~= nil and (tint.a == 0 or tint[4] == 0)
end

---Defines a `Transform` and the other fields that are applied to one icon layer at once.
---@class (exact) IconLayerAdjustment : Transform
---The tint to set. The layer keeps its own tint when that tint is additive.
---@field tint? Color
---When `true`, indicates that the layer is floated. A layer that is already floating is not modified.
---@field floating? boolean
---When `true`, indicates that the background of the layer is drawn. A layer with an explicit `false` is not modified.
---@field draw_background? boolean

---Indicates whether every field of the given `adjustment` is `nil`.
---@param adjustment IconLayerAdjustment A valid adjustment.
---@return boolean # `true` if every field of the adjustment is `nil`; otherwise, `false`.
---@nodiscard
local function is_empty_adjustment(adjustment)
	return not adjustment.scale
		and not adjustment.shift
		and not adjustment.tint
		and not adjustment.floating
		and not adjustment.draw_background
end

---Applies the given `adjustment` to the given `icon_datum`, with missing fields set to default values.
---No validation is performed; callers are expected to have pre-validated the input.
---
---`floating` and `draw_background` are set only if the layer does not already set them. Tint adjustments replace any
---defined tint on the layer, except where the tint is classified as an additive blend.
---@param icon_datum IconData A valid `IconData` object.
---@param adjustment IconLayerAdjustment A valid adjustment to apply.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults.
---@return SafeIconData # A copy of `icon_datum` with the adjustment applied.
---@nodiscard
local function apply_icon_adjustment(icon_datum, adjustment, defaults_type)
	local copy = apply_icon_defaults(icon_datum, defaults_type)
	if is_empty_adjustment(adjustment) then
		return copy
	end

	local scale, shift = adjustment.scale, adjustment.shift

	local scaled_shift = copy.shift and util.mul_shift(copy.shift, scale or 1) or nil
	---@type SafeIconData
	local adjusted = {
		icon = copy.icon,
		icon_size = copy.icon_size,
		scale = copy.scale * (scale or 1),
		shift = shift and util.add_shift(scaled_shift or { 0, 0 }, shift) or scaled_shift,
		tint = has_additive_tint(copy) and copy.tint or adjustment.tint or copy.tint,
		-- The adjustment sets a flag when its value is `true`. An explicit `false` on the layer is preserved.
		draw_background = adjustment.draw_background or copy.draw_background,
		floating = adjustment.floating or copy.floating,
	}

	return adjusted
end

---Applies the given `adjustment` to every layer of the given `icon_data`, with missing fields set to default values.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon_data IconData[] A valid array of `IconData` objects.
---@param adjustment IconLayerAdjustment A valid adjustment to apply to every layer.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults.
---@return SafeIconData[] # A copy of `icon_data` with the adjustment applied to each layer.
---@nodiscard
local function apply_icons_transform(icon_data, adjustment, defaults_type)
	if is_empty_adjustment(adjustment) then
		return apply_icons_defaults(icon_data, defaults_type)
	end

	local adjusted_icon_data = {}
	for index = 1, #icon_data do
		adjusted_icon_data[index] = apply_icon_adjustment(icon_data[index], adjustment, defaults_type)
	end

	return adjusted_icon_data
end

---Indicates whether the given `icon_datum` is an empty (transparent) layer.
---
---An empty layer is a characterized by an `icon_size` of 1 and a file name ending in `empty.png`.
---@param icon_datum IconData A valid `IconData` object.
---@return boolean # `true` if the layer is an empty layer; otherwise, `false`.
---@nodiscard
local function is_empty_layer(icon_datum)
	return icon_datum.icon:match("empty%.png$") ~= nil and icon_datum.icon_size == 1
end

---Sets `draw_background` on the first layer of the given `icon_data` that is not an empty layer, in place.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon_data IconData[] A valid array of `IconData` objects, owned by the caller.
---@return IconData[] # `icon_data`, with `draw_background` set on its first layer that is not an empty layer.
local function outline_first_non_empty_layer_in_place(icon_data)
	for _, icon_datum in pairs(icon_data) do
		if not is_empty_layer(icon_datum) then
			icon_datum.draw_background = true
			break
		end
	end

	return icon_data
end

local check_get_expected_icon_size = V.signature("get_expected_icon_size", {
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Gets the `icon_size` an icon assigned to a prototype of the given `defaults_type` is expected to have when
---`icon_size` is not set.
---
---The default `scale` of a layer and the unit of its `shift` are derived from the expected icon size.
---
---#### Parameters
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SpriteSizeType # The expected icon size, in pixels.
---
---#### Examples
---```lua
----- Get the unit in which the shift of a technology icon layer is measured.
---local expected_icon_size = _icons.get_expected_icon_size("technology") -- 256
---
---local shift_unit = expected_icon_size / 2 -- 128
---```
---@nodiscard
function _icons.get_expected_icon_size(defaults_type)
	check_get_expected_icon_size(defaults_type)

	return resolve_expected_icon_size(defaults_type)
end

local check_empty_icon = V.signature("empty_icon", {
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Gets an empty icon, scaled for the given `defaults_type`.
---
---#### Parameters
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData # An empty icon.
---
---#### Examples
---```lua
----- Get an empty icon scaled for a technology.
---local icon_datum = _icons.empty_icon("technology")
----- { icon = "__core__/graphics/empty.png", icon_size = 1, scale = 128 }
---```
---@throws When `defaults_type` is an empty string.
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

---Scales the given `icon_data` by the given `scalar`.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects to scale.
---@param scalar double The factor by which the icon is scaled.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` scaled by the given `scalar`.
---
---#### Examples
---```lua
----- Double the size of a two-layer icon.
----- Note: this does not necessarily have an impact in the GUI, but will increase the apparent size in-world.
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
---icon_data = _icons.scale_icon(icon_data, 2)
----- The second layer has scale 0.5 and shift { -32, 32 }.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `scalar` is not a number greater than 0.
---@throws When `defaults_type` is an empty string.
---@see Icons.transform_icons
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

local check_minify_icon = V.signature("minify_icon", {
	{ "icon_data", Common.icon_data },
	{ "scalar", Common.positive_number:less_than(1) },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Minifies the artwork of the given `icon_data` by the given `scalar` relative to the expected icon size.
---A transparent layer is placed beneath the minified artwork, and the icon is outlined as by `outline_icon`.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects to minify.
---@param scalar double The scalar by which the icon is minified. Must be greater than 0 and less than 1.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` minified by the given `scalar`, over a transparent layer of the expected icon size.
---
---#### Examples
---```lua
----- Resize the icon to 80% of its normal size in the GUI.
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/assembling-machine-1.png",
---        icon_size = 64,
---    },
---}
---
---icon_data = _icons.minify_icon(icon_data, 0.8)
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `scalar` is not a number greater than 0 and less than 1.
---@throws When `defaults_type` is an empty string.
---@see Icons.scale_icon
---@nodiscard
function _icons.minify_icon(icon_data, scalar, defaults_type)
	check_minify_icon(icon_data, scalar, defaults_type)

	local minified = _icons.compose_icons(defaults_type, {
		icon = "__reskins-sprite-utils__/graphics/icons/minified-empty.png",
		icon_size = 1,
		scale = resolve_expected_icon_size(defaults_type) / 2,
	}, _icons.scale_icon(icon_data, scalar, defaults_type))

	return outline_first_non_empty_layer_in_place(minified)
end

---Clears the icon fields from the given `prototype`.
---
---The prototype is left in an invalid state until a new icon is set on it.
---
---- The dark-background icon fields are cleared with the main ones.
---- `SpaceLocationPrototype::starmap_icon` is not modified.
---- A `nil` prototype is ignored.
---@param prototype? PrototypeWithIcons The prototype from which the icon is cleared.
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

---Clears the icon fields from the prototype with the given `name` and `type_name`.
---
---This method leaves the prototype in an invalid state: an icon is required and must be provided by the caller.
---
---- The icon fields are cleared as by `clear_icon_from_prototype`.
---- A prototype that does not exist is a no-op.
---@param name string The name of the prototype.
---@param type_name string The type name of the prototype.
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@see Icons.clear_icon_from_prototype
function _icons.clear_icon_from_named_prototype(name, type_name)
	check_clear_icon_from_named_prototype(name, type_name)

	_icons.clear_icon_from_prototype(data.raw[type_name][name])
end

local check_add_missing_icon_defaults = V.signature("add_missing_icon_defaults", {
	{ "icon_datum", Common.icon_datum },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Adds default values to missing fields from the given `icon_datum`.
---
---- The default `icon_size` is the expected icon size of `defaults_type`, and the default `scale` is
---  `(expected_icon_size / 2) / icon_size`.
---- `IconData.draw_background` and `IconData.floating` are copied as given and are not defaulted.
---- `icon_datum` is not modified.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData # A copy of `icon_datum` with missing fields set to default values.
---
---#### Examples
---```lua
----- Set the default scale of a 64px icon layer.
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---}
---
---icon_datum = _icons.add_missing_icon_defaults(icon_datum)
----- icon_datum.scale is 0.5.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `defaults_type` is an empty string.
---@see Icons.add_missing_icons_defaults
---@nodiscard
function _icons.add_missing_icon_defaults(icon_datum, defaults_type)
	check_add_missing_icon_defaults(icon_datum, defaults_type)

	return apply_icon_defaults(icon_datum, defaults_type)
end

local check_add_missing_icons_defaults = V.signature("add_missing_icons_defaults", {
	{ "icon_data", Common.icon_data },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Adds default values to missing fields from each element of the given `icon_data` array.
---
---- Each layer is defaulted as by `add_missing_icon_defaults`.
---- `icon_data` is not modified.
---
---#### Parameters
---@param icon_data IconData[] An icon represented by an array of `IconData` objects.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` with missing fields on each layer set to default values.
---
---#### Examples
---```lua
----- Set the default scale of the layers of a technology icon.
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/technology/logistics-1.png",
---        icon_size = 256,
---    },
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        shift = { -64, 64 }
---    },
---}
---
---icon_data = _icons.add_missing_icons_defaults(icon_data, "technology")
----- The first layer has scale 0.5, and the second layer has scale 2.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `defaults_type` is an empty string.
---@see Icons.add_missing_icon_defaults
---@nodiscard
function _icons.add_missing_icons_defaults(icon_data, defaults_type)
	check_add_missing_icons_defaults(icon_data, defaults_type)

	return apply_icons_defaults(icon_data, defaults_type)
end

---Creates an `IconData` object from the given fields.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon FileName
---@param icon_size SpriteSizeType
---@param scale? double
---@param shift? Vector
---@param tint? Color
---@return IconData
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

---The parameters shared by `create_icon` and `create_technology_icon`.
local create_icon_params = {
	{ "icon", Common.mod_file_path },
	{ "icon_size", Common.sprite_size:optional() },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
}

local check_create_icon = V.signature("create_icon", create_icon_params)

---Creates an entity, item or recipe `IconData` object with the specified parameters.
---
---#### Parameters
---@param icon FileName The file name of the icon to use.
---@param icon_size SpriteSizeType The size of the icon, in pixels.
---@param scale? double The scale of the icon. Default `32 / icon_size`.
---@param shift? Vector The shift of the icon. Default `nil`.
---@param tint? Color The tint of the icon. Default `nil`.
---
---#### Returns
---@return SafeIconData # An `IconData` object representing the created icon.
---
---#### Examples
---```lua
----- Create a quarter-size icon in the lower-left corner of the icon.
---local icon_datum = _icons.create_icon("__base__/graphics/icons/copper-wire.png", 64, 0.25, { -16, 16 })
----- { icon = "__base__/graphics/icons/copper-wire.png", icon_size = 64, scale = 0.25, shift = { -16, 16 } }
---```
---@throws When `icon` is not a mod-prefixed absolute file path with a valid extension.
---@throws When `icon_size` is not an integer between 1 and 8192.
---@throws When `scale` is not a number greater than 0.
---@throws When `shift` is not a `Vector`.
---@throws When `tint` is not a `Color`.
---@see Icons.create_technology_icon
---@nodiscard
function _icons.create_icon(icon, icon_size, scale, shift, tint)
	check_create_icon(icon, icon_size, scale, shift, tint)

	return apply_icon_defaults(pack_as_icon_datum(icon, icon_size, scale, shift, tint))
end

local check_create_technology_icon = V.signature("create_technology_icon", create_icon_params)

---Creates a technology `IconData` object with the specified parameters.
---
---#### Parameters
---@param icon FileName The file name of the icon to use.
---@param icon_size SpriteSizeType The size of the icon, in pixels.
---@param scale? double The scale of the icon. Default `128 / icon_size`.
---@param shift? Vector The shift of the icon. Default `nil`.
---@param tint? Color The tint of the icon. Default `nil`.
---
---#### Returns
---@return SafeIconData # An `IconData` object representing the created technology icon.
---
---#### Examples
---```lua
----- Create a technology icon from a 256px image.
---local icon_datum = _icons.create_technology_icon("__base__/graphics/technology/logistics-1.png", 256)
----- { icon = "__base__/graphics/technology/logistics-1.png", icon_size = 256, scale = 0.5 }
---```
---@throws When `icon` is not a mod-prefixed absolute file path with a valid extension.
---@throws When `icon_size` is not an integer between 1 and 8192.
---@throws When `scale` is not a number greater than 0.
---@throws When `shift` is not a `Vector`.
---@throws When `tint` is not a `Color`.
---@see Icons.create_icon
---@nodiscard
function _icons.create_technology_icon(icon, icon_size, scale, shift, tint)
	check_create_technology_icon(icon, icon_size, scale, shift, tint)

	return apply_icon_defaults(pack_as_icon_datum(icon, icon_size, scale, shift, tint), "technology")
end

local check_get_icon_from_prototype = V.signature("get_icon_from_prototype", {
	{ "prototype", Common.prototype_with_icons },
})

---Gets the icon as an array of `IconData` objects directly from the given `prototype`.
---A `RecipePrototype` must have a defined `icon` or `icons` field; an inherited icon is not resolved.
---@param prototype PrototypeWithIcons The prototype from which the icon is retrieved.
---@return SafeIconData[] # A copy of the icon retrieved from the prototype.
---@throws When `prototype` is `nil`.
---@throws When `prototype` has no defined field `icon` or `icons`.
---@see Icons.get_icon_from_named_prototype
---@nodiscard
function _icons.get_icon_from_prototype(prototype)
	check_get_icon_from_prototype(prototype)

	-- A recipe must define `icon` or `icons`.
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

		-- Ensure icon_size is set prior to assigning defaults. An icon defined in icons may be constructed such that
		-- some or all layers do not set `icon_size`, in which case an `icon_size` at the prototype root is used instead.
		-- Where that `icon_size` is not the expected icon size for the type, the assigned defaults would be wrong.

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
}, { Common.prototypes.names_an_existing_prototype() })

---Gets the icon as an array of `IconData` objects from the prototype with the given `name` and `type_name`.
---A `RecipePrototype` must have a defined `icon` or `icons` field; an inherited icon is not resolved.
---@param name string The name of the prototype.
---@param type_name string The type name of the prototype.
---@return SafeIconData[] # A copy of the icon retrieved from the prototype.
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@throws When no prototype with the given `name` and `type_name` exists.
---@throws When the prototype has no defined field `icon` or `icons`.
---@see Icons.get_icon_from_prototype
---@nodiscard
function _icons.get_icon_from_named_prototype(name, type_name)
	check_get_icon_from_named_prototype(name, type_name)

	return _icons.get_icon_from_prototype(data.raw[type_name][name])
end

---Gets the dark-background icon as an array of `IconData` objects directly from the given `item_prototype`.
---@param item_prototype? ItemPrototype The item prototype from which the icon is retrieved.
---@return SafeIconData[]? # A copy of the dark-background icon retrieved from the prototype, or `nil` if the prototype is `nil` or does not have a defined dark-background icon.
---@throws When a layer of the dark-background icon is not a valid `IconData` object.
---@see Icons.get_dark_background_icon_from_named_prototype
---@nodiscard
function _icons.get_dark_background_icon_from_prototype(item_prototype)
	if not item_prototype then
		return
	end

	local dark_background_icons = item_prototype.dark_background_icons

	---@type IconData[]
	local icons

	if dark_background_icons and dark_background_icons[1] then
		icons = util.copy(dark_background_icons)

		-- Ensure icon_size is set prior to assigning defaults. An icon defined in icons may be constructed such that
		-- some or all layers do not set `icon_size`, in which case an `icon_size` at the prototype root is used instead.
		-- Where that `icon_size` is not the expected icon size for the type, the assigned defaults would be wrong.

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

---Gets the dark-background icon as an array of `IconData` objects from the item prototype with the given `name` and
---`type_name`.
---@param name string The name of the item prototype.
---@param type_name string The type name of the item prototype.
---@return SafeIconData[]? # A copy of the dark-background icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined dark-background icon.
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@throws When a layer of the dark-background icon is not a valid `IconData` object.
---@see Icons.get_dark_background_icon_from_prototype
---@nodiscard
function _icons.get_dark_background_icon_from_named_prototype(name, type_name)
	check_get_dark_background_icon_from_named_prototype(name, type_name)

	return _icons.get_dark_background_icon_from_prototype(data.raw[type_name][name])
end

---Gets the starmap icon as an array of `IconData` objects directly from the given `space_location_prototype`.
---@param space_location_prototype? SpaceLocationPrototype The space location prototype from which the icon is retrieved.
---@return SafeIconData[]? # A copy of the starmap icon retrieved from the prototype, or `nil` if the prototype is `nil` or does not have a defined starmap icon.
---@throws When a layer of the starmap icon is not a valid `IconData` object.
---@see Icons.get_starmap_icon_from_named_prototype
---@nodiscard
function _icons.get_starmap_icon_from_prototype(space_location_prototype)
	if not space_location_prototype then
		return
	end

	local starmap_icons = space_location_prototype.starmap_icons

	---@type IconData[]
	local icons

	if starmap_icons and starmap_icons[1] then
		icons = util.copy(starmap_icons)

		-- Ensure icon_size is set prior to assigning defaults. An icon defined in icons may be constructed such that
		-- some or all layers do not set `icon_size`, in which case an `icon_size` at the prototype root is used instead.
		-- Where that `icon_size` is not the expected icon size for the type, the assigned defaults would be wrong.

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

---Gets the starmap icon as an array of `IconData` objects from the space location prototype with the given `name` and
---`type_name`.
---@param name string The name of the space location prototype.
---@param type_name string The type name of the space location prototype.
---
---#### Returns
---@return SafeIconData[]? # A copy of the starmap icon retrieved from the prototype, or `nil` if the prototype does not exist or does not have a defined starmap icon.
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@throws When a layer of the starmap icon is not a valid `IconData` object.
---@see Icons.get_starmap_icon_from_prototype
---@nodiscard
function _icons.get_starmap_icon_from_named_prototype(name, type_name)
	check_get_starmap_icon_from_named_prototype(name, type_name)

	return _icons.get_starmap_icon_from_prototype(data.raw[type_name][name])
end

---The type names of the prototypes that are assigned an icon as related prototypes.
local related_prototypes = {
	["item"] = true,
	["item-with-entity-data"] = true,
	["explosion"] = true,
	["corpse"] = true,
}

---The `IconAssignmentOptions` used when a caller passes no `options`.
local default_icon_assignment_options = {
	infer_item = true,
	infer_recipe = true,
	infer_explosion = true,
	infer_corpse = true,
	explosion_by_convention = true,
	corpse_by_convention = true,
}

---Sets every missing field of the given `options` to `true`, or every field to `false` when `strict` is `true`.
---@param options? IconAssignmentOptions The options to resolve.
---@return IconAssignmentOptions # The resolved options, with every field set to `true` or `false`.
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

---Gets the entity name of an `EntityID` or an `ExplosionDefinition`.
---@param definition? ExplosionDefinition|ExplosionDefinition[] The definition from which the name is retrieved.
---@return EntityID? # The entity name, or `nil` if the definition has none.
---@nodiscard
local function get_explosion_name(definition)
	if type(definition) == "string" then
		return definition
	elseif type(definition) == "table" and type(definition.name) == "string" then
		return definition.name
	end

	return nil
end

---Gets the prototype with the given `name` and `type_name`, if `type_name` is given and is not a related prototype
---type; otherwise, returns `nil`.
---@param name EntityID The name of the prototype.
---@param type_name? string The type name of the prototype.
---@return PrototypeWithIcons?
---@nodiscard
local function resolve_target_prototype(name, type_name)
	if type_name and not related_prototypes[type_name] then
		return data.raw[type_name][name]
	end

	return nil
end

---Gets the `item` and `item-with-entity-data` prototypes with the given `name`, if found.
---@param name ItemID The name of the prototype.
---@return PrototypeWithIcons[] # The item prototypes that exist, in that order.
---@nodiscard
local function resolve_related_items(name)
	local items = {}
	for _, item_type in pairs({ "item", "item-with-entity-data" }) do
		local item = data.raw[item_type][name]
		if item ~= nil then
			items[#items + 1] = item
		end
	end

	return items
end

---Gets the recipe with the given `name`, if it exists and its only result is the prototype with that name.
---@param name RecipeID The name of the prototype.
---@return RecipePrototype? # The recipe, or `nil` if there is none.
---@nodiscard
local function resolve_related_recipe(name)
	local recipe = data.raw["recipe"][name]
	if recipe and recipe.results and #recipe.results == 1 and recipe.results[1].name == name then
		return recipe
	end

	return nil
end

---Gets the explosion prototypes related to the given entity prototype. The related explosions are the explosion named
---by its `dying_explosion` and, when `by_convention` is `true`, the explosions named `[ar-]<name>-explosion`.
---@param prototype PrototypeWithIcons The entity prototype.
---@param name string The name of the prototype.
---@param by_convention? boolean When `true`, indicates that explosions named by convention are included.
---@return PrototypeWithIcons[] # The explosion prototypes that exist.
---@nodiscard
local function resolve_related_explosions(prototype, name, by_convention)
	---@cast prototype EntityWithHealthPrototype
	local dying_explosion = prototype.dying_explosion
	local dying_explosion_name = get_explosion_name(dying_explosion)
		or (type(dying_explosion) == "table" and get_explosion_name(dying_explosion[1]))
		or nil

	local names = {}
	if by_convention then
		names[name .. "-explosion"] = true
		names["ar-" .. name .. "-explosion"] = true
	end

	if dying_explosion_name then
		names[dying_explosion_name] = true
	end

	local explosions = {}
	for explosion_name in pairs(names) do
		local explosion = data.raw["explosion"][explosion_name]
		if explosion ~= nil then
			explosions[#explosions + 1] = explosion
		end
	end

	return explosions
end

---Gets the corpse prototypes related to the given entity prototype. The related corpses are the corpse named by its
---`corpse` field and, when `by_convention` is `true`, the corpses named `[ar-]<name>-remnants`.
---@param prototype PrototypeWithIcons The entity prototype.
---@param name string The name of the prototype.
---@param by_convention? boolean When `true`, indicates that corpses named by convention are included.
---@return CorpsePrototype[] # The corpse prototypes that exist.
---@nodiscard
local function resolve_related_corpses(prototype, name, by_convention)
	---@cast prototype EntityWithHealthPrototype
	local corpse_name
	if type(prototype.corpse) == "string" then
		corpse_name = prototype.corpse
	elseif type(prototype.corpse) == "table" and type(prototype.corpse[1]) == "string" then
		corpse_name = prototype.corpse[1]
	end

	local names = {}
	if by_convention then
		names[name .. "-remnants"] = true
		names["ar-" .. name .. "-remnants"] = true
	end

	if corpse_name then
		names[corpse_name] = true
	end

	local corpses = {}
	for remnants_name in pairs(names) do
		local remnants = data.raw["corpse"][remnants_name]
		if remnants ~= nil then
			corpses[#corpses + 1] = remnants
		end
	end

	return corpses
end

---Replaces the icon of the given `prototype` with the given `icon_data`.
---@param prototype PrototypeWithIcons The prototype on which the icon is set.
---@param icon_data SafeIconData[] The icon, with missing fields set to default values.
local function set_icon_on_prototype(prototype, icon_data)
	_icons.clear_icon_from_prototype(prototype)
	prototype.icons = icon_data
end

local check_assign_icons_to_prototype_and_related_prototypes =
	V.signature("assign_icons_to_prototype_and_related_prototypes", {
		{ "name", Common.prototype_name },
		{ "type_name", Common.prototypes.is_registered_type:optional() },
		{ "icon_data", Common.icon_data },
		{ "pictures", V.table():optional() },
		{ "options", Common.icon_assignment_options:optional() },
	})

---Sets the given `icon_data` on the prototype with the given `name` and `type_name`, and its related prototypes. The
---`pictures` field on the related item prototypes are set to the given `pictures`; when `nil`, the field is cleared.
---
---`options` controls which related prototypes are assigned the icon.
---No related prototype is assigned the icon when `type_name` is `"technology"` or `"recipe"`.
---
---Related prototypes are resolved in the following way:
---- The `item` and `item-with-entity-data` of the same name.
---- The explosion named by `dying_explosion`, and as named by convention: `[ar-]<name>-explosion`.
---- The corpse named by `corpse`, and as named by convention: `[ar-]<name>-remnants`.
---- A `recipe` of the same name, for which the named prototype is the only product. The icon is assigned when
---  `main_product` is not defined; otherwise, it is cleared and the `recipe` inherits the icon of its `main_product`.
---
---#### Parameters
---@param name string The name of the prototype.
---@param type_name? string The type name of the prototype.
---@param icon_data IconData[] An icon represented by an array of `IconData` objects.
---@param pictures? SpriteVariations A `SpriteVariations` object to use as the in-world sprite, or `nil` to clear any existing one so the icon is used instead. Typical use is when `icon_data` has a layer, such as a badge, that the in-world sprite should not. Ignored when `infer_item` is `false`.
---@param options? IconAssignmentOptions Controls which related prototypes the icon is assigned to. Defaults apply as per `IconAssignmentOptions`.
---
---#### Examples
---```lua
----- Assign a badged icon to a machine, with unbadged pictures for the item.
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/assembling-machine-1.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
----- Get a sprite for display in-world from the icon without the badge.
---local pictures = _sprites.create_sprite_from_icon(icon_datum, 1.0)
---
----- Add a badge to the icon that should not be displayed in-world.
---local badged_icon = {
---    icon_datum,
---    { icon = "__my-mod__/graphics/icons/badge.png", icon_size = 64, scale = 0.25, shift = { 8, 8 } },
---}
---
---_icons.assign_icons_to_prototype_and_related_prototypes(
---    "assembling-machine-1",
---    "assembling-machine",
---    badged_icon,
---    pictures
---)
----- The machine, its item, its explosion, and its corpse have the badged icon, and the item has the pictures.
----- The recipe inherits the icon of the machine.
---
----- Assign the icon to a variant entity. The corpse and explosion it shares with another prototype are not
----- assigned the icon.
---_icons.assign_icons_to_prototype_and_related_prototypes(
---    "assembling-machine-1-penalty",
---    "assembling-machine",
---    badged_icon,
---    nil,
---    { infer_explosion = false, infer_corpse = false }
---)
---```
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `pictures` is not a table.
---@throws When `options` is not an `IconAssignmentOptions`.
function _icons.assign_icons_to_prototype_and_related_prototypes(name, type_name, icon_data, pictures, options)
	check_assign_icons_to_prototype_and_related_prototypes(name, type_name, icon_data, pictures, options)

	local resolved_options = resolve_icon_assignment_options(options)

	local icon_data_copy = apply_icons_defaults(icon_data, type_name)

	local prototype = resolve_target_prototype(name, type_name)

	-- Exclude technologies and recipes from related-prototype updates.
	local assigns_to_related = type_name ~= "technology" and type_name ~= "recipe"

	if assigns_to_related and resolved_options.infer_item then
		for _, item in pairs(resolve_related_items(name)) do
			set_icon_on_prototype(item, icon_data_copy)

			-- Note: item-with-entity-data ignores the field.
			item.pictures = pictures
		end
	end

	if assigns_to_related and resolved_options.infer_recipe then
		local recipe = resolve_related_recipe(name)
		if recipe then
			-- Clear the icon; the icon of the product is inherited.
			_icons.clear_icon_from_prototype(recipe)

			-- An icon is required when the recipe does not have a main product.
			if not recipe.main_product then
				recipe.icons = icon_data_copy
			end
		end
	end

	if prototype then
		set_icon_on_prototype(prototype, icon_data_copy)

		if assigns_to_related and resolved_options.infer_explosion then
			for _, explosion in pairs(resolve_related_explosions(prototype, name, resolved_options.explosion_by_convention)) do
				set_icon_on_prototype(explosion, icon_data_copy)
			end
		end

		if assigns_to_related and resolved_options.infer_corpse then
			for _, corpse in pairs(resolve_related_corpses(prototype, name, resolved_options.corpse_by_convention)) do
				set_icon_on_prototype(corpse, icon_data_copy)
			end
		end
	end
end

---Assigns the icon from the given `icon_assignment` to the associated prototype and its related prototypes.
---The `pictures` field on the related item prototypes are set when `pictures` content is available from the assignment;
---otherwise, the field is cleared.
---
---`icon_assignment.options` controls which related prototypes are assigned the icon.
---No related prototype is assigned the icon when `type_name` is `"technology"` or `"recipe"`.
---
---Related prototypes are resolved in the following way:
---- The `item` and `item-with-entity-data` of the same name.
---- The explosion named by `dying_explosion`, and as named by convention: `[ar-]<name>-explosion`.
---- The corpse named by `corpse`, and as named by convention: `[ar-]<name>-remnants`.
---- A `recipe` of the same name, for which the named prototype is the only product. The icon is assigned when
---  `main_product` is not defined; otherwise, it is cleared and the `recipe` inherits the icon of its `main_product`.
---
---#### Examples
---```lua
----- Assign an icon to an item and its related prototypes.
------@type IconDataAssignment
---local icon_assignment = {
---    name = "iron-plate",
---    type_name = "item",
---    icon_data = { {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    } },
---}
---
---_icons.apply_icon_assignment(icon_assignment)
----- data.raw.item["iron-plate"].icons holds a copy of the icon.
---```
---@param icon_assignment IconAssignment
---@throws When `icon_assignment.name` is `nil` or an empty string.
---@throws When `icon_assignment.type_name` is not a registered prototype type name.
---@throws When `icon_assignment.icon_data` is not an array of valid `IconData` objects, or `icon_assignment.icon_datum` is not a valid `IconData` object, or `icon_assignment.composition` is not a valid `IconComposition`.
---@throws When `icon_assignment.options` is not an `IconAssignmentOptions`.
---@see Icons.assign_icons_to_prototype_and_related_prototypes
function _icons.apply_icon_assignment(icon_assignment)
	local icon_data = {}
	local pictures = nil
	if icon_assignment.icon_data and icon_assignment.icon_data[1] then
		icon_data = icon_assignment.icon_data
		pictures = icon_assignment.pictures
	elseif icon_assignment.icon_datum then
		icon_data = { icon_assignment.icon_datum }
	elseif icon_assignment.composition then
		Common.icon_composition:assert(icon_assignment.composition, "icon_assignment.composition", "apply_icon_assignment")
		icon_data, pictures = icon_assignment.composition:build()
	end

	_icons.assign_icons_to_prototype_and_related_prototypes(
		icon_assignment.name,
		icon_assignment.type_name,
		icon_data,
		pictures,
		icon_assignment.options
	)
end

---Defines a dictionary of deferrable icons, indexed by the stage in which they are assigned.
---@deprecated Deferred assignment is being removed; assign icons in the target stage.
---@alias DeferredIconStore { [Stage]: (DeferrableIconData|DeferrableIconDatum)[] }

---Performs validation and sanitization of the given `deferrable_icon`, and adds it to the given `deferred_icon_store`
---dictionary of `DeferrableIconData` for later assignment in the given `stage`.
---
---Pass the same `deferred_icon_store` to `assign_icons_deferred_to_stage` with the same `stage`, during that stage, to
---assign the stored icons to the associated prototypes.
---
---#### Parameters
---@param deferred_icon_store DeferredIconStore The dictionary of deferrable icons, indexed by stage, to which the deferrable icon is added.
---@param stage Stage The key of the data stage under which the deferrable icon is stored.
---@param deferrable_icon DeferrableIconData|DeferrableIconDatum The icon data to store for deferred assignment.
---
---#### Examples
---```lua
----- Store an icon created in the data stage for assignment in the data-updates stage.
---
----- Create the empty table to hold the stored icons. No pre-configuration is required.
----- The lifetime of this variable must continue between stages.
---globals.deferred_icon_store = {}
---
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
---_icons.store_icon_for_deferred_assignment_in_stage(
---    globals.deferred_icon_store,
---    _defines.stage.data_updates,
---    deferrable_icon
---)
----- globals.deferred_icon_store[_defines.stage.data_updates][1] is the deferrable icon.
---```
---@throws When `deferred_icon_store` is `nil`.
---@throws When `stage` is `nil`.
---@throws When `deferrable_icon` is `nil`.
---@throws When `deferrable_icon.name` is `nil` or an empty string.
---@throws When `deferrable_icon.type_name` is `nil` or an empty string.
---@throws When `deferrable_icon.icon_data` is not a non-empty array of valid `IconData` objects.
---@see Icons.assign_icons_deferred_to_stage
---@deprecated Use `assign_deferrable_icon` in the target stage.
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

---Assigns the deferrable icons in `deferred_icon_store[stage]` to the associated prototypes.
---
---#### Parameters
---@param deferred_icon_store DeferredIconStore The dictionary of deferrable icons, indexed by stage, from which the deferrable icons are assigned.
---@param stage Stage The index of the data stage from which the deferrable icons are taken.
---
---#### Examples
---```lua
----- Assign the icons stored for the data-updates stage.
---_icons.assign_icons_deferred_to_stage(globals.deferred_icon_store, _defines.stage.data_updates)
---```
---@throws When the `name` of a stored icon is `nil` or an empty string.
---@throws When the `type_name` of a stored icon is not a registered prototype type name.
---@throws When the `icon_data` of a stored icon is not a non-empty array of valid `IconData` objects.
---@see Icons.store_icon_for_deferred_assignment_in_stage
---@see Icons.assign_deferrable_icon
---@deprecated Use `assign_deferrable_icon` in the target stage.
function _icons.assign_icons_deferred_to_stage(deferred_icon_store, stage)
	if not deferred_icon_store[stage] then
		return
	end

	for _, deferrable_icon in pairs(deferred_icon_store[stage]) do
		_icons.apply_icon_assignment(deferrable_icon)
	end
end

local check_compose_icons = V.signature("compose_icons", {
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Composes the given set of icons defined by `IconData` objects or arrays of `IconData` objects into a single icon,
---with the first icon at the base of the stack and the last icon at the top.
---
---#### Parameters
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@param ... IconData|IconData[]|nil A variable set of `IconData` or `IconData` arrays to combine. A `nil` argument is skipped.
---
---#### Returns
---@return SafeIconData[] # A single icon built from combining the input icons.
---
---#### Examples
---```lua
----- Stack a badge on an icon.
---local badge = { icon = "__my-mod__/graphics/icons/badge.png", icon_size = 64, scale = 0.25, shift = { 8, 8 } }
---
---local icon_data = _icons.compose_icons(nil, _icons.get_icon_from_named_prototype("iron-plate", "item"), badge)
----- The badge is the last layer.
---```
---@throws When `defaults_type` is an empty string.
---@throws When an argument is neither a valid `IconData` nor an array of valid `IconData` objects.
---@see Icons.add_missing_icon_defaults
---@nodiscard
function _icons.compose_icons(defaults_type, ...)
	check_compose_icons(defaults_type)

	---@type IconData[]
	local combined_icon_data = {}

	-- The arguments are keyed by position; a `nil` argument is absent from the packed table. The
	-- positions are offset by one for the leading `defaults_type`.
	for position, input_icon in pairs({ ... }) do
		Common.icon:assert(input_icon, string.format("argument %d", position + 1), "compose_icons")

		if input_icon.icon then
			-- The argument is an `IconData` object.
			table.insert(combined_icon_data, apply_icon_defaults(input_icon, defaults_type))
		else
			-- The argument is an array of `IconData` objects.
			for _, icon_datum in pairs(input_icon) do
				table.insert(combined_icon_data, apply_icon_defaults(icon_datum, defaults_type))
			end
		end
	end

	return combined_icon_data
end

---Adds the icon from the given `prototype` to a copy of the given `icon_data` array.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon_data IconData[] A valid array of `IconData` objects.
---@param prototype PrototypeWithIcons The prototype from which the icon is retrieved.
---@param scale? double The scale to apply to the sourced icon.
---@param shift? Vector The shift to apply to the sourced icon.
---@param tint? Color The tint to apply to the sourced icon.
---@return SafeIconData[] # A copy of `icon_data` with the sourced icon layered on top.
---@nodiscard
local function apply_icons_from_prototype(icon_data, prototype, scale, shift, tint)
	local icon_data_copy = apply_icons_defaults(icon_data, prototype.type)

	-- Layers from a prototype are validated by `get_icon_from_prototype`.
	local sourced_icon_data = _icons.get_icon_from_prototype(prototype)

	for index = 1, #sourced_icon_data do
		table.insert(
			icon_data_copy,
			apply_icon_adjustment(sourced_icon_data[index], { scale = scale, shift = shift, tint = tint }, prototype.type)
		)
	end

	return icon_data_copy
end

local check_add_icons_from_prototype_to_icons = V.signature("add_icons_from_prototype_to_icons", {
	{ "icon_data", Common.icon_data },
	{ "prototype", Common.prototype_with_icons },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
})

---Adds the icon from the given `prototype` to a copy of the given `icon_data` array, and applies any of the optional
---transformations given by `scale`, `shift` or `tint`.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects to receive the icon from `prototype`.
---@param prototype PrototypeWithIcons The prototype from which the icon is retrieved.
---@param scale? double The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color The tint to apply to the sourced icon. A layer with a tint alpha of zero keeps its tint. Default `nil`.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` composed with the transformed icon data from `prototype`.
---
---#### Examples
---```lua
----- Add the copper wire icon at half scale to the lower-left corner of the icon.
------@type IconData[]
---local icon_data = {
---    {
---        icon = "__base__/graphics/icons/iron-plate.png",
---        icon_size = 64,
---        scale = 0.5,
---    },
---}
---
---local prototype = data.raw["item"]["copper-wire"]
---local iron_plate_with_copper_wire = _icons.add_icons_from_prototype_to_icons(icon_data, prototype, 0.5, { -16, 16 })
----- The copper wire is the second layer, with scale 0.25 and shift { -16, 16 }.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `prototype` is not a prototype with a `type` field that defines `icon` or `icons`.
---@throws When `scale` is not a number greater than 0.
---@throws When `shift` is not a `Vector`.
---@throws When `tint` is not a `Color`.
---@see Icons.add_missing_icons_defaults
---@see Icons.get_icon_from_prototype
---@nodiscard
function _icons.add_icons_from_prototype_to_icons(icon_data, prototype, scale, shift, tint)
	check_add_icons_from_prototype_to_icons(icon_data, prototype, scale, shift, tint)

	return apply_icons_from_prototype(icon_data, prototype, scale, shift, tint)
end

local check_add_icons_from_prototype_to_icon = V.signature("add_icons_from_prototype_to_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "prototype", Common.prototype_with_icons },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
})

---Adds the icon from the given `prototype` to a new `IconData[]` array with the given `icon_datum` as the base layer,
---and applies any of the optional transformations given by `scale`, `shift` or `tint`.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object to be combined with the icon from `prototype`.
---@param prototype PrototypeWithIcons The prototype from which the icon is retrieved.
---@param scale? double The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color The tint to apply to the sourced icon. A layer with a tint alpha of zero keeps its tint. Default `nil`.
---
---#### Returns
---@return SafeIconData[] # An array of `IconData` with a copy of `icon_datum` as the base layer, composed with the transformed icon data from `prototype`.
---
---#### Examples
---```lua
----- Add the copper wire icon at half scale to the lower-left corner of the icon.
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
---local prototype = data.raw["item"]["copper-wire"]
---local iron_plate_with_copper_wire = _icons.add_icons_from_prototype_to_icon(icon_datum, prototype, 0.5, { -16, 16 })
----- The copper wire is the second layer, with scale 0.25 and shift { -16, 16 }.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `prototype` is not a prototype with a `type` field that defines `icon` or `icons`.
---@throws When `scale` is not a number greater than 0.
---@throws When `shift` is not a `Vector`.
---@throws When `tint` is not a `Color`.
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
}, { Common.prototypes.names_an_existing_prototype() })

---Adds the icon from the prototype with the given `name` and `type_name` to a copy of the given `icon_data` array, and
---applies any of the optional transformations given by `scale`, `shift` or `tint`.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects to receive the icon from the prototype.
---@param name string The name of the prototype from which the icon is retrieved.
---@param type_name string The type name of the prototype from which the icon is retrieved.
---@param scale? double The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color The tint to apply to the sourced icon. A layer with a tint alpha of zero keeps its tint. Default `nil`.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` composed with the transformed icon data from the prototype.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@throws When no prototype with the given `name` and `type_name` exists.
---@throws When `scale` is not a number greater than 0.
---@throws When `shift` is not a `Vector`.
---@throws When `tint` is not a `Color`.
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
}, { Common.prototypes.names_an_existing_prototype() })

---Adds the icon from the prototype with the given `name` and `type_name` to a new `IconData[]` array with the given
---`icon_datum` as the base layer, and applies any of the optional transformations given by `scale`, `shift` or `tint`.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object to be combined with the icon from the prototype.
---@param name string The name of the prototype from which the icon is retrieved.
---@param type_name string The type name of the prototype from which the icon is retrieved.
---@param scale? double The scale to apply to the sourced icon. Default `nil`.
---@param shift? Vector The shift to apply to the sourced icon. Default `nil`.
---@param tint? Color The tint to apply to the sourced icon. A layer with a tint alpha of zero keeps its tint. Default `nil`.
---
---#### Returns
---@return SafeIconData[] # An array of `IconData` with a copy of `icon_datum` as the base layer, composed with the transformed icon data from the prototype.
---
---#### Examples
---```lua
----- Add the copper wire icon at half scale to the lower-left corner of the icon.
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
---local iron_plate_with_copper_wire =
---    _icons.add_icons_from_prototype_to_icon_by_name(icon_datum, "copper-wire", "item", 0.5, { -16, 16 })
----- The copper wire is the second layer, with scale 0.25 and shift { -16, 16 }.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `name` is `nil` or an empty string.
---@throws When `type_name` is not a registered prototype type name.
---@throws When no prototype with the given `name` and `type_name` exists.
---@throws When `scale` is not a number greater than 0.
---@throws When `shift` is not a `Vector`.
---@throws When `tint` is not a `Color`.
---@see Icons.add_icons_from_prototype_to_icon
---@nodiscard
function _icons.add_icons_from_prototype_to_icon_by_name(icon_datum, name, type_name, scale, shift, tint)
	check_add_icons_from_prototype_to_icon_by_name(icon_datum, name, type_name, scale, shift, tint)

	return apply_icons_from_prototype({ icon_datum }, data.raw[type_name][name], scale, shift, tint)
end

---Sets the given `field` of the given `icon_datum` to the given `value`.
---@param icon_datum IconData A valid `IconData` object.
---@param field string The name of the field.
---@param value any The value of the field. A `nil` value clears the field.
---@return IconData # A copy of `icon_datum` with the field set.
---@nodiscard
local function layer_with_field(icon_datum, field, value)
	local layer = util.copy(icon_datum)
	layer[field] = value

	return layer
end

---Gets an array of the results of the given `fn` for each layer of the given `icon_data`, in order.
---@generic T
---@param icon_data IconData[] A valid array of `IconData` objects.
---@param fn fun(icon_datum: IconData, ...): T The function called with each layer and the extra arguments.
---@param ... any The extra arguments passed to `fn` after the layer.
---@return T[]
---@nodiscard
local function map_layers(icon_data, fn, ...)
	local mapped = {}
	for index = 1, #icon_data do
		mapped[index] = fn(icon_data[index], ...)
	end

	return mapped
end

local check_transform_icon = V.signature("transform_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "transform", Common.transform },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

local check_transform_icon_positional = V.signature("transform_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Scales and shifts the given `icon_datum` by the given `transform`.
---
---The positional call form, `transform_icon(icon_datum, scale, shift, tint, defaults_type)`, is deprecated. Pass a
---`Transform` for scale and shift, and use `set_icon_tint` for tint.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object.
---@param transform Transform The scale and shift to apply.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@param ... unknown The extra arguments of the deprecated positional form. The `Transform` form does not use them.
---
---#### Returns
---@return SafeIconData # A copy of `icon_datum` with the transform applied.
---
---#### Examples
---```lua
----- Halve the layer and move it into the upper-right quadrant.
---local placed = _icons.transform_icon(icon_datum, { scale = 0.5, shift = { 8, -8 } })
----- A layer with scale 0.5 and no shift gets scale 0.25 and shift { 8, -8 }.
---
----- Use a preset placement.
---local cornered = _icons.transform_icon(icon_datum, _defines.icon_transforms.corners.northeast)
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `transform` is not a `Transform`.
---@see Icons.transform_icons
---@overload fun(icon_datum: IconData, scale?: double, shift?: Vector, tint?: Color, defaults_type?: IconDefaultsType): SafeIconData
---@nodiscard
function _icons.transform_icon(icon_datum, transform, defaults_type, ...)
	if type(transform) ~= "table" then
		-- Read the arguments of the positional form: `scale`, `shift`, `tint`, and `defaults_type`.
		local scale, shift = transform, defaults_type
		local tint, positional_defaults_type = ...

		check_transform_icon_positional(icon_datum, scale, shift, tint, positional_defaults_type)

		return apply_icon_adjustment(icon_datum, {
			scale = scale --[[@as double?]],
			shift = shift --[[@as Vector?]],
			tint = tint --[[@as Color?]],
		}, positional_defaults_type--[[@as IconDefaultsType?]])
	end

	check_transform_icon(icon_datum, transform, defaults_type)

	return apply_icon_adjustment(icon_datum, {
		scale = transform.scale,
		shift = transform.shift,
	}, defaults_type)
end

local check_transform_icons = V.signature("transform_icons", {
	{ "icon_data", Common.icon_data },
	{ "transform", Common.transform },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

local check_transform_icons_positional = V.signature("transform_icons", {
	{ "icon_data", Common.icon_data },
	{ "scale", Common.positive_number:optional() },
	{ "shift", Common.vector:optional() },
	{ "tint", Common.color:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Scales and shifts every layer of the given `icon_data` by the given `transform`.
---
---The positional call form, `transform_icons(icon_data, scale, shift, tint, defaults_type)`, is deprecated. Pass a
---`Transform` for scale and shift, and use `set_icons_tint` for tint.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects.
---@param transform Transform The scale and shift to apply to every layer.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@param ... unknown The extra arguments of the deprecated positional form. The `Transform` form does not use them.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` with the transform applied to every layer.
---
---#### Examples
---```lua
----- Scale every layer to 1.5 times its size and move the icon 16 pixels to the right.
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
---local transformed_icon_data = _icons.transform_icons(icon_data, { scale = 1.5, shift = { 16, 0 } })
----- The second layer has scale 0.375 and shift { -8, 24 }.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `transform` is not a `Transform`.
---@see Icons.transform_icon
---@see Icons.scale_icon
---@overload fun(icon_data: IconData[], scale?: double, shift?: Vector, tint?: Color, defaults_type?: IconDefaultsType): SafeIconData[]
---@nodiscard
function _icons.transform_icons(icon_data, transform, defaults_type, ...)
	if type(transform) ~= "table" then
		-- Read the arguments of the positional form: `scale`, `shift`, `tint`, and `defaults_type`.
		local scale, shift = transform, defaults_type
		local tint, positional_defaults_type = ...

		check_transform_icons_positional(icon_data, scale, shift, tint, positional_defaults_type)

		return apply_icons_transform(icon_data, {
			scale = scale --[[@as double?]],
			shift = shift --[[@as Vector?]],
			tint = tint --[[@as Color?]],
		}, positional_defaults_type --[[@as IconDefaultsType?]])
	end

	check_transform_icons(icon_data, transform, defaults_type)

	return apply_icons_transform(icon_data, {
		scale = transform.scale,
		shift = transform.shift,
	}, defaults_type)
end

local check_convert_icon_defaults_type = V.signature("convert_icon_defaults_type", {
	{ "icon_datum", Common.icon_datum },
	{ "from_type", Common.icon_defaults_type:optional() },
	{ "to_type", Common.icon_defaults_type:optional() },
})

---Converts the scale and shift of the given `icon_datum` from the expected icon size of one icon defaults type to that
---of another.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object.
---@param from_type? IconDefaultsType The name of the type-specific icon defaults for which `icon_datum` is scaled, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@param to_type? IconDefaultsType The name of the type-specific icon defaults for which the copy is scaled. Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData # A copy of `icon_datum` scaled for `to_type`.
---
---#### Examples
---```lua
----- Reuse the icon layer of an item for its technology, at technology size.
---local technology_layer = _icons.convert_icon_defaults_type(item_layer, nil, "technology")
----- The scale and shift of the layer are multiplied by 4.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `from_type` or `to_type` is `nil` or an empty string.
---@see Icons.convert_icons_defaults_type
---@see Icons.get_expected_icon_size
---@nodiscard
function _icons.convert_icon_defaults_type(icon_datum, from_type, to_type)
	check_convert_icon_defaults_type(icon_datum, from_type, to_type)

	local ratio = resolve_expected_icon_size(to_type) / resolve_expected_icon_size(from_type)

	return apply_icon_adjustment(icon_datum, { scale = ratio }, from_type)
end

local check_convert_icons_defaults_type = V.signature("convert_icons_defaults_type", {
	{ "icon_data", Common.icon_data },
	{ "from_type", Common.icon_defaults_type:optional() },
	{ "to_type", Common.icon_defaults_type:optional() },
})

---Converts the scale and shift of every layer of the given `icon_data` from the expected icon size of one icon defaults
---type to that of another.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects.
---@param from_type? IconDefaultsType The name of the type-specific icon defaults for which `icon_data` is scaled, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---@param to_type? IconDefaultsType The name of the type-specific icon defaults for which the copy is scaled. Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return SafeIconData[] # A copy of `icon_data` scaled for `to_type`.
---
---#### Examples
---```lua
----- Reuse the icon of an item for its technology, at technology size.
---local technology_icon = _icons.convert_icons_defaults_type(item_icon_data, nil, "technology")
----- The scale and shift of every layer are multiplied by 4.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `from_type` or `to_type` is `nil` or an empty string.
---@see Icons.convert_icon_defaults_type
---@see Icons.get_expected_icon_size
---@nodiscard
function _icons.convert_icons_defaults_type(icon_data, from_type, to_type)
	check_convert_icons_defaults_type(icon_data, from_type, to_type)

	local ratio = resolve_expected_icon_size(to_type) / resolve_expected_icon_size(from_type)

	return apply_icons_transform(icon_data, { scale = ratio }, from_type)
end

local check_icon_datum_verb = V.signature("icon operation", {
	{ "icon_datum", Common.icon_datum },
})

local check_icon_data_verb = V.signature("icon operation", {
	{ "icon_data", Common.icon_data },
})

---Floats the given `icon_datum`. A floated layer does not contribute to the bounding box of the icon when rendered in
---the GUI.
---@param icon_datum IconData An `IconData` object.
---@return IconData # A copy of `icon_datum` with `floating` set.
---
---#### Examples
---```lua
----- Place a chevron past the right edge of the icon without shrinking the icon to fit it.
---local indicator = _icons.float_icon(_icons.transform_icon(chevron, { shift = { 25, 0 } }))
----- indicator.floating is true.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@see Icons.float_icons
---@see Icons.remove_floating_from_icon
---@nodiscard
function _icons.float_icon(icon_datum)
	check_icon_datum_verb(icon_datum)

	return layer_with_field(icon_datum, "floating", true)
end

---Floats every layer of the given `icon_data`. A floated layer does not contribute to the bounding box of the icon when
---rendered in the GUI.
---@param icon_data IconData[] An array of `IconData` objects.
---@return IconData[] # A copy of `icon_data` with `floating` set on every layer.
---
---#### Examples
---```lua
----- Place a chevron past the right edge of the icon without shrinking the icon to fit it.
---local indicator = _icons.float_icons(_icons.transform_icons(chevron, { shift = { 25, 0 } }))
----- Every layer of the indicator has floating set to true.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@see Icons.float_icon
---@see Icons.remove_floating_from_icons
---@nodiscard
function _icons.float_icons(icon_data)
	check_icon_data_verb(icon_data)

	return map_layers(icon_data, layer_with_field, "floating", true)
end

---Removes `floating` from the given `icon_datum`.
---@param icon_datum IconData An `IconData` object
---@return IconData # A copy of `icon_datum` with `floating` cleared.
---@throws When `icon_datum` is not a valid `IconData` object.
---@see Icons.remove_floating_from_icons
---@see Icons.float_icon
---@nodiscard
function _icons.remove_floating_from_icon(icon_datum)
	check_icon_datum_verb(icon_datum)

	return layer_with_field(icon_datum, "floating", nil)
end

---Removes `floating` from every layer of the given `icon_data`.
---@param icon_data IconData[] An array of `IconData` objects.
---@return IconData[] # A copy of `icon_data` with `floating` cleared from every layer.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@see Icons.remove_floating_from_icon
---@see Icons.float_icons
---@nodiscard
function _icons.remove_floating_from_icons(icon_data)
	check_icon_data_verb(icon_data)

	return map_layers(icon_data, layer_with_field, "floating", nil)
end

---Outlines the given `icon_datum`, unless it is an empty layer.
---@param icon_datum IconData An `IconData` object.
---@return IconData # A copy of `icon_datum` with `draw_background` set, unless it is an empty layer.
---@throws When `icon_datum` is not a valid `IconData` object.
---@see Icons.outline_icons
---@see Icons.remove_outline_from_icon
---@nodiscard
function _icons.outline_icon(icon_datum)
	check_icon_datum_verb(icon_datum)

	if is_empty_layer(icon_datum) then
		return util.copy(icon_datum)
	end

	return layer_with_field(icon_datum, "draw_background", true)
end

---Outlines the given `icon_data`, with the outline drawn by the first layer that is not an empty layer.
---@param icon_data IconData[] An array of `IconData` objects.
---@return IconData[] # A copy of `icon_data` with `draw_background` set on its first layer of artwork.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@see Icons.outline_icon
---@see Icons.remove_outline_from_icons
---@nodiscard
function _icons.outline_icons(icon_data)
	check_icon_data_verb(icon_data)

	return outline_first_non_empty_layer_in_place(util.copy(icon_data))
end

---Removes the outline from the given `icon_datum`.
---
---`draw_background` is set to `false`, as the game draws the outline of the first layer of an icon
---when `draw_background` is omitted.
---@param icon_datum IconData An `IconData` object.
---@return IconData # A copy of `icon_datum` with `draw_background` set to `false`.
---@throws When `icon_datum` is not a valid `IconData` object.
---@see Icons.remove_outline_from_icons
---@see Icons.outline_icon
---@nodiscard
function _icons.remove_outline_from_icon(icon_datum)
	check_icon_datum_verb(icon_datum)

	return layer_with_field(icon_datum, "draw_background", false)
end

---Removes the outline from the given `icon_data`.
---
---`draw_background` is set to `false` on every layer, as the game draws the outline of the first layer of an icon when
---`draw_background` is omitted.
---@param icon_data IconData[] An array of `IconData` objects.
---@return IconData[] # A copy of `icon_data` with `draw_background` set to `false` on every layer.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@see Icons.remove_outline_from_icon
---@see Icons.outline_icons
---@nodiscard
function _icons.remove_outline_from_icons(icon_data)
	check_icon_data_verb(icon_data)

	return map_layers(icon_data, layer_with_field, "draw_background", false)
end

---Sets a copy of the given `tint` on the given `icon_datum`.
---@param icon_datum IconData A valid `IconData` object.
---@param tint Color The tint to set.
---@return IconData # A copy of `icon_datum` with the tint set.
---@nodiscard
local function layer_with_tint(icon_datum, tint)
	return layer_with_field(icon_datum, "tint", util.copy(tint))
end

---Sets the given `tint` on the given `icon_datum`, unless its tint is additive.
---@param icon_datum IconData A valid `IconData` object.
---@param tint Color The tint to set.
---@return IconData # A copy of `icon_datum` with the tint set, or with its own tint when that tint is additive.
---@nodiscard
local function layer_with_tint_unless_additive(icon_datum, tint)
	if has_additive_tint(icon_datum) then
		return util.copy(icon_datum)
	end

	return layer_with_tint(icon_datum, tint)
end

local check_set_icon_tint = V.signature("set_icon_tint", {
	{ "icon_datum", Common.icon_datum },
	{ "tint", Common.color },
})

---Sets the tint of the given `icon_datum` to the given `tint`. Colors are replaced, not blended. A layer with a tint
---alpha of zero, which the game renders additively, is returned unchanged.
---@param icon_datum IconData An `IconData` object.
---@param tint Color The tint to set.
---@return IconData # A copy of `icon_datum` with `tint` set, unless its tint is additive.
---
---#### Examples
---```lua
----- Tint a layer red.
---local red_layer = _icons.set_icon_tint(icon_datum, { r = 1, g = 0, b = 0 })
----- red_layer.tint is { r = 1, g = 0, b = 0 }.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `tint` is not a `Color`.
---@see Icons.set_icons_tint
---@see Icons.blend_icon_tint
---@nodiscard
function _icons.set_icon_tint(icon_datum, tint)
	check_set_icon_tint(icon_datum, tint)

	return layer_with_tint_unless_additive(icon_datum, tint)
end

local check_set_icons_tint = V.signature("set_icons_tint", {
	{ "icon_data", Common.icon_data },
	{ "tint", Common.color },
})

---Sets the tint of every layer of the given `icon_data`. Colors are replaced, not blended. A layer with a tint
---alpha of zero, which the game renders additively, is returned unchanged.
---@param icon_data IconData[] An array of `IconData` objects.
---@param tint Color The tint to set.
---@return IconData[] # A copy of `icon_data` with `tint` set on every layer that is not additive.
---
---#### Examples
---```lua
----- Tint every layer of an icon red.
---local red_icon = _icons.set_icons_tint(icon_data, { r = 1, g = 0, b = 0 })
----- Every layer that is not additive has a tint of { r = 1, g = 0, b = 0 }.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `tint` is not a `Color`.
---@see Icons.set_icon_tint
---@see Icons.blend_icons_tint
---@nodiscard
function _icons.set_icons_tint(icon_data, tint)
	check_set_icons_tint(icon_data, tint)

	return map_layers(icon_data, layer_with_tint_unless_additive, tint)
end

---Defines a blending function that takes the existing tint of a layer and the incoming tint, both normalized, and
---returns the resulting tint of the layer.
---@alias IconTintBlender fun(existing: NormalizedColor, incoming: NormalizedColor): Color

---A validator that checks that a value is a blending function.
local blender_function = V.func():describe_as("a blending function")

---The tint of a layer with no `tint`.
local UNTINTED = { r = 1, g = 1, b = 1, a = 1 }

---Gets the given `blender`, or `colors.blend` at `weight` when `blender` is `nil`.
---@param weight? float The weight used by `colors.blend`.
---@param blender? IconTintBlender The function with which the tints are blended, in place of `colors.blend`.
---@return IconTintBlender # The blending function.
---@nodiscard
local function resolve_blender(weight, blender)
	return blender or function(existing, incoming)
		return Colors.blend(existing, incoming, weight)
	end
end

---Blends `incoming` into the tint of the given `icon_datum` by `mix`. A layer without a tint is given a white tint
---before it is blended.
---@param icon_datum IconData A valid `IconData` object.
---@param incoming NormalizedColor The normalized tint that is blended into the tint of the layer.
---@param mix IconTintBlender The blending function.
---@return IconData # A copy of `icon_datum` with the blended tint.
---@nodiscard
local function layer_with_blended_tint(icon_datum, incoming, mix)
	local existing = Colors.normalize(icon_datum.tint or UNTINTED)

	return layer_with_field(icon_datum, "tint", Colors.normalize(mix(existing, incoming)))
end

---Blends `incoming` into the tint of the given `icon_datum` by `mix`, unless its tint is additive.
---@param icon_datum IconData A valid `IconData` object.
---@param incoming NormalizedColor The normalized tint that is blended into the tint of the layer.
---@param mix IconTintBlender The blending function.
---@return IconData # A copy of `icon_datum` with the blended tint, or with its own tint when that tint is additive.
---@nodiscard
local function layer_with_blended_tint_unless_additive(icon_datum, incoming, mix)
	if has_additive_tint(icon_datum) then
		return util.copy(icon_datum)
	end

	return layer_with_blended_tint(icon_datum, incoming, mix)
end

local check_blend_icon_tint = V.signature("blend_icon_tint", {
	{ "icon_datum", Common.icon_datum },
	{ "tint", Common.color },
	{ "weight", Common.unit_interval:optional() },
	{ "blender", blender_function:optional() },
})

---Blends the given `tint` into the tint of the given `icon_datum`.
---
---- A layer without a tint is blended as if its tint were white.
---- A layer with a tint alpha of zero, which the game renders additively, is returned unchanged.
---- The tints are blended with `colors.blend` at the given `weight`. If `blender` is given, it is used instead, and
---  `weight` is ignored. `blender` receives normalized colors, and its result is normalized.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object.
---@param tint Color The tint to blend in.
---@param weight? float The weight of `tint` in the blend, between 0 and 1. Default `0.5`.
---@param blender? IconTintBlender The function with which the tints are blended, in place of `colors.blend`.
---
---#### Returns
---@return IconData # A copy of `icon_datum` with its tint blended.
---
---#### Examples
---```lua
----- Move the tint of a layer toward the group color, at a weight of 0.4.
---local blended = _icons.blend_icon_tint(icon_datum, group_color, 0.4)
----- An untinted layer is given the tint of white blended with the group color at 0.4.
---```
---@throws When `icon_datum` is not a valid `IconData` object.
---@throws When `tint` is not a `Color`.
---@throws When `weight` is not between 0 and 1.
---@throws When `blender` is not a function, or returns something other than a `Color`.
---@see Icons.blend_icons_tint
---@see Icons.set_icon_tint
---@see Colors.blend
---@nodiscard
function _icons.blend_icon_tint(icon_datum, tint, weight, blender)
	check_blend_icon_tint(icon_datum, tint, weight, blender)

	return layer_with_blended_tint_unless_additive(icon_datum, Colors.normalize(tint), resolve_blender(weight, blender))
end

local check_blend_icons_tint = V.signature("blend_icons_tint", {
	{ "icon_data", Common.icon_data },
	{ "tint", Common.color },
	{ "weight", Common.unit_interval:optional() },
	{ "blender", blender_function:optional() },
})

---Blends the given `tint` into the tint of every layer of the given `icon_data`.
---
---- A layer without a tint is blended as if its tint were white.
---- A layer with a tint alpha of zero, which the game renders additively, is not modified.
---- The tints are blended with `colors.blend` at the given `weight`. If `blender` is given, it is used instead, and
---  `weight` is ignored. `blender` receives normalized colors, and its result is normalized.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects.
---@param tint Color The tint to blend in.
---@param weight? float The weight of `tint` in the blend, between 0 and 1. Default `0.5`.
---@param blender? IconTintBlender The function with which the tints are blended, in place of `colors.blend`.
---
---#### Returns
---@return IconData[] # A copy of `icon_data` with the tint of each layer that is not additive blended.
---
---#### Examples
---```lua
----- Move the tint of every layer toward the group color, at a weight of 0.4.
---local blended = _icons.blend_icons_tint(icon_data, group_color, 0.4)
----- An untinted layer is given the tint of white blended with the group color at 0.4.
---
----- Composite the group color over the tint of every layer.
---local overlaid = _icons.blend_icons_tint(icon_data, group_color, nil, _colors.overlay)
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `tint` is not a `Color`.
---@throws When `weight` is not between 0 and 1.
---@throws When `blender` is not a function, or returns something other than a `Color`.
---@see Icons.blend_icon_tint
---@see Icons.set_icons_tint
---@see Colors.blend
---@see Colors.overlay
---@nodiscard
function _icons.blend_icons_tint(icon_data, tint, weight, blender)
	check_blend_icons_tint(icon_data, tint, weight, blender)

	return map_layers(
		icon_data,
		layer_with_blended_tint_unless_additive,
		Colors.normalize(tint),
		resolve_blender(weight, blender)
	)
end

---Gets the icon named by the given `source`, or a blank icon when the named prototype does not exist.
---No validation is performed; callers are expected to have pre-validated the input.
---@param source? IconSource The `IconSource` to resolve.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate.
---@return SafeIconData[] icon_data A copy of the icon data from `source`, if it exists; otherwise, a blank icon.
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

---Adds the icons named by the given `sources` on top of the given `icon_data`.
---No validation is performed; callers are expected to have pre-validated the input.
---@param icon_data IconData[] A valid array of `IconData` objects.
---@param sources IconSources The sources of the icons added on top of `icon_data`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate.
---@return SafeIconData[] # A copy of `icon_data` with the sourced icons on top.
---@return boolean # `true` if a blank icon was substituted for a source naming a prototype that does not exist; otherwise, `false`.
---@nodiscard
local function apply_icons_from_sources(icon_data, sources, defaults_type)
	---@type IconData[]
	local combined_icon = apply_icons_defaults(icon_data, defaults_type)

	local has_blank_layers = false
	for _, source in pairs(sources) do
		-- The icon is blank when the prototype does not exist.
		local icon, is_blank_icon = get_icons_from_source(source, defaults_type)
		has_blank_layers = has_blank_layers or is_blank_icon

		-- A `transform` replaces `scale` and `shift`. `tint` and `floating` are applied separately.
		local placement = source.transform or source
		local transformed_icon = apply_icons_transform(icon, {
			scale = placement.scale,
			shift = placement.shift,
			tint = source.tint,
			floating = source.floating,
		}, source.type_name or source.defaults_type or defaults_type)

		for index = 1, #transformed_icon do
			local icon_datum = transformed_icon[index]

			-- Set `draw_background` on the first layer of each sourced icon. The game draws the outline of
			-- the first layer of an icon when `draw_background` is absent, and the sourced layer is no
			-- longer first.
			if index == 1 then
				icon_datum.draw_background = true
			end

			table.insert(combined_icon, icon_datum)
		end
	end

	return combined_icon, has_blank_layers
end

---Adds the icons from the given `sources` to a copy of the given `icon_data` array, and applies any of the optional
---transformations.
---
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist will be replaced with a
---  blank icon.
---- `draw_background` is set on the first layer of each sourced icon.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects to receive the sourced icons.
---@param sources IconSources An array of `IconData` sources to layer on `icon_data`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`. The `defaults_type` or `type_name` of a source takes precedence for the layers of that source.
---
---#### Returns
---@return SafeIconData[] combined_icon A copy of `icon_data` with the sourced icons transformed and layered on top.
---@return boolean has_blank_layers When `true`, a blank icon layer was created.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `sources` is not an array of valid `IconSource` objects.
---@throws When `defaults_type` is an empty string.
---@see Icons.create_icons_from_sources
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

---Creates an icon from the given `sources`, with the first element providing the base icon layer, and the remaining
---elements layered on top sequentially.
---
---- The `scale`, `shift`, `transform`, and `floating` of the first source are ignored, and its `tint` is applied to
---  each layer of its icon.
---- The remaining sources are added as by `add_icons_from_sources_to_icons`.
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist will be replaced with a
---  blank icon, including the base layer.
---
---#### Parameters
---@param sources IconSources An array of `IconData` sources, with the base icon first.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults to generate, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`. The `defaults_type` or `type_name` of a source takes precedence for the layers of that source.
---
---#### Returns
---@return SafeIconData[] icon A new icon created from the sources, with the base icon from the first source, and icons from the remaining sources layered on top.
---@return boolean has_blank_layers When `true`, a blank icon layer was created.
---
---#### Examples
---```lua
----- Create an icon with an iron plate as the base, and half-size copper wire and copper plate icons in the
----- upper-left and upper-right corners.
------@type (IconDatumSource|PrototypeIconSource)[]
---local sources = {
---    -- Define the base layer directly.
---    {
---        icon_datum = {
---            icon = "__base__/graphics/icons/iron-plate.png",
---            icon_size = 64,
---            scale = 0.5,
---        },
---    },
---    -- Read the corner icons from item prototypes.
---    { name = "copper-wire", type_name = "item", scale = 0.5, shift = { -8, -8 } },
---    { name = "copper-plate", type_name = "item", scale = 0.5, shift = { 8, -8 } },
---}
---
---local icon_data = _icons.create_icons_from_sources(sources)
----- The icon has three layers: the iron plate, the copper wire, and the copper plate.
---```
---@throws When `sources` is not a non-empty array of valid `IconSource` objects.
---@throws When `defaults_type` is an empty string.
---@see Icons.add_icons_from_sources_to_icons
---@nodiscard
function _icons.create_icons_from_sources(sources, defaults_type)
	check_create_icons_from_sources(sources, defaults_type)

	---@type IconSources
	local sources_copy = util.copy(sources)

	local has_blank_layers = false

	-- Get the base icon from the first source.
	local base_source = table.remove(sources_copy, 1)
	local base_icon_data, is_blank_icon = get_icons_from_source(base_source, defaults_type)

	has_blank_layers = (has_blank_layers or is_blank_icon)

	for _, icon_datum in pairs(base_icon_data) do
		if not has_additive_tint(icon_datum) then
			icon_datum.tint = base_source.tint or icon_datum.tint
		end
	end

	local icon_data, added_blank_layers = apply_icons_from_sources(base_icon_data, sources_copy, defaults_type)
	has_blank_layers = (has_blank_layers or added_blank_layers)

	return icon_data, has_blank_layers
end

---Creates an icon from the sources given for each recipe in the given `recipe_icon_source_map`, and assigns it to that
---recipe and to its related prototypes.
---
---- Each icon is created as by `create_icons_from_sources`, and assigned as by
---  `assign_icons_to_prototype_and_related_prototypes`.
---- Any layer of the icon using a `PrototypeIconSource` for a prototype that does not exist will be replaced with a
---  blank icon.
---- Missing icon fields are set to default values as appropriate.
---
---#### Parameters
---@param recipe_icon_source_map table<string, IconSources> A map of recipe names to the icon sources used to create a combined icon. The first entry in each `IconSources` is the first layer of the created icon.
---
---#### Examples
---```lua
----- Assign a recipe an icon of its product with a half-size ingredient in the upper-left corner.
------@type table<string, IconSources>
---local recipe_icon_source_map = {
---    ["bio-resin-wood-reprocessing"] = {
---        { name = "resin", type_name = "item" },
---        { name = "wood", type_name = "item", scale = 0.5, shift = { -8, -8 } },
---    },
---}
---
---_icons.create_and_assign_composed_icons_from_sources_to_recipe(recipe_icon_source_map)
----- data.raw.recipe["bio-resin-wood-reprocessing"].icons holds the two-layer icon.
---```
---@throws When an entry is not a non-empty array of valid `IconSource` objects.
---@see Icons.create_icons_from_sources
---@see Icons.assign_icons_to_prototype_and_related_prototypes
function _icons.create_and_assign_composed_icons_from_sources_to_recipe(recipe_icon_source_map)
	for recipe_name, sources in pairs(recipe_icon_source_map) do
		local icon_data = _icons.create_icons_from_sources(sources)
		_icons.assign_icons_to_prototype_and_related_prototypes(recipe_name, "recipe", icon_data)
	end
end

return _icons
