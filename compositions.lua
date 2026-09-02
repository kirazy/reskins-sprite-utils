---@using data

---@namespace Reskins.SpriteUtils

--- Provides methods for composing an icon from named groups of layers, and for projecting the
--- result as an icon or as pictures.
---
---### Examples
---```lua
---local _compositions = require("__reskins-sprite-utils__.compositions")
---```
---@class Compositions
local _compositions = {}

local V = require("validation")
local Common = require("validation.common")
local _defines = require("defines")
local _icons = require("icons")
local _sprites = require("sprites")

---The position of each stratum in the stack, lowest first.
---@type table<IconCompositionStratum, integer>
local STRATUM_INDEX = {}
for index, stratum in ipairs(_defines.icon_composition_strata) do
	---@diagnostic disable-next-line: inject-field
	STRATUM_INDEX[stratum] = index
end

---The strata whose content is artwork: placed, transformed, and floated as one drawing.
---@type table<IconCompositionStratum, boolean>
local ARTWORK_STRATA = { backdrop = true, canvas = true, overlay = true }

---One piece of content in a composition, as added: the group it belongs to, its layers, and where
---they are placed. Never modified once made, so compositions derived from one another share it.
---@class IconCompositionContribution
---The position in the order content was added, which makes the stacking order total.
---@field sequence integer
---The group the content was added to, as the composition adopted it.
---@field group IconCompositionGroup
---The layers, in the composition's frame.
---@field content IconData[]
---Where the layers are placed, for artwork.
---@field placement? Transform

---A verb recorded on a composition, applied when it is built.
---@class IconCompositionOperation
---@field kind "transform"|"set_tint"|"blend_tint"|"float"|"remove_floating"|"outline"|"remove_outline"
---@field transform? Transform
---@field tint? Color
---@field weight? float
---@field blender? IconTintBlender

---
---An icon assembled from named groups of layers.
---
---Every method that changes a composition returns a new one and leaves the original as it was, so a
---composition can be made once and then extended in several directions without any of them seeing
---the others' changes. Arguments are checked as they are given; the work is done by `build` or
---`project`, which read the content as it stands at that moment and copy everything they return.
---
---### Remarks
---- Content stacks by stratum first: everything in `backdrop` beneath everything in `canvas`,
---  beneath `overlay`, beneath `annotation`. Within a stratum, groups stack by `order`, then by
---  name; within a group, in the order content was added. The layers of one piece of content are
---  never reordered.
---- `backdrop`, `canvas`, and `overlay` are artwork: a placement given with the content, and any
---  `transform` recorded on the composition, move and scale them together. `annotation` content is
---  authored against the slot the finished icon is drawn in: it takes no placement, is never
---  transformed or floated, and is left out when the composition is embedded in another.
---- Verbs are recorded, not applied. `set_tint`, `blend_tint`, `float`, `remove_floating`,
---  `outline`, and `remove_outline` describe the finished composition, so content added or replaced
---  after one is recorded is covered by it all the same.
---- The tint verbs pass by a layer whose tint has an alpha of zero, which the game draws
---  additively rather than in a color, so a highlights layer keeps its effect however its group
---  is tinted.
---- Content is read at build, not copied when added. An array added to a composition and then
---  changed builds as changed.
---
---### Examples
---```lua
---local _compositions = require("__reskins-sprite-utils__.compositions")
---local _defines = require("__reskins-sprite-utils__.defines")
---
---local ARTWORK = { name = "artwork", stratum = "canvas" }
---local SYMBOL = { name = "symbol", stratum = "overlay", unique = true }
---
----- The family's shape, made once.
---local machine = _compositions
---    .from_named_prototype("assembling-machine-1", "assembling-machine", ARTWORK)
---    :outline()
---
----- Each member extends it without disturbing the others.
---for name, symbol in pairs(symbols_by_name) do
---    local icon_data = machine
---        :add(SYMBOL, symbol, _defines.icon_transforms.corners.northeast)
---        :build()
---end
---```
---@class IconComposition
---The name of the type-specific icon defaults the composition is authored in. Read-only.
---@field defaults_type? IconDefaultsType
---@field package groups table<string, IconCompositionGroup>
---@field package contributions IconCompositionContribution[]
---@field package operations IconCompositionOperation[]
---@field package next_sequence integer
local IconComposition = {}
IconComposition.__index = IconComposition

---Reports whether `value` is an `IconComposition`.
---@param value any # The value to check.
---@return boolean # Whether it is a composition.
---@nodiscard
local function is_composition(value)
	return getmetatable(value) == IconComposition
end

local icon_composition = V.custom(is_composition, "an IconComposition"):describe_as("an IconComposition")

---A prototype held by reference, defining an icon. Its `type` is required: it is what sizes the
---icon, and what tells a prototype apart from an `IconData` object, which has no `type`.
local prototype_with_icons =
	V.all_of(V.shape({ type = Common.prototype_type_name }), Common.prototypes.prototype_with_icons)
		:describe_as("a prototype with a type, defining an icon")

---What may be added to a composition.
---
---Checked rather than sniffed, for the same reason `compose_icons` checks its arguments: a table
---that is none of these is reported, not silently read as an empty icon.
local composition_content =
	V.any_of(Common.icon_datum, Common.icon_data, Common.icon_source, prototype_with_icons, icon_composition):describe_as(
		"an IconData object, an array of IconData objects, an IconSource, a prototype defining an icon, or an IconComposition"
	)

