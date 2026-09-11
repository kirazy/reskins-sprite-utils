---@namespace Reskins.SpriteUtils.Validation

local Validator = require("validation.validator")
local _result = require("validation.result")

---Provides validators for tables: arrays, maps, structs, and tuples.
---@class Collections
local _collections = {}

---Counts the entries of the given `value` and finds its largest whole-number key, or 0 when there is none.
---@param value table
---@return integer count
---@return integer max_index
local function measure(value)
	local count, max_index = 0, 0

	for key in pairs(value) do
		count = count + 1
		if type(key) == "number" and key % 1 == 0 and key > max_index then
			max_index = key --[[@as integer]]
		end
	end

	return count, max_index
end

---Gets the keys of the given `value`, sorted alphabetically.
---@param value table
---@return any[]
local function sorted_keys(value)
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end

	table.sort(keys, function(a, b)
		return _result.format_value(a) < _result.format_value(b)
	end)

	return keys
end

---Represents a validator that checks each element of an array against an element validator.
---@class ArrayValidator<T> : Validator<T[]>
local ArrayValidator = Validator.subclass("array")

---A gate that checks that a value is a contiguous, one-based sequence.
local SEQUENCE_GATE = {
	id = "array.sequence",
	describe = "an array",
	is_gate = true,
	check = function(value)
		local count, max_index = 0, 0

		for key in pairs(value) do
			count = count + 1

			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, string.format("must be an array, but has the non-index key %s", _result.format_value(key))
			end

			if key > max_index then
				max_index = key --[[@as integer]]
			end
		end

		if count ~= max_index then
			return false,
				string.format("must be an array without gaps, but has %d elements spanning indices 1 to %d", count, max_index)
		end

		return true
	end,
}

