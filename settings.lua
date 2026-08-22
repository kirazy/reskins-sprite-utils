---@using data

---@namespace Reskins.SpriteUtils

-- What this library does when you hand it an invalid argument:
--
--   "throw"  raise, blaming the line that made the call (the default)
--   "log"    write the same message to the log and carry on
--   "off"    skip validation entirely
--
-- Hidden, so it will not appear in the mod settings GUI: it is here for
-- debugging your own calls into this library, not for players to tune. Set it
-- from your own settings-final-fixes.lua:
--
--   data.raw["string-setting"]["reskins-sprite-utils-validation-behavior"].default_value = "log"
--
-- To change it around a single call rather than everywhere, use
-- `validation.set_behavior` and put it back afterwards.
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