---Assigns a layer of an icon to a group.
---@alias IconLayerClassifier fun(icon_datum: IconData, index: integer): IconCompositionGroup

local classifier_function = V.func():describe_as("a classifier function")

local build_options = V.shape({
	to = Common.icon_defaults_type:optional(),
})
	:strict()
	:describe_as("an IconCompositionBuildOptions")

local blender_function = V.func():describe_as("a blending function")

---Reports whether the values of `a` and `b` are the same, entry for entry.
---@param a table
---@param b table
---@return boolean
---@nodiscard
local function shallow_equal(a, b)
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

---Reports whether two sets of projection entries say the same things.
---@param a? table<string, table|false>
---@param b? table<string, table|false>
---@return boolean
---@nodiscard
local function same_projections(a, b)
	a, b = a or {}, b or {}

	for name, entry in pairs(a) do
		local other = b[name]

		if type(entry) ~= "table" or type(other) ~= "table" then
			if entry ~= other then
				return false
			end
		elseif not shallow_equal(entry, other) then
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

---Reports whether two group definitions say the same things about a group.
---
---Compared by what each field means rather than by how it was written, so an absent `order` and
---an `order` of `0` agree.
---@param existing IconCompositionGroup # The definition the composition adopted.
---@param given IconCompositionGroup # The definition offered now.
---@return boolean # Whether they agree.
---@nodiscard
local function same_definition(existing, given)
	return existing.stratum == given.stratum
		and (existing.order or 0) == (given.order or 0)
		and (existing.tintable ~= false) == (given.tintable ~= false)
		and (existing.unique == true) == (given.unique == true)
		and same_projections(existing.projections, given.projections)
end

---Orders contributions by stratum, then by group order, then by group name, then by the order
---they were added. No two contributions compare equal, so the order is fixed by these rules alone
---rather than by how the sort happens to arrange ties.
---@param a IconCompositionContribution
---@param b IconCompositionContribution
---@return boolean # Whether `a` stacks beneath `b`.
---@nodiscard
local function stacks_beneath(a, b)
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

---Reports whether a group's content takes part in a projection.
---
---A group's own entry decides first. Failing that, annotation content takes part only where the
---output has a slot for it to be authored against, and never when the composition is being
---embedded, since the host owns the slot.
---@param group IconCompositionGroup # The group.
---@param projection IconCompositionProjection<any> # The projection.
---@param is_embedding boolean # Whether the composition is being embedded in another.
---@return boolean # Whether the group's content is projected.
---@nodiscard
local function participates(group, projection, is_embedding)
	local entry = group.projections and group.projections[projection.name]
	if entry == false then
		return false
	end

	if group.stratum == "annotation" then
		if is_embedding then
			return false
		end

		return projection.has_slot or entry ~= nil
	end

	return true
end

---Gets the contribution that carries the composition's outline: the first in the canvas or overlay
---strata, and failing those, the first in the backdrop. Annotations never carry it.
---@param realized IconCompositionProjectedContribution[] # The projected contributions, in stacking order.
---@return IconCompositionProjectedContribution? # The contribution to outline, if there is artwork.
---@nodiscard
local function outline_target(realized)
	local backdrop

	for _, projected in ipairs(realized) do
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

---Applies one recorded verb to a projected contribution, as far as its group admits it.
---@param projected IconCompositionProjectedContribution # The contribution.
---@param operation IconCompositionOperation # The verb.
---@param defaults_type? IconDefaultsType # The composition's frame.
---@return SafeIconData[] # The layers after the verb.
---@nodiscard
local function apply_operation(projected, operation, defaults_type)
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

---Gets the expected icon size of a frame, with an absent frame as the default.
---@param defaults_type? IconDefaultsType
---@return SpriteSizeType
---@nodiscard
local function frame_size(defaults_type)
	return _icons.get_expected_icon_size(defaults_type or "default")
end

