---@using data

---@namespace Reskins.SpriteUtils

local V = require("validation")
local Common = require("validation.common")
local _defines = require("defines")
local _icons = require("icons")
local _sprites = require("sprites")
local _utils = require("utils")

---The position of each stratum in the stack, lowest first.
---@type table<IconCompositionStratum, integer>
local STRATUM_INDEX = {}
for index, stratum in pairs(_defines.icon_composition_strata) do
	---@diagnostic disable-next-line: inject-field
	STRATUM_INDEX[stratum] = index
end

---The strata that hold artwork.
---@type table<IconCompositionStratum, boolean>
local ARTWORK_STRATA = { backdrop = true, canvas = true, overlay = true }

---Represents content added to a composition, with the group it was added to and its placement. A
---contribution is not modified after it is created, and may be shared by multiple compositions.
---@class IconCompositionContribution
---The sequence number assigned when the content was added. Contributions in the same group are
---drawn in sequence order.
---@field sequence integer
---The group definition stored by the composition when the content was added.
---@field group IconCompositionGroup
---The layers of the content, converted to the icon defaults type of the composition.
---@field content IconData[]
---The placement of the layers. `nil` for annotation content.
---@field placement? Transform

---Represents an operation recorded on a composition that is applied when the composition is built.
---@class IconCompositionOperation
---@field kind "transform"|"set_tint"|"blend_tint"|"float"|"remove_floating"|"outline"|"remove_outline"
---@field transform? Transform
---@field tint? Color
---@field weight? float
---@field blender? IconTintBlender

---
---An icon assembled from named groups of layers.
---
---Methods that change a composition return a new composition; the original is not modified.
---Content is read when the composition is built, and is not copied when added.
---
---- Content is drawn by stratum, `backdrop` beneath `canvas` beneath `overlay` beneath `annotation`.
---  Within a stratum, groups are drawn by `order`, then by name; within a group, in the order the
---  content was added.
---- `backdrop`, `canvas`, and `overlay` content is artwork, and is placed and transformed together.
---  `annotation` content is positioned relative to the finished icon, is not transformed or
---  floated, and is omitted when the composition is embedded in another.
---- Operations are applied when the composition is built, in the order they were recorded, to all
---  content, including content added after the operation was recorded.
---
---#### Examples
---```lua
---local IconComposition = require("__reskins-sprite-utils__.icon-composition")
---local _defines = require("__reskins-sprite-utils__.defines")
---
---local ARTWORK = { name = "artwork", stratum = "canvas" }
---local SYMBOL = { name = "symbol", stratum = "overlay", unique = true }
---
----- Create the base composition once.
---local machine = IconComposition
---    :from_named_prototype("assembling-machine-1", "assembling-machine", ARTWORK)
---    :outline()
---
----- Extend the base composition for each member; the base composition is not modified.
---for name, symbol in pairs(symbols_by_name) do
---    local icon_data = machine
---        :add(SYMBOL, symbol, _defines.icon_transforms.corners.northeast)
---        :build()
---end
---
----- Define a subclass with additional methods.
---local BADGE = { name = "badge", stratum = "annotation", tintable = false, unique = true }
---
------@class BadgedIconComposition : IconComposition
---local BadgedIconComposition = {}
---BadgedIconComposition.__index = BadgedIconComposition
---setmetatable(BadgedIconComposition, IconComposition)
---
------@generic S : BadgedIconComposition
------@param self S
------@return S
---function BadgedIconComposition.add_badge(self, badge)
---    return self:add(BADGE, badge)
---end
---
---local icon_data = BadgedIconComposition:from_icons(icon_data, ARTWORK):add_badge(badge):build()
---```
---@class IconComposition
---The name of the type-specific icon defaults used by the composition. Read-only.
---@field defaults_type? IconDefaultsType
---@field package groups table<string, IconCompositionGroup>
---@field package contributions IconCompositionContribution[]
---@field package operations IconCompositionOperation[]
---@field package next_sequence integer
local IconComposition = {}
IconComposition.__index = IconComposition

---Indicates whether the given `value` is an `IconComposition`.
---@param value any The value to check.
---@return boolean # `true` if `value` is an `IconComposition`; otherwise, `false`.
---@nodiscard
local function is_icon_composition(value)
	local class = getmetatable(value)
	while class ~= nil do
		if class == IconComposition then
			return true
		end

		local meta = getmetatable(class)
		class = meta and meta.__index or nil
	end

	return false
end

---A validator that checks that a value is an `IconComposition`.
local icon_composition = V.custom(is_icon_composition, "an IconComposition"):describe_as("an IconComposition")

---A validator that checks that content being added to a composition is one of the supported
---shapes: an `IconData` object, an array of them, an `IconSource`, a prototype defining an icon,
---or an `IconComposition`.
local composition_content = V.any_of(
	Common.icon_datum,
	Common.icon_data,
	Common.icon_source,
	Common.prototypes.prototype_with_icons,
	icon_composition
):describe_as(
	"an IconData object, an array of IconData objects, an IconSource, a prototype defining an icon, or an IconComposition"
)

---A function that returns the group a layer of an icon belongs to.
---@alias IconLayerClassifier fun(icon_datum: IconData, index: integer): IconCompositionGroup

---A validator that checks that a value is a classifier function.
local classifier_function = V.func():describe_as("a classifier function")

---A validator that checks that a value is an `IconCompositionBuildOptions` object with no unknown fields.
local build_options = V.shape({
	to = Common.icon_defaults_type:optional(),
})
	:strict()
	:describe_as("an IconCompositionBuildOptions")

---A validator that checks that a value is a blending function.
local blender_function = V.func():describe_as("a blending function")

