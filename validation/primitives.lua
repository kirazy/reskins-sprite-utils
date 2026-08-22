---@namespace Reskins.SpriteUtils.Validation

local Validator = require("validation.validator")
local _result = require("validation.result")

---Validators for the primitive Lua types.
---@class Primitives
local _primitives = {}

-- Any

---@generic T
---@class NotNullValidator<T> : Validator<T>
local NotNullValidator = Validator.subclass("any")

---Creates a validator accepting any non-`nil` value.
---
---Useful as a starting point for `:satisfies` rules, and as the value validator
---of a map whose values are unconstrained.
---@return NotNullValidator<any>
---@nodiscard
function _primitives.any()
	return Validator.instance(NotNullValidator)
end

-- Boolean

---@class BooleanValidator : Validator<boolean>
local BooleanValidator = Validator.subclass("boolean")

---Creates a validator accepting booleans.
---@return BooleanValidator
---@nodiscard
function _primitives.boolean()
	return Validator.instance(BooleanValidator, {
		rules = {
			Validator.type_gate("boolean"),
		},
	})
end

-- Table

---@class TableValidator : Validator<table>
local TableValidator = Validator.subclass("table")

---Creates a validator accepting any table, without constraining its contents.
---
---Use `V.shape`, `V.array`, or `V.map` to constrain what is inside.
---@return TableValidator
---@nodiscard
function _primitives.table()
	return Validator.instance(TableValidator, {
		rules = {
			Validator.type_gate("table"),
		},
	})
end

-- String

---@class StringValidator : Validator<string>
local StringValidator = Validator.subclass("string")

---Creates a validator accepting strings.
---@return StringValidator
---@nodiscard
function _primitives.string()
	return Validator.instance(StringValidator, {
		rules = {
			Validator.type_gate("string"),
		},
	})
end

