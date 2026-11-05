---@using data

---@namespace Reskins.SpriteUtils

---Provides methods for selecting prototypes.
---
---#### Examples
---```lua
---local _prototypes = require("__reskins-sprite-utils__.prototypes")
---```
---@class Prototypes
local _prototypes = {}

local V = require("validation")
local Common = require("validation.common")

---A validator that checks that a value is a recipe prototype, without validating its ingredients and results.
local recipe_prototype = V.struct({
	type = V.literal("recipe"),
	name = Common.prototype_name,
	ingredients = V.table():optional(),
	results = V.table():optional(),
}):describe_as("a recipe prototype")

---Indicates whether the given `recipe` has an ingredient or a result with the given `name`.
---@param recipe RecipePrototype The recipe.
---@param name string The name of the ingredient or result.
---@return boolean # `true` if the recipe has the ingredient or result; otherwise, `false`.
---@nodiscard
local function is_used_by_recipe(recipe, name)
	for _, field in pairs({ "ingredients", "results" }) do
		for _, entry in pairs(recipe[field] or {}) do
			if entry.name == name then
				return true
			end
		end
	end

	return false
end

local check_select_name = V.signature("select_name", {
	{ "type_name", Common.prototypes.is_registered_type },
	{ "names", V.array(Common.prototype_name):not_empty() },
	{ "recipe", recipe_prototype:optional() },
})

---Gets the name of the prototype of the given `type_name` to use from the given `names`, which are in order of
---precedence.
---
---The name is selected by the first of these rules that selects one:
---1. When `recipe` is given, the first of `names` that exists and that the recipe has as an ingredient or a result.
---2. The first of `names` that exists and is not hidden.
---3. The first of `names` that exists.
---
---#### Parameters
---@param type_name string The type name of the prototypes.
---@param names string[] The names of the prototypes, in order of precedence.
---@param recipe? RecipePrototype The recipe for which the prototype is selected, such as the recipe of which the icon shows the prototype.
---
---#### Returns
---@return string? # The name of the selected prototype, or `nil` if no prototype in `names` exists.
---
---#### Examples
---```lua
----- Select the aluminium plate that a recipe makes. One mod creates both plates and hides its own.
---local name = _prototypes.select_name(
---    "item",
---    { "angels-plate-aluminium", "bob-aluminium-plate" },
---    data.raw.recipe["angels-plate-aluminium"]
---)
----- "bob-aluminium-plate" when the recipe makes it; otherwise, the first plate that exists and is not hidden.
---```
---@throws When `type_name` is not a registered prototype type name.
---@throws When `names` is not a non-empty array of prototype names.
---@throws When `recipe` is not a recipe prototype.
---@nodiscard
function _prototypes.select_name(type_name, names, recipe)
	check_select_name(type_name, names, recipe)

	local prototypes = data.raw[type_name] --[[@as table<string, { hidden?: boolean }>]]

	if recipe then
		for index = 1, #names do
			if prototypes[names[index]] and is_used_by_recipe(recipe, names[index]) then
				return names[index]
			end
		end
	end

	for index = 1, #names do
		local prototype = prototypes[names[index]]
		if prototype and not prototype.hidden then
			return names[index]
		end
	end

	for index = 1, #names do
		if prototypes[names[index]] then
			return names[index]
		end
	end

	return nil
end

return _prototypes