---Indicates whether the given tables `a` and `b` have the same keys with equal values.
---@param a table The first table.
---@param b table The second table.
---@return boolean # `true` if the tables are equal; otherwise, `false`.
---@nodiscard
local function are_tables_shallowly_equal(a, b)
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false
		end
	end

	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

---Indicates whether two `projections` maps of group definitions are equal. An absent map is
---treated as an empty map.
---@param a? table<string, table|false> The first map.
---@param b? table<string, table|false> The second map.
---@return boolean # `true` if the maps are equal; otherwise, `false`.
---@nodiscard
local function are_projection_entries_equal(a, b)
	a, b = a or {}, b or {}

	for name, entry in pairs(a) do
		local other = b[name]

		if type(entry) ~= "table" or type(other) ~= "table" then
			if entry ~= other then
				return false
			end
		elseif not are_tables_shallowly_equal(entry, other) then
			return false
		end
	end

	for name in pairs(b) do
		if a[name] == nil then
			return false
		end
	end

	return true
end

---Indicates whether two group definitions are equal. An absent `order` is equal to `0`, an absent
---`tintable` is equal to `true`, and an absent `unique` is equal to `false`.
---@param existing IconCompositionGroup The definition stored by the composition.
---@param given IconCompositionGroup The definition to compare with it.
---@return boolean # `true` if the definitions are equal; otherwise, `false`.
---@nodiscard
local function are_group_definitions_equal(existing, given)
	return existing.stratum == given.stratum
		and (existing.order or 0) == (given.order or 0)
		and (existing.tintable ~= false) == (given.tintable ~= false)
		and (existing.unique == true) == (given.unique == true)
		and are_projection_entries_equal(existing.projections, given.projections)
end

---Indicates whether contribution `a` is drawn beneath contribution `b`, comparing by stratum, then
---group order, then group name, then sequence number.
---@param a IconCompositionContribution The first contribution.
---@param b IconCompositionContribution The second contribution.
---@return boolean # `true` if `a` is drawn beneath `b`; otherwise, `false`.
---@nodiscard
local function is_contribution_drawn_beneath(a, b)
	local a_stratum, b_stratum = STRATUM_INDEX[a.group.stratum], STRATUM_INDEX[b.group.stratum]
	if a_stratum ~= b_stratum then
		return a_stratum < b_stratum
	end

	local a_order, b_order = a.group.order or 0, b.group.order or 0
	if a_order ~= b_order then
		return a_order < b_order
	end

	if a.group.name ~= b.group.name then
		return a.group.name < b.group.name
	end

	return a.sequence < b.sequence
end

---Indicates whether the content of the given `group` is included in the given `projection`. A
---`false` entry for the projection in the `projections` of the group excludes it. Annotation
---content is excluded when the composition is being embedded, and otherwise is included only if
---the projection includes annotations or the group has an entry for the projection.
---@param group IconCompositionGroup The group.
---@param projection IconCompositionProjection<any> The projection.
---@param is_embedding boolean Whether the composition is being embedded in another composition.
---@return boolean # `true` if the content of the group is included; otherwise, `false`.
---@nodiscard
local function is_group_in_projection(group, projection, is_embedding)
	local entry = group.projections and group.projections[projection.name]
	if entry == false then
		return false
	end

	if group.stratum == "annotation" then
		if is_embedding then
			return false
		end

		return projection.includes_annotations or entry ~= nil
	end

	return true
end

---Gets the contribution that receives the outline: the first contribution in the `canvas` or
---`overlay` strata, or if there is none, the first contribution in the `backdrop` stratum.
---@param projected_contributions IconCompositionProjectedContribution[] The projected contributions, in drawing order.
---@return IconCompositionProjectedContribution? # The contribution to outline, or `nil` if there is no artwork.
---@nodiscard
local function get_contribution_carrying_outline(projected_contributions)
	local backdrop

	for _, projected in pairs(projected_contributions) do
		local stratum = projected.group.stratum
		if stratum == "canvas" or stratum == "overlay" then
			return projected
		end

		if stratum == "backdrop" and not backdrop then
			backdrop = projected
		end
	end

	return backdrop
end

---Applies the given `operation` to the layers of the given projected contribution, subject to the
---stratum and `tintable` setting of its group.
---@param projected IconCompositionProjectedContribution The projected contribution.
---@param operation IconCompositionOperation The operation to apply.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition.
---@return SafeIconData[] # The layers with the operation applied.
---@nodiscard
local function apply_operation_to_contribution(projected, operation, defaults_type)
	local layers = projected.layers
	local is_artwork = ARTWORK_STRATA[projected.group.stratum] == true
	local is_tintable = projected.group.tintable ~= false
	local kind = operation.kind

	if kind == "transform" then
		local transform = operation.transform --[[@as Transform]]

		return is_artwork and _icons.transform_icons(layers, transform, defaults_type) or layers
	elseif kind == "set_tint" then
		local tint = operation.tint --[[@as Color]]

		return is_tintable and _icons.set_icons_tint(layers, tint) or layers
	elseif kind == "blend_tint" then
		local tint = operation.tint --[[@as Color]]

		return is_tintable and _icons.blend_icons_tint(layers, tint, operation.weight, operation.blender) or layers
	elseif kind == "float" then
		return is_artwork and _icons.float_icons(layers) or layers
	elseif kind == "remove_floating" then
		return is_artwork and _icons.remove_floating_from_icons(layers) or layers
	elseif kind == "remove_outline" then
		return _icons.remove_outline_from_icons(layers)
	end

	return layers
end

