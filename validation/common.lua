---@using data
---@using Reskins.SpriteUtils

---@namespace Reskins.SpriteUtils.Validation

local V = require("validation")

---A catalog of ready-made validators for the values this library works with.
---
---These are ordinary validators built from `validation`, defined once and shared.
---Because builder methods never mutate, an entry can be narrowed for a specific
---use without disturbing the shared original:
---
---```lua
---local SmallIconSize = Common.sprite_size:max(64) -- Common.sprite_size is unchanged
---```
---
---Everything here is stage-agnostic except `Common.prototypes`, which reads
---`data.raw`.
---
---### Examples
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
---@param ... table<string, Validator<any>> # The groups to merge.
---@return table<string, Validator<any>>
---@nodiscard
local function fields(...)
	local merged = {}

	-- Counted so that a nil group cannot silently drop every group after it.
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
---The named form is strict, so `{ r = 1, gg = 0.5 }` is reported rather than
---silently read as pure red. That strictness is also what separates the two
---forms: an array's numeric keys are unrecognized by the named branch.
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

---A [Vector](https://lua-api.factorio.com/latest/types/Vector.html), as either a
---two-element array or a table of `x` and `y`.
---@type Validator<Vector>
_common.vector = V.any_of(
	V.tuple(V.number():finite(), V.number():finite()):describe_as("a two-element array of numbers"),
	V.shape({ x = V.number():finite(), y = V.number():finite() }):strict():describe_as("a table of x and y components")
):describe_as("a Vector")

---The name of the type-specific icon defaults to generate.
---
---Deliberately not an enumeration: unrecognized names resolve to the default
---icon size rather than being rejected, so constraining the set here would
---reject values the library itself accepts.
_common.icon_defaults_type = V.string():not_empty():describe_as("an icon defaults type name")

---A single [IconData](https://lua-api.factorio.com/latest/types/IconData.html) object.
---
---Left open to unrecognized fields, since prototypes carry fields this library
---does not model. Call `:strict()` on a copy where a typo would matter.
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
		-- Passing an array where one object was wanted is the easy mistake to
		-- make, and the field check alone reports it as a missing `icon`, which
		-- does not point at what went wrong.
		---@diagnostic disable-next-line: undefined-field
		return value[1] == nil
	end, "must be a single IconData object, not an array of them")
	:describe_as("an IconData object")

---An icon expressed as an array of `IconData` objects.
_common.icon_data = V.array(_common.icon_datum):not_empty():describe_as("an array of IconData objects")

---The transformations applied to a sourced icon.
---@type ShapeValidator<IconTransform>
_common.icon_transform = V.shape({
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	floating = V.boolean():optional(),
	draw_background = V.boolean():optional(),
})
	:strict()
	:describe_as("an IconTransform")

---The transformation fields every icon source shares.
local transformable = {
	scale = _common.positive_number:optional(),
	shift = _common.vector:optional(),
	tint = _common.color:optional(),
	transform = _common.icon_transform:optional(),
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

---An icon held for deferred assignment to a named prototype.
---@type ShapeValidator<DeferrableIconData>
_common.deferrable_icon_data = V.shape({
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	icon_data = _common.icon_data,
	pictures = V.table():optional(),
}):describe_as("a DeferrableIconData")

---A single-object icon held for deferred assignment to a named prototype.
---@type ShapeValidator<DeferrableIconDatum>
_common.deferrable_icon_datum = V.shape({
	name = _common.prototype_name,
	type_name = _common.prototype_type_name,
	icon_datum = _common.icon_datum,
}):describe_as("a DeferrableIconDatum")

-- Prototypes

---Validators that consult the prototypes defined so far.
---
---These read `data.raw`, because that is what they check. There is no runtime
---equivalent — `prototypes` is keyed by base class rather than concrete type
---name — so rather than pass quietly outside the prototype stages, they raise.
---@class Common.Prototypes
_common.prototypes = {}

---Gets `data.raw`, or explains why it is unavailable.
---@return table<string, table<string, table>>
---@nodiscard
local function require_data_raw()
	if not data or not data.raw then
		error(
			"reskins-sprite-utils: the validators in validation.common.prototypes read data.raw, so they only work "
				.. "during the prototype stages. Using one elsewhere is a mistake rather than a pass.",
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
---
---### Examples
---```lua
---local ExistingItem = Common.prototypes.existing_prototype("item")
---ExistingItem:assert(name, "name")
---```
---
---### Parameters
---@param type_name string # The prototype type to look the name up in.
---
---### Returns
---@return Validator<any>
---@nodiscard
function _common.prototypes.existing_prototype(type_name)
	return _common.prototype_name
		:satisfies(function(value)
			local prototypes = require_data_raw()[type_name]

			return prototypes ~= nil and prototypes[value] ~= nil
		end, string.format("the name of an existing '%s' prototype", type_name))
		:describe_as(string.format("the name of an existing '%s' prototype", type_name))
end

---A prototype defining an icon, through either its `icon` or its `icons` field.
---@type ShapeValidator<PrototypeWithIcons>
_common.prototypes.prototype_with_icons = V.shape({})
	:where(function(value)
		-- `icons` first, because that is the one the engine takes when both are
		-- set. An empty array is truthy but defines nothing, so it does not
		-- count as the field being present.
		return (value.icons ~= nil and value.icons[1] ~= nil) or value.icon ~= nil
	end, "must define an icon through either the 'icon' or the 'icons' field")
	:describe_as("a prototype defining an icon")

return _common
