---@using data

---@namespace Reskins.SpriteUtils

---Provides methods for finding the transport-belt-connectable prototypes that use the belt animation set of a transport
---belt, and for setting a belt animation set on them.
---
---#### Examples
---```lua
---local _belt_animation_sets = require("__reskins-sprite-utils__.belt-animation-sets")
---```
---@class BeltAnimationSets
local _belt_animation_sets = {}

local V = require("validation")
local Common = require("validation.common")
local _colors = require("colors")

-- The prototype types that `find_belt_animation_set_users` searches, which do not include `transport-belt`.
local user_types = {
	"underground-belt",
	"splitter",
	"lane-splitter",
	"loader",
	"loader-1x1",
	"linked-belt",
}

---A validator that checks that a value is a prototype, as a table with a `type` and a `name`.
local prototype = V.class("TransportBeltConnectablePrototype", {
	type = Common.prototype_type_name,
	name = Common.prototype_name,
}):describe_as("a prototype")

local check_get_belt_animation_set_identity = V.signature("get_belt_animation_set_identity", {
	{ "prototype", prototype },
})

local check_find_belt_animation_set_users = V.signature("find_belt_animation_set_users", {
	{ "prototype", prototype },
})

local check_set_belt_animation_set = V.signature("set_belt_animation_set", {
	{ "prototypes", V.array(prototype) },
	{ "belt_animation_set", V.table():describe_as("a TransportBeltAnimationSet") },
})

---Gets the given `tint` as text, or an empty string when `tint` is `nil`.
---@param tint? Color
---@return string
local function format_tint(tint)
	if tint == nil then
		return ""
	end

	local color = _colors.normalize(tint)
	return string.format("[%.3f,%.3f,%.3f,%.3f]", color.r, color.g, color.b, color.a)
end

---Adds the file name and the tint of each layer of the given `animation` to `parts` in order, in place.
---@param animation table A `RotatedAnimation`, or a layer of one.
---@param parts string[] The array to which the text of each layer is added.
local function add_layer_parts(animation, parts)
	if animation.layers then
		for _, layer in pairs(animation.layers) do
			add_layer_parts(layer, parts)
		end
		return
	end

	local filenames = {}
	if animation.filename then
		filenames[1] = animation.filename
	elseif animation.filenames then
		filenames = animation.filenames
	elseif animation.stripes then
		for _, stripe in pairs(animation.stripes) do
			filenames[#filenames + 1] = stripe.filename
		end
	end

	parts[#parts + 1] = table.concat(filenames, ",") .. format_tint(animation.tint)
end

---Gets the identity of the belt animation set of the given `prototype`, from the file name and the tint of each layer
---of its animation set and the speed of `prototype`.
---
---Two prototypes with belt animation sets that draw the same files in the same tints, at the same speed, have the same
---identity, whether or not they share one table. The identity is lowercase, so the file names are compared without
---regard to case.
---@param prototype TransportBeltConnectablePrototype The prototype with the belt animation set.
---@return string? # The identity, or `nil` when `prototype` has no belt animation set.
---
---#### Examples
---```lua
----- Get the identities of the transport belt and the underground belt of the base game.
---local belt = _belt_animation_sets.get_belt_animation_set_identity(data.raw["transport-belt"]["transport-belt"])
---local underground =
---    _belt_animation_sets.get_belt_animation_set_identity(data.raw["underground-belt"]["underground-belt"])
----- `belt` and `underground` are equal.
---```
---@throws When `prototype` is not a prototype.
---@nodiscard
function _belt_animation_sets.get_belt_animation_set_identity(prototype)
	check_get_belt_animation_set_identity(prototype)

	local belt_animation_set = prototype.belt_animation_set
	if belt_animation_set == nil or belt_animation_set.animation_set == nil then
		return nil
	end

	local parts = {}
	add_layer_parts(belt_animation_set.animation_set, parts)
	parts[#parts + 1] = tostring(prototype.speed)

	return string.lower(table.concat(parts, "|"))
end

---Gets each underground belt, splitter, lane splitter, loader, 1 x 1 loader, and linked belt with the same belt
---animation set identity as the given `prototype`.
---
---Call this function before the belt animation set of `prototype` is replaced. A prototype with a different speed from
---`prototype` is not found. Any prototype with the same identity is found, including one that belongs to another
---transport belt with the same files, tints, and speed.
---@param prototype TransportBeltConnectablePrototype The transport belt.
---@return TransportBeltConnectablePrototype[] # The prototypes in `data.raw` that use the belt animation set, other than `prototype`. The array is empty when `prototype` has no belt animation set.
---
---#### Examples
---```lua
----- Replace the belt animation set of the fast transport belt and of the prototypes that use it.
---local belt = data.raw["transport-belt"]["fast-transport-belt"]
---local users = _belt_animation_sets.find_belt_animation_set_users(belt)
---belt.belt_animation_set = {
---    animation_set = {
---        filename = "__mod-name__/graphics/entity/transport-belt/transport-belt.png",
---        priority = "extra-high",
---        size = 128,
---        scale = 0.5,
---        frame_count = 16,
---        direction_count = 20,
---    },
---}
---_belt_animation_sets.set_belt_animation_set(users, belt.belt_animation_set)
----- The fast underground belt and the fast splitter have a copy of the new belt animation set.
---```
---@throws When `prototype` is not a prototype.
---@see BeltAnimationSets.set_belt_animation_set
---@nodiscard
function _belt_animation_sets.find_belt_animation_set_users(prototype)
	check_find_belt_animation_set_users(prototype)

	local users = {}
	local identity = _belt_animation_sets.get_belt_animation_set_identity(prototype)
	if identity == nil then
		return users
	end

	for _, type_name in pairs(user_types) do
		for _, candidate in pairs(data.raw[type_name] or {}) do
			---@cast candidate TransportBeltConnectablePrototype
			if candidate ~= prototype and _belt_animation_sets.get_belt_animation_set_identity(candidate) == identity then
				users[#users + 1] = candidate
			end
		end
	end

	return users
end

---Sets a copy of the given `belt_animation_set` on each of the given `prototypes`, in place.
---@param prototypes TransportBeltConnectablePrototype[] The prototypes to modify.
---@param belt_animation_set TransportBeltAnimationSet The belt animation set to copy, which is not modified.
---@throws When `prototypes` is not an array of prototypes.
---@throws When `belt_animation_set` is not a table.
function _belt_animation_sets.set_belt_animation_set(prototypes, belt_animation_set)
	check_set_belt_animation_set(prototypes, belt_animation_set)

	for _, target in pairs(prototypes) do
		target.belt_animation_set = util.copy(belt_animation_set)
	end
end

return _belt_animation_sets
