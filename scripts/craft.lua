-- Recipe math: per-craft amounts, the slot cap and the output unit. Pure
-- prototype reads, no LuaEntity access, so it is the same for every player.

local craft = {}

-- Runtime recipe order (items before fluids, whatever the data file says),
-- with each item ingredient's 0-based slot among the item ingredients: an
-- assembler's crafter_input stacks follow exactly that order (proved by the
-- spike), and a furnace has one source slot per item.
function craft.ingredients(recipe_name)
  local recipe = recipe_name and prototypes.recipe[recipe_name]
  if not recipe then return {} end
  local list, slot = {}, 0
  for _, ingredient in ipairs(recipe.ingredients) do
    local entry = { name = ingredient.name, type = ingredient.type, amount = ingredient.amount }
    if ingredient.type == "item" then
      entry.stack_size = prototypes.item[ingredient.name].stack_size
      entry.slot = slot
      slot = slot + 1
    end
    list[#list + 1] = entry
  end
  return list
end

-- The most one ingredient slot is asked to hold: a stack, or one craft's
-- worth when a single craft needs more than a stack (satellite: 100 low
-- density structures of stack 50). The engine lets a crafter's input slot
-- hold that much, and robots deliver it into one slot (bp-test delivery.g).
function craft.slot_limit(ingredient)
  return math.max(ingredient.stack_size, ingredient.amount)
end

-- The tightest item ingredient decides (ADR-0003); fluids never cap.
function craft.slot_cap(recipe_name)
  local cap
  for _, ingredient in ipairs(craft.ingredients(recipe_name)) do
    if ingredient.type == "item" and ingredient.amount > 0 then
      local fits = math.floor(craft.slot_limit(ingredient) / ingredient.amount)
      if not cap or fits < cap then cap = fits end
    end
  end
  return cap or 0
end

local function main_product(recipe)
  if recipe.main_product then return recipe.main_product end
  local products = recipe.products
  if #products == 1 then return products[1] end
  return nil
end

-- A product whose amount varies per craft (probability, min/max, or a
-- fractional bonus) has no honest output count; the slider counts crafts.
local function deterministic_amount(product)
  if product.probability and product.probability < 1 then return nil end
  if (product.extra_count_fraction or 0) > 0 then return nil end
  if product.amount_min and product.amount_min ~= product.amount_max then return nil end
  return product.amount or product.amount_min
end

function craft.output(recipe_name)
  local recipe = recipe_name and prototypes.recipe[recipe_name]
  local product = recipe and main_product(recipe)
  if not product then return nil end
  local amount = deterministic_amount(product)
  if not amount or amount <= 0 then return nil end
  return { name = product.name, type = product.type, amount_per_craft = amount }
end

return craft
