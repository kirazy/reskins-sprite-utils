---@using data

---@namespace Reskins.SpriteUtils

local V = require("validation")
local Common = require("validation.common")
local _colors = require("colors")
local _defines = require("defines")
local _icons = require("icons")
local _sprites = require("sprites")
local _utils = require("utils")

---The number of pixels in one tile.
local TILE_SIZE = 32

---The index of each stratum in `_defines.icon_composition_strata`.
---@type table<IconCompositionStratum, integer>
local STRATUM_INDEX = {}
for index, stratum in pairs(_defines.icon_composition_strata) do
	---@diagnostic disable-next-line: inject-field
	STRATUM_INDEX[stratum] = index
end

---The strata that contain artwork.
---@type table<IconCompositionStratum, boolean>
local ARTWORK_STRATA = { backdrop = true, canvas = true, overlay = true, symbol = true }

---The strata that are outlined as one icon.
---@type table<IconCompositionStratum, boolean>
local OUTLINED_STACK_STRATA = { backdrop = true, canvas = true }

---The transparent 1x1 pixel that `minify` inserts as the backdrop. The pixel is scaled to the expected icon size of the
---icon defaults type.
local MINIFY_BACKDROP_ICON = "__reskins-sprite-utils__/graphics/icons/minified-empty.png"

---The group to which `add_backdrop` adds content.
---@type IconCompositionGroup
local BACKDROP_GROUP = { name = "backdrop", stratum = "backdrop" }

---The group to which `add_canvas` adds content, and to which a constructor given no group adds content.
---@type IconCompositionGroup
local CANVAS_GROUP = { name = "canvas", stratum = "canvas" }

---The group to which `add_overlay` adds content.
---@type IconCompositionGroup
local OVERLAY_GROUP = { name = "overlay", stratum = "overlay", tintable = false }

---The group to which `add_symbol` adds content.
---@type IconCompositionGroup
local SYMBOL_GROUP = { name = "symbol", stratum = "symbol", tintable = false }

---The group to which `add_label` adds content.
---@type IconCompositionGroup
local LABEL_GROUP = { name = "label", stratum = "label", tintable = false }

---The group to which `minify` adds the backdrop when the composition has no backdrop content.
---@type IconCompositionGroup
local MINIFY_BACKDROP_GROUP = { name = "minify-backdrop", stratum = "backdrop", tintable = false }

---The group to which `add_light` adds content. Light content is not included in the icon, and is included in the
---`pictures` projection with `draw_as_light` set.
---@type IconCompositionGroup
local LIGHT_GROUP = {
	name = "light",
	stratum = "canvas",
	order = 1,
	tintable = false,
	projections = { icon = false },
}

---Applies the given `transform` to the given sprite layer, in place.
---@param sprite Sprite The sprite layer.
---@param transform Transform The scale and shift to apply.
---@return Sprite # `sprite`.
local function transform_sprite(sprite, transform)
	local scale = transform.scale or 1
	sprite.scale = (sprite.scale or 1) * scale

	---@type Vector?
	local shift = sprite.shift and util.mul_shift(sprite.shift, scale) or nil
	if transform.shift then
		local offset = util.mul_shift(transform.shift, 1 / TILE_SIZE) --[[@as { [1]: double, [2]: double }]]
		if shift then
			---@cast shift { [1]: double, [2]: double }
			shift = { shift[1] + offset[1], shift[2] + offset[2] }
		else
			shift = offset
		end
	end
	sprite.shift = shift

	return sprite
end

---Represents content added to a composition, with the group to which it was added and its placement. A contribution is
---not modified after it is created, and may be shared by multiple compositions.
---@class IconCompositionContribution
---The sequence number assigned when the content was added. Contributions in the same group are composed in sequence
---order.
---@field sequence integer
---The group definition stored by the composition when the content was added.
---@field group IconCompositionGroup
---The layers of the content, in the icon defaults type of the composition. The field is `nil` when the contribution has
---a sprite.
---@field content? IconData[]
---The sprite layer of the content. The field is `nil` when the contribution has layers.
---@field sprite? Sprite
---The placement of the content. The field is `nil` for label content.
---@field placement? Transform

---Represents an operation recorded on a composition that is applied when the composition is built.
---@class IconCompositionOperation
---The type of operation, which determines the other fields that are set.
---@field type "transform"|"set_tint"|"blend_tint"|"float"|"remove_floating"|"outline"|"remove_outline"|"minify"
---The scale and shift that a `transform` operation applies.
---@field transform? Transform
---The tint that a `set_tint` operation sets or that a `blend_tint` operation blends.
---@field tint? Color
---The weight of `tint` in the blend of a `blend_tint` operation.
---@field weight? float
---The function with which a `blend_tint` operation blends the tints.
---@field blender? IconTintBlender
---The scalar by which a `minify` operation minifies the canvas.
---@field scalar? double

---Represents an icon assembled from named groups of layers.
---
---Methods that change a composition return a new composition. The original is not modified. Content is copied when it
---is added, and the composition is built from the copy.
---
---- Content is drawn by stratum, `backdrop` beneath `canvas` beneath `overlay` beneath `symbol` beneath `label`. Within
---  a stratum, groups are drawn by `order`, then by name. Within a group, content is drawn in the order it was added.
---- `backdrop`, `canvas`, `overlay`, and `symbol` content is artwork, and is placed and transformed together. `label`
---  content is positioned relative to the finished icon, is not placed, transformed, or floated, and is not included
---  when the composition is embedded in another.
---- Operations are applied when the composition is built, in the order they were recorded, to all content, including
---  content added after the operation was recorded.
---
--- |                                 | `backdrop`                  | `canvas`                    | `overlay`                                   | `symbol` | `label`                      |
--- |---------------------------------|-----------------------------|-----------------------------|---------------------------------------------|----------|------------------------------|
--- | Placement given to `add`        | yes                         | yes                         | yes                                         | yes      | no                           |
--- | `transform`, `float`            | yes                         | yes                         | yes                                         | yes      | no                           |
--- | `minify`                        | reference                   | minified                    | no                                          | no       | no                           |
--- | `outline`                       | first non-transparent layer | first non-transparent layer | first non-transparent layer of each overlay | no       | no                           |
--- | Embedded in another composition | yes                         | yes                         | yes                                         | yes      | no                           |
--- | In `pictures`                   | yes                         | yes                         | yes                                         | yes      | only with a `pictures` entry |
---
---#### Examples
---```lua
---local IconComposition = require("__reskins-sprite-utils__.icon-composition")
---```
---@class IconComposition
---The read-only name of the type-specific icon defaults used by the composition. The icon defaults type determines the
---default values of missing icon fields, and the expected icon size against which placements and label content are
---measured.
---@field defaults_type? IconDefaultsType
---The stored definition of each group, under the name of the group.
---@field package groups table<string, IconCompositionGroup>
---The content added to the composition, in the order it was added.
---@field package contributions IconCompositionContribution[]
---The operations recorded on the composition, in the order they were recorded.
---@field package operations IconCompositionOperation[]
---The sequence number assigned to the next contribution.
---@field package next_sequence integer
local IconComposition = {}
IconComposition.__index = IconComposition

