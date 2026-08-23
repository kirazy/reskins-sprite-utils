---@namespace Reskins.SpriteUtils.Validation

local Validator = require("validation.validator")
local _result = require("validation.result")

---Validators for tables: arrays, maps, shapes, and tuples.
---@class Collections
local _collections = {}

---Counts the entries of a table and finds its largest whole-number key.
---
---`#` is unreliable on a table with gaps, so length rules count entries instead.
---@param value table
---@return integer count # The number of entries.
---@return integer max_index # The largest whole-number key, or `0` when there is none.
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

---Collects the keys of a table in alphabetical order.
---
---Factorio's `pairs` order is already stable from run to run, but it is hash
---order rather than a meaningful one. Sorting is what makes a list of field
---failures read predictably — alphabetically — rather than in whatever order
---the fields happened to be written.
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

-- Array

---@class ArrayValidator<T> : Validator<T[]>
local ArrayValidator = Validator.subclass("array")

---Rejects tables that are not contiguous, one-based sequences.
---
---This is a gate: with gaps or stray keys present, per-element failures would
---describe the wrong positions.
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

---Creates a validator accepting an array whose every element satisfies `element`.
---
---### Examples
---```lua
---local IconData = V.array(IconDatum):not_empty()
---```
---
---### Parameters
---@generic T
---@param element Validator<T> # The validator applied to each element.
---
---### Returns
---@return ArrayValidator<T>
---@nodiscard
function _collections.array(element)
	local element_rule = {
		id = "array.elements",
		-- Deferred: describing the element now would force a `lazy` element to
		-- resolve before a recursive definition had finished binding.
		describe = function()
			return string.format("an array of %s", element:describe())
		end,
		check = function(value, ctx)
			local _, max_index = measure(value)

			local errors = {}
			for index = 1, max_index do
				-- Entries absent from a gapped array are the sequence gate's
				-- business, not the element validator's.
				if value[index] ~= nil then
					local result = element:validate(value[index], { path = string.format("%s[%d]", ctx.path, index) })
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
		element = element,
		collect_all = true,
		rules = { Validator.type_gate("table", "an array"), SEQUENCE_GATE, element_rule },
	})
end

---Creates a copy of this validator that tolerates gaps and non-index keys.
---
---Elements still present are validated; missing positions are skipped.
---@param self ArrayValidator<T>
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.allow_holes(self)
	return ArrayValidator.without(self, "array.sequence")
end

---Requires the array to hold at least one element.
---@param self ArrayValidator<T>
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.not_empty(self)
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

---Requires the array to hold at least `min_length` elements.
---@param self ArrayValidator<T>
---@param min_length integer # The fewest elements allowed.
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.min_length(self, min_length)
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

---Requires the array to hold at most `max_length` elements.
---@param self ArrayValidator<T>
---@param max_length integer # The most elements allowed.
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.max_length(self, max_length)
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

