---@namespace Reskins.SpriteUtils

--- Provides low-level generalized utility methods.
---
---#### Examples
---```lua
---local _utils = require("__reskins-sprite-utils__.utils")
---```
---@class Utils
local _utils = {}

local V = require("validation")

---A validator that checks that a value is an array. Elements are not validated.
local any_array = V.array(V.any()):describe_as("an array")

---
---Concatenates the given arrays into a single new array, preserving order.
---
---Elements are copied by reference; the given arrays are not modified.
---
---An argument that is `nil` contributes nothing, so an array that is only
---sometimes wanted can be passed conditionally without standing in an empty one.
---
---#### Parameters
---@generic T
---@param ... T[] The arrays to concatenate.
---
---#### Returns
---@return T[] # A new array containing the elements of each given array, in order.
---
---#### Examples
---```lua
---local base_layers = { base_animation, base_shadow_animation }
---local tint_layers = { mask_animation, highlights_animation }
---
---local layers = _utils.array_concat(base_layers, tint_layers)
----- { base_animation, base_shadow_animation, mask_animation, highlights_animation }
---```
---@throws Thrown when an argument is neither an array nor `nil`.
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
