---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")
local _result = require("validation.result")

---Builds argument checkers for whole function signatures.
---@class Signature
local _signature = {}

---One parameter of a signature: its name, then its validator.
---@alias SignatureParameter [string, Validator<any>]

---A rule spanning more than one argument.
---
---A parameter's validator sees only that parameter, so a constraint one
---argument places on another has nowhere to live. This is where it goes.
---@class SignatureRule
---The parameter to blame. Omit where no single argument is at fault and the
---failure belongs to the call as a whole.
---@field parameter string?
---The parameters to hand `check`, named rather than positional so one rule can
---be shared between signatures that declare them in different orders. Every
---argument in declaration order when absent.
---@field arguments string[]?
---Receives the arguments named by `arguments`, in that order, and returns
---whether they are acceptable together. A returned message replaces `message`.
---@field check fun(...): boolean, string?
---What the arguments must satisfy, phrased to follow `must be`. Used when
---`check` returns no message of its own.
---@field message string?

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
---A rule spanning several arguments goes in `rules`, since a parameter's
---validator sees only that parameter:
---```lua
---local check_args = V.signature("get_icon_from_named_prototype", {
---    { "name", Common.prototype_name },
---    { "type_name", Common.prototypes.is_registered_type },
---}, {
---    { parameter = "name", check = name_exists_under_type },
---})
---```
---
---### Parameters
---@param function_name string # The name of the function being guarded, used in messages.
---@param params SignatureParameter[] # Each parameter's name and validator, in declaration order.
---@param rules SignatureRule[]? # Rules spanning more than one argument, run once every argument is individually valid.
---
---### Returns
---@return fun(...) # A checker accepting the guarded function's arguments, in order.
---
---### Exceptions
---*@throws* `string` — Thrown by the returned checker when an argument is invalid and the behavior is `"throw"`.
---@nodiscard
function _signature.signature(function_name, params, rules)
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

	local positions = {}
	for index, param in pairs(params) do
		positions[param[1]] = index
	end

	-- Rules are resolved here rather than at call time: a rule naming an
	-- argument the signature does not declare is a mistake in the declaration,
	-- and it should be reported where it was written.
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

		-- Only once every argument stands on its own. A rule spanning two
		-- arguments has nothing useful to say about one that is the wrong type,
		-- and would have to guard against it before looking at either.
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
