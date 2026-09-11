---@using data
---@using Reskins.SpriteUtils

---@namespace Reskins.SpriteUtils.Validation

local V = require("validation")
local _defines = require("defines")

---Provides validators for the values used by this library.
---
---Everything here is stage-agnostic except `Common.prototypes`, which reads `data.raw`.
---
---#### Examples
---```lua
---local Common = require("__reskins-sprite-utils__.validation.common")
---
---function _icons.scale_icon(icon_data, scalar)
---    Common.icon_data:assert(icon_data, "icon_data")
---    Common.positive_number:assert(scalar, "scalar")
---    ...
---end
---```
---@class Common
local _common = {}

---A validator that checks that a value is a finite number greater than 0.
_common.positive_number = V.number():finite():positive()

---A validator that checks that a value is a finite number of 0 or greater.
_common.non_negative_number = V.number():finite():non_negative()

---A validator that checks that a value is a whole number greater than 0.
_common.positive_integer = V.integer():positive()

---A validator that checks that a value is a whole number of 0 or greater.
_common.non_negative_integer = V.integer():non_negative()

---A validator that checks that a value is a number between 0 and 1 inclusive, as used for a color component or an
---opacity.
_common.unit_interval = V.number():finite():in_range(0, 1)

---A validator that checks that a value is a string of at least one character.
_common.non_empty_string = V.string():not_empty()

---A validator that checks that a value is a mod-relative file path, such as `__base__/graphics/icons/iron-plate.png`.
---
---The `__mod-name__/` prefix and the file extension are checked by separate rules.
---@see FileName
_common.mod_file_path = V.string()
	:not_empty()
	:matches("^__[%a%d%-%_]+__/", "a mod-relative path beginning with '__mod-name__/'")
	:matches("%.[%a%d]+$", "a path ending in a file extension")
	:describe_as("a mod-relative file path")

---A validator that checks that a value is the pixel size of a sprite or icon, as an integer between 1 and 8192.
---@see SpriteSizeType
_common.sprite_size = V.integer():in_range(1, 8192):describe_as("a sprite size in pixels")

---A validator that checks that a value is a single component of a color, as a number between 0 and 1 or an integer
---between 0 and 255.
local color_component = V.any_of(_common.unit_interval, V.integer():in_range(0, 255))

