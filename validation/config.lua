---@namespace Reskins.SpriteUtils.Validation

---Defines the behavior applied when a validation fails. Default `"throw"`.
---@alias ValidationBehavior
---| "throw" # Raises an error and aborts the load.
---| "log" # Writes the message to the log and continues the load.
---| "off" # Skips validation.

---Provides methods for reading and setting the behavior applied when a validation fails.
---
---The behavior is read from the hidden `reskins-sprite-utils-validation-behavior` startup setting until `set_behavior`
---is called.
---@class Configuration
local _config = {}

local SETTING_NAME = "reskins-sprite-utils-validation-behavior"
local DEFAULT_BEHAVIOR = "throw"

local VALID_BEHAVIORS = {
	throw = true,
	log = true,
	off = true,
}

---The current behavior, or `nil` when no behavior has been read or set.
---@type ValidationBehavior?
local behavior = nil

---Gets the behavior from the startup setting.
---
---The default behavior is returned when `settings` is not available, as in the settings stage, or when the value of the
---setting is not a `ValidationBehavior`.
---@return ValidationBehavior
---@nodiscard
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
---@nodiscard
function _config.get_behavior()
	if not behavior then
		behavior = read_setting()
	end

	return behavior
end

---Sets the behavior applied when a validation fails.
---
---The given `new_behavior` replaces the value read from the startup setting until `reset_behavior` is called.
---@param new_behavior ValidationBehavior
function _config.set_behavior(new_behavior)
	---@diagnostic disable-next-line: unnecessary-if
	if not VALID_BEHAVIORS[new_behavior] then
		error(string.format("set_behavior(): parameter 'new_behavior': must be one of 'throw', 'log', or 'off'."), 2)
	end

	behavior = new_behavior
end

---Removes the behavior set by `set_behavior`. The next call to `get_behavior` reads the startup setting.
function _config.reset_behavior()
	behavior = nil
end

return _config
