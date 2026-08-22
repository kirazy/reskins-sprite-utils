---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")
local _result = require("validation.result")

---Builds argument checkers for whole function signatures.
---@class Signature
local _signature = {}

---One parameter of a signature: its name, then its validator.
---@alias SignatureParameter [string, Validator<any>]

---Creates a checker validating a function's arguments in one call.
---
---The function name and every parameter name are bound once, where the
---signature is declared, rather than repeated at each guard. Every argument is
---checked, so one call reports every bad argument instead of only the first.
---
---### Examples
---```lua
---local check_args = V.signature("scale_icon", {
---    { "icon_data", Common.icon_data },
---    { "scalar", Common.positive_number },
---    { "defaults_type", Common.icon_defaults_type:optional() },
---})
---
---function _icons.scale_icon(icon_data, scalar, defaults_type)
---    check_args(icon_data, scalar, defaults_type)
---    ...
---end
---```
---
---### Parameters
---@param function_name string # The name of the function being guarded, used in messages.
---@param params SignatureParameter[] # Each parameter's name and validator, in declaration order.
---
---### Returns
---@return fun(...) # A checker accepting the guarded function's arguments, in order.
---
---### Exceptions
---*@throws* `string` — Thrown by the returned checker when an argument is invalid and the behavior is `"throw"`.
---@nodiscard
function _signature.signature(function_name, params)
	-- Checked once, here, rather than trusted at call time. A gap in the list
	-- would otherwise mean quietly validating fewer arguments than were
	-- declared, which is the one failure a validator must never have.
	local declared = 0
	for _ in pairs(params) do
		declared = declared + 1
	end

	if declared ~= #params then
		error(
			string.format(
				"V.signature(): the parameter list for '%s' has %d entries but spans %d positions; it must be a "
					.. "contiguous array of { name, validator } pairs.",
				function_name,
				declared,
				#params
			),
			2
		)
	end

	for index, param in pairs(params) do
		if type(param) ~= "table" or type(param[1]) ~= "string" or type(param[2]) ~= "table" then
			error(
				string.format(
					"V.signature(): entry %d of the parameter list for '%s' must be { name, validator }.",
					index,
					function_name
				),
				2
			)
		end
	end

	return function(...)
		if _config.get_behavior() == "off" then
			return
		end

		local args = table.pack(...)

		local errors = {}
		for index, param in pairs(params) do
			local param_name, validator = param[1], param[2]

			local result = validator:validate(args[index], { path = param_name })
			for _, err in pairs(result.errors) do
				errors[#errors + 1] = err
			end
		end

		if #errors == 0 then
			return
		end

		local message
		if #errors == 1 then
			message = string.format("%s(): parameter '%s': %s", function_name, errors[1].path, errors[1].message)
		else
			local lines = { string.format("%s(): invalid arguments:", function_name) }
			for _, err in pairs(errors) do
				lines[#lines + 1] = string.format("  - %s: %s", err.path, err.message)
			end
			message = table.concat(lines, "\n")
		end

		_result.report(message)
	end
end

return _signature