---Indicates whether the given `value` is an `IconComposition`.
---@param value unknown The value to check.
---@return TypeGuard<IconComposition> # `true` if `value` is an `IconComposition`; otherwise, `false`.
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

---A validator that checks that content being added to a composition is one of the supported forms: an `IconData`
---object, an array of them, an `IconSource`, a prototype defining an icon, or an `IconComposition`.
local composition_content = V.any_of(
	Common.icon_datum,
	Common.icon_data,
	Common.icon_source,
	Common.prototype_with_icons,
	Common.icon_composition
):describe_as(
	"an IconData object, an array of IconData objects, an IconSource, a prototype defining an icon, or an IconComposition"
)

---A validator that checks that a value is a `Sprite` with a mod-relative `filename`, without validating other fields.
local sprite_layer = V.struct({
	filename = Common.mod_file_path,
}):describe_as("a Sprite")

---Defines a function that returns the group of a layer of an icon.
---@alias IconLayerClassifier fun(icon_datum: IconData, index: integer): IconCompositionGroup

---A validator that checks that a value is a classifier function.
local classifier_function = V.func():describe_as("a classifier function")

---A validator that checks that a value is an `IconCompositionBuildOptions` object with no unknown fields.
local build_options = V.struct({
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

---Indicates whether two `projections` maps of group definitions are equal. An absent map is treated as an empty map.
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

---Indicates whether two group definitions are equal. An absent `order` is equal to 0, an absent `tintable` is equal to
---`true`, and an absent `unique` is equal to `false`.
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

---Indicates whether contribution `a` is drawn beneath contribution `b`, comparing by stratum, then group order, then
---group name, then sequence number.
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

---Indicates whether the content of the given `group` is included in the given `projection`. The content is not included
---when the `projections` of the group has a `false` entry for the projection. Label content is not included when the
---composition is being embedded, and otherwise is included only if the projection includes labels or the group has an
---entry for the projection.
---@param group IconCompositionGroup The group definition.
---@param projection IconCompositionProjection<any> The projection in which the content is included.
---@param is_embedding boolean When `true`, indicates that the composition is being embedded in another composition.
---@return boolean # `true` if the content of the group is included; otherwise, `false`.
---@nodiscard
local function is_group_in_projection(group, projection, is_embedding)
	local entry = group.projections and group.projections[projection.name]
	if entry == false then
		return false
	end

	if group.stratum == "label" then
		if is_embedding then
			return false
		end

		return projection.includes_labels or entry ~= nil
	end

	return true
end

---Sets `draw_background` on the first non-transparent layer of the stack formed by the `backdrop` and `canvas`
---contributions, and on the first such layer of each `overlay` contribution, in place. `symbol` and `label`
---contributions are not modified.
---@param projected_contributions IconCompositionProjectedContribution[] The projected contributions, in draw order.
local function apply_outline(projected_contributions)
	-- Join the stack layers, outline them, and put each layer back in its contribution. A sprite
	-- contribution has no layers and is not outlined.
	local stack = {}
	for _, projected in pairs(projected_contributions) do
		if projected.layers and OUTLINED_STACK_STRATA[projected.group.stratum] then
			stack = _utils.array_concat(stack, projected.layers)
		end
	end

	if #stack > 0 then
		local outlined = _icons.outline_icons(stack)
		local cursor = 1
		for _, projected in pairs(projected_contributions) do
			if projected.layers and OUTLINED_STACK_STRATA[projected.group.stratum] then
				local layers = {}
				for index = 1, #projected.layers do
					layers[index] = outlined[cursor]
					cursor = cursor + 1
				end

				projected.layers = layers
			end
		end
	end

	for _, projected in pairs(projected_contributions) do
		if projected.layers and projected.group.stratum == "overlay" then
			projected.layers = _icons.outline_icons(projected.layers)
		end
	end
end

---Minifies the `canvas` contributions by `scalar` relative to the backdrop, and outlines the contributions. When no
---contribution is in the `backdrop` stratum, a transparent layer scaled to the expected icon size of the type is
---inserted as the backdrop.
---
---Contributions are modified in place.
---@param projected_contributions IconCompositionProjectedContribution[] The projected contributions, in draw order.
---@param scalar double The scalar by which the canvas is minified.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition.
local function apply_minify(projected_contributions, scalar, defaults_type)
	local has_backdrop = false
	for _, projected in pairs(projected_contributions) do
		if projected.group.stratum == "backdrop" then
			has_backdrop = true
			break
		end
	end

	if not has_backdrop then
		local backdrop = {
			icon = MINIFY_BACKDROP_ICON,
			icon_size = 1,
			scale = _icons.get_expected_icon_size(defaults_type) / 2,
		}

		table.insert(projected_contributions, 1, {
			group = MINIFY_BACKDROP_GROUP,
			layers = _icons.add_missing_icons_defaults({ backdrop }, defaults_type),
		})
	end

	for _, projected in pairs(projected_contributions) do
		if projected.group.stratum == "canvas" then
			if projected.sprite then
				transform_sprite(projected.sprite, { scale = scalar })
			elseif projected.layers then
				projected.layers = _icons.scale_icon(projected.layers, scalar, defaults_type)
			end
		end
	end

	apply_outline(projected_contributions)
end

---Applies the given `operation` to the sprite layer of the given projected contribution, subject to the stratum and
---`tintable` setting of its group.
---
---A `float`, `remove_floating`, `outline`, or `remove_outline` operation does not modify the sprite.
---@param projected IconCompositionProjectedContribution The projected sprite contribution.
---@param operation IconCompositionOperation The operation to apply.
local function apply_operation_to_sprite(projected, operation)
	local sprite = projected.sprite --[[@as Sprite]]
	local is_artwork = ARTWORK_STRATA[projected.group.stratum] == true
	local is_tintable = projected.group.tintable ~= false

	if operation.type == "transform" and is_artwork then
		transform_sprite(sprite, operation.transform --[[@as Transform]])
	elseif operation.type == "set_tint" and is_tintable then
		sprite.tint = util.copy(operation.tint)
	elseif operation.type == "blend_tint" and is_tintable then
		local existing = _colors.normalize(sprite.tint or { 1, 1, 1, 1 })
		if existing.a > 0 then
			local incoming = _colors.normalize(operation.tint --[[@as Color]])
			if operation.blender then
				sprite.tint = _colors.normalize(operation.blender(existing, incoming)) --[[@as Color]]
			else
				sprite.tint = _colors.blend(existing --[[@as Color]], incoming --[[@as Color]], operation.weight or 0.5)--[[@as Color]]
			end
		end
	end
end

---Applies the given `operation` to the layers of the given projected contribution, subject to the stratum and
---`tintable` setting of its group.
---@param projected IconCompositionProjectedContribution The projected contribution.
---@param operation IconCompositionOperation The operation to apply.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition.
---@return SafeIconData[] # The layers with the operation applied.
---@nodiscard
local function apply_operation_to_contribution(projected, operation, defaults_type)
	local layers = projected.layers --[[@as SafeIconData[] ]]
	local is_artwork = ARTWORK_STRATA[projected.group.stratum] == true
	local is_tintable = projected.group.tintable ~= false

	if operation.type == "transform" then
		local transform = operation.transform --[[@as Transform]]

		return is_artwork and _icons.transform_icons(layers, transform, defaults_type) or layers
	elseif operation.type == "set_tint" then
		local tint = operation.tint --[[@as Color]]

		return is_tintable and _icons.set_icons_tint(layers, tint) or layers
	elseif operation.type == "blend_tint" then
		local tint = operation.tint --[[@as Color]]

		return is_tintable and _icons.blend_icons_tint(layers, tint, operation.weight, operation.blender) or layers
	elseif operation.type == "float" then
		return is_artwork and _icons.float_icons(layers) or layers
	elseif operation.type == "remove_floating" then
		return is_artwork and _icons.remove_floating_from_icons(layers) or layers
	elseif operation.type == "remove_outline" then
		return _icons.remove_outline_from_icons(layers)
	end

	return layers
end

---Gets the contributions of the given composition that are included in the given `projection`, in draw order, with
---missing icon fields set to default values, placements applied, recorded operations applied, and scale and shift
---converted to the icon defaults type `to_defaults_type`.
---@param self IconComposition The composition.
---@param projection IconCompositionProjection<any> The projection in which the contributions are included.
---@param to_defaults_type? IconDefaultsType The icon defaults type to which the layers are converted. If `nil`, the layers are not converted.
---@param is_embedding boolean When `true`, indicates that the composition is being embedded in another composition.
---@return IconCompositionProjectedContribution[] # The projected contributions. Empty if no contribution is included.
---@nodiscard
local function get_projected_contributions(self, projection, to_defaults_type, is_embedding)
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
			local entry = group.projections and group.projections[projection.name] or nil

			if contribution.sprite then
				local sprite = util.copy(contribution.sprite)
				if contribution.placement then
					transform_sprite(sprite, contribution.placement)
				end

				projected_contributions[#projected_contributions + 1] = { group = group, sprite = sprite, entry = entry or nil }
			else
				local layers = _icons.add_missing_icons_defaults(contribution.content, self.defaults_type)
				if contribution.placement then
					layers = _icons.transform_icons(layers, contribution.placement, self.defaults_type)
				end

				projected_contributions[#projected_contributions + 1] = { group = group, layers = layers, entry = entry or nil }
			end
		end
	end

	-- Apply the operations in the order recorded. The outline is applied across all contributions at
	-- its turn, and a `remove_outline` before or after it affects the same layers.
	for _, operation in pairs(self.operations) do
		if operation.type == "outline" then
			apply_outline(projected_contributions)
		elseif operation.type == "minify" then
			apply_minify(projected_contributions, operation.scalar --[[@as double]], self.defaults_type)
		else
			for _, projected in pairs(projected_contributions) do
				if projected.sprite then
					apply_operation_to_sprite(projected, operation)
				else
					projected.layers = apply_operation_to_contribution(projected, operation, self.defaults_type)
				end
			end
		end
	end

	if
		to_defaults_type
		and _icons.get_expected_icon_size(to_defaults_type) ~= _icons.get_expected_icon_size(self.defaults_type)
	then
		local ratio = _icons.get_expected_icon_size(to_defaults_type) / _icons.get_expected_icon_size(self.defaults_type)
		for _, projected in pairs(projected_contributions) do
			if projected.sprite then
				transform_sprite(projected.sprite, { scale = ratio })
			elseif projected.layers then
				projected.layers = _icons.convert_icons_defaults_type(projected.layers, self.defaults_type, to_defaults_type)
			end
		end
	end

	return projected_contributions
end

---The projection that builds the icon, an array of `IconData` objects.
---@type IconCompositionProjection<SafeIconData[]>
local icon_projection = {
	name = "icon",
	includes_labels = true,
	lower = function(contributions)
		local icon_data = {}
		for _, contribution in pairs(contributions) do
			for _, layer in pairs(contribution.layers or {}) do
				icon_data[#icon_data + 1] = layer
			end
		end

		return icon_data
	end,
}

---The projection that builds the pictures, a `SpriteVariations` with a single layered sprite.
---@type IconCompositionProjection<SpriteVariations>
local pictures_projection

---Gets the artwork layers of the given composition, converted to the given `defaults_type`, for embedding in another
---composition, without label content.
---@param inner IconComposition The composition to embed.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition in which the layers are embedded.
---@return IconData[] # The layers. Empty if the composition has no artwork.
---@nodiscard
local function get_artwork_layers_from_composition(inner, defaults_type)
	-- A `nil` defaults type disables conversion. Use the default type.
	defaults_type = defaults_type or "default"

	return icon_projection.lower(get_projected_contributions(inner, icon_projection, defaults_type, true), {
		defaults_type = defaults_type,
		composition = inner,
	})
end

---Gets the layers of the icon named by the given `source`, converted to the given `defaults_type`. The `scale`,
---`shift`, or `transform` of the source is applied to the layers, the `tint` is set on each layer except layers with a
---tint alpha of zero, `floating` is set on each layer, and `draw_background` is set on the first layer.
---@param source IconSource The `IconSource` to resolve.
---@param defaults_type? IconDefaultsType The icon defaults type of the composition.
---@return SafeIconData[]
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

	-- The layers are copies. The tables of the caller are not modified.
	local first = placed[1]
	if first then
		first.draw_background = true
	end

	if _icons.get_expected_icon_size(source_defaults_type) ~= _icons.get_expected_icon_size(defaults_type) then
		return _icons.convert_icons_defaults_type(placed, source_defaults_type, defaults_type)
	end

	return placed
end

---Gets the layers of the given `content`, converted to the icon defaults type of the given composition.
---@param self IconComposition The composition to which the content is added.
---@param content IconCompositionContent The content from which the layers are read.
---@return IconData[] # A copy of the layers. Empty only if `content` is a composition with no artwork.
---@nodiscard
local function get_layers_from_content(self, content)
	if is_icon_composition(content) then
		---@cast content IconComposition
		return get_artwork_layers_from_composition(content, self.defaults_type)
	end

	---@cast content -IconComposition
	---@diagnostic disable-next-line: undefined-field
	if content.type then
		-- The icon is read in the icon defaults type of the `type` of the prototype. Set `draw_background`
		-- on the first layer.
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
		return { util.copy(content) }
	end

	if content.icon_datum or content.icon_data or content.name then
		---@cast content IconSource
		return get_layers_from_source(content, self.defaults_type)
	end

	---@cast content IconData[]
	return util.copy(content)
end

---Creates a shallow copy of the given composition. The `groups`, `contributions`, and `operations` tables are copied.
---The definitions, contributions, and operations they contain are shared.
---@generic S : IconComposition
---@param self S The composition to copy.
---@return S
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

---Appends the given `operation` to the operations of the given composition.
---@generic S : IconComposition
---@param self S The composition to copy.
---@param operation IconCompositionOperation The operation to append.
---@return S # A copy of the composition with the operation appended.
---@nodiscard
local function copy_composition_with_operation(self, operation)
	local derived = copy_composition_for_step(self)
	derived.operations[#derived.operations + 1] = operation

	return derived
end

---Removes every contribution to the group with the given `name` from the given `composition`. The composition is
---modified in place.
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

---Gets the definition of the given `group` stored by the given composition, or a copy of `group` if the composition has
---none. An error is raised when the stored definition differs from `group`.
---@param self IconComposition The composition.
---@param group IconCompositionGroup The group definition.
---@param function_name string The name of the calling method, for error messages.
---@return IconCompositionGroup
---@nodiscard
local function adopt_group(self, group, function_name)
	local adopted = self.groups[group.name]
	if not adopted then
		return util.copy(group)
	end

	if not are_group_definitions_equal(adopted, group) then
		error(
			string.format(
				"%s(): parameter 'group': '%s' is already defined in this composition with a different definition",
				function_name,
				group.name
			),
			4
		)
	end

	return adopted
end

---Adds the given `sprite` to the given `group` of the given composition as a sprite contribution, without validating
---the arguments.
---@generic S : IconComposition
---@param self S The composition to copy.
---@param group IconCompositionGroup The group definition.
---@param sprite Sprite The sprite layer to add.
---@param placement? Transform The placement of the sprite.
---@param function_name string The name of the calling method, for error messages.
---@return S # A copy of the composition with the sprite added.
---@nodiscard
local function add_sprite_to_group(self, group, sprite, placement, function_name)
	local adopted = adopt_group(self, group, function_name)

	local derived = copy_composition_for_step(self)
	derived.groups[adopted.name] = adopted

	if adopted.unique then
		remove_contributions_from_group(derived, adopted.name)
	end

	derived.contributions[#derived.contributions + 1] = {
		sequence = derived.next_sequence,
		group = adopted,
		sprite = util.copy(sprite),
		placement = placement and util.copy(placement) or nil,
	}
	derived.next_sequence = derived.next_sequence + 1

	return derived
end

---Adds the given `content` to the given `group` of the given composition, without validating the arguments.
---@generic S : IconComposition
---@param self S The composition to copy.
---@param group IconCompositionGroup The group definition.
---@param content IconCompositionContent The content to add.
---@param placement? Transform The placement of the content.
---@param replacing boolean When `true`, indicates that the existing content of the group is removed.
---@param function_name string The name of the calling method, for error messages.
---@return S # A copy of the composition with the content added.
---@nodiscard
local function add_content_to_group(self, group, content, placement, replacing, function_name)
	local adopted = adopt_group(self, group, function_name)

	local layers = get_layers_from_content(self, content)
	if #layers == 0 then
		error(
			string.format(
				"%s(): parameter 'content': the composition has no artwork; label content is not embedded",
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

---A signature rule that checks that `placement` is `nil` when `group` is a label group.
---@type Reskins.SpriteUtils.Validation.SignatureRule[]
local placement_only_for_artwork = {
	{
		parameter = "placement",
		arguments = { "group", "placement" },
		check = function(group, placement)
			if placement ~= nil and group.stratum == "label" then
				return false, "must be absent for a label group"
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

---Adds the given `content` to the given `group`.
---
---If the group is `unique`, the existing content of the group is removed. An `IconSource` or a prototype is resolved to
---layers when it is added, and `draw_background` is set on the first layer. An `IconComposition` is added as its
---artwork layers. Layers with a different icon defaults type are converted to the icon defaults type of the
---composition. `placement` is applied in addition to the scale and shift of the layers.
---
---#### Parameters
---@param group IconCompositionGroup The group to which the content is added.
---@param content IconCompositionContent The content to add.
---@param placement? Transform The scale and shift to apply to the content. A placement is permitted for artwork only.
---
---#### Returns
---@return self # A copy of the composition with the content added.
---
---#### Examples
---```lua
----- Add a badge to a group of its own, which holds one badge at a time.
---local BADGE = IconComposition.define_group({ name = "badge", stratum = "label", tintable = false, unique = true })
---
---local badged = composition:add(BADGE, badge_icon)
----- The badge is drawn on the finished icon, and is not transformed or tinted with the artwork.
---```
---@throws When `group` is not a valid `IconCompositionGroup`, or is not equal to the stored definition of the group with the same name.
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws When `placement` is not a `Transform`, or is given for a label group.
---@see IconComposition.replace
---@see IconComposition.remove
---@nodiscard
function IconComposition:add(group, content, placement)
	check_add(group, content, placement)

	return add_content_to_group(self, group, content, placement, false, "IconComposition:add")
end

local check_replace = V.signature("IconComposition:replace", {
	{ "group", Common.icon_composition_group },
	{ "content", composition_content },
	{ "placement", Common.transform:optional() },
}, placement_only_for_artwork)

---Replaces the content of the given `group` with the given `content`.
---
---#### Parameters
---@param group IconCompositionGroup The group in which the content is replaced.
---@param content IconCompositionContent The content that replaces the existing content of the group.
---@param placement? Transform The scale and shift to apply to the content. A placement is permitted for artwork only.
---
---#### Returns
---@return self # A copy of the composition with the content replaced.
---@throws When `group` is not a valid `IconCompositionGroup`, or is not equal to the stored definition of the group with the same name.
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws When `placement` is not a `Transform`, or is given for a label group.
---@see IconComposition.add
---@nodiscard
function IconComposition:replace(group, content, placement)
	check_replace(group, content, placement)

	return add_content_to_group(self, group, content, placement, true, "IconComposition:replace")
end

---Creates the signature check of a method adding placed content to the group of a stratum.
---@param method_name string The name of the method, for error messages.
---@return fun(content: any, placement: any)
---@nodiscard
local function placed_content_signature(method_name)
	return V.signature(method_name, {
		{ "content", composition_content },
		{ "placement", Common.transform:optional() },
	})
end

local check_add_backdrop = placed_content_signature("IconComposition:add_backdrop")
local check_add_canvas = placed_content_signature("IconComposition:add_canvas")
local check_add_overlay = placed_content_signature("IconComposition:add_overlay")
local check_add_symbol = placed_content_signature("IconComposition:add_symbol")

---Adds the given `content` to the backdrop group, `IconComposition.backdrop_group`, by `add`.
---
---#### Parameters
---@param content IconCompositionContent The content to add.
---@param placement? Transform The scale and shift to apply to the content.
---
---#### Returns
---@return self # A copy of the composition with the content added.
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws When `placement` is not a `Transform`.
---@see IconComposition.add
---@nodiscard
function IconComposition:add_backdrop(content, placement)
	check_add_backdrop(content, placement)

	return self:add(BACKDROP_GROUP, content, placement)
end

---Adds the given `content` to the canvas group, `IconComposition.canvas_group`, by `add`.
---
---#### Parameters
---@param content IconCompositionContent The content to add.
---@param placement? Transform The scale and shift to apply to the content.
---
---#### Returns
---@return self # A copy of the composition with the content added.
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws When `placement` is not a `Transform`.
---@see IconComposition.add
---@nodiscard
function IconComposition:add_canvas(content, placement)
	check_add_canvas(content, placement)

	return self:add(CANVAS_GROUP, content, placement)
end

---Adds the given `content` to the overlay group, `IconComposition.overlay_group`, by `add`.
---
---#### Parameters
---@param content IconCompositionContent The content to add.
---@param placement? Transform The scale and shift to apply to the content.
---
---#### Returns
---@return self # A copy of the composition with the content added.
---
---#### Examples
---```lua
----- Compose the ingredient of a recipe onto its icon.
---local recipe_icon = IconComposition:from_named_prototype("iron-gear-wheel", "item")
---    :add_overlay({ name = "iron-plate", type_name = "item" }, _defines.icon_transforms.corners.southwest)
---    :outline()
---    :build()
----- The plate is drawn outlined at half size in the southwest corner.
---```
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws When `placement` is not a `Transform`.
---@see IconComposition.add
---@nodiscard
function IconComposition:add_overlay(content, placement)
	check_add_overlay(content, placement)

	return self:add(OVERLAY_GROUP, content, placement)
end

---Adds the given `content` to the symbol group, `IconComposition.symbol_group`, by `add`.
---
---#### Parameters
---@param content IconCompositionContent The content to add.
---@param placement? Transform The scale and shift to apply to the content.
---
---#### Returns
---@return self # A copy of the composition with the content added.
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@throws When `placement` is not a `Transform`.
---@see IconComposition.add
---@nodiscard
function IconComposition:add_symbol(content, placement)
	check_add_symbol(content, placement)

	return self:add(SYMBOL_GROUP, content, placement)
end

local check_add_label = V.signature("IconComposition:add_label", {
	{ "content", composition_content },
})

---Adds the given `content` to the label group, `IconComposition.label_group`, by `add`.
---
---#### Parameters
---@param content IconCompositionContent The content to add.
---
---#### Returns
---@return self # A copy of the composition with the content added.
---@throws When `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.
---@see IconComposition.add
---@nodiscard
function IconComposition:add_label(content)
	check_add_label(content)

	return self:add(LABEL_GROUP, content)
end

local check_remove = V.signature("IconComposition:remove", {
	{ "name", Common.non_empty_string },
})

---Removes the group with the given `name` and its content.
---
---The stored definition of the group is removed. If there is no group with the given `name`, the composition is
---returned unmodified.
---
---#### Parameters
---@param name string The name of the group to remove.
---
---#### Returns
---@return self # A copy of the composition without the group, or the composition if it has no group with the given `name`.
---@throws When `name` is `nil` or an empty string.
---@see IconComposition.has_group
---@nodiscard
function IconComposition:remove(name)
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

---Indicates whether the composition has a group with the given `name`.
---
---#### Parameters
---@param name string The name of the group.
---
---#### Returns
---@return boolean # `true` if content has been added to a group with the given `name`; otherwise, `false`.
---@throws When `name` is `nil` or an empty string.
---@nodiscard
function IconComposition:has_group(name)
	check_has_group(name)

	return self.groups[name] ~= nil
end

local check_transform = V.signature("IconComposition:transform", {
	{ "transform", Common.transform },
})

---Applies the given `transform` to the artwork when the composition is built.
---
---The transform is applied after the placement of each content.
---
---#### Parameters
---@param transform Transform The scale and shift to apply.
---
---#### Returns
---@return self # A copy of the composition with the transform recorded.
---
---#### Examples
---```lua
----- Shrink the artwork into the lower half of the icon.
---local shrunk = composition:transform({ scale = 0.5, shift = { 0, 8 } })
----- The artwork is drawn at half size, centered 8 pixels below the center of the icon.
---```
---@throws When `transform` is not a `Transform`.
---@see IconComposition.minify
---@nodiscard
function IconComposition:transform(transform)
	check_transform(transform)

	return copy_composition_with_operation(self, {
		type = "transform",
		transform = util.copy(transform),
	})
end

local check_set_tint = V.signature("IconComposition:set_tint", {
	{ "tint", Common.color },
})

---Sets the given `tint` on the content when the composition is built.
---
---A layer with a tint alpha of zero is not modified.
---
---#### Parameters
---@param tint Color The tint to set.
---
---#### Returns
---@return self # A copy of the composition with the tint recorded.
---@throws When `tint` is not a `Color`.
---@see IconComposition.blend_tint
---@see Icons.set_icons_tint
---@nodiscard
function IconComposition:set_tint(tint)
	check_set_tint(tint)

	return copy_composition_with_operation(self, {
		type = "set_tint",
		tint = util.copy(tint),
	})
end

local check_blend_tint = V.signature("IconComposition:blend_tint", {
	{ "tint", Common.color },
	{ "weight", Common.unit_interval:optional() },
	{ "blender", blender_function:optional() },
})

---Blends the given `tint` into the tint of the content when the composition is built.
---
---A layer with a tint alpha of zero is not modified. A layer without a tint is given a white tint before it is blended.
---
---#### Parameters
---@param tint Color The tint to blend into the tint of each layer.
---@param weight? float The weight of `tint` in the blend, between 0 and 1. Default `0.5`.
---@param blender? IconTintBlender The function that blends the tints. Default `colors.blend`. If given, `weight` is ignored.
---
---#### Returns
---@return self # A copy of the composition with the blend recorded.
---
---#### Examples
---```lua
----- Move the tint of every tintable layer toward red, at a weight of 0.4.
---local blended = composition:blend_tint({ r = 0.8, g = 0.2, b = 0.2 }, 0.4)
----- An untinted layer is given the tint of white blended with red at 0.4.
---```
---@throws When `tint` is not a `Color`.
---@throws When `weight` is not between 0 and 1.
---@throws When `blender` is not a function.
---@see IconComposition.set_tint
---@see Icons.blend_icons_tint
---@nodiscard
function IconComposition:blend_tint(tint, weight, blender)
	check_blend_tint(tint, weight, blender)

	return copy_composition_with_operation(self, {
		type = "blend_tint",
		tint = util.copy(tint),
		weight = weight,
		blender = blender,
	})
end

---Sets `floating` on the artwork layers when the composition is built.
---@return self # A copy of the composition with the operation recorded.
---@see IconComposition.remove_floating
---@see Icons.float_icons
---@nodiscard
function IconComposition:float()
	return copy_composition_with_operation(self, {
		type = "float",
	})
end

---Clears `floating` on the artwork layers when the composition is built.
---@return self # A copy of the composition with the operation recorded.
---@see IconComposition.float
---@see Icons.remove_floating_from_icons
---@nodiscard
function IconComposition:remove_floating()
	return copy_composition_with_operation(self, {
		type = "remove_floating",
	})
end

---Outlines the icon when the composition is built.
---
---`draw_background` is set on the first non-transparent layer of the stack formed by the `backdrop` and `canvas`
---content, and on the first such layer of each `overlay` content.
---@return self # A copy of the composition with the operation recorded.
---@see IconComposition.remove_outline
---@see Icons.outline_icons
---@nodiscard
function IconComposition:outline()
	return copy_composition_with_operation(self, {
		type = "outline",
	})
end

---Sets `draw_background` to `false` on every layer when the composition is built.
---@return self # A copy of the composition with the operation recorded.
---@see IconComposition.outline
---@see Icons.remove_outline_from_icons
---@nodiscard
function IconComposition:remove_outline()
	return copy_composition_with_operation(self, {
		type = "remove_outline",
	})
end

local check_minify = V.signature("IconComposition:minify", {
	{ "scalar", Common.positive_number:less_than(1) },
})

---Minifies the `canvas` content by the given `scalar` relative to the backdrop when the composition is built.
---
---The icon is outlined as by `outline`. When no content is in the `backdrop` stratum, a transparent layer scaled to the
---expected icon size of the icon defaults type is inserted as the backdrop.
---
---#### Parameters
---@param scalar double The scalar by which the canvas is minified. Must be greater than 0 and less than 1.
---
---#### Returns
---@return self # A copy of the composition with the operation recorded.
---@throws When `scalar` is not a number greater than 0 and less than 1.
---@see IconComposition.transform
---@see Icons.minify_icon
---@nodiscard
function IconComposition:minify(scalar)
	check_minify(scalar)

	return copy_composition_with_operation(self, {
		type = "minify",
		scalar = scalar,
	})
end

local check_add_light = V.signature("IconComposition:add_light", {
	{ "sprite", sprite_layer },
	{ "placement", Common.transform:optional() },
})

---Adds the given `sprite` as a light layer.
---
---The sprite is added to the light group, `IconComposition.light_group`, with `draw_as_light` set. The `mipmap_count`,
---`flags`, and other fields of the sprite are kept. The `shift` of a placement or transform, in pixels, is divided by
---the tile size and added to the shift of the sprite. `float`, `remove_floating`, `outline`, and `remove_outline` do
---not modify a sprite.
---
---#### Parameters
---@param sprite Sprite The sprite to add as a light.
---@param placement? Transform The scale and shift to apply to the sprite.
---
---#### Returns
---@return self # A copy of the composition with the light layer added.
---
---#### Examples
---```lua
----- Add a light to the pictures of an item.
---local light = {
---    filename = light_file,
---    size = 64,
---    mipmap_count = 4,
---    scale = 0.5,
---    flags = { "icon", "light" },
---    tint = tint,
---}
---
---local icon_data, pictures = composition:add_light(light):build()
----- The icon does not include the light, and the pictures hold the icon layers with the light drawn after the canvas
----- content.
---```
---@throws When `sprite` is not a `Sprite` naming a mod-relative file.
---@throws When `placement` is not a `Transform`.
---@see IconComposition.build
---@nodiscard
function IconComposition:add_light(sprite, placement)
	check_add_light(sprite, placement)

	local light = util.copy(sprite)
	light.draw_as_light = true

	return add_sprite_to_group(self, LIGHT_GROUP, light, placement, "IconComposition:add_light")
end

local check_project = V.signature("IconComposition:project", {
	{ "projection", Common.icon_composition_projection },
	{ "options", build_options:optional() },
})

---Builds the composition with the given `projection`.
---
---#### Parameters
---@generic T
---@param projection IconCompositionProjection<T> The projection with which the composition is built.
---@param options? IconCompositionBuildOptions The build options.
---
---#### Returns
---@return T # The output of the projection.
---
---#### Examples
---```lua
----- Add a light layer to the sprite projection.
---local GLOW = {
---  name = "glow",
---  stratum = "overlay",
---  projections = {
---    icon = false,
---    pictures = {
---      rewrite = function(layers)
---        for _, layer in pairs(layers) do
---          layer.draw_as_glow = true
---        end
---        return layers
---      end,
---    },
---  },
---}
---
---local pictures = composition:add(GLOW, glow_layer):project(IconComposition.projections.pictures)
----- The glow layer is drawn on top of the canvas content, with `draw_as_glow` set.
---```
---@throws When `projection` is not an `IconCompositionProjection`.
---@throws When `options` is not an `IconCompositionBuildOptions`.
---@throws When no content is included in the projection.
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
				"IconComposition:project(): nothing to project: no content is included in projection '%s'",
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

---Indicates whether every contribution of the given composition has layers, is included in both the `icon` and
---`pictures` projections or in neither, and has no `rewrite` for the pictures.
---@param self IconComposition The composition.
---@return boolean # `true` if every contribution meets the conditions; otherwise, `false`.
---@nodiscard
local function are_pictures_a_conversion_of_icon(self)
	for _, contribution in pairs(self.contributions) do
		local group = contribution.group

		if contribution.sprite then
			return false
		end
		local in_icon = is_group_in_projection(group, icon_projection, false)
		local in_pictures = is_group_in_projection(group, pictures_projection, false)

		if in_icon ~= in_pictures then
			return false
		end

		local entry = group.projections and group.projections.pictures
		if in_pictures and type(entry) == "table" and entry.rewrite then
			return false
		end
	end

	return true
end

---Builds the composition into a compiled icon. Where the composition requires a sprite presentation to be properly
---rendered, a `pictures` object will be returned as well.
---
---#### Parameters
---@param options? IconCompositionBuildOptions The build options.
---
---#### Returns
---@return SafeIconData[] # An array of `IconData` objects.
---@return SpriteVariations? # The sprite icon, suitable for assignment to `prototype.pictures`, if required by the composition; otherwise, `nil`.
---
---#### Examples
---```lua
----- Build the icon of a prototype, and the same icon at technology size.
---local icon_data = composition:build()
---local technology_icon_data = composition:build({ to = "technology" })
---
----- Assign the icon and the pictures of an item with a light.
---local icon_data, pictures = composition:add_light(light_layer):build()
---prototype.icons = icon_data
---prototype.pictures = pictures or _sprites.create_sprite_from_icons(icon_data)
---```
---@throws When `options` is not an `IconCompositionBuildOptions`.
---@throws When no content is included in the icon.
---@see IconComposition.project
---@see IconComposition.add_light
---@nodiscard
function IconComposition:build(options)
	check_build(options)

	local icon_data = self:project(icon_projection, options)
	if are_pictures_a_conversion_of_icon(self) then
		return icon_data, nil
	end

	local to = options and options.to or nil
	local projected_contributions = get_projected_contributions(self, pictures_projection, to, false)
	if #projected_contributions == 0 then
		return icon_data, nil
	end

	return icon_data,
		pictures_projection.lower(projected_contributions, { defaults_type = to or self.defaults_type, composition = self })
end

---Creates an empty composition with the given `defaults_type`.
---@generic S : IconComposition
---@param class S The class of the new composition.
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
	{ "group", Common.icon_composition_group:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a composition containing the given `icon_datum` in the given `group`.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object.
---@param group? IconCompositionGroup The group to which the icon is added. Default `IconComposition.canvas_group`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return self # A composition containing the icon in the given group.
---@throws When `icon_datum` is not a valid `IconData`.
---@throws When `group` is not a valid `IconCompositionGroup`.
---@throws When `defaults_type` is an empty string.
---@see IconComposition.from_icons
---@see IconComposition.add
---@nodiscard
function IconComposition:from_icon(icon_datum, group, defaults_type)
	check_from_icon(icon_datum, group, defaults_type)

	return new_composition(self, defaults_type):add(group or CANVAS_GROUP, icon_datum)
end

local check_from_icons = V.signature("IconComposition:from_icons", {
	{ "icon_data", Common.icon_data },
	{ "group", Common.icon_composition_group:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a composition containing the given `icon_data` in the given `group`.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects.
---@param group? IconCompositionGroup The group to which the icon is added. Default `IconComposition.canvas_group`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return self # A composition containing the icon in the given group.
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `group` is not a valid `IconCompositionGroup`.
---@throws When `defaults_type` is an empty string.
---@see IconComposition.from_icon
---@see IconComposition.from_classified_icons
---@see IconComposition.add
---@nodiscard
function IconComposition:from_icons(icon_data, group, defaults_type)
	check_from_icons(icon_data, group, defaults_type)

	return new_composition(self, defaults_type):add(group or CANVAS_GROUP, icon_data)
end

local check_from_source = V.signature("IconComposition:from_source", {
	{ "source", Common.icon_source },
	{ "group", Common.icon_composition_group:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a composition containing the icon from the given `source` in the given `group`.
---
---#### Parameters
---@param source IconSource The `IconSource` to resolve.
---@param group? IconCompositionGroup The group to which the icon is added. Default `IconComposition.canvas_group`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return self # A composition containing the icon in the given group.
---
---#### Examples
---```lua
----- Create a composition from the icon of a prototype, placed at half size in the lower half of the icon.
---local composition = IconComposition:from_source({
---    name = "iron-plate",
---    type_name = "item",
---    transform = { scale = 0.5, shift = { 0, 8 } },
---})
----- The composition holds one layer with scale 0.25 and shift { 0, 8 }.
---```
---@throws When `source` is not a valid `IconSource`, or names a prototype that does not exist.
---@throws When `group` is not a valid `IconCompositionGroup`.
---@throws When `defaults_type` is an empty string.
---@see IconComposition.from_named_prototype
---@see IconComposition.add
---@nodiscard
function IconComposition:from_source(source, group, defaults_type)
	check_from_source(source, group, defaults_type)

	return new_composition(self, defaults_type):add(group or CANVAS_GROUP, source)
end

local check_from_prototype = V.signature("IconComposition:from_prototype", {
	{ "prototype", Common.prototype_with_icons },
	{ "group", Common.icon_composition_group:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a composition containing the icon of the given `prototype` in the given `group`.
---
---#### Parameters
---@param prototype PrototypeWithIcons The prototype from which the icon is read.
---@param group? IconCompositionGroup The group to which the icon is added. Default `IconComposition.canvas_group`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return self # A composition containing the icon in the given group.
---@throws When `prototype` does not have a `type` field, or defines neither `icon` nor `icons`.
---@throws When `group` is not a valid `IconCompositionGroup`.
---@throws When `defaults_type` is an empty string.
---@see IconComposition.from_named_prototype
---@see Icons.get_icon_from_prototype
---@nodiscard
function IconComposition:from_prototype(prototype, group, defaults_type)
	check_from_prototype(prototype, group, defaults_type)

	return new_composition(self, defaults_type):add(group or CANVAS_GROUP, prototype)
end

local check_from_named_prototype = V.signature("IconComposition:from_named_prototype", {
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototype_type_name },
	{ "group", Common.icon_composition_group:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a composition containing the icon of the prototype with the given `name` and `type_name` in the given
---`group`.
---
---#### Parameters
---@param name string The name of the prototype.
---@param type_name string The type name of the prototype.
---@param group? IconCompositionGroup The group to which the icon is added. Default `IconComposition.canvas_group`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return self # A composition containing the icon in the given group.
---@throws When `name` or `type_name` is `nil` or an empty string, or no such prototype exists.
---@throws When `group` is not a valid `IconCompositionGroup`.
---@throws When `defaults_type` is an empty string.
---@see IconComposition.from_prototype
---@see IconComposition.from_source
---@nodiscard
function IconComposition:from_named_prototype(name, type_name, group, defaults_type)
	check_from_named_prototype(name, type_name, group, defaults_type)

	return new_composition(self, defaults_type):add(group or CANVAS_GROUP, { name = name, type_name = type_name })
end

local check_from_composition = V.signature("IconComposition:from_composition", {
	{ "composition", Common.icon_composition },
})

---Creates a composition of the calling class with the groups, content, operations, and icon defaults type of the given
---`composition`.
---
---#### Parameters
---@param composition IconComposition The composition from which the state is copied.
---
---#### Returns
---@return self # A composition of the calling class with the same state.
---
---#### Examples
---```lua
----- Define a subclass with a method of its own, and convert a composition to it.
---local BADGE = { name = "badge", stratum = "label", tintable = false, unique = true }
---
------@class BadgedIconComposition : IconComposition
---local BadgedIconComposition = {}
---BadgedIconComposition.__index = BadgedIconComposition
---setmetatable(BadgedIconComposition, IconComposition)
---
------@param badge IconCompositionContent
------@return self
---function BadgedIconComposition:add_badge(badge)
---    return self:add(BADGE, badge)
---end
---
---local badged = BadgedIconComposition:from_composition(composition):add_badge(badge)
----- `badged` is a `BadgedIconComposition` with the groups, content, and operations of `composition` and the badge.
---```
---@throws When `composition` is not an `IconComposition`.
---@nodiscard
function IconComposition:from_composition(composition)
	check_from_composition(composition)

	return setmetatable(copy_composition_for_step(composition), self)
end

local check_from_classified_icons = V.signature("IconComposition:from_classified_icons", {
	{ "icon_data", Common.icon_data },
	{ "classify", classifier_function },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a composition containing the layers of the given `icon_data`, each in the group returned by `classify` for
---it.
---
---`classify` is called once per layer, in order. Consecutive layers with the same group are added as one content.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects.
---@param classify IconLayerClassifier A function that returns the group for each layer.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.default_icon_size`.
---
---#### Returns
---@return self # A composition containing the layers in their groups.
---
---#### Examples
---```lua
----- Split the badge layers of an existing icon into a group of their own.
---local composition = IconComposition:from_classified_icons(prototype.icons, function(icon_datum)
---    return is_badge(icon_datum) and BADGE or ARTWORK
---end)
----- The badge layers are in the `BADGE` group, and the other layers are in the `ARTWORK` group.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `classify` is not a function, or returns something other than a valid `IconCompositionGroup`.
---@throws When `classify` returns definitions for one group name that are not equal.
---@throws When `defaults_type` is an empty string.
---@see IconComposition.from_icons
---@see IconComposition.add
---@nodiscard
function IconComposition:from_classified_icons(icon_data, classify, defaults_type)
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
			-- The definition of a run is the first one given. Later layers in the run must match it.
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

---The group to which `add_backdrop` adds content. The group is named `backdrop`, is in the `backdrop` stratum, and is
---tintable. The group must not be modified.
---@type IconCompositionGroup
IconComposition.backdrop_group = BACKDROP_GROUP

---The group to which `add_canvas` adds content, and to which a constructor given no group adds content. The group is
---named `canvas`, is in the `canvas` stratum, and is tintable. The group must not be modified.
---@type IconCompositionGroup
IconComposition.canvas_group = CANVAS_GROUP

---The group to which `add_overlay` adds content. The group is named `overlay`, is in the `overlay` stratum, and is not
---tintable. The group must not be modified.
---@type IconCompositionGroup
IconComposition.overlay_group = OVERLAY_GROUP

---The group to which `add_symbol` adds content. The group is named `symbol`, is in the `symbol` stratum, and is not
---tintable. The group must not be modified.
---@type IconCompositionGroup
IconComposition.symbol_group = SYMBOL_GROUP

---The group to which `add_label` adds content. The group is named `label`, is in the `label` stratum, and is not
---tintable. The group must not be modified.
---@type IconCompositionGroup
IconComposition.label_group = LABEL_GROUP

---The group to which `add_light` adds content. The group is named `light`, is in the `canvas` stratum with an `order`
---of 1, is not tintable, and is not included in the `icon` projection. The group must not be modified.
---@type IconCompositionGroup
IconComposition.light_group = LIGHT_GROUP

---Indicates whether the given `value` is an `IconComposition`.
---
---#### Parameters
---@param value unknown The value to check.
---
---#### Returns
---@return TypeGuard<IconComposition> # `true` if `value` is an `IconComposition`; otherwise, `false`.
---@nodiscard
function IconComposition.is_icon_composition(value)
	return is_icon_composition(value)
end

---A validator that checks that a value is an `IconCompositionPicturesEntry` with no unknown fields.
local pictures_entry = V.struct({
	rewrite = V.func():optional(),
})
	:strict()
	:describe_as("an IconCompositionPicturesEntry")

---A validator that checks that a value is an array of sprite layers, without validating the layers.
local sprite_layers = V.array(V.table()):describe_as("an array of sprite layers")

pictures_projection = {
	name = "pictures",
	includes_labels = false,
	lower = function(contributions)
		local layers, trailing = {}, {}

		for _, contribution in pairs(contributions) do
			local lowered = {}
			if contribution.sprite then
				lowered[1] = contribution.sprite
			else
				for index, layer in pairs(contribution.layers or {}) do
					lowered[index] = _sprites.create_sprite_from_icon(layer)
				end
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
			error("IconComposition:project(): projection 'pictures' has no layers to draw", 2)
		end

		if #layers == 1 then
			return layers[1]
		end

		return { layers = layers }
	end,
}

---Provides the projections of `IconComposition`.
---@class IconCompositionProjections
---The projection that builds an array of `IconData` objects and includes label content.
---@field icon IconCompositionProjection<SafeIconData[]>
---The projection that builds a `SpriteVariations` for the `pictures` field of an item. Label content is included only
---if its group has a `pictures` entry.
---@field pictures IconCompositionProjection<SpriteVariations>
IconComposition.projections = {
	icon = icon_projection,
	pictures = pictures_projection,
}

return IconComposition