---Creates a validator that checks each element of an array against `validator`.
---@generic T
---@param validator Validator<T> The validator applied to each element.
---@return ArrayValidator<T>
---
---#### Examples
---```lua
----- Create a validator for a non-empty array of icon data.
---local IconData = V.array(IconDatum):not_empty()
---```
---@nodiscard
function _collections.array(validator)
	local element_rule = {
		id = "array.elements",
		-- The description is computed on demand. A `lazy` element is not resolved until its definition is bound.
		describe = function()
			return string.format("an array of %s", validator:describe())
		end,
		check = function(value, ctx)
			local _, max_index = measure(value)

			local errors = {}
			for index = 1, max_index do
				-- Gaps in the array are reported by the sequence gate.
				if value[index] ~= nil then
					local result = validator:validate(value[index], { path = string.format("%s[%d]", ctx.path, index) })
					for _, err in pairs(result.errors) do
						errors[#errors + 1] = err
					end
				end
			end

			if #errors == 0 then
				return true
			end

			return false, errors
		end,
	}

	return Validator.instance(ArrayValidator, {
		element = validator,
		collect_all = true,
		rules = { Validator.type_gate("table", "an array"), SEQUENCE_GATE, element_rule },
	})
end

---Permits gaps and non-index keys in the array.
---
---The elements at whole-number positions are validated. The values of non-index keys are not validated.
---@return self # A copy of this validator with the sequence rule removed.
---@nodiscard
function ArrayValidator:allow_holes()
	return self:without("array.sequence")
end

---Requires the array to contain at least one element.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function ArrayValidator:not_empty()
	return self:extend({
		id = "array.not_empty",
		describe = "not empty",
		check = function(value)
			if measure(value) > 0 then
				return true
			end

			return false, "must not be empty"
		end,
	})
end

---Requires the array to contain at least `min_length` elements.
---@param min_length integer The fewest elements allowed.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function ArrayValidator:min_length(min_length)
	return self:extend({
		id = "array.min_length",
		describe = string.format("at least %d elements", min_length),
		check = function(value)
			local count = measure(value)
			if count >= min_length then
				return true
			end

			return false, string.format("must have at least %d elements, got %d", min_length, count)
		end,
	})
end

---Requires the array to contain at most `max_length` elements.
---@param max_length integer The most elements allowed.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function ArrayValidator:max_length(max_length)
	return self:extend({
		id = "array.max_length",
		describe = string.format("at most %d elements", max_length),
		check = function(value)
			local count = measure(value)
			if count <= max_length then
				return true
			end

			return false, string.format("must have at most %d elements, got %d", max_length, count)
		end,
	})
end

---Requires the array to contain exactly `length` elements.
---@param length integer The number of elements required.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function ArrayValidator:length(length)
	return self:extend({
		id = "array.length",
		describe = string.format("exactly %d elements", length),
		check = function(value)
			local count = measure(value)
			if count == length then
				return true
			end

			return false, string.format("must have exactly %d elements, got %d", length, count)
		end,
	})
end

---Requires no two elements of the array to be equal.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function ArrayValidator:unique()
	return self:extend({
		id = "array.unique",
		describe = "free of duplicates",
		check = function(value)
			local _, max_index = measure(value)

			local seen = {}
			for index = 1, max_index do
				local element = value[index]
				-- `nan` is skipped. It cannot be a table key, and it is never equal to itself.
				if element ~= nil and element == element then
					if seen[element] then
						return false,
							string.format(
								"must not contain duplicates, but %s appears at indices %d and %d",
								_result.format_value(element),
								seen[element],
								index
							)
					end
					seen[element] = index
				end
			end

			return true
		end,
	})
end

---Requires the elements of the array to be sorted according to `compare`.
---@param compare? fun(a: T, b: T): boolean A function that returns `true` if `a` may precede `b`. Default `a <= b`.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function ArrayValidator:sorted(compare)
	compare = compare or function(a, b)
		return a <= b
	end

	return self:extend({
		id = "array.sorted",
		describe = "sorted",
		check = function(value)
			local _, max_index = measure(value)

			---@type integer?
			local previous_index
			for index = 1, max_index do
				if value[index] ~= nil then
					if previous_index then
						-- Elements that failed the element rule are still compared here, and comparing them may raise.
						local compared, precedes = pcall(compare, value[previous_index], value[index])

						if not compared then
							return false,
								string.format(
									"must be sorted, but the elements at indices %d and %d cannot be compared",
									previous_index,
									index
								)
						end

						if not precedes then
							return false, string.format("must be sorted, but the element at index %d precedes it", index)
						end
					end

					previous_index = index
				end
			end

			return true
		end,
	})
end

---Represents a validator that checks each key and each value of a table against a validator.
---@class MapValidator<K, V> : Validator<table<K, V>>
local MapValidator = Validator.subclass("map")

---Creates a validator that checks each key of a table against `key` and each value against `value`.
---@generic K, V
---@param key Validator<K> The validator applied to each key.
---@param value Validator<V> The validator applied to each value.
---@return MapValidator<K, V>
---
---#### Examples
---```lua
----- Create a validator for a table of icon data keyed by non-empty strings.
---local IconsByName = V.map(V.string():not_empty(), IconData)
---```
---@nodiscard
function _collections.map(key, value)
	---@type ValidationRule<table<K, V>>
	local entries_rule = {
		id = "map.entries",
		describe = function()
			return string.format("a table of %s keyed by %s", value:describe(), key:describe())
		end,
		check = function(subject, ctx)
			local errors = {}

			-- Keys are walked in sorted order, and failures are reported alphabetically.
			for _, entry_key in pairs(sorted_keys(subject)) do
				local key_result = key:validate(entry_key, { path = ctx.path })
				for _, err in pairs(key_result.errors) do
					errors[#errors + 1] = {
						path = ctx.path,
						message = string.format("has an invalid key %s: %s", _result.format_value(entry_key), err.message),
					}
				end

				local value_result = value:validate(subject[entry_key], { path = _result.child_path(ctx.path, entry_key) })
				for _, err in pairs(value_result.errors) do
					errors[#errors + 1] = err
				end
			end

			if #errors == 0 then
				return true
			end

			return false, errors
		end,
	}

	return Validator.instance(MapValidator, {
		key = key,
		value = value,
		collect_all = true,
		rules = { Validator.type_gate("table"), entries_rule },
	})
end

---Requires the map to contain at least one entry.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function MapValidator:not_empty()
	return self:extend({
		id = "map.not_empty",
		describe = "not empty",
		check = function(value)
			if next(value) ~= nil then
				return true
			end

			return false, "must not be empty"
		end,
	})
end

---Requires the map to contain at least `min_count` entries.
---@param min_count integer The fewest entries allowed.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function MapValidator:min_count(min_count)
	return self:extend({
		id = "map.min_count",
		describe = string.format("at least %d entries", min_count),
		check = function(value)
			local count = measure(value)
			if count >= min_count then
				return true
			end

			return false, string.format("must have at least %d entries, got %d", min_count, count)
		end,
	})
end

---Requires the map to contain at most `max_count` entries.
---@param max_count integer The most entries allowed.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function MapValidator:max_count(max_count)
	return self:extend({
		id = "map.max_count",
		describe = string.format("at most %d entries", max_count),
		check = function(value)
			local count = measure(value)
			if count <= max_count then
				return true
			end

			return false, string.format("must have at most %d entries, got %d", max_count, count)
		end,
	})
end

---Represents a validator that checks the named fields of a table against their validators.
---@class StructValidator<TValidated> : Validator<TValidated>
---The validator for each named field.
---@field fields table<string, Validator<any>>
local StructValidator = Validator.subclass("struct")

---Defines a validator for each field of `T`, keyed by the name of the field. Each validator is typed over the type of
---its field.
---@alias StructFields<T> { [K in keyof T]: Validator<T[K]> }

---Creates a validator that checks the named fields of a table against their validators.
---
---Fields are required unless their validator is `:optional()`. Unrecognized keys are permitted unless `:strict()` is
---called.
---@generic F : table<string, Validator<any>>
---@param fields F The validator for each named field.
---@return StructValidator<{ [K in keyof F]: any }> # A validator typed over the given field names.
---
---#### Examples
---```lua
----- Create a validator for an icon datum with an optional size and scale.
---local IconDatum = V.struct({
---    icon = ModFilePath,
---    icon_size = V.integer():positive():optional(),
---    scale = V.number():positive():optional(),
---})
---```
---@nodiscard
function _collections.struct(fields)
	local names = sorted_keys(fields)

	local fields_rule = {
		id = "struct.fields",
		describe = string.format("a table with the fields %s", table.concat(names, ", ")),
		check = function(value, ctx)
			local errors = {}

			-- Fields are walked in sorted order, and failures are reported alphabetically.
			for _, name in pairs(names) do
				local result = fields[name]:validate(value[name], { path = _result.child_path(ctx.path, name) })
				for _, err in pairs(result.errors) do
					errors[#errors + 1] = err
				end
			end

			if #errors == 0 then
				return true
			end

			return false, errors
		end,
	}

	return Validator.instance(StructValidator, {
		fields = fields,
		collect_all = true,
		rules = { Validator.type_gate("table"), fields_rule },
	}) --[[@as StructValidator<{ [K in keyof F]: any }>]]
end

---Creates a validator for the named class that checks the named fields of a table against their validators.
---
---The language server checks each field validator against the type of the class field of the same name. At runtime, the
---class name is not checked, and the validator is the one that `struct` creates.
---
---#### Parameters
---@generic T
---@param _type_name `T` The name of the class.
---@param fields StructFields<T> The validator for each named field.
---
---#### Returns
---@return StructValidator<T> # A validator typed over `T`.
---
---#### Examples
---```lua
----- Create a validator for a transform with an optional scale and shift.
------@using Reskins.SpriteUtils
---local Transform = V.class("Transform", {
---    scale = V.number():positive():optional(),
---    shift = Vector:optional(),
---})
---```
---@nodiscard
function _collections.class(_type_name, fields)
	return _collections.struct(fields) --[[@as StructValidator<T>]]
end

---Requires the table to have no unrecognized keys.
---@return self # A copy of this validator with the rule added.
---@nodiscard
function StructValidator:strict()
	local fields = self.fields

	return self:extend({
		id = "struct.strict",
		describe = "free of unrecognized fields",
		check = function(value, ctx)
			local errors = {}

			for _, key in pairs(sorted_keys(value)) do
				if fields[key] == nil then
					errors[#errors + 1] = {
						path = ctx.path,
						message = string.format("has the unrecognized field %s", _result.format_value(key)),
					}
				end
			end

			if #errors == 0 then
				return true
			end

			return false, errors
		end,
	})
end

---Requires the table to satisfy the given `predicate`.
---
---#### Parameters
---@param predicate fun(value: TValidated): boolean A function that returns `true` if the table is acceptable.
---@param message string The failure message, which follows the path in the rendered message.
---
---#### Returns
---@return self # A copy of this validator with the rule added.
---
---#### Examples
---```lua
----- Create a validator that requires `icon` or `icons` to be present.
---local Prototype = V.struct({ icon = Icon:optional(), icons = Icons:optional() })
---    :where(function(value) return value.icon ~= nil or value.icons ~= nil end,
---           "must define one of 'icon' or 'icons'")
---```
---@nodiscard
function StructValidator:where(predicate, message)
	return self:extend({
		id = "struct.where",
		describe = message,
		check = function(value)
			if predicate(value) then
				return true
			end

			return false, message
		end,
	})
end

---Represents a validator that checks each element of a fixed-length array against the validator for its position.
---@class TupleValidator<T> : Validator<T>
local TupleValidator = Validator.subclass("tuple")

---Creates a validator that checks each element of a fixed-length array against the validator for its position.
---@param ... Validator<any> The validator for each position, in order.
---@return TupleValidator<any>
---
---#### Examples
---```lua
----- Create a validator for a pair of numbers.
---local Offset = V.tuple(V.number(), V.number())
---```
---@nodiscard
function _collections.tuple(...)
	-- `table.pack` keeps a `nil` argument in the list. The result is walked by index. `pairs` would return the `n`
	-- field as an element.
	local elements = table.pack(...)
	local arity = elements.n

	for index = 1, arity do
		if elements[index] == nil then
			error(string.format("V.tuple(): argument %d is nil; every position needs a validator.", index), 2)
		end
	end

	local arity_rule = {
		id = "tuple.arity",
		describe = string.format("exactly %d elements", arity),
		is_gate = true,
		check = function(value)
			local count = measure(value)
			if count == arity then
				return true
			end

			return false, string.format("must have exactly %d elements, got %d", arity, count)
		end,
	}

	local elements_rule = {
		id = "tuple.elements",
		describe = function()
			local descriptions = {}
			for index = 1, arity do
				descriptions[index] = elements
					[index]--[[@cast -?]]
					:describe()
			end

			return string.format("(%s)", table.concat(descriptions, ", "))
		end,
		check = function(value, ctx)
			local errors = {}

			for index = 1, arity do
				local element = elements[index] --[[@as Validator<any>]]
				local result = element:validate(value[index], { path = string.format("%s[%d]", ctx.path, index) })
				for _, err in pairs(result.errors) do
					errors[#errors + 1] = err
				end
			end

			if #errors == 0 then
				return true
			end

			return false, errors
		end,
	}

	return Validator.instance(TupleValidator, {
		elements = elements,
		collect_all = true,
		rules = { Validator.type_gate("table", "an array"), arity_rule, elements_rule },
	})
end

return _collections
