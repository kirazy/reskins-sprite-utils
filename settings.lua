---@using data

---@namespace Reskins.SpriteUtils

-- Controls what this library does when a function is given an invalid argument:
--
--   "throw"  Raises an error, reported against the calling line. Default.
--   "log"    Writes the message to the log and continues.
--   "off"    Skips validation.
--
-- The setting is hidden from the mod settings GUI. To change it, set the default value from a
-- settings-final-fixes.lua:
--
--   data.raw["string-setting"]["reskins-sprite-utils-validation-behavior"].default_value = "log"
--
-- To change the behavior for a single call, use `validation.set_behavior`.
data:extend({
	{
		type = "string-setting",
		name = "reskins-sprite-utils-validation-behavior",
		setting_type = "startup",
		default_value = "throw",
		allowed_values = { "throw", "log", "off" },
		hidden = true,
		order = "a",
	},
})

-- Marks the icons that this library assigns:
--
--   true   Draws the square of `__core__/graphics/buildability-collision-elevated.png` under each icon and item picture
--          that `icons.assign_icons_to_prototype_and_related_prototypes` assigns, at the size of the icon. An icon
--          that is assigned another way has no square.
--   false  Draws the icons as given. Default.
--
-- The setting is hidden from the mod settings GUI. To turn it on, set the default value from a
-- settings-final-fixes.lua:
--
--   data.raw["bool-setting"]["reskins-sprite-utils-mark-assigned-icons"].default_value = true
data:extend({
	{
		type = "bool-setting",
		name = "reskins-sprite-utils-mark-assigned-icons",
		setting_type = "startup",
		default_value = false,
		hidden = true,
		order = "b",
	},
})
