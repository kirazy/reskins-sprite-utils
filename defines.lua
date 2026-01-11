--- Provides enumerations for use with Artisanal Reskins: Sprite Utils.
---
---### Examples
---```lua
---local defines_api = require("__reskins-sprite-utils__.defines")
---```
---@class Reskins.SpriteUtils.Defines
local defines_api = {}

---Represents stages of the Factorio mod loading process.
---@enum Reskins.SpriteUtils.Defines.Stage
defines_api.stage = {
	---The settings stage.
	settings = 0,
	---The settings updates stage.
	settings_updates = 1,
	---The settings final fixes stage.
	settings_final_fixes = 2,
	---The data stage.
	data = 3,
	---The data updates stage.
	data_updates = 4,
	---The data final fixes stage.
	data_final_fixes = 5,
	---The control stage.
	runtime = 6,
}

return defines_api
