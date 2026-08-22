---@namespace Reskins.SpriteUtils.Validation

local _config = require("validation.config")
local _result = require("validation.result")

---A single check applied to a value.
---
---`check` returns `true` when the value satisfies the rule. On failure it
---returns `false` plus either a message describing what was wrong, or a list of
---`ValidationError` objects already carrying their own paths — the latter is how
---composite rules report failures against nested values.
---@class ValidationRule<TValidated>
---A stable identifier, such as `string.min_length`. Used to locate a rule for removal.
---@field id string
---A fragment describing what the rule requires, such as `at least 3 characters long`.
---
---A rule whose description depends on another validator supplies a function
---instead of a string, so that describing it is deferred along with everything
---else. Calling `describe()` on a child at rule-construction time would force a
---`lazy` child to resolve before a recursive definition had been bound.
---@field describe string|fun(): string
---The check itself.
---
---`value` is whatever the validator validates, so a rule of an `ArrayValidator<TValidated>`
---is handed the whole `T[]` rather than an element.
---@field check fun(value: TValidated, ctx: ValidationContext): boolean, (string|ValidationError[])?
---When `true`, a failure stops evaluation of the remaining rules. Used by type checks.
---@field is_gate boolean?

---The context handed to a rule as it runs.
---@class ValidationContext
---The path of the value being checked.
---@field path string

---Options accepted by `Validator:validate`.
---@class ValidationOptions
---The path to report failures against. Defaults to `"value"`.
---@field path string?
---Whether to keep evaluating rules after the first failure. Defaults to the validator's own preference.
---@field collect_all boolean?

---An immutable, reusable set of rules describing what a valid value looks like.
---
---A validator is built once, from rules, and then applied to many values. Builder
---methods never mutate; each returns a new validator carrying one more rule, so
---a validator shared from a catalog can be safely extended by any caller.
---
---### Examples
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
---@generic TValidated
---@class Validator<TValidated>
---The kind of value this validator accepts, such as `"string"` or `"shape"`.
---@field kind string
---The rules applied, in order.
---@field rules ValidationRule<TValidated>[]
---Whether a `nil` value is accepted.
---@field presence "required"|"optional"
---Overrides the generated description, when set.
---@field description string?
---Whether to keep evaluating rules after the first failure, absent an explicit option.
---@field collect_all boolean?
local Validator = {}
Validator.__index = Validator

---Resolves a rule's description, which may be deferred behind a function.
---@generic T
---@param rule ValidationRule<T>
---@return string?
local function describe_rule(rule)
	if type(rule.describe) == "function" then
		return rule.describe()
	end

	return rule.describe
end

---Creates a validator class inheriting the shared methods.
---
---Each kind gets its own class so that kind-specific builder methods are only
---reachable on validators that can use them.
---@param kind string # The kind of value the class validates.
---@return Validator<TValidated> # The new class.
---@nodiscard
function Validator.subclass(kind)
	local class = setmetatable({}, { __index = Validator })
	class.__index = class
	class.kind = kind

	return class
end

---Creates a validator instance of the given class.
---@generic C
---@param class C # A class produced by `Validator<TValidated>.subclass`.
---@param fields table? # Additional instance fields, such as a shape's field validators.
---@return C
---@nodiscard
function Validator.instance(class, fields)
	local instance = setmetatable(fields or {}, class)
	instance.kind = class.kind
	instance.rules = instance.rules or {}
	instance.presence = "required"

	return instance
end

---Creates a rule asserting the Lua type of a value.
---
---Type rules are gates: when one fails the remaining rules are skipped, so a
---length rule never sees a number and the caller gets one clear message instead
---of a Lua error from inside the rule.
---@param expected_type type # The `type()` name required.
---@param article string? # How to describe the type, such as `"an array"`. Defaults to the type name.
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
---Every field is copied shallowly so subclass state travels with the copy, and
---the rules array is duplicated so the original is never disturbed.
---
---The copy is of the same class as the original, so a copy of a `ShapeValidator`
---still offers `:strict()`.
---@generic S : Validator<any>
---@param self S
---@return S
---@nodiscard
function Validator.clone(self)
	local copy = {}
	for key, value in pairs(self) do
		copy[key] = value
	end

	local rules = {}
	for index, rule in pairs(self.rules) do
		rules[index] = rule
	end
	copy.rules = rules

	return setmetatable(copy, getmetatable(self))
end

