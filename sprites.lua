---cspell: words premul

---@using data

---@namespace Reskins.SpriteUtils

--- Provides methods for manipulating sprites.
---
---### Examples
---```lua
---local _sprites = require("__reskins-sprite-utils__.sprites")
---```
---@class Sprites
local _sprites = {}

local _icons = require("icons")
local V = require("validation")
local Common = require("validation.common")

---Converts one defaulted icon layer into a sprite layer.
---
---Takes the layer already defaulted rather than defaulting it here, so an
---array is checked once against its own indices rather than once per layer
---with no indication of which layer it was.
---@param icon_layer SafeIconData # A defaulted icon layer.
---@param scale? double # The scale to apply to the sprite.
---@param shift_span number # The shift units the icon spans, `expected_icon_size / 2`.
---@return Sprite # A layer of sprite
local function convert_icon_layer_to_sprite_layer(icon_layer, scale, shift_span)
	local icon_copy = icon_layer
	local scale_to_apply = scale and scale * icon_copy.scale or icon_copy.scale

	-- An icon's shift is in pixels of a space the icon spans `shift_span` of,
	-- while a sprite's is in tiles. Dividing by the span the icon was measured
	-- against is what puts the two in the same units, and that span is a
	-- property of the defaults type rather than a constant.
	local converted_shift = icon_copy.shift and util.mul_shift(icon_copy.shift, 1 / shift_span) or nil

	---@type Sprite
	local sprite_layer = {
		flags = { "icon" },
		filename = icon_copy.icon,
		size = icon_copy.icon_size,
		scale = scale_to_apply,
		shift = converted_shift,
		tint = icon_copy.tint,
	}

	return sprite_layer
end

local check_create_sprite_from_icons = V.signature("create_sprite_from_icons", {
	-- Checked as a table only. The icon data itself is validated once, by the
	-- call to `icons.add_missing_icons_defaults` below, which reports a failure
	-- against the index it came from.
	{ "icon_data", V.table() },
	{ "scale", Common.positive_number:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
	{ "shift_type", Common.icon_defaults_type:optional() },
})

---
---Creates a `Sprite` object from the given `icon_data` array, at the given `scale`.
---
---`defaults_type` names the coordinate space assumed for the icon. It decides
---both what fills in the fields the icon does not state, and the units its
---`shift` is written in, since an icon spans `expected_icon_size / 2` of them.
---Omitted, the icon is read as an entity, item, or recipe icon.
---
---Those two roles coincide for an icon authored for the prototype it is being
---drawn from. `shift_type` separates them for an icon whose shift was written
---against one space while its missing fields belong to another.
---
---Missing icon fields are set to default values as appropriate.
---`icon_data` is not modified.
---
---### Parameters
---@param icon_data IconData[] # An array of `IconData` objects.
---@param scale? double # The scale to apply to the sprite.
---@param defaults_type? IconDefaultsType # The coordinate space assumed for the icons, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---@param shift_type? IconDefaultsType # The coordinate space the icon's `shift` is written against, where that differs from the space its defaults come from. Defaults to `defaults_type`.
---
---### Returns
---@return Sprite # A `Sprite` object created from `icon_data`.
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
---        shift = { -16, -16 }
---    },
---}
---
---local sprite = _sprites.create_sprite_from_icons(icon_data, 1.0)
---```
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_data` is `nil`.\
---*@throws* `string` — Thrown when `icon_data[n].icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_data[n].icon_size` is not a positive integer.
---@nodiscard
function _sprites.create_sprite_from_icons(icon_data, scale, defaults_type, shift_type)
	check_create_sprite_from_icons(icon_data, scale, defaults_type, shift_type)

	local defaulted = _icons.add_missing_icons_defaults(icon_data, defaults_type)
	local shift_span = _icons.get_expected_icon_size(shift_type or defaults_type) / 2

	if #defaulted == 1 then
		return convert_icon_layer_to_sprite_layer(defaulted[1], scale, shift_span)
	end

	local sprite = { layers = {} }
	for index = 1, #defaulted do
		sprite.layers[index] = convert_icon_layer_to_sprite_layer(defaulted[index], scale, shift_span)
	end

	return sprite
end

