---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")
local _result = require("validation.result")

---Defines a single check applied to a value.
---
---`check` returns `true` if the value satisfies the rule. Otherwise, it returns `false` and either a message describing
---the failure, or an array of `ValidationError` objects with their own paths, for failures against nested values.
---@class ValidationRule<TValidated>
---A stable identifier, such as `string.min_length`. The identifier locates a rule for removal.
---@field id string
---A fragment describing what the rule requires, such as `at least 3 characters long`. A rule with a description that
---depends on another validator supplies a function, which is called when the description is needed.
---@field describe string|fun(): string
---The function that checks the value. `value` is the whole value being validated; a rule of an `ArrayValidator`
---receives the whole array.
---@field check? fun(value: TValidated, ctx: ValidationContext): boolean, (string|ValidationError[])?
---When `true`, indicates that a failure stops evaluation of the remaining rules, as for type checks.
---@field is_gate? boolean

---Defines the context passed to a rule as it runs.
---@class ValidationContext
---The path of the value being checked.
---@field path string

---Defines the options accepted by `Validator:validate`.
---@class ValidationOptions
---The path against which failures are reported. Default `"value"`.
---@field path? string
---When `true`, indicates that rules are evaluated after the first failure. Default the `collect_all` field of the
---validator.
---@field collect_all? boolean

---Represents an immutable, reusable set of rules that a valid value satisfies.
---
---A validator is built once, from rules, and then applied to many values. Builder methods return a new validator with
---one more rule; the original is not modified.
---
---#### Examples
---```lua
---local V = require("__reskins-sprite-utils__.validation")
---
----- Built once, at load:
---local AssemblySet = V.integer():in_range(1, 6)
---
----- Reused at every call site:
---function M.get_assembly_machine(assembly_set)
---    AssemblySet:assert(assembly_set, "assembly_set")
---    ...
---end
---```
---@class Validator<TValidated>
---The type of value that this validator accepts, such as `"string"` or `"struct"`.
---@field value_type string
---The rules applied, in order.
---@field rules ValidationRule<TValidated>[]
---Whether a `nil` value is accepted.
---@field presence "required"|"optional"
---Overrides the generated description, when set.
---@field description? string
---When `true`, indicates that rules are evaluated after the first failure when no explicit option is given.
---@field collect_all? boolean
local Validator = {}
Validator.__index = Validator

---Gets the description of the given `rule`, calling it when it is a function.
---@generic T
---@param rule ValidationRule<T>
---@return string?
local function describe_rule(rule)
	if type(rule.describe) == "function" then
		return rule.describe()
	end

	return rule.describe
end

---Creates a validator class for the given `value_type` that inherits the shared methods.
---
---The builder methods of the class are defined on the returned class.
---@param value_type string The type of value that the class validates.
---@return Validator<TValidated> # The new class.
---@nodiscard
function Validator.subclass(value_type)
	local class = setmetatable({}, { __index = Validator })
	class.__index = class
	class.value_type = value_type

	return class
end

---Creates a validator instance of the given class.
---
---#### Parameters
---@generic C
---@param class C A class produced by `Validator<TValidated>.subclass`.
---@param fields? table Additional instance fields, such as the field validators of a struct.
---
---#### Returns
---@return C # The instance.
---@nodiscard
function Validator.instance(class, fields)
	local instance = setmetatable(fields or {}, class)
	instance.value_type = class.value_type
	instance.rules = instance.rules or {}
	instance.presence = "required"

	return instance
end

---Creates a gate that checks the Lua type of a value.
---
---When the gate fails, the remaining rules are skipped.
---@param expected_type type The `type()` name required.
---@param article? string How to describe the type, such as `"an array"`. Default the type name.
---@return ValidationRule<any>
---@nodiscard
function Validator.type_gate(expected_type, article)
	local described = article or ("a " .. expected_type)

	return {
		id = expected_type .. ".type",
		describe = described,
		is_gate = true,
		check = function(value)
			if type(value) == expected_type then
				return true
			end

			return false, string.format("must be %s, got %s", described, type(value))
		end,
	}
