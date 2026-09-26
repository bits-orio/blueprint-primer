-- Reopening the window on a machine that already carries a primed request
-- starts from that request, so pressing Request again without touching
-- anything rewrites the same request instead of shrinking it to half the
-- cap or swapping its fuel for the default. Pure state, like priming.lua.

local const = require("scripts.const")
local craft = require("scripts.craft")
local fuel = require("scripts.fuel")
local pending = require("scripts.pending")
local target = require("scripts.target")

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
  local input, crafts, requested = defines.inventory.crafter_input, nil, false
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

-- A fuel amount that differs from the estimate was typed, and stays typed.
function reopen.preset(p)
  local plans = pending.plans(p.target)
  if #plans == 0 then return end
  local item, quality, count = planned_fuel(p, plans)
  if p.recipe then p.crafts = planned_crafts(p, plans, item ~= nil) or p.crafts end
  if not item then return end
  p.fuel, p.fuel_quality, p.fuel_count = item, quality, count
  if p.target.kind == const.KIND_FUEL_ONLY then return end
  p.fuel_edited = p.crafts < 1 or count ~= fuel.estimate(p.target, p.recipe, p.crafts, item)
end

return reopen
