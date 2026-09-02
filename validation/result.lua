---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")

---A single validation failure, located by the path of the value that failed.
---@class ValidationError
---The dotted/indexed path to the offending value, such as `icon_data[3].icon_size`.
---@field path string
---What was wrong, phrased to follow the path, such as `must be a positive integer, got -1`.
---@field message string

---The outcome of validating a value.
---@class ValidationResult
---Whether the value satisfied every rule.
---@field ok boolean
---Every failure found. Empty when `ok` is `true`.
---@field errors ValidationError[]

---Builds validation results, composes value paths, and renders failure messages.
---@class ValidationResults
local _result = {}

---Matches a key that can be written with dot notation.
local IDENTIFIER_PATTERN = "^[%a_][%w_]*$"

---The directory of this module, read from the source path of this file.
local MODULE_PREFIX = ""
if debug ~= nil then
	---@diagnostic disable-next-line: need-check-nil
	MODULE_PREFIX = (debug.getinfo(1, "S").source:gsub("[^/\\]*$", ""))
end

---Indicates whether a stack frame belongs to this module.
---@param source string The `source` of the frame, as reported by `debug.getinfo`.
---@return boolean # `true` if the frame belongs to this module; otherwise, `false`.
local function is_module_frame(source)
	return MODULE_PREFIX ~= "" and source:sub(1, #MODULE_PREFIX) == MODULE_PREFIX
end

---Formats the given value for inclusion in a failure message. Uses `serpent` if it is available.
---@param value any
---@return string
function _result.format_value(value)
	if type(value) == "string" then
		return string.format("'%s'", value)
	end

	if serpent ~= nil then
		return serpent.line(value, { maxlevel = 3, nocode = true })
	end

	return tostring(value)
end

---Extends a path with a table key.
---
---Identifier-safe string keys use dot notation; everything else is bracketed.
---@param path string The path of the containing value.
---@param key any The key of the contained value.
---@return string
function _result.child_path(path, key)
	if type(key) == "string" and key:match(IDENTIFIER_PATTERN) then
		return path .. "." .. key
	end

	if type(key) == "string" then
		return string.format("%s['%s']", path, key)
	end

	return string.format("%s[%s]", path, tostring(key))
end

---Creates a result representing a value that satisfied every rule.
---@return ValidationResult
---@nodiscard
function _result.pass()
	return { ok = true, errors = {} }
end

---Creates a result representing a single failure.
---@param path string The path of the offending value.
---@param message string The failure message.
---@return ValidationResult
---@nodiscard
function _result.fail(path, message)
	return { ok = false, errors = { { path = path, message = message } } }
end

---Creates a result from a list of failures, passing when the list is empty.
---@param errors ValidationError[]
---@return ValidationResult
---@nodiscard
function _result.from_errors(errors)
	if #errors == 0 then
		return _result.pass()
	end

	return { ok = false, errors = errors }
end

---Renders one or more failures as a single human-readable message.
---
---A lone failure reads as one line; several are listed beneath a header so the
---path of each is visible at a glance.
---
---#### Parameters
---@param function_name string The function whose parameter failed.
---@param param_name string The parameter that failed.
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

---Renders the source location `error` would prefix at the given level.
---
---`log` has no level parameter and stamps its own call site instead, which would
---attribute every logged failure to this file. Resolving the location by hand is
---what keeps `"log"` pointing at the same line `"throw"` blames.
---@param level integer The stack level to locate, as per `error`.
---@return string # A `source:line: ` prefix, or an empty string when unavailable.
---@nodiscard
local function where(level)
	if not debug then
		return ""
	end

	-- Offset by one, since `error` counts levels from its caller.
	local info = debug.getinfo(level + 1, "Sl")
	if not info or not info.currentline or info.currentline <= 0 then
		return ""
	end

	return string.format("%s:%d: ", info.short_src, info.currentline)
end

---Locates the call a failure should be reported against.
---
---The number of frames between a failure and the caller differs between `parse`,
---`assert`, and a signature check, and would change again if this module grew an
---internal frame. Walking out of the module is correct for all of them, which is
---what keeps a stack level out of the public API.
---
---The frame blamed is the one that called the validated function, not the guard
---inside it: the guard is in the same place on every failure and so locates
---nothing.
---
---#### Returns
---@return integer # The level of the frame to blame, relative to the caller of this function.
---@return string? # The name of the validated function, when it can be known.
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
		-- Every frame belongs to this module, which should not happen. Blame the outermost frame.
		return level - 2, nil
	end

	-- A tail call into this module discards the validated function's frame, so the frame found is
	-- its caller. A tail call into the validated function discards its caller's frame, leaving the
	-- validated function's own line. In either case the frame found is the one to blame, and Lua
	-- keeps no name for a frame entered by a tail call.
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
---Throwing is the default; `"log"` records the message and returns; `"off"`
---does nothing.
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
		log(where(level) .. message)
		return
	end

	error(message, level)
end

return _result