---Gets the contributions of `self` that take part in `projection`, in stacking order, with
---placements applied, the recorded verbs applied, and the layers scaled for `to`.
---
---The working half of `project`, and of embedding one composition in another.
---@param self IconComposition # The composition.
---@param projection IconCompositionProjection<any> # The projection to realize for.
---@param to? IconDefaultsType # The frame to size the layers for; the composition's own when absent.
---@param is_embedding boolean # Whether the result is content for another composition.
---@return IconCompositionProjectedContribution[] # The projected contributions; empty when nothing takes part.
---@nodiscard
local function realize(self, projection, to, is_embedding)
	local sorted = {}
	for index = 1, #self.contributions do
		sorted[index] = self.contributions[index]
	end
	table.sort(sorted, stacks_beneath)

	---@type IconCompositionProjectedContribution[]
	local realized = {}
	for _, contribution in ipairs(sorted) do
		local group = contribution.group

		if participates(group, projection, is_embedding) then
			local layers = _icons.add_missing_icons_defaults(contribution.content, self.defaults_type)
			if contribution.placement then
				layers = _icons.transform_icons(layers, contribution.placement, self.defaults_type)
			end

			local entry = group.projections and group.projections[projection.name] or nil
			realized[#realized + 1] = { group = group, layers = layers, entry = entry or nil }
		end
	end

	-- Verbs are applied in the order they were recorded. The outline is the one verb that reads
	-- the composition as a whole, so it runs across every contribution at its turn, where a
	-- `remove_outline` before or after it lands on the same layers in the same order.
	for _, operation in ipairs(self.operations) do
		if operation.kind == "outline" then
			local target = outline_target(realized)
			if target then
				target.layers = _icons.outline_icons(target.layers)
			end
		else
			for _, projected in ipairs(realized) do
				projected.layers = apply_operation(projected, operation, self.defaults_type)
			end
		end
	end

	if to and frame_size(to) ~= frame_size(self.defaults_type) then
		for _, projected in ipairs(realized) do
			projected.layers = _icons.convert_icons_defaults_type(projected.layers, self.defaults_type, to)
		end
	end

	return realized
end

---@type IconCompositionProjection<SafeIconData[]>
local icon_projection = {
	name = "icon",
	has_slot = true,
	lower = function(contributions)
		local icon_data = {}
		for _, contribution in ipairs(contributions) do
			for _, layer in ipairs(contribution.layers) do
				icon_data[#icon_data + 1] = layer
			end
		end

		return icon_data
	end,
}

---Gets the artwork of `inner` as layers in `frame`, for adding to another composition.
---@param inner IconComposition # The composition to embed.
---@param frame? IconDefaultsType # The host's frame.
---@return IconData[] # The layers; empty when the composition has no artwork.
---@nodiscard
local function embed(inner, frame)
	-- Named explicitly, since an absent frame would read as "no conversion" rather than "the default".
	frame = frame or "default"

	return icon_projection.lower(realize(inner, icon_projection, frame, true), {
		defaults_type = frame,
		composition = inner,
	})
end

---Gets the layers an `IconSource` names, scaled for `frame`.
---
---A sourced icon is treated as the sources pipeline treats it: its own scale, shift, or
---transform place it, its tint and floating apply to every layer, and its first layer draws the
---background it drew on its own. Unlike that pipeline, an icon scaled for another kind of prototype
---has its scale and shift recomputed for `frame`, and a layer with an additive tint keeps it.
---@param source IconSource # A valid `IconSource`.
---@param frame? IconDefaultsType # The composition's frame.
---@return SafeIconData[] # The layers, in `frame`.
---@nodiscard
local function resolve_source(source, frame)
	---@type IconData[], IconDefaultsType?
	local layers, source_frame

	if source.icon_datum then
		---@cast source IconDatumSource
		layers, source_frame = { source.icon_datum }, source.defaults_type or frame
	elseif source.icon_data then
		---@cast source IconDataSource
		layers, source_frame = source.icon_data, source.defaults_type or frame
	else
		---@cast source PrototypeIconSource
		layers, source_frame = _icons.get_icon_from_named_prototype(source.name, source.type_name), source.type_name
	end

	local placement = source.transform or { scale = source.scale, shift = source.shift }
	local placed = _icons.transform_icons(layers, placement, source_frame)

	if source.tint then
		placed = _icons.set_icons_tint(placed, source.tint)
	end

	if source.floating then
		placed = _icons.float_icons(placed)
	end

	-- The layers are copies by now, so this touches nothing of the caller's.
	local first = placed[1]
	if first then
		first.draw_background = true
	end

	if frame_size(source_frame) ~= frame_size(frame) then
		return _icons.convert_icons_defaults_type(placed, source_frame, frame)
	end

	return placed
end

---Gets valid content as layers in the composition's frame.
---@param self IconComposition # The composition the content is for.
---@param content IconCompositionContent # Valid content.
---@return IconData[] # The layers; empty only for a composition with no artwork.
---@nodiscard
local function resolve_content(self, content)
	if is_composition(content) then
		---@cast content IconComposition
		return embed(content, self.defaults_type)
	end

	---@cast content -IconComposition
	---@diagnostic disable-next-line: undefined-field
	if content.type then
		-- A prototype, sized by its type. As with a sourced icon, its first layer keeps the
		-- background it drew on its own.
		---@cast content PrototypeWithIcons
		local layers = _icons.get_icon_from_prototype(content)
		local first = layers[1]
		if first then
			first.draw_background = true
		end

		if frame_size(content.type) ~= frame_size(self.defaults_type) then
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
		return resolve_source(content, self.defaults_type)
	end

	---@cast content IconData[]
	return content
end

---Gets a composition holding the same content, groups, and verbs as `self`, for a step to change.
---
---The records themselves are shared, since none is modified after it is made; only the tables
---that hold them are copied.
---@param self IconComposition # The composition to derive from.
---@return IconComposition # The derived composition.
---@nodiscard
local function derive(self)
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
	}, IconComposition)
end

