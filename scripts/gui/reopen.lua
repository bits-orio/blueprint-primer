-- Reopening the window on a machine that already carries a primed request
-- starts from that request, so pressing Request again without touching
-- anything rewrites the same request instead of shrinking it to half the
-- cap or swapping its fuel for the default. Pure state, like priming.lua.

local const = require("scripts.const")
local craft = require("scripts.craft")
local fuel = require("scripts.fuel")
local pending = require("scripts.pending")
local target = require("scripts.target")
local items = require("scripts.gui.items")

local reopen = {}

-- What the target holds once the request lands: requests top a built
-- machine up, so what is inside already counts (0 for a ghost).
local function planned(t, plans, inventory, name, quality)
  local requested = pending.count(plans, inventory, name, quality)
  return requested + target.inventory_count(t, inventory, name, quality), requested > 0
end

-- Whole crafts the planned ingredients cover; nil when nothing of this
-- request is pending, so an untouched machine still opens at half the cap.
-- A pending fuel counts as pending: robots may deliver the ingredients
-- before the fuel, and the crafts inside must still size that fuel.
local function planned_crafts(p, plans, fuel_pending)
  local input, crafts, requested = target.input_inventory(p.target), nil, false
  for _, ingredient in ipairs(craft.ingredients(p.recipe)) do
    if ingredient.type == "item" and ingredient.amount > 0 then
      local have, asked = planned(p.target, plans, input, ingredient.name, p.quality)
      crafts = math.min(crafts or math.huge, math.floor(have / ingredient.amount))
      requested = requested or asked
    end
  end
  return (requested or fuel_pending) and crafts or nil
end

-- The first requested fuel this burner takes, at its quality, and how much
-- of it is planned.
local function planned_fuel(p, plans)
  local fuel_inventory = defines.inventory.fuel
  for _, item in ipairs(pending.items_in(plans, fuel_inventory)) do
    if fuel.accepts(p.target, item.name) then
      return item.name, item.quality, (planned(p.target, plans, fuel_inventory, item.name, item.quality))
    end
  end
  return nil
end

-- The item ingredients of a recipe, `{ name, amount }` in recipe order.
local function item_ingredients(recipe)
  local list = {}
  for _, ingredient in ipairs(craft.ingredients(recipe)) do
    if ingredient.type == "item" and ingredient.amount > 0 then list[#list + 1] = ingredient end
  end
  return list
end

local function is_ingredient(list, name)
  for _, ingredient in ipairs(list) do
    if ingredient.name == name then return true end
  end
  return false
end

-- The crafts of `recipe` at `quality` a chest's pending request is exactly
-- the request for, or nil (ADR-0013): every pending item is an ingredient at
-- that quality, the planned amounts cover N >= 1 crafts, and each pending
-- ingredient plans exactly ceil(N * amount), so an untouched Request
-- rewrites the same request (ADR-0003). Never guessed from the items alone.
local function chest_crafts(t, plans, recipe, quality)
  local chest, ingredients, crafts = target.input_inventory(t), item_ingredients(recipe), nil
  for _, item in ipairs(pending.items_in(plans, chest)) do
    if item.quality ~= quality or not is_ingredient(ingredients, item.name) then return nil end
  end
  for _, ingredient in ipairs(ingredients) do
    local have = planned(t, plans, chest, ingredient.name, quality)
    crafts = math.min(crafts or math.huge, math.floor(have / ingredient.amount))
  end
  if not crafts or crafts < 1 then return nil end
  for _, ingredient in ipairs(ingredients) do
    local have, asked = planned(t, plans, chest, ingredient.name, quality)
    if asked and have ~= math.ceil(crafts * ingredient.amount) then return nil end
  end
  return crafts
end

-- Rows in the order a fresh placement filled them, from the last slot down:
-- the engine hands plans back in its own order, not the order written.
local function by_slot(a, b)
  if a.top ~= b.top then return a.top > b.top end
  if a.name ~= b.name then return a.name < b.name end
  return a.quality < b.quality
end

-- One row per pending item and quality, highest slot first, at what the
-- chest holds once it lands.
local function pending_rows(t, plans)
  local chest, rows, seen = target.input_inventory(t), {}, {}
  for _, item in ipairs(pending.items_in(plans, chest)) do
    local key = item.name .. "/" .. item.quality
    if not seen[key] then
      seen[key] = true
      local count = planned(t, plans, chest, item.name, item.quality)
      rows[#rows + 1] = { name = item.name, quality = item.quality, count = count, top = item.top }
    end
  end
  table.sort(rows, by_slot)
  return rows
end

-- A fresh chest opens in recipe mode on its fed recipe (at half the chest
-- cap), else in items mode with no rows. A pending request reopens as its
-- fed recipe only when it is exactly that recipe's request; anything else
-- reopens as items.
local function chest_preset(p)
  local t = p.target
  local plans = pending.plans(t)
  local recipe, quality = target.fed_recipe(t)
  local rows = pending_rows(t, plans)
  local crafts = recipe and #rows > 0 and chest_crafts(t, plans, recipe, quality)
  if recipe and (#rows == 0 or crafts) then
    p.mode, p.recipe, p.quality, p.crafts = const.MODE_RECIPE, recipe, quality, crafts or 0
    return
  end
  p.mode = const.MODE_ITEMS
  items.fill(p, rows)
end

-- A fuel amount that differs from the estimate was typed, and stays typed.
function reopen.preset(p)
  if p.target.kind == const.KIND_CHEST then return chest_preset(p) end
  local plans = pending.plans(p.target)
  if #plans == 0 then return end
  local item, quality, count = planned_fuel(p, plans)
  if p.recipe then p.crafts = planned_crafts(p, plans, item ~= nil) or p.crafts end
  if not item then return end
  p.fuel, p.fuel_quality, p.fuel_count = item, quality, count
  if p.target.kind == const.KIND_FUEL_ONLY then return end
  p.fuel_edited = p.crafts < 1 or count ~= fuel.estimate(p.target, p.recipe, p.crafts, item)
end

-- A settings paste (ADR-0008) starts from the source machine's Priming
-- instead: its recipe, crafts and fuel, and for a chest its mode and rows
-- (fresh ids). Settling then fits them to this machine, whose own estimate
-- sizes the fuel unless the amount was typed, and whose row caps keep the
-- earlier rows first.
function reopen.carry(p, from)
  p.recipe, p.quality, p.crafts = from.recipe, from.quality, from.crafts
  if from.fuel then p.fuel, p.fuel_quality = from.fuel, fuel.quality_for(p.target, from.fuel) end
  p.fuel_count, p.fuel_edited = from.fuel_count, from.fuel_edited
  if p.items then
    p.mode = from.mode or p.mode
    items.fill(p, from.items)
  end
end

return reopen
