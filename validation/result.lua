---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")

---Represents a single validation failure and the path of the invalid value.
---@class ValidationError
---The path of the invalid value, such as `icon_data[3].icon_size`.
---@field path string
---The description of the failure, which follows the path in the rendered message, such as
---`must be a positive integer, got -1`.
---@field message string

---Represents the outcome of validating a value.
---@class ValidationResult
---When `true`, indicates that the value satisfies every rule.
---@field ok boolean
---The failures, or an empty array when `ok` is `true`.
---@field errors ValidationError[]

---Provides methods for building validation results, composing value paths, and rendering failure messages.
---@class ValidationResults
local _result = {}

---Matches a key that is a valid Lua identifier.
local IDENTIFIER_PATTERN = "^[%a_][%w_]*$"

---The directory of this module. The value is read from the source path of this file.
local MODULE_PREFIX = ""
if debug ~= nil then
	---@diagnostic disable-next-line: need-check-nil
	MODULE_PREFIX = (debug.getinfo(1, "S").source:gsub("[^/\\]*$", ""))
end

---Indicates whether a stack frame belongs to this module.
---@param source string
---@return boolean
---@nodiscard
local function is_module_frame(source)
	return MODULE_PREFIX ~= "" and source:sub(1, #MODULE_PREFIX) == MODULE_PREFIX
end

---Formats the given `value` for inclusion in a failure message, with `serpent` if it is available.
---@param value unknown The value to format.
---@return string
---@nodiscard
function _result.format_value(value)
	if type(value) == "string" then
		return string.format("'%s'", value)
	end

	if serpent ~= nil then
		return serpent.line(value, { maxlevel = 3, nocode = true })
	end

	return tostring(value)
end

---Appends the given `key` to the given `path`.
---
---A string key that is a valid Lua identifier is appended with dot notation. Any other key is appended in brackets.
---@param path string The path of the containing value.
---@param key any The key of the contained value.
---@return string
---@nodiscard
function _result.child_path(path, key)
	if type(key) == "string" and key:match(IDENTIFIER_PATTERN) then
		return path .. "." .. key
	end

	if type(key) == "string" then
		return string.format("%s['%s']", path, key)
	end

	return string.format("%s[%s]", path, tostring(key))
end

---Creates a `ValidationResult` representing a value that satisfies every rule.
---@return ValidationResult
---@nodiscard
function _result.pass()
	return { ok = true, errors = {} }
end

---Creates a `ValidationResult` representing a single failure.
---@param path string The path of the invalid value.
---@param message string The failure message.
---@return ValidationResult
---@nodiscard
function _result.fail(path, message)
	return { ok = false, errors = { { path = path, message = message } } }
end

---Creates a `ValidationResult` from the given `errors`, which passes when the list is empty.
---@param errors ValidationError[] The failures.
---@return ValidationResult
---@nodiscard
function _result.from_errors(errors)
	if #errors == 0 then
		return _result.pass()
	end

	return { ok = false, errors = errors }
end

---Renders the given `errors` as a single message.
---
---A single failure is rendered as one line. Several failures are rendered as a header followed by one line per failure.
---
---#### Parameters
---@param function_name string The name of the function that receives the invalid parameter.
---@param param_name string The name of the invalid parameter.
---@param errors ValidationError[] The failures to render.
---@return string
---@nodiscard
function _result.format_message(function_name, param_name, errors)
	if #errors == 1 then
		return string.format("%s(): parameter '%s': %s", function_name, errors[1].path, errors[1].message)
	end

	local lines = { string.format("%s(): parameter '%s' is invalid:", function_name, param_name) }
	for _, err in pairs(errors) do
		lines[#lines + 1] = string.format("  - %s: %s", err.path, err.message)
	end

	return table.concat(lines, "\n")
end

---Gets the `source:line: ` prefix that `error` adds at the given `level`.
---@param level integer
---@return string
---@nodiscard
local function where(level)
	if not debug then
		return ""
	end

	-- `error` counts levels from its caller. Offset the level by one.
	local info = debug.getinfo(level + 1, "Sl")
	if not info or not info.currentline or info.currentline <= 0 then
		return ""
	end

	return string.format("%s:%d: ", info.short_src, info.currentline)
end

---Gets the stack level of the call against which a failure is reported.
---
---The level is that of the first frame outside this module, and is the same for `parse`, `assert`, and a signature
---check. The frame that is blamed is the frame that calls the validated function.
---
---#### Returns
---@return integer level The level of the frame to blame, relative to the caller of this function.
---@return string? function_name The name of the validated function, if it is known.
---@nodiscard
function _result.blame()
	if not debug then
		return 1, nil
	end

	-- Level 1 is this function and level 2 is its caller, which is in this module. Walk outwards
	-- until a frame outside the module is found.
	local level = 2
	local frame = debug.getinfo(level, "S")
	while frame and is_module_frame(frame.source) do
		level = level + 1
		frame = debug.getinfo(level, "S")
	end

	if not frame then
		-- Every frame belongs to this module. This case is not expected. Blame the outermost frame.
		return level - 2, nil
	end

	-- A tail call into or out of the validated function discards one frame. The frame found is still the one
	-- to blame. A frame entered by a tail call has no name.
	local entry = debug.getinfo(level - 1, "t")
	local guarded = debug.getinfo(level, "t")
	if (entry and entry.istailcall) or (guarded and guarded.istailcall) then
		return level - 1, nil
	end

	local named = debug.getinfo(level, "n")

	return level, named and named.name or nil
end

---Reports a failure according to the configured behavior.
---
---The behavior determines how the message is reported:
---- `"throw"` raises the message as an error.
---- `"log"` writes the message to the log with its source location.
---- `"off"` does nothing.
---@param message string The rendered failure message.
function _result.report(message)
	local behavior = _config.get_behavior()

	if behavior == "off" then
		return
	end

	-- `blame` reports levels relative to its caller, and `error` counts levels from its caller,
	-- which is this function. No adjustment is needed.
	local level = _result.blame()

	if behavior == "log" then
		-- `log` has no level parameter and records its own call site. Prepend the location to the message.
		log(where(level) .. message)
		return
	end

	error(message, level)
end

return _result
