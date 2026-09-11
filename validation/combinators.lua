---@namespace Reskins.SpriteUtils.Validation

local Validator = require("validation.validator")
local _result = require("validation.result")

---Provides validators built by combining other validators.
---@class Combinators
local _combinators = {}

---Packs the given branch validators into a table with their count in `n`, and raises an error when a branch is `nil`.
---@param caller string
---@param ... Validator<any>
---@return table branches
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

---Represents a validator that accepts a value when at least one of its validators accepts it.
---@class AnyOfValidator<T> : Validator<T>
local AnyOfValidator = Validator.subclass("any_of")

---Creates a validator that accepts a value when at least one of the given validators accepts it.
---
---When no validator accepts the value, the failure message lists the requirement of each validator and why the value
---did not satisfy it.
---@generic const T
---@param ... Validator<T> The branches to try, in order.
---@return AnyOfValidator<any>
---
---#### Examples
---```lua
---local Vector = V.any_of(V.tuple(V.number(), V.number()), V.struct({ x = V.number(), y = V.number() }))
---```
---@overload fun<const A>(a: Validator<A>): AnyOfValidator<A>
---@overload fun<const A, const B>(a: Validator<A>, b: Validator<B>): AnyOfValidator<A|B>
---@overload fun<const A, const B, const C>(a: Validator<A>, b: Validator<B>, c: Validator<C>): AnyOfValidator<A|B|C>
---@overload fun<const A, const B, const C, const D>(a: Validator<A>, b: Validator<B>, c: Validator<C>, d: Validator<D>): AnyOfValidator<A|B|C|D>
---@overload fun<const A, const B, const C, const D, const E>(a: Validator<A>, b: Validator<B>, c: Validator<C>, d: Validator<D>, e: Validator<E>): AnyOfValidator<A|B|C|D|E>
---@overload fun(...): AnyOfValidator<any>
---@nodiscard
function _combinators.any_of(...)
	local branches = pack_branches("V.any_of", ...)

	-- Descriptions are resolved on demand; a `lazy` branch can be described only after its deferred validator is
	-- defined.
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

					-- Branches are tried in order; the first match is used.
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

---Represents a validator that accepts a value when every one of its validators accepts it.
---@class AllOfValidator<T> : Validator<T>
local AllOfValidator = Validator.subclass("all_of")

---Creates a validator that accepts a value when every one of the given validators accepts it.
---@generic T
---@param ... Validator<T> The validators to apply, in order.
---@return AllOfValidator<T>
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

---Represents a validator that accepts any value in a set.
---@class OneOfValidator<T> : Validator<T>
local OneOfValidator = Validator.subclass("one_of")

---Creates a validator that accepts any of the given `values`.
---
---Membership is decided by equality; the set may contain values of any type.
---@generic K, const V
---@param values table<K, V> The permitted values.
---@return OneOfValidator<V>
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

---Represents a validator that accepts a single value.
---@class LiteralValidator<T> : Validator<T>
local LiteralValidator = Validator.subclass("literal")

---Creates a validator that accepts only the given `expected` value.
---@generic const T
---@param expected T The only permitted value.
---@return LiteralValidator<T>
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

---Represents a validator that checks a value with a predicate function.
---@class CustomValidator<T> : Validator<T>
local CustomValidator = Validator.subclass("custom")

---Creates a validator that checks a value with the given `predicate`.
---@generic T
---@param _type_name `T` The name of the type that the validator validates.
---@param predicate fun(value: unknown): TypeGuard<T> A function that returns `true` if the value is acceptable.
---@param message string The requirement that the value must satisfy, which follows `must be` in the failure message.
---@return CustomValidator<T>
---@nodiscard
function _combinators.custom(_type_name, predicate, message)
	return Validator.instance(CustomValidator):satisfies(predicate, message)
end

---Represents a validator that defers to a validator that is not yet defined.
---
---`TDeferred` is the class of the deferred validator, and `TValidated` is the type that it validates.
---@generic TDeferred : Validator<TValidated>, TValidated
---@class LazyValidator<TDeferred, TValidated> : Validator<TValidated>
---Resolves and caches the deferred validator, and returns it. The builder methods of the deferred validator's class are
---available on the returned validator only. The deferred validator must be defined before the call.
---@field resolve fun(): TDeferred
local LazyValidator = Validator.subclass("lazy")

---Gets the description of the deferred validator, resolving it first.
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

---Creates a validator that defers to the validator returned by the given `resolver`, which is called once on first use.
---
---The type of the deferred validator is inferred from the resolver. A forward declaration must be annotated with its
---type.
---@generic TDeferred : Validator<any>, TValidated
---@param resolver (fun(): TDeferred)|(fun(): Validator<TValidated>) A function that returns the validator to which validation is delegated.
---@return LazyValidator<TDeferred, TValidated>
---
---#### Examples
---```lua
------@type StructValidator<Animation>
---local Animation
---
---Animation = V.struct({
---    filename = ModFilePath:optional(),
---    layers = V.array(V.lazy(function() return Animation end)):optional(),
---})
---```
---@nodiscard
function _combinators.lazy(resolver)
	---@type TDeferred?
	local resolved

	local function resolve()
		if not resolved then
			resolved = resolver()

			if not resolved then
				-- The resolver ran before the validator that it refers to was assigned.
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