---Requires the string to be at least `min_length` characters long.
---@param min_length integer # The fewest characters allowed.
---@return StringValidator
---@nodiscard
function StringValidator:min_length(min_length)
	return self:extend({
		id = "string.min_length",
		describe = string.format("at least %d characters long", min_length),
		check = function(value)
			if #value >= min_length then
				return true
			end

			return false, string.format("must be at least %d characters long, got %d", min_length, #value)
		end,
	})
end

---Requires the string to be at most `max_length` characters long.
---@param max_length integer # The most characters allowed.
---@return StringValidator
---@nodiscard
function StringValidator:max_length(max_length)
	return self:extend({
		id = "string.max_length",
		describe = string.format("at most %d characters long", max_length),
		check = function(value)
			if #value <= max_length then
				return true
			end

			return false, string.format("must be at most %d characters long, got %d", max_length, #value)
		end,
	})
end

---Requires the string's length to fall within the given inclusive range.
---@param min_length integer # The fewest characters allowed.
---@param max_length integer # The most characters allowed.
---@return StringValidator
---@nodiscard
function StringValidator:length_in_range(min_length, max_length)
	return self:extend({
		id = "string.length_in_range",
		describe = string.format("between %d and %d characters long", min_length, max_length),
		check = function(value)
			if #value >= min_length and #value <= max_length then
				return true
			end

			return false, string.format("must be between %d and %d characters long, got %d", min_length, max_length, #value)
		end,
	})
end

---Requires the string to contain at least one character.
---@return StringValidator
---@nodiscard
function StringValidator:not_empty()
	return self:extend({
		id = "string.not_empty",
		describe = "not empty",
		check = function(value)
			if value ~= "" then
				return true
			end

			return false, "must not be empty"
		end,
	})
end

---Requires the string to contain no characters.
---@return StringValidator
---@nodiscard
function StringValidator:is_empty()
	return self:extend({
		id = "string.is_empty",
		describe = "empty",
		check = function(value)
			if value == "" then
				return true
			end

			return false, string.format("must be empty, got %s", _result.format_value(value))
		end,
	})
end

---Requires the string to match the given Lua pattern.
---@param pattern string # The Lua pattern to match.
---@param description string? # How to describe the requirement, in place of the raw pattern.
---@return StringValidator
---@nodiscard
function StringValidator:matches(pattern, description)
	local described = description or string.format("a match for the pattern '%s'", pattern)

	return self:extend({
		id = "string.matches",
		describe = described,
		check = function(value)
			if string.match(value, pattern) then
				return true
			end

			return false, string.format("must be %s, got %s", described, _result.format_value(value))
		end,
	})
end

---Requires the string to begin with the given prefix.
---
---The prefix is compared literally; pattern magic characters carry no meaning.
---@param prefix string # The required prefix.
---@return StringValidator
---@nodiscard
function StringValidator:starts_with(prefix)
	return self:extend({
		id = "string.starts_with",
		describe = string.format("prefixed with '%s'", prefix),
		check = function(value)
			if value:sub(1, #prefix) == prefix then
				return true
			end

			return false, string.format("must start with '%s', got %s", prefix, _result.format_value(value))
		end,
	})
end

---Requires the string to end with the given suffix.
---
---The suffix is compared literally; pattern magic characters carry no meaning.
---@param suffix string # The required suffix.
---@return StringValidator
---@nodiscard
function StringValidator:ends_with(suffix)
	return self:extend({
		id = "string.ends_with",
		describe = string.format("suffixed with '%s'", suffix),
		check = function(value)
			if #suffix == 0 or (#value >= #suffix and value:sub(-#suffix) == suffix) then
				return true
			end

			return false, string.format("must end with '%s', got %s", suffix, _result.format_value(value))
		end,
	})
end

---Requires the string to contain the given substring.
---
---The substring is compared literally; pattern magic characters carry no meaning.
---@param substring string # The required substring.
---@return StringValidator
---@nodiscard
function StringValidator:contains(substring)
	return self:extend({
		id = "string.contains",
		describe = string.format("containing '%s'", substring),
		check = function(value)
			if string.find(value, substring, 1, true) then
				return true
			end

			return false, string.format("must contain '%s', got %s", substring, _result.format_value(value))
		end,
	})
end

-- Number

---@class NumberValidator : Validator<number>
local NumberValidator = Validator.subclass("number")

---Rejects values that are not whole numbers.
---
---`nan` and the infinities fail as a side effect: neither yields zero from the
---modulo, which is the behavior wanted here.
---@type ValidationRule<number>
local INTEGER_GATE = {
	id = "number.integer",
	describe = "an integer",
	is_gate = true,
	check = function(value)
		if value % 1 == 0 then
			return true
		end

		return false, string.format("must be an integer, got %s", _result.format_value(value))
	end,
}

---Creates a validator accepting numbers.
---@return NumberValidator
---@nodiscard
function _primitives.number()
	return Validator.instance(NumberValidator, {
		rules = {
			Validator.type_gate("number"),
		},
	})
end

---Creates a validator accepting whole numbers.
---@return NumberValidator
---@nodiscard
function _primitives.integer()
	return Validator.instance(NumberValidator, {
		rules = {
			Validator.type_gate("number"),
			INTEGER_GATE,
		},
	})
end

---Requires the number to be greater than zero.
---@return NumberValidator
---@nodiscard
function NumberValidator:positive()
	return self:extend({
		id = "number.positive",
		describe = "positive",
		check = function(value)
			if value > 0 then
				return true
			end

			return false, string.format("must be positive, got %s", _result.format_value(value))
		end,
	})
end

---Requires the number to be less than zero.
---@return NumberValidator
---@nodiscard
function NumberValidator:negative()
	return self:extend({
		id = "number.negative",
		describe = "negative",
		check = function(value)
			if value < 0 then
				return true
			end

			return false, string.format("must be negative, got %s", _result.format_value(value))
		end,
	})
end

---Requires the number to be zero or greater.
---@return NumberValidator
---@nodiscard
function NumberValidator:non_negative()
	return self:extend({
		id = "number.non_negative",
		describe = "zero or greater",
		check = function(value)
			if value >= 0 then
				return true
			end

			return false, string.format("must be zero or greater, got %s", _result.format_value(value))
		end,
	})
end

---Requires the number to be anything other than zero.
---@return NumberValidator
---@nodiscard
function NumberValidator:not_zero()
	return self:extend({
		id = "number.not_zero",
		describe = "non-zero",
		check = function(value)
			if value ~= 0 then
				return true
			end

			return false, "must not be zero"
		end,
	})
end

---Requires the number to fall within the given inclusive range.
---@param min number # The smallest value allowed.
---@param max number # The largest value allowed.
---@return NumberValidator
---@nodiscard
function NumberValidator:in_range(min, max)
	return self:extend({
		id = "number.in_range",
		describe = string.format("between %s and %s inclusive", tostring(min), tostring(max)),
		check = function(value)
			if value >= min and value <= max then
				return true
			end

			return false,
				string.format(
					"must be between %s and %s inclusive, got %s",
					tostring(min),
					tostring(max),
					_result.format_value(value)
				)
		end,
	})
end

---Requires the number to be no smaller than the given value.
---
---The inclusive counterpart of `greater_than`, and the one-sided form of `in_range`.
---@param min number # The smallest value allowed.
---@return NumberValidator
---@nodiscard
function NumberValidator:at_least(min)
	return self:extend({
		id = "number.at_least",
		describe = string.format("%s or greater", tostring(min)),
		check = function(value)
			if value >= min then
				return true
			end

			return false, string.format("must be %s or greater, got %s", tostring(min), _result.format_value(value))
		end,
	})
end

---Requires the number to be no larger than the given value.
---
---The inclusive counterpart of `less_than`, and the one-sided form of `in_range`.
---@param max number # The largest value allowed.
---@return NumberValidator
---@nodiscard
function NumberValidator:at_most(max)
	return self:extend({
		id = "number.at_most",
		describe = string.format("%s or less", tostring(max)),
		check = function(value)
			if value <= max then
				return true
			end

			return false, string.format("must be %s or less, got %s", tostring(max), _result.format_value(value))
		end,
	})
end

---Requires the number to exceed the given value.
---@param min number # The value the number must exceed.
---@return NumberValidator
---@nodiscard
function NumberValidator:greater_than(min)
	return self:extend({
		id = "number.greater_than",
		describe = string.format("greater than %s", tostring(min)),
		check = function(value)
			if value > min then
				return true
			end

			return false, string.format("must be greater than %s, got %s", tostring(min), _result.format_value(value))
		end,
	})
end

---Requires the number to fall below the given value.
---@param max number # The value the number must fall below.
---@return NumberValidator
---@nodiscard
function NumberValidator:less_than(max)
	return self:extend({
		id = "number.less_than",
		describe = string.format("less than %s", tostring(max)),
		check = function(value)
			if value < max then
				return true
			end

			return false, string.format("must be less than %s, got %s", tostring(max), _result.format_value(value))
		end,
	})
end

---Requires the number to be neither infinite nor `nan`.
---@return NumberValidator
---@nodiscard
function NumberValidator:finite()
	return self:extend({
		id = "number.finite",
		describe = "finite",
		check = function(value)
			if value == value and value ~= math.huge and value ~= -math.huge then
				return true
			end

			return false, string.format("must be finite, got %s", tostring(value))
		end,
	})
end

return _primitives
