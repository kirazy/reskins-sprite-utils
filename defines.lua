---@namespace Reskins.SpriteUtils

---Provides enumerations for use with Artisanal Reskins: Sprite Utils.
---
---#### Examples
---```lua
---local _defines = require("__reskins-sprite-utils__.defines")
---```
---@class Defines
local _defines = {}

---Represents stages of the Factorio mod loading process.
---@enum Stage
_defines.stage = {
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

local CORNER_SCALE = 0.5
local CORNER_SHIFT = 8

local COMPASS_SCALE = 0.4375
local COMPASS_SHIFT = 10

---Provides `Transform` values for the common ways of positioning a composed icon over another icon.
---
---The presets are sized for the expected icon size of an item, entity, fluid, or recipe icon. Not suitable for use with
---technology, achievement, item group, shortcut, and starmap icons.
---
---#### Examples
---```lua
---local _defines = require("__reskins-sprite-utils__.defines")
---local _icons = require("__reskins-sprite-utils__.icons")
---
----- Put the copper plate icon in the top-right corner of the iron plate icon at half scale.
---local icon_data = _icons.create_icons_from_sources({
---    { name = "iron-plate", type_name = "item" },
---    {
---        name = "copper-plate",
---        type_name = "item",
---        transform = _defines.icon_transforms.corners.northeast,
---    },
---})
---```
---@class IconTransformPresets
_defines.icon_transforms = {
	---Provides the icon transform presets that place an icon in one of the four quadrants.
	---@class CornerIconTransformPresets
	corners = {
		---Places an icon in the upper-left quadrant.
		northwest = { scale = CORNER_SCALE, shift = { -CORNER_SHIFT, -CORNER_SHIFT } },
		---Places an icon in the upper-right quadrant.
		northeast = { scale = CORNER_SCALE, shift = { CORNER_SHIFT, -CORNER_SHIFT } },
		---Places an icon in the lower-right quadrant.
		southeast = { scale = CORNER_SCALE, shift = { CORNER_SHIFT, CORNER_SHIFT } },
		---Places an icon in the lower-left quadrant.
		southwest = { scale = CORNER_SCALE, shift = { -CORNER_SHIFT, CORNER_SHIFT } },
	},
	---Provides the icon transform presets that place an icon at one of eight points around the edge of the icon.
	---@class CompassIconTransformPresets
	compass = {
		---Places an icon at the top edge, centred.
		north = { scale = COMPASS_SCALE, shift = { 0, -COMPASS_SHIFT } },
		---Places an icon at the upper-right corner.
		northeast = { scale = COMPASS_SCALE, shift = { COMPASS_SHIFT, -COMPASS_SHIFT } },
		---Places an icon at the right edge, centred.
		east = { scale = COMPASS_SCALE, shift = { COMPASS_SHIFT, 0 } },
		---Places an icon at the lower-right corner.
		southeast = { scale = COMPASS_SCALE, shift = { COMPASS_SHIFT, COMPASS_SHIFT } },
		---Places an icon at the bottom edge, centred.
		south = { scale = COMPASS_SCALE, shift = { 0, COMPASS_SHIFT } },
		---Places an icon at the lower-left corner.
		southwest = { scale = COMPASS_SCALE, shift = { -COMPASS_SHIFT, COMPASS_SHIFT } },
		---Places an icon at the left edge, centred.
		west = { scale = COMPASS_SCALE, shift = { -COMPASS_SHIFT, 0 } },
		---Places an icon at the upper-left corner.
		northwest = { scale = COMPASS_SCALE, shift = { -COMPASS_SHIFT, -COMPASS_SHIFT } },
	},
}

---The strata of an icon composition, in draw order.
---
---- Content in an earlier stratum is drawn beneath content in a later stratum, independent of the order the content was
---  added.
---- `backdrop`, `canvas`, `overlay`, and `symbol` contain artwork subject to placements and transforms.
---- `label` contains artwork positioned relative to the finished icon, and is not subject to transforms.
---@type IconCompositionStratum[]
_defines.icon_composition_strata = { "backdrop", "canvas", "overlay", "symbol", "label" }

return _defines
