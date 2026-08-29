---@namespace Reskins.SpriteUtils.Validation

local Validator = require("validation.validator")
local _result = require("validation.result")

---Validators built by combining other validators.
---@class Combinators
local _combinators = {}

---Packs a run of branch validators, rejecting a nil among them.
---
---Collecting varargs with `{ ... }` leaves a gap wherever a nil was passed, and
---every branch after that gap is silently dropped. The count `table.pack`
---records turns that into an error at the point of definition.
---
---Callers walk the result by index: a packed table carries its count in `n`, so
---`pairs` would hand back `n` as though it were a branch.
---@param caller string # The name of the calling factory, for the message.
---@param ... Validator<any> # The branches to pack.
---@return table branches # The packed branches, with `n` holding the count.
---@nodiscard
local function pack_branches(caller, ...)
	local branches = table.pack(...)

	for index = 1, branches.n do
		if branches[index] == nil then
			error(string.format("%s(): argument %d is nil; every branch needs a validator.", caller, index), 3)
		end
	end

	return branches
end

-- Unions and intersections

local AnyOfValidator = Validator.subclass("any_of")

---Creates a validator accepting a value that satisfies at least one of the given validators.
---
---Factorio's types are full of unions — a `Vector` is either `{x, y}` or a pair
---of numbers, an icon source is one of three shapes — and this is how they are
---expressed. When nothing matches, the failure lists what each branch wanted and
---why it did not fit, since the caller cannot otherwise tell which branch they
---were closest to satisfying.
---
---### Examples
---```lua
---local Vector = V.any_of(V.tuple(V.number(), V.number()), V.shape({ x = V.number(), y = V.number() }))
---```
---
---### Parameters
---@generic T
---@param ... Validator<T> # The branches to try, in order.
---
---### Returns
---@return Validator<any>
---
---@overload fun<A>(a: Validator<A>): Validator<A>
---@overload fun<A, B>(a: Validator<A>, b: Validator<B>): Validator<A|B>
---@overload fun<A, B, C>(a: Validator<A>, b: Validator<B>, c: Validator<C>): Validator<A|B|C>
---@overload fun<A, B, C, D>(a: Validator<A>, b: Validator<B>, c: Validator<C>, d: Validator<D>): Validator<A|B|C|D>
---@nodiscard
function _combinators.any_of(...)
	local branches = pack_branches("V.any_of", ...)

	-- Descriptions are resolved on demand rather than up front: a branch may be
	-- a `lazy` validator standing in for a definition that is still being bound.
	local function describe_branches()
		local descriptions = {}
		for index = 1, branches.n do
			descriptions[index] = branches[index]:describe()
		end

		return descriptions
	end

	return Validator.instance(AnyOfValidator, {
		rules = {
			{
				id = "any_of",
				describe = function()
					return table.concat(describe_branches(), ", or ")
				end,
				check = function(value, ctx)
					local failures = {}

					-- Branches are tried in the order they were given, and the
					-- first that matches wins.
					for index = 1, branches.n do
						local result = branches[index]:validate(value, { path = ctx.path })
						if result.ok then
							return true
						end

						failures[index] = result.errors[1]
					end

					local descriptions = describe_branches()

					local details = {}
					for index = 1, branches.n do
						local failure = failures[index]
						details[index] =
							string.format("  - %s: %s", descriptions[index], failure and failure.message or "did not match")
					end

					return false,
						string.format(
							"must be %s, but matched none of them:\n%s",
							table.concat(descriptions, ", or "),
							table.concat(details, "\n")
						)
				end,
			},
		},
	})
end

local AllOfValidator = Validator.subclass("all_of")

