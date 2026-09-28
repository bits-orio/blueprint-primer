-- The recipe questions for a chest (ADR-0012). A chest crafts nothing, so
-- its recipe mode offers every recipe some crafter could run: the union of
-- the crafting categories of every assembling machine and furnace. Never
-- asks the chest's own prototype for categories, and never calls get_recipe
-- on a container. target_recipe.lua delegates here for chests.

local const = require("scripts.const")
local recipes = require("scripts.recipes")

local chest_recipe = {}

-- Memoised in file-level locals: pure functions of the prototypes, so every
-- peer computes the same answer (like target_recipe's per-prototype memos).
local categories, candidates

function chest_recipe.categories()
  if categories then return categories end
  categories = {}
  local types = {}
  for type_name in pairs(const.CRAFTER_TYPES) do types[#types + 1] = type_name end
  for _, prototype in pairs(prototypes.get_entity_filtered({ { filter = "type", type = types } })) do
    for category in pairs(prototype.crafting_categories or {}) do categories[category] = true end
  end
  return categories
end

function chest_recipe.filters()
  return recipes.filters_for(chest_recipe.categories())
end

-- Long with Space Age (hundreds of recipes): accepted, the picker opens on
-- the current recipe's group tab.
function chest_recipe.candidates()
  if candidates then return candidates end
  candidates = recipes.sorted(chest_recipe.filters(), function(recipe)
    return not recipe.parameter and recipes.item_ingredient_count(recipe) > 0
  end)
  return candidates
end

local function in_categories(recipe)
  for category in pairs(chest_recipe.categories()) do
    if recipe.has_category(category) then return true end
  end
  return false
end

-- Unresearched recipes are allowed, as for machines (ADR-0009).
function chest_recipe.allows(t, recipe_name)
  if not recipe_name or not t.force.valid then return false end
  local recipe = t.force.recipes[recipe_name]
  if not recipe or recipe.hidden or recipe.prototype.parameter then return false end
  return in_categories(recipe) and recipes.item_ingredient_count(recipe) > 0
end

return chest_recipe