---Gets a composition with `operation` recorded after everything `self` records.
---@param self IconComposition # The composition to derive from.
---@param operation IconCompositionOperation # The verb to record.
---@return IconComposition # The derived composition.
---@nodiscard
local function record(self, operation)
	local derived = derive(self)
	derived.operations[#derived.operations + 1] = operation

	return derived
end

---Removes every contribution to the named group from `composition`, in place.
---@param composition IconComposition # A composition no one else holds yet.
---@param name string # The group name.
local function drop_contributions(composition, name)
	local kept = {}
	for _, contribution in ipairs(composition.contributions) do
		if contribution.group.name ~= name then
			kept[#kept + 1] = contribution
		end
	end

	composition.contributions = kept
end

---Gets a composition with `content` added to `group`.
---
---The working half of `add` and `replace`, without the validation.
---@param self IconComposition # The composition to derive from.
---@param group IconCompositionGroup # A valid group definition.
---@param content IconCompositionContent # Valid content.
---@param placement? Transform # A valid placement.
---@param replacing boolean # Whether the group's existing content goes.
---@param function_name string # The public method, for messages.
---@return IconComposition # The derived composition.
---@nodiscard
local function insert(self, group, content, placement, replacing, function_name)
	local adopted = self.groups[group.name]
	if adopted then
		if not same_definition(adopted, group) then
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

	local layers = resolve_content(self, content)
	if #layers == 0 then
		error(
			string.format(
				"%s(): parameter 'content': the composition has no artwork to embed; annotations are left behind",
				function_name
			),
			3
		)
	end

	local derived = derive(self)
	derived.groups[adopted.name] = adopted

	if replacing or adopted.unique then
		drop_contributions(derived, adopted.name)
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

---A placement is a statement about artwork, and an annotation is not artwork.
---@type Reskins.SpriteUtils.Validation.SignatureRule[]
local placement_only_for_artwork = {
	{
		parameter = "placement",
		arguments = { "group", "placement" },
		check = function(group, placement)
			if placement ~= nil and group.stratum == "annotation" then
				return false, "must be absent for an annotation group, whose content is authored against the slot"
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
---Gets a composition with `content` added to `group`.
---
---### Remarks
---- The group is adopted the first time content is added to it. A later `group` of the same name
---  must agree with it field for field.
---- When the group is `unique`, what it held goes; otherwise the content stacks on top of it.
---- `content` may be an `IconData` object, an array of them, an `IconSource`, a prototype defining
---  an icon, or another composition. An `IconSource` is resolved now, as the sources pipeline
---  resolves it, with its scale and shift recomputed for this composition's frame. A prototype is
---  read through `icons.get_icon_from_prototype`, sized by its `type`, and its first layer draws its
---  background. Another composition contributes its artwork the same way, with its own verbs applied
---  and its annotations left behind.
---- `placement` scales and shifts artwork, in this composition's frame, on top of whatever
---  placement the content carries. An annotation group takes none.
---- Neither `self` nor its content is modified. Content is read when the composition is built.
---
---### Examples
---```lua
---local with_symbol = composition:add(SYMBOL, symbol_icon, _defines.icon_transforms.corners.northeast)
---```
---
---### Parameters
---@param group IconCompositionGroup # The group to add to.
---@param content IconCompositionContent # What to add.
---@param placement? Transform # Where to place it, for artwork.
---
---### Returns
---@return IconComposition # A composition with the content added.
---
---### Exceptions
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`, or disagrees with the group of the same name already in the composition.\
---*@throws* `string` — Thrown when `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.\
---*@throws* `string` — Thrown when `placement` is not a `Transform`, or is given for an annotation group.
---
---### See Also
---@see IconComposition.replace
---@see IconComposition.remove
---@nodiscard
function IconComposition:add(group, content, placement)
	check_add(group, content, placement)

	return insert(self, group, content, placement, false, "IconComposition:add")
end

local check_replace = V.signature("IconComposition:replace", {
	{ "group", Common.icon_composition_group },
	{ "content", composition_content },
	{ "placement", Common.transform:optional() },
}, placement_only_for_artwork)

---
---Gets a composition with `content` in place of everything `group` held.
---
---### Remarks
---- As `add`, except that the group's existing content goes whether or not the group is `unique`.
---  A group with nothing in it is simply added to.
---- Verbs recorded before the replacement cover the replacement.
---- Neither `self` nor its content is modified.
---
---### Examples
---```lua
---local retinted = composition:replace(ARTWORK, other_artwork)
---```
---
---### Parameters
---@param group IconCompositionGroup # The group to replace the content of.
---@param content IconCompositionContent # What to hold instead.
---@param placement? Transform # Where to place it, for artwork.
---
---### Returns
---@return IconComposition # A composition with the content replaced.
---
---### Exceptions
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`, or disagrees with the group of the same name already in the composition.\
---*@throws* `string` — Thrown when `content` is not valid content, names a prototype that does not exist, or is a composition with no artwork.\
---*@throws* `string` — Thrown when `placement` is not a `Transform`, or is given for an annotation group.
---
---### See Also
---@see IconComposition.add
---@nodiscard
function IconComposition:replace(group, content, placement)
	check_replace(group, content, placement)

	return insert(self, group, content, placement, true, "IconComposition:replace")
end

local check_remove = V.signature("IconComposition:remove", {
	{ "name", Common.non_empty_string },
})

---
---Gets a composition without the named group or anything it held.
---
---### Remarks
---- The group is forgotten along with its content, so a different definition may later be added
---  under the same name.
---- A name no group has is not an error; the composition is returned as it is.
---- `self` is not modified.
---
---### Examples
---```lua
---local unlabeled = composition:remove("tier-label")
---```
---
---### Parameters
---@param name string # The name of the group to remove.
---
---### Returns
---@return IconComposition # A composition without the group.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is not a non-empty string.
---
---### See Also
---@see IconComposition.has_group
---@nodiscard
function IconComposition:remove(name)
	check_remove(name)

	if not self.groups[name] then
		return self
	end

	local derived = derive(self)
	derived.groups[name] = nil
	drop_contributions(derived, name)

	return derived
end

local check_has_group = V.signature("IconComposition:has_group", {
	{ "name", Common.non_empty_string },
})

---
---Reports whether the composition holds content in the named group.
---
---### Examples
---```lua
---if not composition:has_group("tier-label") then
---    composition = composition:add(TIER_LABEL, label)
---end
---```
---
---### Parameters
---@param name string # The group name.
---
---### Returns
---@return boolean # Whether the group has been added to.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` is not a non-empty string.
---@nodiscard
function IconComposition:has_group(name)
	check_has_group(name)

	return self.groups[name] ~= nil
end

local check_transform = V.signature("IconComposition:transform", {
	{ "transform", Common.transform },
})

---
---Gets a composition whose artwork is scaled and shifted by `transform` when built.
---
---### Remarks
---- Applies to every artwork stratum together, after each piece of content's own placement, so
---  the arrangement of the artwork survives. Annotations are left where they are.
---- Recorded in order with the other verbs; two transforms compose.
---- `self` is not modified.
---
---### Examples
---```lua
----- Shrink the whole drawing into the lower half, leaving the label where it was.
---local shrunk = composition:transform({ scale = 0.5, shift = { 0, 8 } })
---```
---
---### Parameters
---@param transform Transform # The scale and shift to apply.
---
---### Returns
---@return IconComposition # A composition recording the transform.
---
---### Exceptions
---*@throws* `string` — Thrown when `transform` is not a `Transform`.
---@nodiscard
function IconComposition:transform(transform)
	check_transform(transform)

	return record(self, { kind = "transform", transform = util.copy(transform) })
end

local check_set_tint = V.signature("IconComposition:set_tint", {
	{ "tint", Common.color },
})

---
---Gets a composition whose content is tinted `tint` when built.
---
---### Remarks
---- Reaches every layer of every group whose `tintable` is not `false`, in any stratum, except a
---  layer whose tint has an alpha of zero: the game draws such a layer additively rather than in a
---  color, and it keeps that tint.
---- Recorded in order with the other verbs, so a `blend_tint` after it blends into `tint`.
---- `self` is not modified.
---
---### Examples
---```lua
---local tinted = composition:set_tint(tier_tint)
---```
---
---### Parameters
---@param tint Color # The tint to set.
---
---### Returns
---@return IconComposition # A composition recording the tint.
---
---### Exceptions
---*@throws* `string` — Thrown when `tint` is not a `Color`.
---
---### See Also
---@see IconComposition.blend_tint
---@see Icons.set_icons_tint
---@nodiscard
function IconComposition:set_tint(tint)
	check_set_tint(tint)

	return record(self, { kind = "set_tint", tint = util.copy(tint) })
end

local check_blend_tint = V.signature("IconComposition:blend_tint", {
	{ "tint", Common.color },
	{ "weight", Common.unit_interval:optional() },
	{ "blender", blender_function:optional() },
})

---
---Gets a composition whose content has `tint` blended into its own when built.
---
---### Remarks
---- Reaches every layer of every group whose `tintable` is not `false`, in any stratum, except a
---  layer whose tint has an alpha of zero: the game draws such a layer additively rather than in a
---  color, and it keeps that tint. A layer without a tint renders untinted, which is white, so
---  that is what `tint` is mixed with.
---- By default the mix is `colors.blend` at the given `weight`. A `blender` replaces the mix
---  entirely, and `weight` is then not used.
---- Recorded in order with the other verbs.
---- `self` is not modified.
---
---### Examples
---```lua
---local shifted = composition:blend_tint(family_color, 0.4)
---```
---
---### Parameters
---@param tint Color # The tint to blend in.
---@param weight? float # How far each layer's tint moves toward `tint`, from `0` to `1`. Default `0.5`.
---@param blender? IconTintBlender # The mix to use in place of `colors.blend` at `weight`.
---
---### Returns
---@return IconComposition # A composition recording the blend.
---
---### Exceptions
---*@throws* `string` — Thrown when `tint` is not a `Color`.\
---*@throws* `string` — Thrown when `weight` is not between 0 and 1.\
---*@throws* `string` — Thrown when `blender` is not a function.
---
---### See Also
---@see IconComposition.set_tint
---@see Icons.blend_icons_tint
---@nodiscard
function IconComposition:blend_tint(tint, weight, blender)
	check_blend_tint(tint, weight, blender)

	return record(self, { kind = "blend_tint", tint = util.copy(tint), weight = weight, blender = blender })
end

---
---Gets a composition whose artwork floats when built: every artwork layer is left out of the bounds
---the game fits the icon into.
---
---### Remarks
---- Annotations do not float; they are what is left to fit.
---- Recorded in order with the other verbs; a `remove_floating` after it wins.
---- `self` is not modified.
---
---### Examples
---```lua
---local floated = composition:float()
---```
---
---### Returns
---@return IconComposition # A composition recording the float.
---
---### See Also
---@see IconComposition.remove_floating
---@see Icons.float_icons
---@nodiscard
function IconComposition:float()
	return record(self, { kind = "float" })
end

---
---Gets a composition whose artwork does not float when built.
---
---### Remarks
---- Clears `floating` on every artwork layer, including layers whose content set it.
---- Recorded in order with the other verbs; a `float` after it wins.
---- `self` is not modified.
---
---### Examples
---```lua
---local grounded = composition:remove_floating()
---```
---
---### Returns
---@return IconComposition # A composition recording the removal.
---
---### See Also
---@see IconComposition.float
---@see Icons.remove_floating_from_icons
---@nodiscard
function IconComposition:remove_floating()
	return record(self, { kind = "remove_floating" })
end

---
---Gets a composition that draws an outline when built.
---
---### Remarks
---- The outline goes to the first layer of artwork of the first group in the `canvas` or
---  `overlay` strata, and failing those, of the first group in `backdrop`. Within that group, a
---  spacer, recognized by a file name ending in `empty.png`, is passed over. Annotations never
---  carry it.
---- Only groups taking part in the projection are considered, so a group kept out of the icon
---  cannot carry the icon's outline.
---- Recorded in order with the other verbs; a `remove_outline` after it wins.
---- `self` is not modified.
---
---### Examples
---```lua
---local outlined = composition:outline()
---```
---
---### Returns
---@return IconComposition # A composition recording the outline.
---
---### See Also
---@see IconComposition.remove_outline
---@see Icons.outline_icons
---@nodiscard
function IconComposition:outline()
	return record(self, { kind = "outline" })
end

---
---Gets a composition that draws no outline when built.
---
---### Remarks
---- Sets `draw_background` to an explicit `false` on every layer of every group, since the first
---  layer of an icon draws its background unless told not to.
---- Recorded in order with the other verbs; an `outline` after it wins for the layer it targets.
---- `self` is not modified.
---
---### Examples
---```lua
---local bare = composition:remove_outline()
---```
---
---### Returns
---@return IconComposition # A composition recording the removal.
---
---### See Also
---@see IconComposition.outline
---@see Icons.remove_outline_from_icons
---@nodiscard
function IconComposition:remove_outline()
	return record(self, { kind = "remove_outline" })
end

local check_project = V.signature("IconComposition:project", {
	{ "projection", Common.icon_composition_projection },
	{ "options", build_options:optional() },
})

---
---Lowers the composition through `projection`.
---
---### Remarks
---- Every group taking part is realized in stacking order: its content is defaulted, placed, and
---  the recorded verbs applied. When `options.to` names another frame, every stratum has its scale
---  and shift recomputed
---  for it, annotations included.
---- A group takes part unless its `projections` entry for the projection is `false`. An
---  annotation group takes part in a projection without a slot only when it makes an entry.
---- The projection's `lower` receives the realized contributions and returns the output. The
---  layers it receives are copies; the output shares nothing with the composition.
---- `self` is not modified.
---
---### Examples
---```lua
---local pictures = composition:project(_compositions.projections.pictures)
---```
---
---### Parameters
---@generic T
---@param projection IconCompositionProjection<T> # The projection to lower through.
---@param options? IconCompositionBuildOptions # The frame to size the output for.
---
---### Returns
---@return T # What the projection lowered the composition to.
---
---### Exceptions
---*@throws* `string` — Thrown when `projection` is not an `IconCompositionProjection`.\
---*@throws* `string` — Thrown when `options` is not an `IconCompositionBuildOptions`.\
---*@throws* `string` — Thrown when no content takes part in the projection.
---
---### See Also
---@see IconComposition.build
---@see Compositions.projections
---@nodiscard
function IconComposition:project(projection, options)
	check_project(projection, options)

	local to = options and options.to or nil
	local realized = realize(self, projection, to, false)

	if #realized == 0 then
		error(
			string.format(
				"IconComposition:project(): nothing to project: no content takes part in projection '%s'",
				projection.name
			),
			2
		)
	end

	return projection.lower(realized, { defaults_type = to or self.defaults_type, composition = self })
end

local check_build = V.signature("IconComposition:build", {
	{ "options", build_options:optional() },
})

---
---Builds the icon.
---
---### Remarks
---- The icon projection: every group taking part, in stacking order, as one array of layers.
---  Missing icon fields are set to default values as appropriate.
---- When `options.to` names another frame, every stratum has its scale and shift recomputed for
---  it, annotations included,
---  so the icon draws the same on that kind of prototype.
---- The result shares nothing with the composition or its content, and building again gives the
---  same result.
---- `self` is not modified.
---
---### Examples
---```lua
---local icon_data = composition:build()
---local technology_icon_data = composition:build({ to = "technology" })
---```
---
---### Parameters
---@param options? IconCompositionBuildOptions # The frame to size the icon for.
---
---### Returns
---@return SafeIconData[] # The icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `options` is not an `IconCompositionBuildOptions`.\
---*@throws* `string` — Thrown when the composition has no content taking part in the icon.
---
---### See Also
---@see IconComposition.project
---@nodiscard
function IconComposition:build(options)
	check_build(options)

	return self:project(icon_projection, options)
end

---Creates an empty composition authored in the frame of `defaults_type`.
---
---The frame fixes what a placement's scale and shift, and an annotation's position, are measured
---against, and what missing icon fields default to. Content scaled for another frame is converted
---to this one as it is added.
---
---Not public: every composition starts from content, through one of the `from_*` constructors.
---@param defaults_type? IconDefaultsType # A valid icon defaults type name.
---@return IconComposition # An empty composition.
---@nodiscard
local function new_composition(defaults_type)
	return setmetatable({
		defaults_type = defaults_type,
		groups = {},
		contributions = {},
		operations = {},
		next_sequence = 1,
	}, IconComposition)
end

local check_from_icon = V.signature("from_icon", {
	{ "icon_datum", Common.icon_datum },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition holding `icon_datum` in `group`.
---
---### Remarks
---- The frame named by `defaults_type` fixes what missing icon fields default to and what a placement is
---  measured against.
---- `icon_datum` is not modified, and is read when the composition is built.
---
---### Examples
---```lua
---local composition = _compositions.from_icon(icon_datum, ARTWORK)
---```
---
---### Parameters
---@param icon_datum IconData # An `IconData` object.
---@param group IconCompositionGroup # The group to hold it.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults the composition is authored in. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconComposition # A composition holding the layer.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is not a valid `IconData` object.\
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`.\
---*@throws* `string` — Thrown when `defaults_type` is not a non-empty string.
---
---### See Also
---@see Compositions.from_icons
---@see IconComposition.add
---@nodiscard
function _compositions.from_icon(icon_datum, group, defaults_type)
	check_from_icon(icon_datum, group, defaults_type)

	return new_composition(defaults_type):add(group, icon_datum)
end

local check_from_icons = V.signature("from_icons", {
	{ "icon_data", Common.icon_data },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition holding `icon_data` in `group`.
---
---### Remarks
---- The frame named by `defaults_type` fixes what missing icon fields default to and what a placement is
---  measured against.
---- `icon_data` is not modified, and is read when the composition is built.
---
---### Examples
---```lua
---local composition = _compositions.from_icons(prototype.icons, ARTWORK)
---```
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects.
---@param group IconCompositionGroup # The group to hold it.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults the composition is authored in. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconComposition # A composition holding the layers.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is not a non-empty array of valid `IconData` objects.\
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`.\
---*@throws* `string` — Thrown when `defaults_type` is not a non-empty string.
---
---### See Also
---@see Compositions.from_icon
---@see Compositions.from_classified_icons
---@see IconComposition.add
---@nodiscard
function _compositions.from_icons(icon_data, group, defaults_type)
	check_from_icons(icon_data, group, defaults_type)

	return new_composition(defaults_type):add(group, icon_data)
end

local check_from_source = V.signature("from_source", {
	{ "source", Common.icon_source },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition holding the icon `source` names, in `group`.
---
---### Remarks
---- The source is resolved
---  now, as the sources pipeline resolves it, with its scale and shift recomputed for the
---  composition's frame.
---- `source` is not modified.
---
---### Examples
---```lua
---local composition = _compositions.from_source({ name = "iron-plate", type_name = "item" }, ARTWORK)
---```
---
---### Parameters
---@param source IconSource # An icon source.
---@param group IconCompositionGroup # The group to hold it.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults the composition is authored in. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconComposition # A composition holding the sourced icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `source` is not a valid `IconSource`, or names a prototype that does not exist.\
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`.\
---*@throws* `string` — Thrown when `defaults_type` is not a non-empty string.
---
---### See Also
---@see Compositions.from_named_prototype
---@see IconComposition.add
---@nodiscard
function _compositions.from_source(source, group, defaults_type)
	check_from_source(source, group, defaults_type)

	return new_composition(defaults_type):add(group, source)
end

local check_from_prototype = V.signature("from_prototype", {
	{ "prototype", prototype_with_icons },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition holding the icon of `prototype`, in `group`.
---
---### Remarks
---- The icon is read
---  through `icons.get_icon_from_prototype`, sized by the prototype's `type`, with its scale and
---  shift recomputed for the composition's frame. Its first layer draws its background.
---- `prototype` is not modified.
---
---### Examples
---```lua
---local composition = _compositions.from_prototype(data.raw["assembling-machine"]["assembling-machine-1"], ARTWORK)
---```
---
---### Parameters
---@param prototype PrototypeWithIcons # A prototype defining an icon.
---@param group IconCompositionGroup # The group to hold it.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults the composition is authored in. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconComposition # A composition holding the prototype's icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `prototype` does not carry a `type` and an `icon` or `icons`.\
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`.\
---*@throws* `string` — Thrown when `defaults_type` is not a non-empty string.
---
---### See Also
---@see Compositions.from_named_prototype
---@see Icons.get_icon_from_prototype
---@nodiscard
function _compositions.from_prototype(prototype, group, defaults_type)
	check_from_prototype(prototype, group, defaults_type)

	return new_composition(defaults_type):add(group, prototype)
end

local check_from_named_prototype = V.signature("from_named_prototype", {
	{ "name", Common.prototype_name },
	{ "type_name", Common.prototype_type_name },
	{ "group", Common.icon_composition_group },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition holding the icon of the prototype registered under `name` and `type_name`,
---in `group`.
---
---### Remarks
---- The same as `from_source({ name = name, type_name = type_name }, group, defaults_type)`.
---
---### Examples
---```lua
---local composition = _compositions.from_named_prototype("iron-plate", "item", ARTWORK)
---```
---
---### Parameters
---@param name string # The name of the prototype.
---@param type_name string # The type name of the prototype.
---@param group IconCompositionGroup # The group to hold it.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults the composition is authored in. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconComposition # A composition holding the prototype's icon.
---
---### Exceptions
---*@throws* `string` — Thrown when `name` or `type_name` is not a non-empty string, or no such prototype exists.\
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`.\
---*@throws* `string` — Thrown when `defaults_type` is not a non-empty string.
---
---### See Also
---@see Compositions.from_prototype
---@see Compositions.from_source
---@nodiscard
function _compositions.from_named_prototype(name, type_name, group, defaults_type)
	check_from_named_prototype(name, type_name, group, defaults_type)

	return new_composition(defaults_type):add(group, { name = name, type_name = type_name })
end

local check_from_classified_icons = V.signature("from_classified_icons", {
	{ "icon_data", Common.icon_data },
	{ "classify", classifier_function },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---
---Creates a composition from `icon_data`, assigning each layer to the group `classify` names for it.
---
---### Remarks
---- `classify` is called once per layer, in order, and returns the group for that layer. A run of
---  consecutive layers assigned to the same group becomes one piece of content, so the order within
---  the run is kept. Where the same group name recurs later in the icon, that run is added to the
---  group after the earlier one.
---- Every group `classify` returns for one name must agree, as for `add`.
---- This is how an icon read back from a prototype is taken apart into groups: the caller recognizes
---  its own layers, such as tier labels, and names the group each belongs in.
---- `icon_data` is not modified, and its layers are read when the composition is built.
---
---### Examples
---```lua
---local composition = _compositions.from_classified_icons(prototype.icons, function(icon_datum)
---    return is_tier_label(icon_datum) and TIER_LABEL or ARTWORK
---end)
---```
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects.
---@param classify IconLayerClassifier # Names the group for each layer.
---@param defaults_type? IconDefaultsType # The name of the type-specific icon defaults the composition is authored in. Unrecognized names resolve to `defines.default_icon_size`.
---
---### Returns
---@return IconComposition # A composition holding the layers in their groups.
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is not a non-empty array of valid `IconData` objects.\
---*@throws* `string` — Thrown when `classify` is not a function, or returns something other than a valid `IconCompositionGroup`.\
---*@throws* `string` — Thrown when `defaults_type` is not a non-empty string.
---
---### See Also
---@see Compositions.from_icons
---@see IconComposition.add
---@nodiscard
function _compositions.from_classified_icons(icon_data, classify, defaults_type)
	check_from_classified_icons(icon_data, classify, defaults_type)

	local composition = new_composition(defaults_type)

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
			-- The run continues under the definition it started with, which this one must match.
			if not same_definition(run_group, group) then
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

local check_define_group = V.signature("define_group", {
	{ "group", Common.icon_composition_group },
})

---
---Checks a group definition and returns a copy of it.
---
---### Remarks
---- A group is an ordinary table, and `add` checks it in any case. Defining it here reports a
---  mistake where the group is written rather than where it is first used.
---
---### Examples
---```lua
---local TIER_LABEL = _compositions.define_group({
---    name = "tier-label",
---    stratum = "annotation",
---    tintable = false,
---    unique = true,
---})
---```
---
---### Parameters
---@param group IconCompositionGroup # The definition.
---
---### Returns
---@return IconCompositionGroup # A copy of the definition.
---
---### Exceptions
---*@throws* `string` — Thrown when `group` is not a valid `IconCompositionGroup`.
---@nodiscard
function _compositions.define_group(group)
	check_define_group(group)

	return util.copy(group)
end

---
---Reports whether `value` is an `IconComposition`.
---
---### Parameters
---@param value any # The value to check.
---
---### Returns
---@return boolean # Whether it is a composition.
---@nodiscard
function _compositions.is_icon_composition(value)
	return is_composition(value)
end

local pictures_entry = V.shape({
	rewrite = V.func():optional(),
})
	:strict()
	:describe_as("an IconCompositionPicturesEntry")

local sprite_layers = V.array(V.table()):describe_as("an array of sprite layers")

---Appends the elements of `from` to `to`.
---@param to table[]
---@param from table[]
local function append(to, from)
	for index = 1, #from do
		to[#to + 1] = from[index]
	end
end

---@type IconCompositionProjection<Sprite>
local pictures_projection = {
	name = "pictures",
	has_slot = false,
	lower = function(contributions)
		local layers, trailing = {}, {}

		for _, contribution in ipairs(contributions) do
			local lowered = {}
			for index, layer in ipairs(contribution.layers) do
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

				append(layers, in_place)
				if deferred then
					append(trailing, deferred)
				end
			else
				append(layers, lowered)
			end
		end

		append(layers, trailing)

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
---The projections this module provides.
---
---### Remarks
---- `icon` lowers the composition to an array of icon layers; it is what `build` uses. Its output
---  is drawn in a slot, so annotations take part.
---- `pictures` lowers the composition to a `Sprite`, as `sprites.create_sprite_from_icons` would
---  make from the icon, for an item's in-world `pictures`. Its output has no slot, so annotations
---  are left out unless their group makes a `pictures` entry. A group's entry may carry a
---  `rewrite`, which receives the group's lowered sprite layers and returns the layers to keep in
---  the group's place, and optionally layers to draw after every group.
---- A projection is an ordinary table; one of your own is passed to `project` the same way.
---
---### Examples
---```lua
---local GLOW = {
---    name = "glow",
---    stratum = "overlay",
---    projections = {
---        icon = false,
---        pictures = {
---            rewrite = function(layers)
---                for _, layer in ipairs(layers) do
---                    layer.draw_as_glow = true
---                end
---                return layers
---            end,
---        },
---    },
---}
---
---local pictures = composition:add(GLOW, glow_layer):project(_compositions.projections.pictures)
---```
---@class CompositionProjections
---Lowers to an array of icon layers.
---@field icon IconCompositionProjection<SafeIconData[]>
---Lowers to a `Sprite`.
---@field pictures IconCompositionProjection<Sprite>
_compositions.projections = {
	icon = icon_projection,
	pictures = pictures_projection,
}

return _compositions