end

---Creates a copy of this validator.
---
---Every field is copied shallowly, and the rules array is duplicated. The original is not modified.
---
---The copy is of the same class as the original, and has the builder methods of that class.
---@return self
---@nodiscard
function Validator:clone()
	local copy = {}
	for key, value in pairs(self) do
		---@diagnostic disable-next-line: assign-type-mismatch
		copy[key] = value
	end

	local rules = {}
	for index, rule in pairs(self.rules) do
		rules[index] = rule
	end
	copy.rules = rules

	return setmetatable(copy, getmetatable(self))
end

---Appends the given `rule` to the rules of the validator.
---@param rule ValidationRule<TValidated> The rule to append.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function Validator:extend(rule)
	local copy = self:clone()
	copy.rules[#copy.rules + 1] = rule

	return copy
end

---Removes the rule with the given `rule_id` from the validator.
---@param rule_id string The `id` of the rule to remove.
---@return self # A copy of this validator with the rule removed.
---@nodiscard
function Validator:without(rule_id)
	local copy = self:clone()

	local rules = {}
	for _, rule in pairs(copy.rules) do
		if rule.id ~= rule_id then
			rules[#rules + 1] = rule
		end
	end
	copy.rules = rules

	return copy
end

---Permits a `nil` value.
---
---When the value is `nil`, no rule is evaluated.
---
---The copy is typed as a plain `Validator` of the nullable type, and the builder methods of a subclass are not
---available on it. Call `optional` last.
---@return Validator<TValidated?> # A copy of this validator that accepts `nil`.
---@nodiscard
function Validator:optional()
	-- The return type is `Validator<TValidated?>` because `self` cannot rewrite its type argument, and a subclass
	-- cannot override the return type of an inherited method; emmylua_ls 0.25.1 resolves the call to the base
	-- signature.
	local copy = self:clone()
	copy.presence = "optional"

	return copy
end

---Requires a value other than `nil`.
---
---Every validator rejects `nil` until `optional` is called.
---@return self # A copy of this validator that rejects `nil`.
---@nodiscard
function Validator:required()
	local copy = self:clone()
	copy.presence = "required"

	return copy
end

---Sets the description of the validator to the given `text`.
---
---The given text replaces the description assembled from the rules of the validator, as in `"an IconData object"`.
---@param text string The description to use.
---@return self # A copy of this validator with the description set.
---@nodiscard
function Validator:describe_as(text)
	local copy = self:clone()
	copy.description = text

	return copy
end

---Requires the value to satisfy the given `predicate`.
---
---#### Parameters
---@param predicate fun(value: TValidated): boolean A function that returns `true` if the value is acceptable.
---@param message string The requirement that the value must satisfy, which follows `must be` in the failure message, such as `a power of two`.
---
---#### Returns
---@return self # A copy of this validator with the rule added.
---@nodiscard
function Validator:satisfies(predicate, message)
	return self:extend({
		id = "custom",
		describe = message,
		check = function(value)
			if predicate(value) then
				return true
			end

			return false, string.format("must be %s, got %s", message, _result.format_value(value))
		end,
	})
end

---Gets the description of this validator.
---@return string
---@nodiscard
function Validator:describe()
	if self.description then
		return self.description
	end

	local parts = {}
	for _, rule in pairs(self.rules) do
		local described = describe_rule(rule)
		if described then
			parts[#parts + 1] = described
		end
	end

	if #parts == 0 then
		return "any value"
	end

	return table.concat(parts, " and ")
end

---Validates a value against this validator's rules, without raising an error.
---
---#### Parameters
---@param value unknown The value to check.
---@param opts? ValidationOptions Path and collection options.
---
---#### Returns
---@return ValidationResult # A result indicating whether the value is valid, with every failure found.
---
---#### Examples
---```lua
---local result = IconDatum:validate(icon_datum, { path = "icon_datum" })
---if not result.ok then
---    for _, err in pairs(result.errors) do
---        log(err.path .. ": " .. err.message)
---    end
---end
---```
---@nodiscard
function Validator:validate(value, opts)
	opts = opts or {}

	local path = opts.path or "value"

	local collect_all = opts.collect_all
	if collect_all == nil then
		collect_all = self.collect_all or false
	end

	if value == nil then
		if self.presence == "optional" then
			return _result.pass()
		end

		return _result.fail(path, "is required, but was nil")
	end

	local ctx = { path = path }
	local errors = {}

	-- Rules run in the order added. The type gate runs first, and later rules receive a value of
	-- the expected type.
	for _, rule in pairs(self.rules) do
		if type(rule.check) == "function" then
			local ok, detail = rule.check(value, ctx)
			if not ok then
				if type(detail) == "table" then
					for _, err in pairs(detail) do
						errors[#errors + 1] = err
					end
				else
					errors[#errors + 1] = { path = path, message = detail or ("must be " .. tostring(describe_rule(rule))) }
				end

				-- A failed gate stops evaluation even when the caller asked for every failure.
				if rule.is_gate or not collect_all then
					return _result.from_errors(errors)
				end
			end
		end
	end

	return _result.from_errors(errors)
end

---Validates the given `value`, reports any failure, and returns the value.
---@param validator Validator<any>
---@param value unknown
---@param param_name? string
---@param function_name? string
---@return unknown
local function report_failure(validator, value, param_name, function_name)
	if _config.get_behavior() == "off" then
		return value
	end

	param_name = param_name or "value"

	local result = validator:validate(value, { path = param_name })
	if result.ok then
		return value
	end

	if not function_name then
		-- The frame is found by walking out of this module. The name and line are read from the same
		-- frame. A tail call leaves no name, and the fallback applies.
		local _, name = _result.blame()

		function_name = name or "<unknown>"
	end

	_result.report(_result.format_message(function_name, param_name, result.errors))

	return value
end

---Indicates whether the given `value` satisfies this validator, without raising an error.
---@param value unknown The value to check.
---@return TypeGuard<TValidated> # `true` if `value` is valid; otherwise, `false`.
---
---#### Examples
---```lua
---if Common.icon_datum:is_valid(source) then
---    source.icon_size = 64 -- source is an IconData here
---end
---```
---@nodiscard
function Validator:is_valid(value)
	return self:validate(value).ok
end

---Validates the given `value` and returns it, typed as `TValidated`.
---
---A failure is reported according to the configured `ValidationBehavior`. When no error is raised, the value is
---returned even when it is invalid.
---
---#### Parameters
---@param value unknown The value to check.
---@param param_name? string The parameter name that appears in the message. Default `"value"`.
---@param function_name? string The function name that appears in the message. When omitted, the name is read from the stack, which does not work under a tail call.
---
---#### Returns
---@return TValidated # The given `value`, unchanged.
---
---#### Examples
---```lua
---function M.scale_icon(icon_data, scalar)
---    icon_data = Common.icon_data:parse(icon_data, "icon_data")
---    scalar = Common.positive_number:parse(scalar, "scalar")
---    -- icon_data is IconData[] and scalar is a number from here on
---end
---```
---@throws When the value is invalid and the behavior is `"throw"`.
function Validator:parse(value, param_name, function_name)
	-- Prevent a tail call which would discard this frame and lose the function_name read from the stack in the process.
	local checked = report_failure(self, value, param_name, function_name)

	return checked
end

---Validates the given `value`.
---
---A failure is reported according to the configured `ValidationBehavior`.
---
---#### Parameters
---@param value unknown The value to check.
---@param param_name? string The parameter name that appears in the message. Default `"value"`.
---@param function_name? string The function name that appears in the message. When omitted, the name is read from the stack.
---
---#### Examples
---```lua
---function M.scale_icon(icon_data, scalar)
---    Common.icon_data:assert(icon_data, "icon_data")
---    Common.positive_number:assert(scalar, "scalar")
---    ...
---end
---```
---@throws When the value is invalid and the behavior is `"throw"`.
function Validator:assert(value, param_name, function_name)
	report_failure(self, value, param_name, function_name)
end

return Validator