---Creates a validator accepting a value that satisfies every one of the given validators.
---@generic T
---@param ... Validator<T> # The validators to apply, in order.
---@return Validator<T>
---@nodiscard
function _combinators.all_of(...)
	local branches = pack_branches("V.all_of", ...)

	return Validator.instance(AllOfValidator, {
		collect_all = true,
		rules = {
			{
				id = "all_of",
				describe = function()
					local descriptions = {}
					for index = 1, branches.n do
						descriptions[index] = branches[index]:describe()
					end

					return table.concat(descriptions, " and ")
				end,
				check = function(value, ctx)
					local errors = {}

					for index = 1, branches.n do
						local result = branches[index]:validate(value, { path = ctx.path })
						for _, err in pairs(result.errors) do
							errors[#errors + 1] = err
						end
					end

					if #errors == 0 then
						return true
					end

					return false, errors
				end,
			},
		},
	})
end

-- Value membership

local OneOfValidator = Validator.subclass("one_of")

---Creates a validator accepting any value drawn from a finite set.
---
---Membership is decided by equality, so the set may hold values of any type.
---
---### Examples
---```lua
---local PipeMaterial = V.one_of(_defines.pipe_material)
---local AntennaVariant = V.one_of({ 0, 1, 2, 3, 4 })
---```
---
---### Parameters
---@generic K, const V
---@param values table<K, V> # The permitted values.
---
---### Returns
---@return Validator<V>
---@nodiscard
function _combinators.one_of(values)
	local described = _result.format_value(values)

	return Validator.instance(OneOfValidator, {
		values = values,
		rules = {
			{
				id = "one_of",
				describe = string.format("one of %s", described),
				check = function(value)
					for _, permitted in pairs(values) do
						if value == permitted then
							return true
						end
					end

					return false, string.format("must be one of %s, got %s", described, _result.format_value(value))
				end,
			},
		},
	})
end

local LiteralValidator = Validator.subclass("literal")

---Creates a validator accepting exactly one value.
---@generic const T
---@param expected T # The only permitted value.
---@return Validator<T>
---@nodiscard
function _combinators.literal(expected)
	local described = _result.format_value(expected)

	return Validator.instance(LiteralValidator, {
		rules = {
			{
				id = "literal",
				describe = described,
				check = function(value)
					if value == expected then
						return true
					end

					return false, string.format("must be %s, got %s", described, _result.format_value(value))
				end,
			},
		},
	})
end

-- Escape hatches

local CustomValidator = Validator.subclass("custom")

---Creates a validator from a bare predicate.
---
---For the cases the built-in rules do not cover. Prefer composing the built-ins
---where possible, since they describe themselves in failure messages.
---
---### Parameters
---@param predicate fun(value: any): boolean # Returns `true` when the value is acceptable.
---@param message string # What the value must be, phrased to follow `must be`.
---
---### Returns
---@return Validator<any>
---@nodiscard
function _combinators.custom(predicate, message)
	return Validator.instance(CustomValidator):satisfies(predicate, message)
end

---A validator standing in for one that is not yet defined.
---
---Two parameters rather than one: `TDeferred` is the deferred validator's own
---class, so `resolve` hands back the real thing, and `TValidated` is what that
---validator validates, which is what this stands in for everywhere a validator
---is accepted.
---@generic TDeferred : Validator<TValidated>, TValidated
---@class LazyValidator<TDeferred, TValidated> : Validator<TValidated>
---Resolves and caches the validator being deferred to.
---
---This is the way to reach a kind-specific builder. A lazy validator is a
---`Validator` and nothing more — `StringValidator` is a sibling class, never in
---its `__index` chain — so `V.lazy(f):min_length(3)` is a nil call where
---`V.lazy(f).resolve():min_length(3)` is not. Calling it resolves, so only do so
---once the definition being deferred to is complete.
---@field resolve fun(): TDeferred
local LazyValidator = Validator.subclass("lazy")

---Describes the deferred validator.
---
---Describing has to resolve, since anything else would report a placeholder in
---the failure message of every union this takes part in.
---@return string
---@nodiscard
function LazyValidator:describe()
	if self.description then
		return self.description
	end

	return self
		.resolve()--[[@as Validator<TValidated>]]
		:describe()
end

---Creates a validator that resolves the given validator the first time it is used.
---
---This is how a recursive or mutually-referencing definition is expressed: the
---resolver runs after both definitions exist, rather than at the point the
---reference is written.
---
---The type of the deferred validator is read from the resolver, so annotating
---the forward declaration is what keeps it from being erased. It has to be named
---once regardless, since a recursive definition cannot be inferred from itself.
---
---### Examples
---```lua
------@type ShapeValidator<Animation>
---local Animation
---
---Animation = V.shape({
---    filename = ModFilePath:optional(),
---    layers = V.array(V.lazy(function() return Animation end)):optional(),
---})
---```
---
---### Parameters
---@generic TDeferred : Validator<any>, TValidated
---@param resolver (fun(): TDeferred)|(fun(): Validator<TValidated>) # Returns the validator to delegate to.
---@return LazyValidator<TDeferred, TValidated>
---@nodiscard
function _combinators.lazy(resolver)
	---@type TDeferred?
	local resolved

	local function resolve()
		if not resolved then
			resolved = resolver()

			if not resolved then
				-- Almost always a forward reference read before it was assigned.
				error(
					"reskins-sprite-utils: a lazy validator's resolver returned nil. It ran before the validator it "
						.. "refers to had been assigned; make sure the reference is only read once the definition is complete.",
					0
				)
			end
		end

		return resolved
	end

	return Validator.instance(LazyValidator, {
		resolve = resolve,
		rules = {
			{
				id = "lazy",
				describe = "as resolved",
				check = function(value, ctx)
					local result = resolve():validate(value, { path = ctx.path })
					if result.ok then
						return true
					end

					return false, result.errors
				end,
			},
		},
	})
end

return _combinators
