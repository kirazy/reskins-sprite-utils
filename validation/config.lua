---@namespace Reskins.SpriteUtils.Validation

---How a failed validation is reported.
---@alias ValidationBehavior
---| "throw" # Raise an error, aborting the load. The default.
---| "log" # Write the message to the log and carry on.
---| "off" # Skip validation entirely; no rules are evaluated.

---Holds the reporting behavior shared by every validator.
---
---The initial value comes from the hidden `reskins-sprite-utils-validation-behavior`
---startup setting, so a mod author can downgrade or disable validation without
---touching code.
---@class Configuration
local _config = {}

local SETTING_NAME = "reskins-sprite-utils-validation-behavior"
local DEFAULT_BEHAVIOR = "throw"

local VALID_BEHAVIORS = {
	throw = true,
	log = true,
	off = true,
}

---The resolved behavior, or `nil` when it has yet to be read from the setting.
---@type ValidationBehavior?
local behavior = nil

---Reads the behavior from the startup setting.
---
---The read is guarded because `settings` does not exist during the settings
---stage, not because validation is tied to any particular stage. Everything
---else in this module is stage-agnostic.
---@return ValidationBehavior
local function read_setting()
	local ok, value = pcall(function()
		return settings.startup[SETTING_NAME].value
	end)

	if ok and VALID_BEHAVIORS[value] then
		return value --[[@as ValidationBehavior]]
	end

	return DEFAULT_BEHAVIOR
end

---Gets the behavior applied when a validation fails.
---@return ValidationBehavior
function _config.get_behavior()
	if not behavior then
		behavior = read_setting()
	end

	return behavior
end

---Sets the behavior applied when a validation fails, overriding the setting.
---@param new_behavior ValidationBehavior # One of `"throw"`, `"log"`, or `"off"`.
function _config.set_behavior(new_behavior)
	---@diagnostic disable-next-line: unnecessary-if
	if not VALID_BEHAVIORS[new_behavior] then
		error(string.format("set_behavior(): parameter 'new_behavior': must be one of 'throw', 'log', or 'off'."), 2)
	end

	behavior = new_behavior
end

---Discards any override, so the next read comes from the startup setting again.
function _config.reset_behavior()
	behavior = nil
end

return _config
