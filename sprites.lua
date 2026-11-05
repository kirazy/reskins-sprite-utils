---cspell: words premul
---@using data

---@namespace Reskins.SpriteUtils

---Provides methods for manipulating sprites.
---
---#### Examples
---```lua
---local _sprites = require("__reskins-sprite-utils__.sprites")
---```
---@class Sprites
local _sprites = {}

local _icons = require("icons")
local V = require("validation")
local Common = require("validation.common")

---The number of pixels in one tile.
local TILE_SIZE = 32

---Converts the given `icon_layer` into a sprite layer.
---@param icon_layer SafeIconData An icon layer with missing fields set to default values.
---@param scale? double The factor by which the scale and shift of the layer are multiplied.
---@return Sprite
---@nodiscard
local function convert_icon_layer_to_sprite_layer(icon_layer, scale)
	local icon_copy = icon_layer
	local scale_to_apply = scale and scale * icon_copy.scale or icon_copy.scale

	-- Icon shifts are in pixels and sprite shifts are in tiles. Both are converted by `TILE_SIZE`.
	local converted_shift = icon_copy.shift and util.mul_shift(icon_copy.shift, (scale or 1) / TILE_SIZE) or nil

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
	-- The argument is checked as a table only. `icons.add_missing_icons_defaults` validates the icon
	-- data and reports failures by index.
	{ "icon_data", V.table() },
	{ "scale", Common.positive_number:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a `Sprite` from the given `icon_data`, resized by the given `scale`.
---
---A single layer is converted to a `Sprite` with the `icon` flag. Two or more layers are converted to a layered
---`Sprite`. Missing icon fields are set to default values as appropriate. `icon_data` is not modified.
---
---#### Parameters
---@param icon_data IconData[] An array of `IconData` objects.
---@param scale? double The factor by which the scale and shift of every layer are multiplied. Default `1`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults of `icon_data`, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.constant.default_icon_size`.
---
---#### Returns
---@return Sprite # A `Sprite` with one layer per element of `icon_data`.
---
---#### Examples
---```lua
----- Convert a two-layer icon into the in-world sprite of an item.
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
----- sprite.layers[2].shift is { -0.5, -0.5 }, in tiles.
---```
---@throws When `icon_data` is not a non-empty array of valid `IconData` objects.
---@throws When `scale` is not a number greater than 0.
---@throws When `defaults_type` is an empty string.
---@nodiscard
function _sprites.create_sprite_from_icons(icon_data, scale, defaults_type)
	check_create_sprite_from_icons(icon_data, scale, defaults_type)

	local defaulted = _icons.add_missing_icons_defaults(icon_data, defaults_type)

	if #defaulted == 1 then
		return convert_icon_layer_to_sprite_layer(defaulted[1], scale)
	end

	local sprite = { layers = {} }
	for index = 1, #defaulted do
		sprite.layers[index] = convert_icon_layer_to_sprite_layer(defaulted[index], scale)
	end

	return sprite
end

local check_create_sprite_from_icon = V.signature("create_sprite_from_icon", {
	-- The icon is validated by `add_missing_icon_defaults`.
	{ "icon_datum", V.table() },
	{ "scale", Common.positive_number:optional() },
	{ "defaults_type", Common.icon_defaults_type:optional() },
})

---Creates a `Sprite` from the given `icon_datum`, resized by the given `scale`.
---
---The sprite has the `icon` flag. Missing icon fields are set to default values as appropriate. `icon_datum` is not
---modified.
---
---#### Parameters
---@param icon_datum IconData An `IconData` object.
---@param scale? double The factor by which the scale and shift of the layer are multiplied. Default `1`.
---@param defaults_type? IconDefaultsType The name of the type-specific icon defaults of `icon_datum`, as per [IconData::scale](https://lua-api.factorio.com/latest/types/IconData.html#scale). Unrecognized names resolve to `defines.constant.default_icon_size`.
---
---#### Returns
---@return Sprite # A `Sprite` with the file, size, scale, shift, and tint of `icon_datum`.
---
---#### Examples
---```lua
----- Convert an icon layer into the in-world sprite of an item.
------@type IconData
---local icon_datum = {
---    icon = "__base__/graphics/icons/iron-plate.png",
---    icon_size = 64,
---    scale = 0.5,
---}
---
---local sprite = _sprites.create_sprite_from_icon(icon_datum, 1.0)
----- { flags = { "icon" }, filename = "__base__/graphics/icons/iron-plate.png", size = 64, scale = 0.5 }
---```
---@throws When `icon_datum` is not a valid `IconData`.
---@throws When `scale` is not a number greater than 0.
---@throws When `defaults_type` is an empty string.
---@nodiscard
function _sprites.create_sprite_from_icon(icon_datum, scale, defaults_type)
	check_create_sprite_from_icon(icon_datum, scale, defaults_type)

	return convert_icon_layer_to_sprite_layer(_icons.add_missing_icon_defaults(icon_datum, defaults_type), scale)
end

---Gets the height in pixels of the given `prototype`, from `height` or `size`, or 0 if neither is set.
---@param prototype? { height?: SpriteSizeType, size?: (SpriteSizeType)|([SpriteSizeType, SpriteSizeType]) }
---@return SpriteSizeType
---@nodiscard
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

---Gets the width in pixels of the given `prototype`, from `width` or `size`, or 0 if neither is set.
---@param prototype? { width?: SpriteSizeType, size?: (SpriteSizeType)|([SpriteSizeType, SpriteSizeType]) }
---@return SpriteSizeType
---@nodiscard
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

---Creates an `Animation4Way` from the given `animation` by slicing its sprite sheet into one `Animation` per direction,
---without validating it.
---@param animation VerticallyOrientableAnimation|Animation The animation with the sprite sheet to slice.
---@return Animation4Way # An `Animation4Way` with one `Animation` per direction.
---@nodiscard
local function build_4way_animation(animation)
	local animation_copy = util.copy(animation)

	---Represents a cardinal direction as an integer index.
	---@class DirectionDefines : integer
	local defines = {
		north = 0,
		east = 1,
		south = 2,
		west = 3,
	}

	---Creates the `Animation` for the given `direction` from the sprite sheet of the given `source_animation`.
	---@param direction DirectionDefines The direction for which the animation is created.
	---@param source_animation VerticallyOrientableAnimation The animation with the sprite sheet from which the direction is cut.
	---@return Animation # The animation for the given `direction`.
	---@nodiscard
	local function make_animation_layer_for_direction(direction, source_animation)
		local start_frame = (source_animation.frame_count or 1) * direction
		local x, y = 0, 0

		-- Read the directions top to bottom on a vertically oriented sprite sheet.
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
			run_mode = source_animation.run_mode,
			frame_sequence = source_animation.frame_sequence,
		}

		return animation_for_direction
	end

	---Creates the `Animation` for the given `direction` from the copied animation, layer by layer when it has layers.
	---@param direction DirectionDefines The direction for which the animation is created.
	---@return Animation # The animation for the given `direction`.
	---@nodiscard
	local function make_animation_for_direction(direction)
		if animation_copy.layers then
			local new_animation = { layers = {} }
			for _, layer in pairs(animation_copy.layers) do
				new_animation.layers[#new_animation.layers + 1] = make_animation_layer_for_direction(direction, layer)
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

---Creates an `Animation4Way` from the given `animation` by slicing its sprite sheet into one `Animation` per direction.
---
---The `x` and `y` offsets of each direction are computed from the `frame_count`, `line_length`, `width`, and `height`
---of `animation`. The directions are read top to bottom when `vertically_oriented` is `true`.
---An animation with `layers` is sliced layer by layer.
---`animation` is not modified.
---
---#### Parameters
---@param animation VerticallyOrientableAnimation|Animation The animation with the sprite sheet to slice.
---
---#### Returns
---@return Animation4Way # An `Animation4Way` with one `Animation` per direction.
---
---#### Examples
---```lua
----- Slice a sheet with four frames per direction, one direction per row.
---local animation = _sprites.make_4way_animation_from_spritesheet({
---    filename = "__mod-name__/graphics/entity/prototype/prototype.png",
---    width = 128,
---    height = 128,
---    frame_count = 4,
---    line_length = 4,
---    scale = 0.5,
---})
----- animation.east.y is 128.
---```
---@throws When `animation` is not a sprite sheet with a `filename`, `filenames`, `stripes`, or `layers` field.
---@nodiscard
function _sprites.make_4way_animation_from_spritesheet(animation)
	check_make_4way_animation_from_spritesheet(animation)

	return build_4way_animation(animation)
end

local check_make_4way_working_visualisations_from_spritesheet =
	V.signature("make_4way_working_visualisations_from_spritesheet", {
		{ "visualisations", Common.working_visualisation },
	})

---Creates a `WorkingVisualisation` from the given `visualisations` by slicing the sprite sheet of its `animation` into
---the `north_animation`, `east_animation`, `south_animation`, and `west_animation` fields.
---
---The `animation` is sliced as by `make_4way_animation_from_spritesheet`. `visualisations` is not modified.
---
---#### Parameters
---@param visualisations WorkingVisualisation The working visualisation with the `animation` to slice.
---
---#### Returns
---@return WorkingVisualisation # A copy of `visualisations` with `animation` replaced by the four direction fields.
---
---#### Examples
---```lua
----- Slice a sheet with four frames per direction into the four direction fields.
---local working_visualisation = _sprites.make_4way_working_visualisations_from_spritesheet({
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
----- working_visualisation.animation is nil, and working_visualisation.east_animation.x is 660.
---```
---@throws When `visualisations` is not a `WorkingVisualisation` with an `animation` that is a sprite sheet.
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

---Creates a `RotatedAnimationVariations` from the given `sheet` by slicing the sprite sheet into `variation_count`
---`RotatedAnimation` objects, each with its own `y` offset.
---
---Every variation occupies the same number of rows of the sheet, computed from the `frame_count`, `line_length`, and
---`direction_count` of `sheet`. A sheet with `layers` is sliced layer by layer. `sheet` is not modified.
---
---#### Parameters
---@param variation_count integer The number of variations to slice from `sheet`.
---@param sheet RotatedAnimation The animation with the sprite sheet on which the variations are stacked top to bottom.
---
---#### Returns
---@return RotatedAnimationVariations # An array of `RotatedAnimation` objects, one per variation.
---
---#### Examples
---```lua
----- Slice four variations of a 36-direction sheet, each one direction per row.
---local variations = _sprites.make_rotated_animation_variations_from_spritesheet(4, {
---    filename = "__mod-name__/graphics/entity/prototype/prototype.png",
---    priority = "high",
---    width = 128,
---    height = 128,
---    direction_count = 36,
---    frame_count = 1,
---})
----- variations[2].y is 4608.
---```
---@throws When `variation_count` is not an integer greater than 0.
---@throws When `sheet` is not a sprite sheet with a `filename`, `filenames`, `stripes`, or `layers` field.
---@nodiscard
function _sprites.make_rotated_animation_variations_from_spritesheet(variation_count, sheet)
	check_make_rotated_animation_variations_from_spritesheet(variation_count, sheet)

	---@type RotatedAnimationVariations
	local result = {}

	---Sets the `y` of the given `variation` to the offset of the `i`th variation on the sheet.
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

---Gets the given `value` with every number in it, at every depth, multiplied by the given `scalar`.
---
---The result is a copy.
---@generic T
---@param value T
---@param scalar double
---@return T
---@nodiscard
local function get_scaled_numbers(value, scalar)
	if type(value) == "number" then
		return value * scalar
	elseif type(value) == "table" then
		local scaled = {}
		for key, item in pairs(value) do
			scaled[key] = get_scaled_numbers(item, scalar)
		end

		return scaled
	end

	return value
end

---Gets the given `sprite` with its shift, or the shift of each of its layers, moved by the given `offset`.
---
---The result is a copy.
---@param sprite Sprite
---@param offset Vector
---@return Sprite
---@nodiscard
local function get_moved_sprite(sprite, offset)
	local moved = util.copy(sprite)
	local layers = sprite.layers
	if layers ~= nil then
		local moved_layers = {}
		for index, layer in pairs(layers) do
			moved_layers[index] = get_moved_sprite(layer, offset)
		end

		moved.layers = moved_layers
	else
		moved.shift = util.add_shift(sprite.shift or { 0, 0 }, offset)
	end

	return moved
end

---Gets the mean of the vectors in the given `wire_position`.
---@param wire_position WirePosition
---@return Vector? # `nil` when `wire_position` holds no vectors.
local function get_mean_wire_position(wire_position)
	---@type Vector
	local sum = { 0, 0 }
	local count = 0
	for _, vector in pairs(wire_position) do
		sum = util.add_shift(sum, vector)
		count = count + 1
	end

	if count == 0 then
		return nil
	end

	return util.mul_shift(sum, 1 / count)
end

---Gets a copy of the given `definition` that is moved to match an entity resized by the given `scalar`.
---
---The sprites of the definition keep their size. Each of `points.wire` and `points.shadow` is moved so that its mean is
---at its scaled position. Each sprite and light offset is moved with `points.shadow` when its name contains "shadow",
---and with `points.wire` otherwise. The wire positions of a definition without sprites are scaled.
---@param definition CircuitConnectorDefinition
---@param scalar double
---@return CircuitConnectorDefinition
---@nodiscard
local function get_moved_circuit_connector_definition(definition, scalar)
	local moved = util.copy(definition)
	local points = definition.points
	if points == nil then
		return moved
	end

	if definition.sprites == nil then
		-- The wires attach to the sprite of the entity.
		moved.points = get_scaled_numbers(points, scalar)
		return moved
	end

	-- The shadow is moved separately because the distance between a connector and its shadow depends on the height of
	-- the connector on the entity, which is scaled.
	---@type table<string, Vector>
	local offsets = {}
	local moved_points = moved.points --[[@as table<string, WirePosition>]]
	for name, wire_position in
		pairs(points --[[@as table<string, WirePosition>]])
	do
		local position = get_mean_wire_position(wire_position)
		if position ~= nil then
			local offset = util.mul_shift(position, scalar - 1) --[[@as Vector]]
			offsets[name] = offset

			---@type WirePosition
			local moved_wire_position = {}
			for color, vector in pairs(wire_position) do
				moved_wire_position[color] = util.add_shift(vector, offset)
			end

			moved_points[name] = moved_wire_position
		end
	end

	-- Each value is computed from `definition`, so a table that appears twice in it is not moved twice.
	local moved_sprites = moved.sprites --[[@as table<string, any>]]
	for name, value in
		pairs(definition.sprites --[[@as table<string, any>]])
	do
		local offset = offsets[name:find("shadow", 1, true) and "shadow" or "wire"]

		-- A sprite has a `filename` or `layers`, and a light offset is a vector. Other fields are not modified.
		if offset ~= nil and type(value) == "table" then
			if value.filename ~= nil or value.layers ~= nil then
				moved_sprites[name] = get_moved_sprite(value, offset)
			elseif value[1] ~= nil or value.x ~= nil then
				moved_sprites[name] = util.add_shift(value, offset)
			end
		end
	end

	return moved
end

---Gets a copy of the given `circuit_connector` that is moved to match an entity resized by the given `scalar`.
---@param circuit_connector CircuitConnectorDefinition | CircuitConnectorDefinition[]
---@param scalar double
---@return CircuitConnectorDefinition | CircuitConnectorDefinition[]
---@nodiscard
local function get_moved_circuit_connector(circuit_connector, scalar)
	-- A single definition has `points` or `sprites`, and an array of definitions has neither.
	if circuit_connector.points ~= nil or circuit_connector.sprites ~= nil then
		return get_moved_circuit_connector_definition(circuit_connector --[[@as CircuitConnectorDefinition]], scalar)
	end

	---@type CircuitConnectorDefinition[]
	local moved = {}
	for index, definition in
		pairs(circuit_connector --[[@as CircuitConnectorDefinition[] ]])
	do
		moved[index] = get_moved_circuit_connector_definition(definition, scalar)
	end

	return moved
end

-- `apply_rescale` filters fields with these tables.
local scaled_fields = {
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
	["tile_width"] = true,
	["tile_height"] = true,
	["source_offset"] = true,
	["projectile_center"] = true,
	["projectile_creation_distance"] = true,
	["drawing_box_vertical_extension"] = true,

	-- Each of these fields holds a `WireConnectionPoint` or an array of them, which hold only positions.
	["circuit_wire_connection_points"] = true,
	["circuit_wire_connection_point"] = true,
	["connection_points"] = true,
	["input_connection_points"] = true,
	["output_connection_points"] = true,
	["left_wire_connection_point"] = true,
	["right_wire_connection_point"] = true,

	-- Each of these fields holds a position, a height, a distance, or an array of positions of an artillery cannon.
	["cannon_base_shift"] = true,
	["cannon_base_height"] = true,
	["cannon_base_shift_when_vertical"] = true,
	["cannon_base_shift_when_horizontal"] = true,
	["cannon_barrel_recoil_shiftings"] = true,

	-- A `TurretSpecialEffect` holds only positions and distances.
	["special_effect"] = true,

	-- Each of these fields holds an `AnimatedVector`, which holds only positions.
	["preparing_muzzle_animation_shift"] = true,
	["prepared_muzzle_animation_shift"] = true,
	["starting_attack_muzzle_animation_shift"] = true,
	["attacking_muzzle_animation_shift"] = true,
	["ending_attack_muzzle_animation_shift"] = true,
	["folding_muzzle_animation_shift"] = true,
	["folded_muzzle_animation_shift"] = true,
}

---Gets a rescaled copy of the given `heat_buffer`, in which the `connections` are not modified, without validating
---the arguments.
---@param heat_buffer table The heat buffer to rescale.
---@param scalar double The factor by which the heat buffer is resized.
---@param rescale fun(subset: table, scalar: double, visited: table<table, true>) The function that rescales a table in place.
---@return table # A rescaled copy of `heat_buffer`.
---@nodiscard
local function get_rescaled_heat_buffer(heat_buffer, scalar, rescale)
	local rescaled = util.copy(heat_buffer)
	local connections = rescaled.connections

	-- Heat connections are positions in the tiles the entity occupies, and are not scaled.
	rescaled.connections = nil
	rescale(rescaled, scalar, {})
	rescaled.connections = connections

	return rescaled
end

---Gets a rescaled copy of the given `shell_particle`, without validating the arguments.
---
---The `center` and the `creation_distance` are scaled. The other fields are not modified.
---@param shell_particle table The shell particle to rescale.
---@param scalar double The factor by which the shell particle is resized.
---@return table # A rescaled copy of `shell_particle`.
---@nodiscard
local function get_rescaled_shell_particle(shell_particle, scalar)
	local rescaled = util.copy(shell_particle)
	rescaled.center = rescaled.center and get_scaled_numbers(rescaled.center, scalar)
	rescaled.creation_distance = rescaled.creation_distance and rescaled.creation_distance * scalar

	return rescaled
end

-- Each of these fields is replaced with the result of its function, and `apply_rescale` does not recurse into it. The
-- function is given the function that rescales a nested table.
---@type table<string, fun(value: any, scalar: double, rescale: fun(subset: table, scalar: double, visited: table<table, true>)): any>
local handled_fields = {
	["circuit_connector"] = get_moved_circuit_connector,
	["circuit_connector_flipped"] = get_moved_circuit_connector,
	["heat_buffer"] = get_rescaled_heat_buffer,
	["shell_particle"] = get_rescaled_shell_particle,
}

local excluded_fields = {
	["fluid_boxes"] = true,
	["fluid_box"] = true,
	["energy_source"] = true,
	["input_fluid_box"] = true,
	["neighbour_connectable"] = true,

	-- Pipe covers are drawn on the tile beyond each connection, and keep their size.
	["pipe_covers"] = true,
	["pipe_covers_frozen"] = true,
	["heat_pipe_covers"] = true,

	-- The radius visualisation depicts a range in tiles, and keeps its size.
	["radius_visualisation_picture"] = true,

	-- A stripe has no `scale` and no positions.
	["stripes"] = true,
}

---Rescales the given `entity_prototype` in place, recursing into every nested table that is not in the given
---`visited`, without validating the arguments.
---@param entity_prototype table The prototype to rescale.
---@param scalar double The factor by which the prototype is resized.
---@param visited table<table, true> The tables that are already rescaled. `entity_prototype` is added to it.
local function rescale_table(entity_prototype, scalar, visited)
	visited[entity_prototype] = true

	local is_sprite = entity_prototype.filename or entity_prototype.stripes or entity_prototype.filenames

	-- Provide a reasonable default scale where not defined, so that rescaling has something to scale and an image
	---is not left the game's inferred scale. Use canon-typical violence.
	-- The default is set before the loop because assigning a new field during `pairs` is undefined.
	if is_sprite then
		entity_prototype.scale = entity_prototype.scale or 0.5
	end

	for key, value in pairs(entity_prototype) do
		if key == "position" and is_sprite then
			-- The `position` of a sprite is the position of its frame in the image file, in pixels.
		elseif scaled_fields[key] ~= nil then
			entity_prototype[key] = get_scaled_numbers(value, scalar)
		elseif handled_fields[key] ~= nil then
			entity_prototype[key] = handled_fields[key](value, scalar, rescale_table)
		elseif excluded_fields[key] ~= nil then
			-- Do nothing.
		elseif type(value) == "table" and not visited[value] then
			rescale_table(value, scalar, visited)
		end
	end
end

---Rescales the given `entity_prototype` in place, recursing into every nested table, without validating the
---arguments.
---
---A table that is reached more than once is rescaled once.
---@param entity_prototype table The prototype to rescale.
---@param scalar double The factor by which the prototype is resized.
local function apply_rescale(entity_prototype, scalar)
	rescale_table(entity_prototype, scalar, {})
end

---Gets a rescaled copy of the given `entity_prototype`, without validating the arguments.
---@generic T
---@param entity_prototype T The prototype to rescale.
---@param scalar double The factor by which the prototype is resized.
---@return T # A rescaled copy of `entity_prototype`.
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

---Resizes the given `entity_prototype` in place by the given `scalar`.
---
---The `scalar` is applied to the fields of the prototype that describe sizes and positions, at every depth, such as
---`scale`, `shift`, `collision_box`, `selection_box`, and the wire connection points of electric poles.
---
---Circuit connectors keep their size and are moved to the same position relative to the resized entity. The wire
---positions of a circuit connector without sprites are scaled.
---
---The `fluid_box`, `fluid_boxes`, `input_fluid_box`, and `energy_source` fields are not modified and will need to be
---handled separately to ensure a valid prototype.
---
---The `pipe_covers`, `pipe_covers_frozen`, and `heat_pipe_covers` fields are not modified at any depth. The
---`neighbour_connectable` field and the `connections` of the `heat_buffer` are not modified.
---
---The `radius_visualisation_picture` field is not modified.
---
---The `position` of a sprite is a position in its image file, and is not modified.
---
---A sprite with no `scale` is assumed to have a default `scale` of 0.5.
---
---Circuit connector definitions are replaced with copies. Other nested tables are modified in place, including tables
---that are shared with other prototypes. A table that is reached more than once is rescaled once.
---
---`scalar` is recommended to be the ratio of the new tile size and the original tile size. For example, if rescaling a
---5 x 5 tile entity to a 3 x 3 tile entity, `scalar` should be `3 / 5`.
---@param entity_prototype table The entity prototype to rescale.
---@param scalar double The factor by which the prototype is resized.
---
---#### Examples
---```lua
----- Rescale the "big-electric-pole" by a factor of 2.
----- The entity and its sprite are rescaled to fit a 4 x 4 tile bounding box.
---_sprites.rescale_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---
----- Rescale the "oil-refinery" by a factor of 3 / 5.
----- The entity and its sprite are rescaled to fit a 3 x 3 tile bounding box.
---_sprites.rescale_prototype(data.raw["assembling-machine"]["oil-refinery"], 3 / 5)
---```
---@throws When `entity_prototype` is not a table.
---@throws When `scalar` is not a number greater than 0.
---@see Sprites.get_rescaled_prototype
function _sprites.rescale_prototype(entity_prototype, scalar)
	check_rescale_prototype(entity_prototype, scalar)

	apply_rescale(entity_prototype, scalar)
end

local check_get_rescaled_prototype = V.signature("get_rescaled_prototype", {
	{ "entity_prototype", V.table() },
	{ "scalar", Common.positive_number },
})

---Resizes the given `entity_prototype` by the given `scalar`.
---
---The prototype is rescaled as by `rescale_prototype`. `entity_prototype` is not modified.
---
---`scalar` is recommended to be the ratio of the new tile size and the original tile size. For example, if rescaling a
---5 x 5 tile entity to a 3 x 3 tile entity, `scalar` should be `3 / 5`.
---@generic T
---@param entity_prototype T The entity prototype to rescale.
---@param scalar double The factor by which the prototype is resized.
---@return T # A rescaled copy of `entity_prototype`.
---
---#### Examples
---```lua
----- Get a rescaled copy of the "big-electric-pole" by a factor of 2.
----- The entity and its sprite are rescaled to fit a 4 x 4 tile bounding box.
---local rescaled = _sprites.get_rescaled_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
---
----- Get a rescaled copy of the "oil-refinery" by a factor of 3 / 5.
----- The entity and its sprite are rescaled to fit a 3 x 3 tile bounding box.
---local rescaled = _sprites.get_rescaled_prototype(data.raw["assembling-machine"]["oil-refinery"], 3 / 5)
---```
---@throws When `entity_prototype` is not a table.
---@throws When `scalar` is not a number greater than 0.
---@see Sprites.rescale_prototype
---@nodiscard
function _sprites.get_rescaled_prototype(entity_prototype, scalar)
	check_get_rescaled_prototype(entity_prototype, scalar)

	return rescaled_copy(entity_prototype, scalar)
end

local check_rescale_remnants_of_prototype = V.signature("rescale_remnants_of_prototype", {
	{ "prototype", V.table() },
	{ "scalar", Common.positive_number },
})

---Adds a rescaled copy of each corpse named by the `corpse` of the given `prototype` to `data.raw`, under its name
---prefixed with `ar-rescaled-`, and sets `corpse` on the prototype to the new names.
---
---Each copy is rescaled as by `rescale_prototype`. A corpse that does not exist is skipped, and the prototype is not
---modified when no corpse exists.
---
---`scalar` is recommended to be the ratio of the new tile size and the original tile size. For example, if rescaling a
---5 x 5 tile entity to a 3 x 3 tile entity, `scalar` should be `3 / 5`.
---@param prototype EntityWithHealthPrototype The entity with the corpse to rescale.
---@param scalar double The factor by which the corpse is resized.
---
---#### Examples
---```lua
----- Rescale the remnants of the "big-electric-pole" by a factor of 2.
---_sprites.rescale_remnants_of_prototype(data.raw["electric-pole"]["big-electric-pole"], 2)
----- The corpse of the pole is "ar-rescaled-big-electric-pole-remnants".
---```
---@throws When `prototype` is not a table.
---@throws When `scalar` is not a number greater than 0.
---@see Sprites.rescale_prototype
function _sprites.rescale_remnants_of_prototype(prototype, scalar)
	check_rescale_remnants_of_prototype(prototype, scalar)

	local corpse_names = type(prototype.corpse) == "table" and prototype.corpse or { prototype.corpse }

	---@type EntityID[]
	local new_corpse_names = {}
	for _, name in pairs(corpse_names) do
		local corpse = data.raw.corpse[name]
		if corpse ~= nil then
			local rescaled_corpse = rescaled_copy(corpse, scalar)
			rescaled_corpse.name = "ar-rescaled-" .. rescaled_corpse.name
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