---A validator that checks that a value is a [`Color`](https://lua-api.factorio.com/latest/types/Color.html), as either
---named components or an array of three to four numbers.
---
---The named form does not permit unknown fields.
---@see Color
---@type Validator<Color>
_common.color = V.any_of(
	V.struct({
		r = color_component:optional(),
		g = color_component:optional(),
		b = color_component:optional(),
		a = color_component:optional(),
	})
		:strict()
		:describe_as("a table of r, g, b, and a components"),
	V.array(color_component):min_length(3):max_length(4):describe_as("an array of three or four numbers")
):describe_as("a Color")

---A validator that checks that a value is a hue in degrees, as a finite number. A value below 0 or above 360 is
---accepted and is read modulo 360.
local hue = V.number():finite():describe_as("a hue in degrees")

---A validator that checks that a value is an `HsvColor` with no unknown fields. The `h` field is in degrees, and the
---`s`, `v`, and `a` fields are between 0 and 1.
---@type StructValidator<HsvColor>
_common.hsv_color = V.struct({
	h = hue,
	s = _common.unit_interval,
	v = _common.unit_interval,
	a = _common.unit_interval,
})
	:strict()
	:describe_as("an HsvColor")

---A validator that checks that a value is an `HslColor` with no unknown fields. The `h` field is in degrees, and the
---`s`, `l`, and `a` fields are between 0 and 1.
---@type StructValidator<HslColor>
_common.hsl_color = V.struct({
	h = hue,
	s = _common.unit_interval,
	l = _common.unit_interval,
	a = _common.unit_interval,
})
	:strict()
	:describe_as("an HslColor")

---A validator that checks that a value is a [Vector](https://lua-api.factorio.com/latest/types/Vector.html), as either
---a two-element array or a table of `x` and `y`.
---
---The named form does not permit unknown fields.
---@type Validator<Vector>
_common.vector = V.any_of(
	V.tuple(V.number():finite(), V.number():finite()):describe_as("a two-element array of numbers"),
	V.struct({ x = V.number():finite(), y = V.number():finite() }):strict():describe_as("a table of x and y components")
):describe_as("a Vector")

---A validator that checks that a value is an icon defaults type name, as a non-empty string. An unrecognized name is
---accepted and resolves to the default icon size.
_common.icon_defaults_type = V.string():not_empty():describe_as("an icon defaults type name")

---A validator that checks that a value is an [`IconData`](https://lua-api.factorio.com/latest/types/IconData.html)
---object. Unknown fields are permitted unless `:strict()` is called.
---@see IconData
_common.icon_datum = V.class("IconData", {
	icon = _common.mod_file_path,
	icon_size = _common.sprite_size:optional(),
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	draw_background = V.boolean():optional(),
	floating = V.boolean():optional(),
})
	:where(function(value)
		-- An array passed where an object was expected would otherwise be reported as a missing
		-- `icon`.
		---@diagnostic disable-next-line: undefined-field
		return value[1] == nil
	end, "must be a single IconData object, not an array of them")
	:describe_as("an IconData object")

---A validator that checks that a value is an icon, as a non-empty array of
---[`IconData`](https://lua-api.factorio.com/latest/types/IconData.html) objects.
---@see IconData
_common.icon_data = V.array(_common.icon_datum):not_empty():describe_as("an array of IconData objects")

---A validator that checks that a value is an [`IconData`](https://lua-api.factorio.com/latest/types/IconData.html)
---object or an array of [`IconData`](https://lua-api.factorio.com/latest/types/IconData.html) objects.
---@see IconData
_common.icon = V.any_of(_common.icon_datum, _common.icon_data)

---A validator that checks that a value is an `IconComposition`.
---@see IconComposition
_common.icon_composition = V.custom("IconComposition", function(value)
	local IconComposition = require("__reskins-sprite-utils__.icon-composition")
	return IconComposition.is_icon_composition(value)
end, "an IconComposition")

---A validator that checks that a value is a `Transform` with no unknown fields.
---@see Transform
_common.transform = V.class("Transform", {
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
})
	:strict()
	:describe_as("a Transform")

---A validator that checks that a value is an `IconDatumSource`, an icon source that provides a single
---[`IconData`](https://lua-api.factorio.com/latest/types/IconData.html) object.
---@see IconDatumSource
_common.icon_datum_source = V.class("IconDatumSource", {
	icon_datum = _common.icon_datum,
	defaults_type = _common.icon_defaults_type:optional(),
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	floating = V.boolean():optional(),
	transform = _common.transform:optional(),
}):describe_as("an IconDatumSource")

---A validator that checks that a value is an `IconDataSource`, an icon source that provides an array of
---[`IconData`](https://lua-api.factorio.com/latest/types/IconData.html) objects.
---@see IconDataSource
_common.icon_data_source = V.class("IconDataSource", {
	icon_data = _common.icon_data,
	defaults_type = _common.icon_defaults_type:optional(),
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	floating = V.boolean():optional(),
	transform = _common.transform:optional(),
}):describe_as("an IconDataSource")

---A validator that checks that a value is a prototype name, as a non-empty string.
_common.prototype_name = V.string():not_empty():describe_as("a prototype name")

---A validator that checks that a value is a prototype type name, such as `"item"` or `"assembling-machine"`, as a
---non-empty string.
_common.prototype_type_name = V.string():not_empty():describe_as("a prototype type name")

---A validator that checks that a value is a `PrototypeIconSource`, an icon source that names the prototype from which
---the icon is taken.
---@see PrototypeIconSource
_common.prototype_icon_source = V.class("PrototypeIconSource", {
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	floating = V.boolean():optional(),
	transform = _common.transform:optional(),
}):describe_as("a PrototypeIconSource")

---A validator that checks that a value is an `IconDatumSource`, an `IconDataSource`, or a `PrototypeIconSource`.
---@see IconSource
_common.icon_source = V.any_of(_common.icon_datum_source, _common.icon_data_source, _common.prototype_icon_source)
	:describe_as("an IconSource")

---A validator that checks that a value is an `IconAssignmentOptions` object with no unknown fields.
---@see IconAssignmentOptions
_common.icon_assignment_options = V.class("IconAssignmentOptions", {
	infer_item = V.boolean():optional(),
	infer_recipe = V.boolean():optional(),
	infer_explosion = V.boolean():optional(),
	infer_corpse = V.boolean():optional(),
	explosion_by_convention = V.boolean():optional(),
	corpse_by_convention = V.boolean():optional(),
	strict = V.boolean():optional(),
})
	:strict()
	:describe_as("an IconAssignmentOptions")

---A validator that checks that a value is an `IconDataAssignment`, an icon from an array of
---[`IconData`](https://lua-api.factorio.com/latest/types/IconData.html) objects with the name and type of the prototype
---to which it may be assigned.
---@see IconDataAssignment
_common.icon_data_assignment = V.class("IconDataAssignment", {
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	icon_data = _common.icon_data,
	pictures = V.table():optional(),
	options = _common.icon_assignment_options:optional(),
}):describe_as("an IconDataAssignment")

---A validator that checks that a value is an `IconDatumAssignment`, an icon from a single
---[`IconData`](https://lua-api.factorio.com/latest/types/IconData.html) object with the name and type of the prototype
---to which it may be assigned.
---@see IconDatumAssignment
_common.icon_datum_assignment = V.class("IconDatumAssignment", {
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	icon_datum = _common.icon_datum,
	options = _common.icon_assignment_options:optional(),
}):describe_as("an IconDatumAssignment")

---A validator that checks that a value is an `IconCompositionAssignment`, an icon from an `IconComposition` object with
---the name and type of the prototype to which it may be assigned.
---@see IconCompositionAssignment
_common.icon_composition_assignment = V.class("IconCompositionAssignment", {
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	composition = _common.icon_composition,
	options = _common.icon_assignment_options:optional(),
}):describe_as("an IconCompositionAssignment")

---A validator that checks that a value is an icon composition stratum.
---@see IconCompositionStratum
_common.icon_composition_stratum = V.one_of(_defines.icon_composition_strata):describe_as("an icon composition stratum")

---A validator that checks that a value is `false` or a table of settings for a group projection. The fields of the
---table are not validated.
local group_projection_entry = V.any_of(V.literal(false), V.table())
	:describe_as("false or a table of settings for the projection")

---A validator that checks that a value is an `IconCompositionGroup` with no unknown fields.
---@see IconCompositionGroup
_common.icon_composition_group = V.class("IconCompositionGroup", {
	name = _common.non_empty_string,
	stratum = _common.icon_composition_stratum,
	order = V.number():finite():optional(),
	tintable = V.boolean():optional(),
	unique = V.boolean():optional(),
	projections = V.map(_common.non_empty_string, group_projection_entry):optional(),
})
	:strict()
	:describe_as("an IconCompositionGroup")

---A validator that checks that a value is an `IconCompositionProjection` with no unknown fields.
---@see IconCompositionProjection
_common.icon_composition_projection = V.class("IconCompositionProjection", {
	name = _common.non_empty_string,
	includes_labels = V.boolean(),
	lower = V.func(),
})
	:strict()
	:describe_as("an IconCompositionProjection")

---A validator that checks that a value is an [`Animation`](https://lua-api.factorio.com/latest/types/Animation.html)
---that includes its artwork, through `filename`, `stripes`, or `layers`, without validating other fields. A `filename`
---must be a mod-relative file path. The check is applied to each layer of a layered animation.
---@see Animation
---@type StructValidator<Animation>
local animation_spritesheet

animation_spritesheet = V.struct({
	filename = _common.mod_file_path:optional(),
	layers = V.array(V.lazy(function()
		return animation_spritesheet
	end))
		:not_empty()
		:optional(),
})
	:where(function(value)
		---@cast value Animation
		return value.filename ~= nil
			or value.filenames ~= nil
			or value.stripes ~= nil
			or (value.layers ~= nil and value.layers[1] ~= nil)
	end, "must name its artwork through 'filename', 'filenames', 'stripes', or 'layers'")
	:describe_as("a sprite sheet")

_common.animation_spritesheet = animation_spritesheet

---A validator that checks that a value is a
---[`WorkingVisualisation`](https://lua-api.factorio.com/latest/types/WorkingVisualisation.html) with an
---[`Animation`](https://lua-api.factorio.com/latest/types/Animation.html) field that is a minimally valid sprite sheet.
---@see WorkingVisualisation
_common.working_visualisation = V.struct({
	animation = _common.animation_spritesheet,
}):describe_as("a WorkingVisualisation carrying an animation")

---Provides validators that check values against the prototypes in `data.raw`. They are usable during the prototype
---stages only. Using one elsewhere raises an error.
---@class Common.Prototypes
_common.prototypes = {}

---Gets `data.raw`, and raises an error when it is unavailable.
---@return table<string, table<string, table>>
---@nodiscard
local function require_data_raw()
	if not data or not data.raw then
		error(
			"reskins-sprite-utils: the validators in validation.common.prototypes read data.raw, and may only be "
				.. "used during the prototype stages.",
			0
		)
	end

	return data.raw
end

---A validator that checks that a value is a prototype type name that Factorio has registered, such as `"item"`. The
---validator reads `data.raw`.
_common.prototypes.is_registered_type = _common.prototype_type_name
	:satisfies(function(value)
		return require_data_raw()[value] ~= nil
	end, "a registered prototype type name")
	:describe_as("a registered prototype type name")

---Creates a validator that checks that a named prototype exists in `data.raw` for the given `type_name`.
---@param type_name string The type of the prototype.
---@return StringValidator validator A validator that checks that a value is the name of a defined prototype. Requires `data.raw`.
---
---#### Examples
---```lua
---local ExistingItem = Common.prototypes.existing_prototype("item")
---ExistingItem:assert(name, "name")
---```
---@nodiscard
function _common.prototypes.existing_prototype(type_name)
	return _common.prototype_name
		:satisfies(function(value)
			local prototypes = require_data_raw()[type_name]

			return prototypes ~= nil and prototypes[value] ~= nil
		end, string.format("the name of an existing '%s' prototype", type_name))
		:describe_as(string.format("the name of an existing '%s' prototype", type_name))
end

---The validators created by `existing_prototype`, keyed by prototype type.
---@type table<string, StringValidator>
local existing_prototype_validators = {}

---Indicates whether the given `name` corresponds to a named prototype of the given `type_name`.
---
---The validator for each type name is cached.
---@param name string The prototype name to check.
---@param type_name string The type of the prototype.
---@return boolean exists `true` if the prototype exists; otherwise, `false`.
---@return string? message A description of the expected value, if the prototype does not exist.
local function name_exists_under_type(name, type_name)
	local validator = existing_prototype_validators[type_name]

	if not validator then
		validator = _common.prototypes.existing_prototype(type_name)
		existing_prototype_validators[type_name] = validator
	end

	local result = validator:validate(name, { path = "name" })

	return result.ok, result.errors[1] and result.errors[1].message
end

---Creates a signature rule that checks that the argument named `name_parameter` corresponds to a named prototype of the
---type given by the argument named `type_parameter`. A failure is reported against `name_parameter`. Requires
---`data.raw`.
---@param name_parameter? string The name of the parameter that contains the prototype name. Default `"name"`.
---@param type_parameter? string The name of the parameter that contains the prototype type. Default `"type_name"`.
---@return SignatureRule
---
---#### Examples
---```lua
---local check_args = V.signature("get_icon_from_named_prototype", {
---    { "name", Common.prototype_name },
---    { "type_name", Common.prototypes.is_registered_type },
---}, { Common.prototypes.names_an_existing_prototype() })
---```
---@nodiscard
function _common.prototypes.names_an_existing_prototype(name_parameter, type_parameter)
	name_parameter = name_parameter or "name"
	type_parameter = type_parameter or "type_name"

	---@type SignatureRule
	return {
		parameter = name_parameter,
		arguments = { name_parameter, type_parameter },
		check = name_exists_under_type,
	}
end

---A validator that checks that a value is a prototype with a `type` field that defines an icon through either its
---`icon` or its `icons` field.
_common.prototype_with_icons = V.struct({
	name = _common.prototype_name,
	type = _common.prototype_type_name,
	icon = _common.mod_file_path:optional(),
	icons = _common.icon_data:optional(),
})
	:where(function(value)
		return value.icons ~= nil or value.icon ~= nil
	end, "must define an icon through either the 'icon' or the 'icons' field")
	:describe_as("a prototype defining an icon")

return _common
