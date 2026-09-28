-- Recipe prototype helpers shared by a machine's recipe questions
-- (target_recipe.lua) and a chest's (chest_recipe.lua): the prototype
-- filters for a set of crafting categories, and the candidate list in the
-- engine's inventory order. Pure prototype reads, the same for every peer.

local recipes = {}

function recipes.item_ingredient_count(recipe)
  local count = 0
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "item" then count = count + 1 end
  end
  return count
end

-- "and" binds tighter than "or" in prototype filters, so the exclusions are
-- repeated after every category: (c1 AND NOT h AND items) OR (c2 AND ...).
-- Fluid-only recipes are left out: robots have nothing to deliver for them.
function recipes.filters_for(categories)
  local filters = {}
  for category in pairs(categories or {}) do
    filters[#filters + 1] = { filter = "category", category = category, mode = "or" }
    filters[#filters + 1] = { filter = "hidden", invert = true, mode = "and" }
    filters[#filters + 1] = { filter = "has-ingredient-item", mode = "and" }
  end
  return filters
end

-- The engine's own furnace rule and the picker's order: group, subgroup,
-- then recipe order. "\0" sorts below every other byte, so comparing the
-- joined strings compares the fields in turn.
function recipes.inventory_order(recipe)
  return table.concat({ recipe.group.order, recipe.subgroup.order, recipe.order, recipe.name }, "\0")
end

-- The names of the recipes `filters` match that `keep` accepts, in
-- inventory order.
function recipes.sorted(filters, keep)
  if #filters == 0 then return {} end
  local keyed = {}
  for name, recipe in pairs(prototypes.get_recipe_filtered(filters)) do
    if keep(recipe) then keyed[#keyed + 1] = { name = name, key = recipes.inventory_order(recipe) } end
  end
  table.sort(keyed, function(a, b) return a.key < b.key end)
  local names = {}
  for i, entry in ipairs(keyed) do names[i] = entry.name end
  return names
end

return recipes