---Gets the contributions of the given composition that are included in the given `projection`, in
---drawing order, with missing icon fields set to default values, placements applied, recorded
---operations applied, and scale and shift converted to the icon defaults type `to`.
---@param self IconComposition The composition.
---@param projection IconCompositionProjection<any> The projection.
---@param to? IconDefaultsType The icon defaults type to convert the layers to. If `nil`, the layers are not converted.
---@param is_embedding boolean Whether the composition is being embedded in another composition.
---@return IconCompositionProjectedContribution[] # The projected contributions. Empty if no contribution is included.
---@nodiscard
local function get_projected_contributions(self, projection, to, is_embedding)
	local sorted = {}
	for index = 1, #self.contributions do
		sorted[index] = self.contributions[index]
	end
	table.sort(sorted, is_contribution_drawn_beneath)

	---@type IconCompositionProjectedContribution[]
	local projected_contributions = {}
	for _, contribution in pairs(sorted) do
		local group = contribution.group

		if is_group_in_projection(group, projection, is_embedding) then
			local layers = _icons.add_missing_icons_defaults(contribution.content, self.defaults_type)
			if contribution.placement then
				layers = _icons.transform_icons(layers, contribution.placement, self.defaults_type)
			end

			local entry = group.projections and group.projections[projection.name] or nil
			projected_contributions[#projected_contributions + 1] = { group = group, layers = layers, entry = entry or nil }
		end
	end

	-- Operations are applied in the order recorded. The outline is applied across all contributions
	-- at its turn, so a `remove_outline` before or after it affects the same layers.
	for _, operation in pairs(self.operations) do
		if operation.kind == "outline" then
			local target = get_contribution_carrying_outline(projected_contributions)
			if target then
				target.layers = _icons.outline_icons(target.layers)
			end
		else
			for _, projected in pairs(projected_contributions) do
				projected.layers = apply_operation_to_contribution(projected, operation, self.defaults_type)
			end
		end
	end

	if to and _icons.get_expected_icon_size(to) ~= _icons.get_expected_icon_size(self.defaults_type) then
		for _, projected in pairs(projected_contributions) do
			projected.layers = _icons.convert_icons_defaults_type(projected.layers, self.defaults_type, to)
		end
	end

	return projected_contributions
end

---@type IconCompositionProjection<SafeIconData[]>
local icon_projection = {
	name = "icon",
	includes_annotations = true,
	lower = function(contributions)
		local icon_data = {}
		for _, contribution in pairs(contributions) do
			for _, layer in pairs(contribution.layers) do
				icon_data[#icon_data + 1] = layer
			end
		end

		return icon_data
	end,
}

---Gets the artwork layers of the given composition, converted to the given `defaults_type`, for
---embedding in another composition. Annotation content is not included.
---@param inner IconComposition The composition to embed.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition to embed in.
---@return IconData[] # The layers. Empty if the composition has no artwork.
---@nodiscard
local function get_artwork_layers_from_composition(inner, defaults_type)
	-- A `nil` defaults type disables conversion. Embedding always converts, so `nil` becomes the
	-- default.
	defaults_type = defaults_type or "default"

	return icon_projection.lower(get_projected_contributions(inner, icon_projection, defaults_type, true), {
		defaults_type = defaults_type,
		composition = inner,
	})
end

---Gets the layers of the icon named by the given `source`, converted to the given `defaults_type`.
---The `scale`, `shift`, or `transform` of the source is applied to the layers, the `tint` is set on
---each layer except layers whose tint has an alpha of zero, `floating` is set on each layer, and
---`draw_background` is set on the first layer.
---@param source IconSource The `IconSource` to resolve.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition.
---@return SafeIconData[] # The layers, converted to `defaults_type`.
---@nodiscard
local function get_layers_from_source(source, defaults_type)
	---@type IconData[], IconDefaultsType?
	local layers, source_defaults_type

	if source.icon_datum then
		---@cast source IconDatumSource
		layers, source_defaults_type = { source.icon_datum }, source.defaults_type or defaults_type
	elseif source.icon_data then
		---@cast source IconDataSource
		layers, source_defaults_type = source.icon_data, source.defaults_type or defaults_type
	else
		---@cast source PrototypeIconSource
		layers, source_defaults_type = _icons.get_icon_from_named_prototype(source.name, source.type_name), source.type_name
	end

	local placement = source.transform or { scale = source.scale, shift = source.shift }
	local placed = _icons.transform_icons(layers, placement, source_defaults_type)

	if source.tint then
		placed = _icons.set_icons_tint(placed, source.tint)
	end

	if source.floating then
		placed = _icons.float_icons(placed)
	end

	-- The layers are copies; the caller's tables are not modified.
	local first = placed[1]
	if first then
		first.draw_background = true
	end

	if _icons.get_expected_icon_size(source_defaults_type) ~= _icons.get_expected_icon_size(defaults_type) then
		return _icons.convert_icons_defaults_type(placed, source_defaults_type, defaults_type)
	end

	return placed
end

---Gets the layers of the given `content`, converted to the icon defaults type of the given
---composition.
---@param self IconComposition The composition the content is added to.
---@param content IconCompositionContent The content.
---@return IconData[] # The layers. Empty only if `content` is a composition with no artwork.
---@nodiscard
local function get_layers_from_content(self, content)
	if is_icon_composition(content) then
		---@cast content IconComposition
		return get_artwork_layers_from_composition(content, self.defaults_type)
	end

	---@cast content -IconComposition
	---@diagnostic disable-next-line: undefined-field
	if content.type then
		-- The icon is read in the icon defaults type of the prototype's `type`. `draw_background` is set
		-- on the first layer, as for a sourced icon.
		---@cast content PrototypeWithIcons
		local layers = _icons.get_icon_from_prototype(content)
		local first = layers[1]
		if first then
			first.draw_background = true
		end

		if _icons.get_expected_icon_size(content.type) ~= _icons.get_expected_icon_size(self.defaults_type) then
			return _icons.convert_icons_defaults_type(layers, content.type, self.defaults_type)
		end

		return layers
	end

	---@cast content -PrototypeWithIcons
	if content.icon then
		---@cast content IconData
		return { content }
	end

	if content.icon_datum or content.icon_data or content.name then
		---@cast content IconSource
		return get_layers_from_source(content, self.defaults_type)
	end

	---@cast content IconData[]
	return content
end

---Creates a shallow copy of the given composition. The `groups`, `contributions`, and `operations`
---tables are copied; the definitions, contributions, and operations they hold are shared.
---@generic S : IconComposition
---@param self S The composition to copy.
---@return S # The copy.
---@nodiscard
local function copy_composition_for_step(self)
	local groups = {}
	for name, group in pairs(self.groups) do
		groups[name] = group
	end

	local contributions = {}
	for index = 1, #self.contributions do
		contributions[index] = self.contributions[index]
	end

	local operations = {}
	for index = 1, #self.operations do
		operations[index] = self.operations[index]
	end

	return setmetatable({
		defaults_type = self.defaults_type,
		groups = groups,
		contributions = contributions,
		operations = operations,
		next_sequence = self.next_sequence,
	}, getmetatable(self))
end

---Creates a copy of the given composition with the given `operation` appended to its operations.
---@generic S : IconComposition
---@param self S The composition to copy.
---@param operation IconCompositionOperation The operation to append.
---@return S # The copy.
---@nodiscard
local function copy_composition_with_operation(self, operation)
	local derived = copy_composition_for_step(self)
	derived.operations[#derived.operations + 1] = operation

	return derived
end

---Removes every contribution to the group with the given `name` from the given `composition`. The
---composition is modified in place.
---@param composition IconComposition The composition to modify.
---@param name string The name of the group.
local function remove_contributions_from_group(composition, name)
	local kept = {}
	for _, contribution in pairs(composition.contributions) do
		if contribution.group.name ~= name then
			kept[#kept + 1] = contribution
		end
	end

	composition.contributions = kept
end

---Creates a copy of the given composition with the given `content` added to the given `group`.
---Arguments are not validated.
---@generic S : IconComposition
---@param self S The composition to copy.
---@param group IconCompositionGroup The group definition.
---@param content IconCompositionContent The content to add.
---@param placement? Transform The placement of the content.
---@param replacing boolean Whether existing content in the group is removed.
---@param function_name string The name of the calling method, used in error messages.
---@return S # The copy.
---@nodiscard
local function add_content_to_group(self, group, content, placement, replacing, function_name)
	local adopted = self.groups[group.name]
	if adopted then
		if not are_group_definitions_equal(adopted, group) then
			error(
				string.format(
					"%s(): parameter 'group': '%s' is already defined in this composition with a different definition",
					function_name,
					group.name
				),
				3
			)
		end
	else
		adopted = util.copy(group)
	end

	local layers = get_layers_from_content(self, content)
	if #layers == 0 then
		error(
			string.format(
				"%s(): parameter 'content': the composition has no artwork; annotation content is not embedded",
				function_name
			),
			3
		)
	end

	local derived = copy_composition_for_step(self)
	derived.groups[adopted.name] = adopted

	if replacing or adopted.unique then
		remove_contributions_from_group(derived, adopted.name)
	end

	derived.contributions[#derived.contributions + 1] = {
		sequence = derived.next_sequence,
		group = adopted,
		content = layers,
		placement = placement and util.copy(placement) or nil,
	}
	derived.next_sequence = derived.next_sequence + 1

	return derived
end

---A signature rule that checks that `placement` is `nil` when `group` is an annotation group.
---@type Reskins.SpriteUtils.Validation.SignatureRule[]
local placement_only_for_artwork = {
	{
		parameter = "placement",
		arguments = { "group", "placement" },
		check = function(group, placement)
			if placement ~= nil and group.stratum == "annotation" then
				return false, "must be absent for an annotation group, whose content is not placed"
			end

			return true
		end,
	},
}

local check_add = V.signature("IconComposition:add", {
	{ "group", Common.icon_composition_group },
	{ "content", composition_content },
	{ "placement", Common.transform:optional() },
}, placement_only_for_artwork)

---
---Creates a copy of the composition with the given `content` added to the given `group`.
---
---- The definition of `group` is stored the first time content is added to a group with its name.
---  A later definition with the same name must be equal to the stored definition.
---- If the group is `unique`, existing content in the group is removed; otherwise, the content is
---  added after the existing content.
---- `content` may be an `IconData` object, an array of `IconData` objects, an `IconSource`, a
---  prototype defining an icon, or an `IconComposition`. An `IconSource` or a prototype is resolved
---  to layers when added, and `draw_background` is set on the first layer. An `IconComposition` is
---  built to its artwork layers when added; its annotation content is not included. Layers with a
---  different icon defaults type are converted to the icon defaults type of this composition.
---- `placement` is applied to the layers in addition to any scale and shift they define. A
---  placement is not permitted for an annotation group.
---- `content` is not modified. It is read when the composition is built, and is not copied.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The composition.
---@param group IconCompositionGroup The group to add the content to.
---@param content IconCompositionContent The content to add.
---@param placement? Transform The scale and shift to apply to the content. Permitted for artwork only.
---
---#### Returns
---@return S # A copy of the composition with the content added.
---
---#### Examples
---```lua
---local with_symbol = composition:add(SYMBOL, symbol_icon, _defines.icon_transforms.corners.northeast)
---```
---@throws Thrown when `group` is not a valid `IconCompositionGroup`, or is not equal to the stored definition of the group with the same name.
---@throws Thrown when `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws Thrown when `placement` is not a `Transform`, or is given for an annotation group.
---@see IconComposition.replace
---@see IconComposition.remove
---@nodiscard
function IconComposition.add(self, group, content, placement)
	check_add(group, content, placement)

	return add_content_to_group(self, group, content, placement, false, "IconComposition:add")
end

local check_replace = V.signature("IconComposition:replace", {
	{ "group", Common.icon_composition_group },
	{ "content", composition_content },
	{ "placement", Common.transform:optional() },
}, placement_only_for_artwork)

---
---Creates a copy of the composition with the given `content` replacing the existing content of the
---given `group`.
---
---- Behaves as `add`, except that existing content in the group is removed whether or not the
---  group is `unique`.
---- `content` is not modified.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The composition.
---@param group IconCompositionGroup The group to replace the content of.
---@param content IconCompositionContent The content to replace the existing content with.
---@param placement? Transform The scale and shift to apply to the content. Permitted for artwork only.
---
---#### Returns
---@return S # A copy of the composition with the content replaced.
---@throws Thrown when `group` is not a valid `IconCompositionGroup`, or is not equal to the stored definition of the group with the same name.
---@throws Thrown when `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws Thrown when `placement` is not a `Transform`, or is given for an annotation group.
---@see IconComposition.add
---@nodiscard
function IconComposition.replace(self, group, content, placement)
	check_replace(group, content, placement)

	return add_content_to_group(self, group, content, placement, true, "IconComposition:replace")
end

local check_remove = V.signature("IconComposition:remove", {
	{ "name", Common.non_empty_string },
})

---
---Creates a copy of the composition without the group with the given `name` and its content.
---
---- The stored definition of the group is removed, so a group with the same name and a different
---  definition may be added afterwards.
---- If there is no group with the given `name`, the composition is returned unmodified.
---@generic S : IconComposition
---@param self S The composition.
---@param name string The name of the group to remove.
---@return S # A copy of the composition without the group.
---@throws Thrown when `name` is not a non-empty string.
---@see IconComposition.has_group
---@nodiscard
function IconComposition.remove(self, name)
	check_remove(name)

	if not self.groups[name] then
		return self
	end

	local derived = copy_composition_for_step(self)
	derived.groups[name] = nil
	remove_contributions_from_group(derived, name)

	return derived
end

local check_has_group = V.signature("IconComposition:has_group", {
	{ "name", Common.non_empty_string },
})

---
---Indicates whether the composition holds content in the named group.
---
---#### Parameters
---@param name string The group name.
---
---#### Returns
---@return boolean # `true` if content has been added to the group; otherwise, `false`.
---@throws Thrown when `name` is not a non-empty string.
---@nodiscard
function IconComposition:has_group(name)
	check_has_group(name)

	return self.groups[name] ~= nil
end

local check_transform = V.signature("IconComposition:transform", {
	{ "transform", Common.transform },
})

---
---Creates a copy of the composition that applies the given `transform` to its artwork when built.
---
---- The transform is applied to all artwork content together, after the placement of each content.
---  Annotation content is not transformed.
---@generic S : IconComposition
---@param self S The composition.
---@param transform Transform The scale and shift to apply.
---@return S # A copy of the composition with the transform recorded.
---
---#### Examples
---```lua
----- Shrink the artwork into the lower half of the icon. Annotation content is not moved.
---local shrunk = composition:transform({ scale = 0.5, shift = { 0, 8 } })
---```
---@throws Thrown when `transform` is not a `Transform`.
---@nodiscard
function IconComposition.transform(self, transform)
	check_transform(transform)

	return copy_composition_with_operation(self, { kind = "transform", transform = util.copy(transform) })
end

local check_set_tint = V.signature("IconComposition:set_tint", {
	{ "tint", Common.color },
})

---
---Creates a copy of the composition that sets the given `tint` on its content when built.
---
---- The tint is set on every layer of every group with `tintable` not equal to `false`. A layer
---  whose tint has an alpha of zero is not modified, as the game renders such a layer additively.
---@generic S : IconComposition
---@param self S The composition.
---@param tint Color The tint to set.
---@return S # A copy of the composition with the tint recorded.
---@throws Thrown when `tint` is not a `Color`.
---@see IconComposition.blend_tint
---@see Icons.set_icons_tint
---@nodiscard
function IconComposition.set_tint(self, tint)
	check_set_tint(tint)

	return copy_composition_with_operation(self, { kind = "set_tint", tint = util.copy(tint) })
end

local check_blend_tint = V.signature("IconComposition:blend_tint", {
	{ "tint", Common.color },
	{ "weight", Common.unit_interval:optional() },
	{ "blender", blender_function:optional() },
})

---
---Creates a copy of the composition that blends the given `tint` into the tint of its content when
---built.
---
---- The tint is blended into the tint of every layer of every group with `tintable` not equal to
---  `false`. A layer whose tint has an alpha of zero is not modified, as the game renders such a
---  layer additively. A layer without a tint is blended as if its tint were white.
---- The tints are blended with `colors.blend` at the given `weight`. If `blender` is given, it is
---  used instead, and `weight` is ignored.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The composition.
---@param tint Color The tint to blend into the tint of each layer.
---@param weight? float The weight of `tint` in the blend, from `0` to `1`. Default `0.5`.
---@param blender? IconTintBlender A function to blend the tints with, used in place of `colors.blend`.
---
---#### Returns
---@return S # A copy of the composition with the blend recorded.
---
---#### Examples
---```lua
---local blended = composition:blend_tint({ r = 0.8, g = 0.2, b = 0.2 }, 0.4)
---```
---@throws Thrown when `tint` is not a `Color`.
---@throws Thrown when `weight` is not between 0 and 1.
---@throws Thrown when `blender` is not a function.
---@see IconComposition.set_tint
---@see Icons.blend_icons_tint
---@nodiscard
function IconComposition.blend_tint(self, tint, weight, blender)
	check_blend_tint(tint, weight, blender)

	return copy_composition_with_operation(
		self,
		{ kind = "blend_tint", tint = util.copy(tint), weight = weight, blender = blender }
	)
end

---
---Creates a copy of the composition that sets `floating` on its artwork layers when built.
---@generic S : IconComposition
---@param self S The composition.
---@return S # A copy of the composition with the operation recorded.
---@see IconComposition.remove_floating
---@see Icons.float_icons
---@nodiscard
function IconComposition.float(self)
	return copy_composition_with_operation(self, { kind = "float" })
end

---
---Creates a copy of the composition that clears `floating` on its artwork layers when built.
---@generic S : IconComposition
---@param self S The composition.
---@return S # A copy of the composition with the operation recorded.
---@see IconComposition.float
---@see Icons.remove_floating_from_icons
---@nodiscard
function IconComposition.remove_floating(self)
	return copy_composition_with_operation(self, { kind = "remove_floating" })
end

---
---Creates a copy of the composition that sets `draw_background` on its first artwork layer when
---built.
---
---- `draw_background` is set on the first layer of the first group in the `canvas` or `overlay`
---  strata, or if there is none, of the first group in the `backdrop` stratum. Layers whose file
---  name ends in `empty.png` are skipped. Annotation content is not modified.
---- Only groups included in the projection are considered.
---@generic S : IconComposition
---@param self S The composition.
---@return S # A copy of the composition with the operation recorded.
---@see IconComposition.remove_outline
---@see Icons.outline_icons
---@nodiscard
function IconComposition.outline(self)
	return copy_composition_with_operation(self, { kind = "outline" })
end

---
---Creates a copy of the composition that sets `draw_background` to `false` on every layer when
---built.
---@generic S : IconComposition
---@param self S The composition.
---@return S # A copy of the composition with the operation recorded.
---@see IconComposition.outline
---@see Icons.remove_outline_from_icons
---@nodiscard
function IconComposition.remove_outline(self)
	return copy_composition_with_operation(self, { kind = "remove_outline" })
end

local check_project = V.signature("IconComposition:project", {
	{ "projection", Common.icon_composition_projection },
	{ "options", build_options:optional() },
})

---
---Builds the composition with the given `projection`.
---
---- The content of each included group is processed in drawing order: missing icon fields are set
---  to default values, placements are applied, and the recorded operations are applied. If
---  `options.to` is given, the scale and shift of every layer, including annotation layers, are
---  converted to that icon defaults type.
---- A group is included unless its `projections` entry for the projection is `false`. An
---  annotation group is included in a projection that does not include annotations only if it has
---  an entry for the projection.
---- The `lower` function of the projection receives the projected contributions and returns the
---  output. The layers it receives are copies.
---@generic T
---@param projection IconCompositionProjection<T> The projection to build with.
---@param options? IconCompositionBuildOptions The build options.
---@return T # The output of the projection.
---@throws Thrown when `projection` is not an `IconCompositionProjection`.
---@throws Thrown when `options` is not an `IconCompositionBuildOptions`.
---@throws Thrown when no content is included in the projection.
---@see IconComposition.build
---@see IconComposition.projections
---@nodiscard
function IconComposition:project(projection, options)
	check_project(projection, options)

	local to = options and options.to or nil
	local projected_contributions = get_projected_contributions(self, projection, to, false)

	if #projected_contributions == 0 then
		error(
			string.format(
				"IconComposition:project(): nothing to project: no content takes part in projection '%s'",
				projection.name
			),
			2
		)
	end

	return projection.lower(projected_contributions, { defaults_type = to or self.defaults_type, composition = self })
end

local check_build = V.signature("IconComposition:build", {
	{ "options", build_options:optional() },
})

---
---Builds the icon from the composition.
---
---- Equivalent to `project` with the `icon` projection. The layers of every included group are
---  returned as one array, in drawing order. Missing icon fields are set to default values as
---  appropriate.
---- If `options.to` is given, the scale and shift of every layer, including annotation layers, are
---  converted to that icon defaults type.
---- The returned layers are copies. Building the same composition again returns an equal result.
---@param options? IconCompositionBuildOptions The build options.
---@return SafeIconData[] # An array of `IconData` objects.
---
---#### Examples
---```lua
---local icon_data = composition:build()
---local technology_icon_data = composition:build({ to = "technology" })
---```
---@throws Thrown when `options` is not an `IconCompositionBuildOptions`.
---@throws Thrown when no content is included in the icon.
---@see IconComposition.project
---@nodiscard
function IconComposition:build(options)
	check_build(options)

	return self:project(icon_projection, options)
end

---Creates an empty composition with the given `defaults_type`.
---@generic S : IconComposition
---@param class S The class to create an instance of.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults.
---@return S # An empty composition.
---@nodiscard
local function new_composition(class, defaults_type)
	return setmetatable({
		defaults_type = defaults_type,
		groups = {},
		contributions = {},
		operations = {},
		next_sequence = 1,
	}, class)
end

local check_from_icon = V.signature("IconComposition:from_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition containing the given `icon_datum` in the given `group`.
---
---- `defaults_type` determines the default values of missing icon fields, and the expected icon
---  size that placements and annotation content are measured against.
---- `icon_datum` is not modified. It is read when the composition is built, and is not copied.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The class to create an instance of. May be a subclass.
---@param icon_datum IconData An `IconData` object.
---@param group IconCompositionGroup The group to add the icon to.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return S # A composition containing the icon in the given group.
---@throws Thrown when `icon_datum` is not a valid `IconData` object.
---@throws Thrown when `group` is not a valid `IconCompositionGroup`.
---@throws Thrown when `defaults_type` is not a non-empty string.
---@see IconComposition.from_icons
---@see IconComposition.add
---@nodiscard
function IconComposition.from_icon(self, icon_datum, group, defaults_type)
	check_from_icon(icon_datum, group, defaults_type)

	return new_composition(self, defaults_type):add(group, icon_datum)
end

local check_from_icons = V.signature("IconComposition:from_icons", {
	{ "icon_data", Common.icon_data },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition containing the given `icon_data` in the given `group`.
---
---- `defaults_type` determines the default values of missing icon fields, and the expected icon
---  size that placements and annotation content are measured against.
---- `icon_data` is not modified. It is read when the composition is built, and is not copied.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The class to create an instance of. May be a subclass.
---@param icon_data IconData[] An array of `IconData` objects.
---@param group IconCompositionGroup The group to add the icon to.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return S # A composition containing the icon in the given group.
---@throws Thrown when `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws Thrown when `group` is not a valid `IconCompositionGroup`.
---@throws Thrown when `defaults_type` is not a non-empty string.
---@see IconComposition.from_icon
---@see IconComposition.from_classified_icons
---@see IconComposition.add
---@nodiscard
function IconComposition.from_icons(self, icon_data, group, defaults_type)
	check_from_icons(icon_data, group, defaults_type)

	return new_composition(self, defaults_type):add(group, icon_data)
end

local check_from_source = V.signature("IconComposition:from_source", {
	{ "source", Common.icon_source },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition containing the icon from the given `source` in the given `group`.
---
---- The source is resolved to layers when the composition is created. Layers with a different icon
---  defaults type are converted to `defaults_type`.
---- `source` is not modified.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The class to create an instance of. May be a subclass.
---@param source IconSource The `IconSource` to resolve.
---@param group IconCompositionGroup The group to add the icon to.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return S # A composition containing the icon in the given group.
---
---#### Examples
---```lua
---local composition = IconComposition:from_source({ name = "iron-plate", type_name = "item" }, ARTWORK)
---```
---@throws Thrown when `source` is not a valid `IconSource`, or names a prototype that does not exist.
---@throws Thrown when `group` is not a valid `IconCompositionGroup`.
---@throws Thrown when `defaults_type` is not a non-empty string.
---@see IconComposition.from_named_prototype
---@see IconComposition.add
---@nodiscard
function IconComposition.from_source(self, source, group, defaults_type)
	check_from_source(source, group, defaults_type)

	return new_composition(self, defaults_type):add(group, source)
end

local check_from_prototype = V.signature("IconComposition:from_prototype", {
	{ "prototype", Common.prototypes.prototype_with_icons },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition containing the icon of the given `prototype` in the given `group`.
---
---- The icon is read with `icons.get_icon_from_prototype` when the composition is created, and
---  `draw_background` is set on its first layer. Layers with a different icon defaults type are
---  converted to `defaults_type`.
---- `prototype` is not modified.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The class to create an instance of. May be a subclass.
---@param prototype PrototypeWithIcons The prototype to read the icon from.
---@param group IconCompositionGroup The group to add the icon to.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return S # A composition containing the icon in the given group.
---@throws Thrown when `prototype` does not have a `type` field, or defines neither `icon` nor `icons`.
---@throws Thrown when `group` is not a valid `IconCompositionGroup`.
---@throws Thrown when `defaults_type` is not a non-empty string.
---@see IconComposition.from_named_prototype
---@see Icons.get_icon_from_prototype
---@nodiscard
function IconComposition.from_prototype(self, prototype, group, defaults_type)
	check_from_prototype(prototype, group, defaults_type)

	return new_composition(self, defaults_type):add(group, prototype)
end

local check_from_named_prototype = V.signature("IconComposition:from_named_prototype", {
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototype_type_name },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition containing the icon of the prototype with the given `name` and `type_name`
---in the given `group`.
---
---- Equivalent to `from_source({ name = name, type_name = type_name }, group, defaults_type)`.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The class to create an instance of. May be a subclass.
---@param name string The name of the prototype.
---@param type_name string The type name of the prototype.
---@param group IconCompositionGroup The group to add the icon to.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return S # A composition containing the icon in the given group.
---
---#### Examples
---```lua
---local composition = IconComposition:from_named_prototype("iron-plate", "item", ARTWORK)
---```
---@throws Thrown when `name` or `type_name` is not a non-empty string, or no such prototype exists.
---@throws Thrown when `group` is not a valid `IconCompositionGroup`.
---@throws Thrown when `defaults_type` is not a non-empty string.
---@see IconComposition.from_prototype
---@see IconComposition.from_source
---@nodiscard
function IconComposition.from_named_prototype(self, name, type_name, group, defaults_type)
	check_from_named_prototype(name, type_name, group, defaults_type)

	return new_composition(self, defaults_type):add(group, { name = name, type_name = type_name })
end

local check_from_classified_icons = V.signature("IconComposition:from_classified_icons", {
	{ "icon_data", Common.icon_data },
	{ "classify", classifier_function },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition containing the layers of the given `icon_data`, each in the group returned
---by `classify` for it.
---
---- `classify` is called once per layer, in order. Consecutive layers assigned to the same group
---  are added to the group as one content, in order. A later run of layers assigned to the same
---  group is added after the earlier run.
---- Every definition `classify` returns for one group name must be equal, as for `add`.
---- `icon_data` is not modified. Its layers are read when the composition is built, and are not
---  copied.
---
---#### Parameters
---@generic S : IconComposition
---@param self S The class to create an instance of. May be a subclass.
---@param icon_data IconData[] An array of `IconData` objects.
---@param classify IconLayerClassifier A function that returns the group for each layer.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return S # A composition containing the layers in their groups.
---
---#### Examples
---```lua
---local composition = IconComposition:from_classified_icons(prototype.icons, function(icon_datum)
---    return is_badge(icon_datum) and BADGE or ARTWORK
---end)
---```
---@throws Thrown when `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws Thrown when `classify` is not a function, or returns something other than a valid `IconCompositionGroup`.
---@throws Thrown when `defaults_type` is not a non-empty string.
---@see IconComposition.from_icons
---@see IconComposition.add
---@nodiscard
function IconComposition.from_classified_icons(self, icon_data, classify, defaults_type)
	check_from_classified_icons(icon_data, classify, defaults_type)

	local composition = new_composition(self, defaults_type)

	---@type IconCompositionGroup?
	local run_group
	---@type IconData[]
	local run = {}

	for index = 1, #icon_data do
		local group = classify(icon_data[index], index)
		Common.icon_composition_group:assert(
			group,
			string.format("classify(icon_data[%d])", index),
			"from_classified_icons"
		)

		if run_group and group.name == run_group.name then
			-- The definition of a run is the first one given; later layers in the run must match it.
			if not are_group_definitions_equal(run_group, group) then
				error(
					string.format(
						"from_classified_icons(): parameter 'classify(icon_data[%d])': '%s' is already defined in this "
							.. "composition with a different definition",
						index,
						group.name
					),
					2
				)
			end
		else
			if run_group then
				composition = composition:add(run_group, run)
				run = {}
			end

			run_group = group
		end

		run[#run + 1] = icon_data[index]
	end

	return composition:add(run_group --[[@as IconCompositionGroup]], run)
end

local check_define_group = V.signature("IconComposition.define_group", {
	{ "group", Common.icon_composition_group },
})

---
---Validates the given group definition and returns a copy of it.
---
---- A group definition may be used without calling this function. `add` validates the definition
---  in any case.
---@param group IconCompositionGroup The group definition to validate.
---@return IconCompositionGroup # A copy of `group`.
---
---#### Examples
---```lua
---local BADGE = IconComposition.define_group({
---    name = "badge",
---    stratum = "annotation",
---    tintable = false,
---    unique = true,
---})
---```
---@throws Thrown when `group` is not a valid `IconCompositionGroup`.
---@nodiscard
function IconComposition.define_group(group)
	check_define_group(group)

	return util.copy(group)
end

---
---Indicates whether the given `value` is an `IconComposition`.
---
---#### Parameters
---@param value any The value to check.
---
---#### Returns
---@return boolean # `true` if `value` is an `IconComposition`; otherwise, `false`.
---@nodiscard
function IconComposition.is_icon_composition(value)
	return is_icon_composition(value)
end

local pictures_entry = V.shape({
	rewrite = V.func():optional(),
})
	:strict()
	:describe_as("an IconCompositionPicturesEntry")

local sprite_layers = V.array(V.table()):describe_as("an array of sprite layers")

---@type IconCompositionProjection<Sprite>
local pictures_projection = {
	name = "pictures",
	includes_annotations = false,
	lower = function(contributions)
		local layers, trailing = {}, {}

		for _, contribution in pairs(contributions) do
			local lowered = {}
			for index, layer in pairs(contribution.layers) do
				lowered[index] = _sprites.create_sprite_from_icon(layer)
			end

			local entry = contribution.entry
			local where = string.format("group '%s' projections.pictures", contribution.group.name)
			if entry then
				pictures_entry:assert(entry, where, "IconComposition:project")
			end

			if entry and entry.rewrite then
				local in_place, deferred = entry.rewrite(lowered, contribution)
				sprite_layers:assert(in_place, where .. ".rewrite return 1", "IconComposition:project")
				if deferred ~= nil then
					sprite_layers:assert(deferred, where .. ".rewrite return 2", "IconComposition:project")
				end

				layers = _utils.array_concat(layers, in_place)
				if deferred then
					trailing = _utils.array_concat(trailing, deferred)
				end
			else
				layers = _utils.array_concat(layers, lowered)
			end
		end

		layers = _utils.array_concat(layers, trailing)

		if #layers == 0 then
			error("IconComposition:project(): projection 'pictures' was left with no layers to draw", 2)
		end

		if #layers == 1 then
			return layers[1]
		end

		return { layers = layers }
	end,
}

---
---The projections provided by `IconComposition`.
---
---- `icon` builds an array of `IconData` objects, and is the projection used by `build`. Annotation
---  content is included.
---- `pictures` builds a `Sprite` as `sprites.create_sprite_from_icons` would from the icon, for use
---  as the `pictures` field of an item. Annotation content is not included unless its group has a
---  `pictures` entry. An entry may define a `rewrite` function, which receives the sprite layers of
---  the group and returns the layers to use in place of them, and optionally an array of layers to
---  draw after all groups.
---- A projection is a table with a `name`, an `includes_annotations` flag, and a `lower` function.
---  A custom projection may be passed to `project`.
---
---#### Examples
---```lua
---local GLOW = {
---    name = "glow",
---    stratum = "overlay",
---    projections = {
---        icon = false,
---        pictures = {
---            rewrite = function(layers)
---                for _, layer in pairs(layers) do
---                    layer.draw_as_glow = true
---                end
---                return layers
---            end,
---        },
---    },
---}
---
---local pictures = composition:add(GLOW, glow_layer):project(IconComposition.projections.pictures)
---```
---@class IconCompositionProjections
---The projection that builds an array of `IconData` objects.
---@field icon IconCompositionProjection<SafeIconData[]>
---The projection that builds a `Sprite`.
---@field pictures IconCompositionProjection<Sprite>
IconComposition.projections = {
	icon = icon_projection,
	pictures = pictures_projection,
}

return IconComposition