local check_create_sprite_from_icon = V.signature("create_sprite_from_icon", {
	-- As above: the icon itself is validated by `add_missing_icon_defaults`.
	{ "icon_datum", V.table() },
	{ "scale", Common.positive_number:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
	{ "shift_type", Common.icon_defaults_type:optional() },
})

---
---Creates a sprite from the given `icon_datum`, at the given `scale`.
---
---`defaults_type` names the coordinate space assumed for the icon. It decides
---both what fills in the fields the icon does not state, and the units its
---`shift` is written in, since an icon spans `expected_icon_size / 2` of them.
---Omitted, the icon is read as an entity, item, or recipe icon.
---
---Those two roles coincide for an icon authored for the prototype it is being
---drawn from. `shift_type` separates them for an icon whose shift was written
---against one space while its missing fields belong to another.
---
---Missing icon fields are set to default values as appropriate.
---`icon_datum` is not modified.
---
---### Parameters
---@param icon_datum IconData  # An `IconData` object.
---@param scale? double # The scale to apply to the sprite.
---@param defaults_type? IconDefaultsType # The coordinate space assumed for the icon, as per https://lua-api.factorio.com/latest/types/IconData.html#scale. Unrecognized names resolve to `defines.default_icon_size`.
---@param shift_type? IconDefaultsType # The coordinate space the icon's `shift` is written against, where that differs from the space its defaults come from. Defaults to `defaults_type`.
---
---### Returns
---@return Sprite # A `Sprite` object created from `icon_datum`.
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
---local sprite = _sprites.create_sprite_from_icon(icon_datum, 1.0)
---```
---
---### Exceptions
---*@throws* `string` — Thrown when `icon_datum` is `nil`.\
---*@throws* `string` — Thrown when `icon_datum` is not an IconData object.\
---*@throws* `string` — Thrown when `icon_datum.icon` is not an absolute file path with a valid extension.\
---*@throws* `string` — Thrown when `icon_datum.icon_size` is not a positive integer.
---@nodiscard
function _sprites.create_sprite_from_icon(icon_datum, scale, defaults_type, shift_type)
	check_create_sprite_from_icon(icon_datum, scale, defaults_type, shift_type)

	return convert_icon_layer_to_sprite_layer(
		_icons.add_missing_icon_defaults(icon_datum, defaults_type),
		scale,
		_icons.get_expected_icon_size(shift_type or defaults_type) / 2
	)
end

---@param prototype? { height?: SpriteSizeType, size?: (SpriteSizeType)|([SpriteSizeType, SpriteSizeType]) }
---@return SpriteSizeType
local function get_height(prototype)
	if prototype then
		if type(prototype.height) == "number" then
			return prototype.height
		elseif type(prototype.size) == "number" then
			return prototype.size
		elseif type(prototype.size) == "table" and #prototype.size == 2 then
			return prototype.size[2]
		end
	end

	return 0
end

---@param prototype? { width?: SpriteSizeType, size?: (SpriteSizeType)|([SpriteSizeType, SpriteSizeType]) }
---@return SpriteSizeType
local function get_width(prototype)
	if prototype then
		if type(prototype.width) == "number" then
			return prototype.width
		elseif type(prototype.size) == "number" then
			return prototype.size
		elseif type(prototype.size) == "table" and #prototype.size == 2 then
			return prototype.size[1]
		end
	end

	return 0
end

---
---Creates an `Animation4Way` object using the given `animation`, parsing the `line_length`
---and `frame_count` fields to slice a sprite sheet into direction-based `Animation` objects.
---
---### Remarks
---Extends the functionality of `make_rotated_animation_variations_from_sheet` to include handling
---of vertically oriented sprite sheets (set `vertically_oriented` to `true`), and of the additional
---parameters `run_mode` and `frame_sequence`.
---
---`animation` is not modified.
---
---### Parameters
---@param animation VerticallyOrientableAnimation|Animation # The animation object to create the 4-way animation from.
---
---### Returns
---@return Animation4Way|Sprite4Way # The 4-way animation object created from `animation`.
---
---### Examples
---To use the `vertically_oriented` parameter, include it in the `animation` object:
---```lua
---{
---    filename = "__mod-name__/graphics/entity/prototype/prototype.png",
---    priority = "extra-high",
---    vertically_oriented = true,
---    width = 660,
---    height = 460,
---    shift = util.by_pixel_hr(100, 20),
---    scale = 0.5,
---},
---```
---For a real-world example, see the Advanced Gas Refinery sprite sheets in Artisanal Reskins:
---Angel's Mods.
---@nodiscard
local function build_4way_animation(animation)
	local animation_copy = util.copy(animation)

	---@class DirectionDefines : integer
	local defines = {
		north = 0,
		east = 1,
		south = 2,
		west = 3,
	}

	---Creates the `Animation` object for the given `direction` using the given `source_animation`.
	---@param direction DirectionDefines # The direction to create the animation for.
	---@param source_animation VerticallyOrientableAnimation # The source animation object with a sprite sheet supporting direction-based configurations.
	---@return Animation # The new animation for the given `direction`.
	local function make_animation_layer_for_direction(direction, source_animation)
		local start_frame = (source_animation.frame_count or 1) * direction
		local x, y = 0, 0

		-- Extend vanilla function with handling for vertically_oriented sprite sheets.
		if source_animation.vertically_oriented then
			local height = math.max(get_height(source_animation), 0)
			if source_animation.line_length then
				y = math.floor(direction * height) * math.floor(start_frame / (source_animation.line_length or 1))
			else
				y = math.floor(direction * height)
			end
		else
			if source_animation.line_length then
				local height = math.max(get_height(source_animation), 0)
				y = height * math.floor(start_frame / (source_animation.line_length or 1))
			else
				local width = math.max(get_width(source_animation), 0)
				x = math.floor(direction * width)
			end
		end

		---@type Animation
		local animation_for_direction = {
			filename = source_animation.filename,
			priority = source_animation.priority or "high",
			flags = source_animation.flags,
			x = x,
			y = y,
			width = source_animation.width,
			height = source_animation.height,
			frame_count = source_animation.frame_count,
			line_length = source_animation.line_length,
			repeat_count = source_animation.repeat_count,
			shift = source_animation.shift,
			draw_as_shadow = source_animation.draw_as_shadow,
			draw_as_glow = source_animation.draw_as_glow,
			draw_as_light = source_animation.draw_as_light,
			apply_runtime_tint = source_animation.apply_runtime_tint,
			animation_speed = source_animation.animation_speed,
			scale = source_animation.scale or 1,
			tint = source_animation.tint,
			blend_mode = source_animation.blend_mode,
			load_in_minimal_mode = source_animation.load_in_minimal_mode,
			premul_alpha = source_animation.premul_alpha,
			generate_sdf = source_animation.generate_sdf,

			-- Extend vanilla function with additional parameters.
			run_mode = source_animation.run_mode,
			frame_sequence = source_animation.frame_sequence,
		}

		return animation_for_direction
	end

	---Creates the `Animation` object for the given `direction` using the given `source_animation`.
	---@param direction DirectionDefines # The direction to create the animation for.
	---@return Animation # The new animation for the given `direction`.
	---@nodiscard
	local function make_animation_for_direction(direction)
		if animation_copy.layers then
			local new_animation = { layers = {} }
			-- Assigned by index rather than appended, so each layer keeps the
			-- position it had; layer order is draw order.
			for index, layer in pairs(animation_copy.layers) do
				new_animation.layers[index] = make_animation_layer_for_direction(direction, layer)
			end
			return new_animation --[[@as Animation]]
		else
			return make_animation_layer_for_direction(direction, animation_copy)
		end
	end

	---@type Animation4Way
	local animation_4way = {
		north = make_animation_for_direction(defines.north),
		east = make_animation_for_direction(defines.east),
		south = make_animation_for_direction(defines.south),
		west = make_animation_for_direction(defines.west),
	}

	return animation_4way
end

local check_make_4way_animation_from_spritesheet = V.signature("make_4way_animation_from_spritesheet", {
	{ "animation", Common.animation_spritesheet },
})

---
---Creates an `Animation4Way` object using the given `animation`, parsing the `line_length`
---and `frame_count` fields to slice a sprite sheet into direction-based `Animation` objects.
---
---### Parameters
---@param animation VerticallyOrientableAnimation|Animation # The animation object to create the 4-way animation from.
---
---### Returns
---@return Animation4Way|Sprite4Way # The 4-way animation object created from `animation`.
---
---### Exceptions
---*@throws* `string` — Thrown when `animation` does not name the artwork it is cut from.
---@nodiscard
function _sprites.make_4way_animation_from_spritesheet(animation)
	check_make_4way_animation_from_spritesheet(animation)

	return build_4way_animation(animation)
end

local check_make_4way_working_visualisations_from_spritesheet =
	V.signature("make_4way_working_visualisations_from_spritesheet", {
		{ "visualisations", Common.working_visualisation },
	})

---
---Creates a `WorkingVisualisation` object using the given `visualisations`, slicing the sprite
---sheet referenced by its `animation` field into direction-based `north_animation`,
---`east_animation`, `south_animation`, and `west_animation` fields.
---
---### Remarks
---Internally delegates to `make_4way_animation_from_spritesheet` to slice `visualisations.animation`,
---so the same `vertically_oriented`, `run_mode`, and `frame_sequence` handling applies.
---
---`visualisations` is not modified.
---
---### Examples
---```lua
---local working_visualisations = _sprites.make_4way_working_visualisations_from_spritesheet({
---    always_draw = true,
---    animation = {
---        filename = "__mod-name__/graphics/entity/prototype/prototype.png",
---        priority = "extra-high",
---        width = 660,
---        height = 460,
---        frame_count = 4,
---        scale = 0.5,
---    },
---})
---```
---
---### Parameters
---@param visualisations WorkingVisualisation # The working visualisation object to create the 4-way working visualisation from. Must contain an `animation` field.
---
---### Returns
---@return WorkingVisualisation # A copy of `visualisations` with `animation` replaced by the direction-based animation fields.
---@nodiscard
function _sprites.make_4way_working_visualisations_from_spritesheet(visualisations)
	check_make_4way_working_visualisations_from_spritesheet(visualisations)

	local animation = build_4way_animation(visualisations.animation--[[@cast-?]])

	local copy = util.copy(visualisations)
	copy.animation = nil

	copy.north_animation = animation.north
	copy.east_animation = animation.east
	copy.south_animation = animation.south
	copy.west_animation = animation.west

	return copy
end

local check_make_rotated_animation_variations_from_spritesheet =
	V.signature("make_rotated_animation_variations_from_spritesheet", {
		{ "variation_count", Common.positive_integer },
		{ "sheet", Common.animation_spritesheet },
	})

---
---Creates a `RotatedAnimationVariations` object from the given `sheet`, slicing the sprite sheet
---into `variation_count` individual `RotatedAnimation` objects by computing the Y offset for each.
---
---Each variation is assumed to occupy the same vertical span on the sheet, derived from
---`frame_count`, `line_length`, and `direction_count` on the source animation layer.
---
---### Examples
---```lua
---local variations = _sprites.make_rotated_animation_variations_from_spritesheet(4, {
---    filename = "__mod-name__/graphics/entity/prototype/prototype.png",
---    priority = "high",
---    width = 128,
---    height = 128,
---    direction_count = 36,
---    frame_count = 1,
---})
---```
---
---### Parameters
---@param variation_count integer # The number of variations to slice from `sheet`.
---@param sheet RotatedAnimation # The source animation referencing a sprite sheet with all variations stacked vertically.
---
---### Returns
---@return RotatedAnimationVariations # An array of `RotatedAnimation` objects, one per variation.
---@nodiscard
function _sprites.make_rotated_animation_variations_from_spritesheet(variation_count, sheet)
	check_make_rotated_animation_variations_from_spritesheet(variation_count, sheet)

	---@type RotatedAnimationVariations
	local result = {}

	---@param variation RotatedAnimation
	---@param i integer
	local function set_y_offset(variation, i)
		local frame_count = math.max(variation.frame_count or 1, 1)
		local line_length = math.max(variation.line_length or frame_count, 1)

		local height = math.max(get_height(variation) or 0, 0)
		local direction_count = math.max(variation.direction_count or 1, 1)
		local height_in_frames = math.floor((frame_count * direction_count + line_length - 1) / line_length)
		variation.y = (height or 0) * (i - 1) * height_in_frames
	end

	for i = 1, variation_count do
		local variation = util.copy(sheet) --[[@as RotatedAnimation]]

		if variation.layers then
			for _, layer in pairs(variation.layers) do
				set_y_offset(layer, i)
			end
		else
			set_y_offset(variation, i)
		end

		table.insert(result, variation)
	end
	return result
end

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

---Rescales the given prototype in place.
---
---The working half of `rescale_prototype`, without the validation. It recurses
---into every nested table, so validating here would re-check the same
---prototype once per node of it.
---@param entity_prototype table # The prototype to rescale.
---@param scalar double # The scale factor to resize the prototype by.
local function apply_rescale(entity_prototype, scalar)
	---Recursively scales all numeric values in the given `table`, regardless of depth.
	---@generic T
	---@param table T # The table to rescale.
	---@return T # The rescaled table.
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

		if included_fields[key] ~= nil then
			if type(value) == "table" then
				entity_prototype[key] = rescale_table_recursively(util.copy(value))
			elseif type(value) == "number" then
				entity_prototype[key] = value * scalar
			else
				-- Do nothing.
			end
		elseif excluded_fields[key] ~= nil then
			-- Do nothing.
		elseif type(value) == "table" then
			apply_rescale(value, scalar)

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

---Returns a rescaled copy of the given prototype.
---
---The working half of `get_rescaled_prototype`, without the validation.
---@generic T
---@param entity_prototype T # The prototype to rescale.
---@param scalar double # The scale factor to resize the prototype by.
---@return T # A rescaled copy.
---@nodiscard
local function rescaled_copy(entity_prototype, scalar)
	local entity_prototype_copy = util.copy(entity_prototype)
	apply_rescale(entity_prototype_copy, scalar)

	return entity_prototype_copy
end

local check_rescale_prototype = V.signature("rescale_prototype", {
	{ "entity_prototype", V.table() },
	{ "scalar", Common.positive_number },
})

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
---_sprites.rescale_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---
----- Rescale the "oil-refinery" by a factor of 3 / 5.
----- The resulting entity will have a 3 x 3 tile footprint, and sprite to match.
---_sprites.rescale_prototype(data.raw["assembling-machine"]["oil-refinery"], 3 / 5)
---```
---
---### Parameters
---@param entity_prototype any # The entity prototype to rescale.
---@param scalar double # The scale factor to resize the prototype by.
function _sprites.rescale_prototype(entity_prototype, scalar)
	check_rescale_prototype(entity_prototype, scalar)

	apply_rescale(entity_prototype, scalar)
end

local check_get_rescaled_prototype = V.signature("get_rescaled_prototype", {
	{ "entity_prototype", V.table() },
	{ "scalar", Common.positive_number },
})

---Returns a rescaled copy of the given `prototype`, resized by the given `scalar`.
---
---Recursively iterates through a copy of the given `prototype` and applies the given `scalar` to all
---the numeric values in the fields listed in `included_fields`.
---
---### Remarks
---`scalar` is recommended to be the ratio of the new tile and the original tile size.
---For example, if rescaling a 5 x 5 tile entity to a 3 x 3 tile entity, `scalar` should be `3 / 5`.
---
---`prototype` is not modified.
---
---### Examples
---```lua
----- Get a rescaled copy of the "big-electric-pole" by a factor of 2.
----- The resulting entity will have a 4 x 4 tile footprint, and sprite to match.
---local rescaled = _sprites.get_rescaled_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---
----- Get a rescaled copy of the "oil-refinery" by a factor of 3 / 5.
----- The resulting entity will have a 3 x 3 tile footprint, and sprite to match.
---local rescaled = _sprites.get_rescaled_prototype(data.raw["assembling-machine"]["oil-refinery"], 3 / 5)
---```
---
---### Parameters
---@generic T
---@param entity_prototype T # The entity prototype to rescale.
---@param scalar double # The scale factor to resize the prototype by.
---
---### Returns
---@return T # A rescaled copy of `entity_prototype`.
---
---### See Also
---@see Sprites.rescale_prototype
---@nodiscard
function _sprites.get_rescaled_prototype(entity_prototype, scalar)
	check_get_rescaled_prototype(entity_prototype, scalar)

	return rescaled_copy(entity_prototype, scalar)
end

local check_rescale_remnants_of_prototype = V.signature("rescale_remnants_of_prototype", {
	-- Optional: a prototype that is not there is a no-op rather than a fault,
	-- so callers may hand over whatever a lookup gave them.
	{ "prototype", V.table():optional() },
	{ "scalar", Common.positive_number },
})

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
---_sprites.rescale_remnants_of_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---```
---
---### Parameters
---@param prototype EntityWithHealthPrototype # The entity with the remnants to rescale.
---@param scalar double # The scale factor to resize the prototype by.
---
---### See Also
---@see Sprites.rescale_prototype
function _sprites.rescale_remnants_of_prototype(prototype, scalar)
	check_rescale_remnants_of_prototype(prototype, scalar)

	if not prototype then
		return
	end

	local corpse_names = type(prototype.corpse) == "table" and prototype.corpse or { prototype.corpse }

	---@type EntityID[]
	local new_corpse_names = {}
	for _, name in pairs(corpse_names) do
		local corpse = data.raw.corpse[name]
		if corpse ~= nil then
			local rescaled_corpse = rescaled_copy(corpse, scalar)
			rescaled_corpse.name = "ar-remnant" .. rescaled_corpse.name
			data:extend({ rescaled_corpse })

			new_corpse_names[#new_corpse_names + 1] = rescaled_corpse.name
		end
	end

	if #new_corpse_names > 1 then
		prototype.corpse = new_corpse_names
	elseif #new_corpse_names == 1 then
		prototype.corpse = new_corpse_names[1]
	end
end

return _sprites
