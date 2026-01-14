local colors = {}

---Converts an ARGB hex code to an RGBA color vector compatible with Factorio prototypes.
---
---This method is to facilitate compatibility between the [Factorio Modding Tool Kit](https://marketplace.visualstudio.com/items?itemName=justarandomgeek.factoriomod-debug)
---and Visual Studio Code's native color picker in a lua workspace. Leading hash (`"#"`) characters are not supported;
---
---Visual Studio Code will remove them anyways on interacting with the color picker.
---
---### Parameters
---@param hex string # An 8-character ARGB color hex code.
---@return data.Color
---
---### Examples
---Import the colors module and then use it to create a tint. If working with the Factorio Modding Tool Kit and Visual
---Studio Code, once the Lua workspace has loaded the color picker will be interactive and render correctly in game.
---```lua
---local colors = require("__reskins-sprites-utils__.colors")
---
---local tahiti_blue = colors.from_argb("FF00C1DF")
---```
---Use anywhere you would use a tint.
---
---### Exceptions
---*@throws* - `string` When `hex` is not a string.</br>
---*@throws* - `string` When `hex` is not 8 characters.
function colors.from_argb(hex)
	if type(hex) ~= "string" then
		error("Invalid type: 'hex' must be a string.")
	elseif #hex ~= 8 then
		error("Invalid format: 'hex' must have 8 characters.")
	end
	return util.color(hex:sub(3, 8) .. hex:sub(1, 2))
end

return colors
