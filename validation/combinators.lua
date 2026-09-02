---@namespace Reskins.SpriteUtils.Validation

local Validator = require("validation.validator")
local _result = require("validation.result")

---Validators built by combining other validators.
---@class Combinators
local _combinators = {}

---Packs the given branch validators into a table with its count in `n`. Raises an error if any
---branch is `nil`. The result must be iterated by index, not with `pairs`.
---@param caller string The name of the calling function, used in error messages.
---@param ... Validator<any> The branches to pack.
---@return table branches The packed branches, with `n` holding the count.
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
---When no validator accepts the value, the failure message lists the requirement of each validator
---and why the value did not satisfy it.
---@generic T
---@param ... Validator<T> The branches to try, in order.
---@return Validator<any>
---
---#### Examples
---```lua
---local Vector = V.any_of(V.tuple(V.number(), V.number()), V.shape({ x = V.number(), y = V.number() }))
---```
---@overload fun<A>(a: Validator<A>): Validator<A>
---@overload fun<A, B>(a: Validator<A>, b: Validator<B>): Validator<A|B>
---@overload fun<A, B, C>(a: Validator<A>, b: Validator<B>, c: Validator<C>): Validator<A|B|C>
---@overload fun<A, B, C, D>(a: Validator<A>, b: Validator<B>, c: Validator<C>, d: Validator<D>): Validator<A|B|C|D>
---@overload fun<A, B, C, D, E>(a: Validator<A>, b: Validator<B>, c: Validator<C>, d: Validator<D>, e: Validator<E>): Validator<A|B|C|D|E>
---@overload fun(...): Validator<any>
---@nodiscard
function _combinators.any_of(...)
	local branches = pack_branches("V.any_of", ...)

	-- Descriptions are resolved on demand, since a branch may be a `lazy` validator whose
	-- definition is not yet bound.
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

local AllOfValidator = Validator.subclass("all_of")

---Creates a validator accepting a value that satisfies every one of the given validators.
---@generic T
---@param ... Validator<T> The validators to apply, in order.
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
---@generic K, const V
---@param values table<K, V> The permitted values.
---@return Validator<V>
---
---#### Examples
---```lua
---local PipeMaterial = V.one_of(_defines.pipe_material)
---local AntennaVariant = V.one_of({ 0, 1, 2, 3, 4 })
---```
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
---@param expected T The only permitted value.
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

---Creates a validator from the given predicate function.
---@param predicate fun(value: any): boolean A function that returns `true` if the value is acceptable.
---@param message string What the value must be, phrased to follow `must be`.
---@return Validator<any>
---@nodiscard
function _combinators.custom(predicate, message)
	return Validator.instance(CustomValidator):satisfies(predicate, message)
end

---A validator that defers to a validator that is not yet defined. `TDeferred` is the class of the
---deferred validator, and `TValidated` is the type it validates.
---@generic TDeferred : Validator<TValidated>, TValidated
---@class LazyValidator<TDeferred, TValidated> : Validator<TValidated>
---Resolves and caches the deferred validator, and returns it. Kind-specific builder methods are
---available on the returned validator, not on the lazy validator. Must not be called before the
---deferred validator is defined.
---@field resolve fun(): TDeferred
local LazyValidator = Validator.subclass("lazy")

---Gets the description of the deferred validator. Resolves the deferred validator.
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

---Creates a validator that calls the given resolver function to get the validator to use the first
---time it is used. Used for recursive and mutually-referencing definitions.
---
---The type of the deferred validator is inferred from the resolver. A forward declaration must be
---annotated with its type.
---@generic TDeferred : Validator<any>, TValidated
---@param resolver (fun(): TDeferred)|(fun(): Validator<TValidated>) A function that returns the validator to delegate to.
---@return LazyValidator<TDeferred, TValidated>
---
---#### Examples
---```lua
------@type ShapeValidator<Animation>
---local Animation
---
---Animation = V.shape({
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
				-- Usually a forward reference read before it was assigned.
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
