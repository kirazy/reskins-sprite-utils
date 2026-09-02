---@using data
---@using Reskins.SpriteUtils

---@namespace Reskins.SpriteUtils.Validation

local V = require("validation")
local _defines = require("defines")

---Provides validators for the values used by this library.
---
---Builder methods return a new validator, so an entry may be narrowed for a specific use without
---modifying the shared validator:
---
---```lua
---local SmallIconSize = Common.sprite_size:max(64) -- Common.sprite_size is unchanged
---```
---
---Everything here is stage-agnostic except `Common.prototypes`, which reads
---`data.raw`.
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

---Merges groups of shape fields into one table, left to right.
---@param ... table<string, Validator<any>> The groups to merge.
---@return table<string, Validator<any>>
---@nodiscard
local function fields(...)
	local merged = {}

	-- Counted so that a nil group does not truncate the list.
	local groups = table.pack(...)
	for index = 1, groups.n do
		for name, validator in pairs(groups[index] or {}) do
			merged[name] = validator
		end
	end

	return merged
end

-- Scalars

---A number greater than zero.
_common.positive_number = V.number():finite():positive()

---A number of zero or greater.
_common.non_negative_number = V.number():finite():non_negative()

---A whole number greater than zero.
_common.positive_integer = V.integer():positive()

---A whole number of zero or greater.
_common.non_negative_integer = V.integer():non_negative()

---A number between zero and one inclusive, as used for a color component or an opacity.
_common.unit_interval = V.number():finite():in_range(0, 1)

---A string of at least one character.
_common.non_empty_string = V.string():not_empty()

-- Factorio structures

---A mod-relative file path, such as `__base__/graphics/icons/iron-plate.png`.
---
---Both halves of the requirement are checked separately so a failure says which
---one was missed: the `__mod-name__/` prefix Factorio resolves paths against, and
---a file extension.
_common.mod_file_path = V.string()
	:not_empty()
	:matches("^__[%a%d%-%_]+__/", "a mod-relative path beginning with '__mod-name__/'")
	:matches("%.[%a%d]+$", "a path ending in a file extension")
	:describe_as("a mod-relative file path")

---The pixel size of a sprite or icon.
_common.sprite_size = V.integer():in_range(1, 8192):describe_as("a sprite size in pixels")

---A single component of a color.
local color_component = V.number():finite():non_negative()

