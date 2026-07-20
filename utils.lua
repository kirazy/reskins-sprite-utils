---@namespace Reskins.SpriteUtils

--- Provides low-level generalized utility methods.
---
---### Examples
---```lua
---local _utils = require("__reskins-sprite-utils__.utils")
---```
---@class Utils
local _utils = {}

---
---Concatenates the given arrays into a single new array, preserving order.
---
---Elements are copied by reference; the given arrays are not modified.
---
---### Examples
---```lua
---local base_layers = { base_animation, base_shadow_animation }
---local tint_layers = { mask_animation, highlights_animation }
---
---local layers = _utils.array_concat(base_layers, tint_layers)
----- { base_animation, base_shadow_animation, mask_animation, highlights_animation }
---```
---
---### Parameters
---@generic T
---@param ... T[] # The arrays to concatenate.
---
---### Returns
---@return T[] # A new array containing the elements of each given array, in order.
---@nodiscard
function _utils.array_concat(...)
	local concatenated = {}
	for _, elements in pairs({ ... }) do
		for _, element in pairs(elements) do
			concatenated[#concatenated + 1] = element
		end
	end
	return concatenated
end

return _utils
