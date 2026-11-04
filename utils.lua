---@using data

---@namespace Reskins.SpriteUtils

---Provides general utility methods.
---
---#### Examples
---```lua
---local _utils = require("__reskins-sprite-utils__.utils")
---```
---@class Utils
local _utils = {}

local V = require("validation")
local Common = require("validation.common")

---A validator that checks that a value is an array, without validating its elements.
local any_array = V.array(V.any()):describe_as("an array")

local check_unpack_vector = V.signature("unpack_vector", {
	{ "vector", Common.vector },
})

---Gets the x and y components of the given `vector`, in either the named or the array form.
---@param vector Vector|MapPosition The vector or position to unpack.
---@return double x The horizontal component.
---@return double y The vertical component.
---
---#### Examples
---```lua
----- Get the components of a vector in the array form and in the named form.
---local x, y = _utils.unpack_vector({ 0.5, -1 })
----- 0.5, -1
---
---local x, y = _utils.unpack_vector({ x = 0.5, y = -1 })
----- 0.5, -1
---```
---@throws When `vector` is not a `Vector`.
---@nodiscard
function _utils.unpack_vector(vector)
	check_unpack_vector(vector)

	if vector.x ~= nil then
		return vector.x, vector.y
	end

	return vector[1], vector[2]
end

---Concatenates the given arrays into a new array.
---
---The elements are copied by reference. The given arrays are not modified. A `nil` argument is skipped.
---
---@generic T
---@param ... T[] The arrays to concatenate.
---@return T[] # A new array that contains the elements of each given array, in order.
---
---#### Examples
---```lua
----- Concatenate the base layers and the tint layers.
---local base_layers = { base_animation, base_shadow_animation }
---local tint_layers = { mask_animation, highlights_animation }
---
---local layers = _utils.array_concat(base_layers, tint_layers)
----- { base_animation, base_shadow_animation, mask_animation, highlights_animation }
---```
---@throws When an argument is neither an array nor `nil`.
---@nodiscard
function _utils.array_concat(...)
	local concatenated = {}

	for index, elements in pairs({ ... }) do
		any_array:assert(elements, string.format("...[%d]", index), "array_concat")

		for element_index = 1, #elements do
			concatenated[#concatenated + 1] = elements[element_index]
		end
	end

	return concatenated
end

return _utils
