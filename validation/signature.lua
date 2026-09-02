---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")
local _result = require("validation.result")

---Builds argument checkers for whole function signatures.
---@class Signature
local _signature = {}

---One parameter of a signature: its name, then its validator.
---@alias SignatureParameter [string, Validator<any>]

---A rule that checks more than one argument together.
---@class SignatureRule
---The name of the parameter to report the failure against. If `nil`, the failure is reported
---against the call as a whole.
---@field parameter string?
---The names of the parameters passed to `check`, in order. If `nil`, every argument is passed in
---declaration order.
---@field arguments string[]?
---Receives the arguments named by `arguments`, in that order, and returns
---whether they are acceptable together. A returned message replaces `message`.
---@field check fun(...): boolean, string?
---What the arguments must satisfy, phrased to follow `must be`. Used when
---`check` returns no message of its own.
---@field message string?

---Creates a function that validates the arguments of a function in one call. Every argument is
---checked, and every invalid argument is reported.
---
---A rule that checks several arguments together is given in `rules`:
---```lua
---local check_args = V.signature("get_icon_from_named_prototype", {
---    { "name", Common.prototype_name },
---    { "type_name", Common.prototypes.is_registered_type },
---}, {
---    { parameter = "name", check = name_exists_under_type },
---})
---```
---
---#### Parameters
---@param function_name string The name of the function being guarded, used in messages.
---@param params SignatureParameter[] Each parameter's name and validator, in declaration order.
---@param rules SignatureRule[]? Rules spanning more than one argument, run once every argument is individually valid.
---
---#### Returns
---@return fun(...) # A function that accepts the arguments of the validated function, in order, and validates them.
---
---#### Examples
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
---@throws Thrown by the returned checker when an argument is invalid and the behavior is `"throw"`.
---@nodiscard
function _signature.signature(function_name, params, rules)
	-- Checked at declaration. A gap in the list would validate fewer arguments than declared.
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

	local positions = {}
	for index, param in pairs(params) do
		positions[param[1]] = index
	end

	-- Resolved at declaration so that a rule naming an undeclared argument is reported where it
	-- is written.
	local prepared_rules = {}
	for index, rule in pairs(rules or {}) do
		if type(rule) ~= "table" or type(rule.check) ~= "function" then
			error(
				string.format(
					"V.signature(): rule %d for '%s' must be a table carrying a 'check' function.",
					index,
					function_name
				),
				2
			)
		end

		local function resolve(parameter_name, field)
			if not positions[parameter_name] then
				error(
					string.format(
						"V.signature(): rule %d for '%s' names '%s' in '%s', which is not one of its parameters.",
						index,
						function_name,
						parameter_name,
						field
					),
					3
				)
			end

			return positions[parameter_name]
		end

		if rule.parameter then
			resolve(rule.parameter, "parameter")
		end

		local selected
		if rule.arguments then
			selected = {}
			for order, parameter_name in pairs(rule.arguments) do
				selected[order] = resolve(parameter_name, "arguments")
			end
		end

		prepared_rules[index] = {
			parameter = rule.parameter,
			message = rule.message,
			check = rule.check,
			selected = selected,
		}
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

		-- Rules run only after every argument is individually valid. A rule spanning arguments
		-- cannot handle an argument of the wrong type.
		if #errors == 0 then
			for _, rule in pairs(prepared_rules) do
				local ok, message
				if rule.selected then
					local selected_args = {}
					for order = 1, #rule.selected do
						selected_args[order] = args[rule.selected[order]]
					end

					ok, message = rule.check(table.unpack(selected_args, 1, #rule.selected))
				else
					ok, message = rule.check(...)
				end

				if not ok then
					errors[#errors + 1] = {
						path = rule.parameter,
						message = message or string.format("must be %s", rule.message or "valid"),
					}
				end
			end
		end

		if #errors == 0 then
			return
		end

		local message
		if #errors == 1 then
			local err = errors[1] --[[@as ValidationError]]
			message = err.path and string.format("%s(): parameter '%s': %s", function_name, err.path, err.message)
				or string.format("%s(): %s", function_name, err.message)
		else
			local lines = { string.format("%s(): invalid arguments:", function_name) }
			for _, err in pairs(errors) do
				lines[#lines + 1] = err.path and string.format("  - %s: %s", err.path, err.message)
					or string.format("  - %s", err.message)
			end
			message = table.concat(lines, "\n")
		end

		_result.report(message)
	end
end

return _signature