---A [Color](https://lua-api.factorio.com/latest/types/Color.html), as either named
---components or an array of three to four numbers.
---
---The named form does not permit unknown fields.
---@type Validator<Color>
_common.color = V.any_of(
	V.shape({
		r = color_component:optional(),
		g = color_component:optional(),
		b = color_component:optional(),
		a = color_component:optional(),
	})
		:strict()
		:describe_as("a table of r, g, b, and a components"),
	V.array(color_component):min_length(3):max_length(4):describe_as("an array of three or four numbers")
):describe_as("a Color")

---A validator that checks that a value is a hue in degrees: a finite number. Values outside 0 to
---360 are accepted, and are read modulo 360.
local hue = V.number():finite():describe_as("a hue in degrees")

---An `HsvColor`, with `h` in degrees and `s`, `v`, and `a` between zero and one.
---
---Unknown fields are not permitted.
---@type ShapeValidator<HsvColor>
_common.hsv_color = V.shape({
	h = hue,
	s = _common.unit_interval,
	v = _common.unit_interval,
	a = _common.unit_interval,
})
	:strict()
	:describe_as("an HsvColor")

---An `HslColor`, with `h` in degrees and `s`, `l`, and `a` between zero and one.
---
---Strict, for the same reason as `Common.hsv_color`.
---@type ShapeValidator<HslColor>
_common.hsl_color = V.shape({
	h = hue,
	s = _common.unit_interval,
	l = _common.unit_interval,
	a = _common.unit_interval,
})
	:strict()
	:describe_as("an HslColor")

---A [Vector](https://lua-api.factorio.com/latest/types/Vector.html), as either a
---two-element array or a table of `x` and `y`.
---@type Validator<Vector>
_common.vector = V.any_of(
	V.tuple(V.number():finite(), V.number():finite()):describe_as("a two-element array of numbers"),
	V.shape({ x = V.number():finite(), y = V.number():finite() }):strict():describe_as("a table of x and y components")
):describe_as("a Vector")

---A validator that checks that a value is an icon defaults type name: a non-empty string.
---Unrecognized names are accepted, and resolve to the default icon size.
_common.icon_defaults_type = V.string():not_empty():describe_as("an icon defaults type name")

---A validator that checks that a value is an [IconData](https://lua-api.factorio.com/latest/types/IconData.html)
---object. Unknown fields are permitted; call `:strict()` to reject them.
---@type ShapeValidator<IconData>
_common.icon_datum = V.shape({
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

---An icon expressed as an array of `IconData` objects.
_common.icon_data = V.array(_common.icon_datum):not_empty():describe_as("an array of IconData objects")

---A validator that checks that a value is a `Transform` with no unknown fields.
---@type ShapeValidator<Transform>
_common.transform = V.shape({
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
})
	:strict()
	:describe_as("a Transform")

---The transformation fields every icon source shares.
local transformable = {
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	floating = V.boolean():optional(),
	transform = _common.transform:optional(),
}

---An icon source providing a single `IconData` object.
---@type ShapeValidator<IconDatumSource>
_common.icon_datum_source = V.shape(fields(transformable, {
	icon_datum = _common.icon_datum,
	defaults_type = _common.icon_defaults_type:optional(),
})):describe_as("an IconDatumSource")

---An icon source providing an array of `IconData` objects.
---@type ShapeValidator<IconDataSource>
_common.icon_data_source = V.shape(fields(transformable, {
	icon_data = _common.icon_data,
	defaults_type = _common.icon_defaults_type:optional(),
})):describe_as("an IconDataSource")

---The name of a prototype.
_common.prototype_name = V.string():not_empty():describe_as("a prototype name")

---The type name of a prototype, such as `"item"` or `"assembling-machine"`.
_common.prototype_type_name = V.string():not_empty():describe_as("a prototype type name")

---An icon source naming the prototype to take the icon from.
---@type ShapeValidator<PrototypeIconSource>
_common.prototype_icon_source = V.shape(fields(transformable, {
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
})):describe_as("a PrototypeIconSource")

---Any of the three forms an icon source may take.
---@type Validator<IconSource>
_common.icon_source = V.any_of(_common.icon_datum_source, _common.icon_data_source, _common.prototype_icon_source)
	:describe_as("an IconSource")

---A validator that checks that a value is an `IconAssignmentOptions` object with no unknown fields.
---@type ShapeValidator<IconAssignmentOptions>
_common.icon_assignment_options = V.shape({
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

---An icon held for deferred assignment to a named prototype.
---@type ShapeValidator<DeferrableIconData>
_common.deferrable_icon_data = V.shape({
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	icon_data = _common.icon_data,
	pictures = V.table():optional(),
	options = _common.icon_assignment_options:optional(),
}):describe_as("a DeferrableIconData")

---A single-object icon held for deferred assignment to a named prototype.
---@type ShapeValidator<DeferrableIconDatum>
_common.deferrable_icon_datum = V.shape({
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	icon_datum = _common.icon_datum,
	options = _common.icon_assignment_options:optional(),
}):describe_as("a DeferrableIconDatum")

-- Icon compositions

---A validator that checks that a value is an icon composition stratum.
---@type Validator<IconCompositionStratum>
_common.icon_composition_stratum = V.one_of(_defines.icon_composition_strata):describe_as("an icon composition stratum")

---A validator that checks that a value is a group `projections` entry: `false`, or a table of
---settings for the projection. The fields of the table are not validated.
local group_projection_entry = V.any_of(V.literal(false), V.table())
	:describe_as("false or a table of settings for the projection")

---A validator that checks that a value is an `IconCompositionGroup` with no unknown fields.
---@type ShapeValidator<IconCompositionGroup>
_common.icon_composition_group = V.shape({
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
---@type ShapeValidator<IconCompositionProjection<unknown>>
_common.icon_composition_projection = V.shape({
	name = _common.non_empty_string,
	includes_annotations = V.boolean(),
	lower = V.func(),
})
	:strict()
	:describe_as("an IconCompositionProjection")

-- Sprite sheets

---A validator that checks that a value is an `Animation` that names its artwork, through `filename`,
---`stripes`, or `layers`. A `filename` must be a mod-relative file path. The check is applied to
---each layer of a layered animation. Other fields are not validated.
---@type ShapeValidator<Animation>
local animation_spritesheet

animation_spritesheet = V.shape({
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

---A validator that checks that a value is a `WorkingVisualisation` with an `animation` field that
---is a sprite sheet. Direction-specific animations are not accepted.
_common.working_visualisation = V.shape({
	animation = _common.animation_spritesheet,
}):describe_as("a WorkingVisualisation carrying an animation")

-- Prototypes

---Validators that check values against the prototypes in `data.raw`. They may only be used during
---the prototype stages; using one elsewhere raises an error.
---@class Common.Prototypes
_common.prototypes = {}

---Gets `data.raw`. Raises an error if it is unavailable.
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

---A prototype type name that Factorio has registered, such as `"item"`.
_common.prototypes.is_registered_type = _common.prototype_type_name
	:satisfies(function(value)
		return require_data_raw()[value] ~= nil
	end, "a registered prototype type name")
	:describe_as("a registered prototype type name")

---Creates a validator accepting the name of a prototype that exists in `data.raw`.
---@param type_name string The prototype type to look the name up in.
---@return Validator<any>
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

---A validator that checks that a value is a prototype with a `type` field that defines an icon
---through either its `icon` or its `icons` field.
---@type ShapeValidator<PrototypeWithIcons>
_common.prototypes.prototype_with_icons = V.shape({ type = _common.prototype_type_name })
	:where(function(value)
		-- `icons` is checked first, as the engine uses it when both are set. An empty array does not
		-- count as present.
		return (value.icons ~= nil and value.icons[1] ~= nil) or value.icon ~= nil
	end, "must define an icon through either the 'icon' or the 'icons' field")
	:describe_as("a prototype defining an icon")

return _common
