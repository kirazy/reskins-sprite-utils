---@namespace Reskins.SpriteUtils

--- Provides enumerations for use with Artisanal Reskins: Sprite Utils.
---
---### Examples
---```lua
---local _defines = require("__reskins-sprite-utils__.defines")
---```
---@class Defines
local _defines = {}

---Represents stages of the Factorio mod loading process.
---@enum Stage
_defines.stage = {
	---The settings stage. Initial mod configuration setup.
	settings = 0,
	---The settings updates stage. Modifications to existing settings.
	settings_updates = 1,
	---The settings final fixes stage. Final adjustments to settings.
	settings_final_fixes = 2,
	---The data stage. Initial prototype definitions.
	data = 3,
	---The data updates stage. Modifications to existing prototypes.
	data_updates = 4,
	---The data final fixes stage. Final prototype adjustments.
	data_final_fixes = 5,
	---The control/runtime stage. Active gameplay logic.
	runtime = 6,
}

---Icon transform presets placing an icon source in one of the four quadrants.
---
---Each halves the source and offsets it by a quarter of the icon, which leaves
---it filling its quadrant. Four of them tile the icon exactly.
---@class CornerIconTransformPresets
---Places an icon source in the upper-left quadrant.
---@field northwest IconTransform
---Places an icon source in the upper-right quadrant.
---@field northeast IconTransform
---Places an icon source in the lower-right quadrant.
---@field southeast IconTransform
---Places an icon source in the lower-left quadrant.
---@field southwest IconTransform

---Icon transform presets placing an icon source at one of eight points around
---the edge of the icon.
---
---Scaled slightly smaller than the corner presets so that all eight fit, and
---offset further out, which leaves the middle of the icon clear.
---@class CompassIconTransformPresets
---Places an icon source at the top edge, centred.
---@field north IconTransform
---Places an icon source at the upper-right corner.
---@field northeast IconTransform
---Places an icon source at the right edge, centred.
---@field east IconTransform
---Places an icon source at the lower-right corner.
---@field southeast IconTransform
---Places an icon source at the bottom edge, centred.
---@field south IconTransform
---Places an icon source at the lower-left corner.
---@field southwest IconTransform
---Places an icon source at the left edge, centred.
---@field west IconTransform
---Places an icon source at the upper-left corner.
---@field northwest IconTransform

---
---Ready-made `IconTransform` values for the common ways of placing one icon on
---another.
---
---### Remarks
---- Sized for the 32-unit shift space of an ordinary prototype, which is not
---  the space a technology, achievement, item group, shortcut, or starmap
---  icon is measured in.
---- Every preset asks for `draw_background`, so a source placed by one is
---  outlined against whatever it is sitting on.
---
---### Examples
---```lua
---local _defines = require("__reskins-sprite-utils__.defines")
---local _icons = require("__reskins-sprite-utils__.icons")
---
----- Put the copper plate icon in the top-right corner of the iron plate icon.
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
---Presets filling one quadrant of the icon each.
---@field corners CornerIconTransformPresets
---Presets ringing the edge of the icon, leaving its middle clear.
---@field compass CompassIconTransformPresets

local CORNER_SCALE = 0.5
local CORNER_SHIFT = 8

local COMPASS_SCALE = 0.4375
local COMPASS_SHIFT = 10

---@type IconTransformPresets
_defines.icon_transforms = {
	corners = {
		northwest = { scale = CORNER_SCALE, shift = { -CORNER_SHIFT, -CORNER_SHIFT }, draw_background = true },
		northeast = { scale = CORNER_SCALE, shift = { CORNER_SHIFT, -CORNER_SHIFT }, draw_background = true },
		southeast = { scale = CORNER_SCALE, shift = { CORNER_SHIFT, CORNER_SHIFT }, draw_background = true },
		southwest = { scale = CORNER_SCALE, shift = { -CORNER_SHIFT, CORNER_SHIFT }, draw_background = true },
	},
	compass = {
		north = { scale = COMPASS_SCALE, shift = { 0, -COMPASS_SHIFT }, draw_background = true },
		northeast = { scale = COMPASS_SCALE, shift = { COMPASS_SHIFT, -COMPASS_SHIFT }, draw_background = true },
		east = { scale = COMPASS_SCALE, shift = { COMPASS_SHIFT, 0 }, draw_background = true },
		southeast = { scale = COMPASS_SCALE, shift = { COMPASS_SHIFT, COMPASS_SHIFT }, draw_background = true },
		south = { scale = COMPASS_SCALE, shift = { 0, COMPASS_SHIFT }, draw_background = true },
		southwest = { scale = COMPASS_SCALE, shift = { -COMPASS_SHIFT, COMPASS_SHIFT }, draw_background = true },
		west = { scale = COMPASS_SCALE, shift = { -COMPASS_SHIFT, 0 }, draw_background = true },
		northwest = { scale = COMPASS_SCALE, shift = { -COMPASS_SHIFT, -COMPASS_SHIFT }, draw_background = true },
	},
}

return _defines