---Creates a copy of this validator with an additional rule.
---@generic S : Validator<any>
---@param self S
---@param rule ValidationRule<TValidated> # The rule to append.
---@return S
---@nodiscard
function Validator.extend(self, rule)
	local copy = self:clone()
	copy.rules[#copy.rules + 1] = rule

	return copy
end

---Creates a copy of this validator with the identified rule removed.
---@generic S : Validator<any>
---@param self S
---@param rule_id string # The `id` of the rule to drop.
---@return S
---@nodiscard
function Validator.without(self, rule_id)
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

---Creates a copy of this validator that accepts `nil`.
---
---When the value is `nil` no rule is evaluated.
---@generic S : Validator<any>
---@param self S
---@return S
---@nodiscard
function Validator.optional(self)
	local copy = self:clone()
	copy.presence = "optional"

	return copy
end

---Creates a copy of this validator that rejects `nil`. The default.
---@generic S : Validator<any>
---@param self S
---@return S
---@nodiscard
function Validator.required(self)
	local copy = self:clone()
	copy.presence = "required"

	return copy
end

---Creates a copy of this validator described by the given text.
---
---Used to give a composed validator a name a reader will recognize, such as
---`"an IconData object"`, in place of a description assembled from its rules.
---@generic S : Validator<any>
---@param self S
---@param text string # The description to use.
---@return S
---@nodiscard
function Validator.describe_as(self, text)
	local copy = self:clone()
	copy.description = text

	return copy
end

---Creates a copy of this validator with an additional predicate rule.
---@generic S : Validator<any>
---@param self S
---@param predicate fun(value: TValidated): boolean # Returns `true` when the value is acceptable.
---@param message string # What the value must be, phrased to follow `must be`, such as `a power of two`.
---@return S
---@nodiscard
function Validator.satisfies(self, predicate, message)
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

---Describes what this validator requires.
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

---Validates a value against this validator's rules, without raising.
---
---### Examples
---```lua
---local result = IconDatum:validate(icon_datum, { path = "icon_datum" })
---if not result.ok then
---    for _, err in pairs(result.errors) do
---        log(err.path .. ": " .. err.message)
---    end
---end
---```
---
---### Parameters
---@param value unknown # The value to check.
---@param opts ValidationOptions? # Path and collection options.
---
---### Returns
---@return ValidationResult # Whether the value is valid, and every failure found.
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

	-- Rules run in the order they were added; the type gate coming first is what
	-- keeps every later rule safe from a value of the wrong type.
	for _, rule in pairs(self.rules) do
		local ok, detail = rule.check(value, ctx)
		if not ok then
			if type(detail) == "table" then
				for _, err in pairs(detail) do
					errors[#errors + 1] = err
				end
			else
				errors[#errors + 1] = { path = path, message = detail or ("must be " .. tostring(describe_rule(rule))) }
			end

			-- A failed type check makes every later rule meaningless, so stop
			-- regardless of whether the caller asked for everything.
			if rule.is_gate or not collect_all then
				return _result.from_errors(errors)
			end
		end
	end

	return _result.from_errors(errors)
end

---Runs the validation and reports a failure, returning the value regardless.
---
---`parse` and `assert` both call this directly rather than one delegating to the
---other, so that neither is a frame the other has to account for.
---@param self Validator<any>
---@param value any
---@param param_name string?
---@param function_name string?
---@return any
local function report_failure(self, value, param_name, function_name)
	if _config.get_behavior() == "off" then
		return value
	end

	param_name = param_name or "value"

	local result = self:validate(value, { path = param_name })
	if result.ok then
		return value
	end

	if not function_name then
		-- Found by walking out of this module rather than by counting frames, so
		-- that the name and the line reported alongside it are read from the very
		-- same frame. Tail calls leave no name behind, hence the fallback.
		local _, name = _result.blame()

		function_name = name or "<unknown>"
	end

	_result.report(_result.format_message(function_name, param_name, result.errors))

	return value
end

---Reports whether a value satisfies this validator. Never raises.
---
---Declared as a `TypeGuard<TValidated>`, so a value checked in a condition is narrowed to
---the type this validator validates for the rest of the branch:
---
---```lua
---if Common.icon_datum:is_valid(source) then
---    source.icon_size = 64 -- source is an IconData here
---end
---```
---
---`self` is an explicit parameter, which is what lets `T` be read from the
---receiver; callers still use `validator:is_valid(value)` as normal.
---@generic T
---@param self Validator<TValidated>
---@param value any # The value to check.
---@return TypeGuard<TValidated>
---@nodiscard
function Validator.is_valid(self, value)
	return self:validate(value).ok
end

---Validates a value and returns it, typed.
---
---The counterpart to `assert`: use `parse` where the typed value is wanted, and
---`assert` where the call is a statement. Assigning the result back over the
---argument is the idiom that carries the type into the rest of the function.
---
---What happens on failure depends on the configured behavior: `"throw"` raises,
---`"log"` records the message, and `"off"` skips validation altogether. The
---value is returned unchanged either way.
---
---### Examples
---```lua
---function M.scale_icon(icon_data, scalar)
---    icon_data = Common.icon_data:parse(icon_data, "icon_data")
---    scalar = Common.positive_number:parse(scalar, "scalar")
---    -- icon_data is IconData[] and scalar is a number from here on
---end
---```
---
---### Parameters
---@generic T
---@param self Validator<TValidated>
---@param value unknown # The value to check.
---@param param_name string? # The parameter name, used in the message. Defaults to `"value"`.
---@param function_name string? # The function name, used in the message. Detected from the stack when omitted, except under a tail call; pass it explicitly there.
---
---### Returns
---@return T # The given `value`, unchanged.
---
---### Exceptions
---*@throws* `string` — Thrown when the value is invalid and the behavior is `"throw"`.
function Validator.parse(self, value, param_name, function_name)
	-- Deliberately not `return report_failure(...)`. A tail call from here would
	-- discard this frame and mark the next one as tail-called, which is the very
	-- signal used to detect a tail call made by the *caller*; the two would then
	-- be indistinguishable without comparing function identities.
	--
	-- The tail call is worth giving up: this is one frame, not recursion, so
	-- there is no stack depth to save, and the frame costs far less than the
	-- validation it sits beside.
	local checked = report_failure(self, value, param_name, function_name)

	return checked
end

---Validates a function parameter, reporting any failure.
---
---Returns nothing, so it reads as a statement guard. Use `parse` when the typed
---value is wanted.
---
---### Examples
---```lua
---function M.scale_icon(icon_data, scalar)
---    Common.icon_data:assert(icon_data, "icon_data")
---    Common.positive_number:assert(scalar, "scalar")
---    ...
---end
---```
---
---### Parameters
---@param value unknown # The value to check.
---@param param_name string? # The parameter name, used in the message. Defaults to `"value"`.
---@param function_name string? # The function name, used in the message. Detected from the stack when omitted.
---
---### Exceptions
---*@throws* `string` — Thrown when the value is invalid and the behavior is `"throw"`.
function Validator:assert(value, param_name, function_name)
	report_failure(self, value, param_name, function_name)
end

return Validator