---Requires the array to hold exactly `length` elements.
---@param self ArrayValidator<T>
---@param length integer # The number of elements required.
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.length(self, length)
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
---@param self ArrayValidator<T>
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.unique(self)
	return self:extend({
		id = "array.unique",
		describe = "free of duplicates",
		check = function(value)
			local _, max_index = measure(value)

			local seen = {}
			for index = 1, max_index do
				local element = value[index]
				-- `nan` is skipped rather than recorded: it cannot be a table key,
				-- and comparing unequal to itself, it can never be a duplicate.
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

---Requires the array's elements to be in order.
---@param self ArrayValidator<T>
---@param compare (fun(a: T, b: T): boolean)? # Returns `true` when `a` may precede `b`. Defaults to `a <= b`.
---@return ArrayValidator<T>
---@nodiscard
function ArrayValidator.sorted(self, compare)
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
						-- Guarded: this rule runs after the element rule rather than
						-- instead of it, so a comparison can be handed elements that
						-- already failed and have no order between them. The default
						-- comparison raises on mixed types, and a supplied one may
						-- raise on anything it did not expect.
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

-- Map

---@class MapValidator<K, V> : Validator<table<K, V>>
local MapValidator = Validator.subclass("map")

---Creates a validator accepting a table whose keys and values each satisfy a validator.
---
---### Examples
---```lua
---local IconsByName = V.map(V.string():not_empty(), IconData)
---```
---
---### Parameters
---@generic K, V
---@param key Validator<K> # The validator applied to each key.
---@param value Validator<V> # The validator applied to each value.
---
---### Returns
---@return MapValidator<K, V>
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

			-- Walked in sorted order so failures read alphabetically by key.
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

---Requires the map to hold at least one entry.
---@param self MapValidator<K, V>
---@return MapValidator<K, V>
---@nodiscard
function MapValidator.not_empty(self)
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

---Requires the map to hold at least `min_count` entries.
---@param self MapValidator<K, V>
---@param min_count integer # The fewest entries allowed.
---@return MapValidator<K, V>
---@nodiscard
function MapValidator.min_count(self, min_count)
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

---Requires the map to hold at most `max_count` entries.
---@param self MapValidator<K, V>
---@param max_count integer # The most entries allowed.
---@return MapValidator<K, V>
---@nodiscard
function MapValidator.max_count(self, max_count)
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

-- Shape

---@class ShapeValidator<TValidated> : Validator<TValidated>
---The validator for each named field.
---@field fields table<string, Validator<any>>
local ShapeValidator = Validator.subclass("shape")

---Creates a validator accepting a table whose named fields satisfy their validators.
---
---Fields are required unless their validator is `:optional()`. Unrecognized keys
---are permitted; call `:strict()` to reject them, which catches misspelled
---prototype fields that would otherwise be silently ignored.
---
---### Examples
---```lua
---local IconDatum = V.shape({
---    icon = ModFilePath,
---    icon_size = V.integer():positive():optional(),
---    scale = V.number():positive():optional(),
---})
---```
---
---### Parameters
---@param fields table<string, Validator<any>> # The validator for each named field.
---
---### Returns
---@return ShapeValidator<any>
---@nodiscard
function _collections.shape(fields)
	local names = sorted_keys(fields)

	local fields_rule = {
		id = "shape.fields",
		describe = string.format("a table with the fields %s", table.concat(names, ", ")),
		check = function(value, ctx)
			local errors = {}

			-- Walked in sorted order so fields are reported alphabetically.
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

	return Validator.instance(ShapeValidator, {
		fields = fields,
		collect_all = true,
		rules = { Validator.type_gate("table"), fields_rule },
	}) --[[@as ShapeValidator<any>]]
end

---Creates a copy of this validator that rejects keys it does not describe.
---@generic S : ShapeValidator<any>
---@param self S
---@return S
---@nodiscard
function ShapeValidator.strict(self)
	local fields = self.fields

	return self:extend({
		id = "shape.strict",
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

---Creates a copy of this validator with an additional rule spanning several fields.
---
---### Examples
---```lua
---local Prototype = V.shape({ icon = Icon:optional(), icons = Icons:optional() })
---    :where(function(value) return value.icon ~= nil or value.icons ~= nil end,
---           "must define one of 'icon' or 'icons'")
---```
---
---### Parameters
---@generic S : ShapeValidator<any>
---@param self S
---@param predicate fun(value: TValidated): boolean # Returns `true` when the table is acceptable.
---@param message string # The complete failure message, phrased to follow the path.
---
---### Returns
---@return S
---@nodiscard
function ShapeValidator.where(self, predicate, message)
	return self:extend({
		id = "shape.where",
		describe = message,
		check = function(value)
			if predicate(value) then
				return true
			end

			return false, message
		end,
	})
end

-- Tuple

---@class TupleValidator<T> : Validator<T>
local TupleValidator = Validator.subclass("tuple")

---Creates a validator accepting a fixed-length array of positionally typed elements.
---
---### Examples
---```lua
---local Offset = V.tuple(V.number(), V.number())
---```
---
---### Parameters
---@param ... Validator<any> # The validator for each position, in order.
---
---### Returns
---@return TupleValidator<any>
---@nodiscard
function _collections.tuple(...)
	-- Packed rather than collected with `{ ... }`: a nil among the arguments
	-- would leave a gap, and the arity would silently shrink to whatever came
	-- before it. `table.pack` records the count that was actually passed.
	--
	-- A packed table carries that count in its `n` field, so everything below
	-- walks it by index; `pairs` would hand back `n` as though it were an
	-- element.
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
