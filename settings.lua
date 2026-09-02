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
