-- Fuel for a burner target: the energy-exact estimate (ADR-0004), how much
-- fits, which fuels it takes, and which one to pre-select. The module and
-- beacon factors the estimate scales by come from effects.lua.

local const = require("scripts.const")
local state = require("scripts.state")
local effects = require("scripts.effects")
local fuel_tier = require("scripts.fuel_tier")

local fuel = {}

local NORMAL = const.NORMAL_QUALITY

-- Base draw per tick. get_max_energy_usage(quality) is not used: bp-test
-- measured it on 2.0.77 and for burner crafters it equals energy_usage at
-- every quality, so quality reaches the estimate only through crafting speed.
local function base_usage(t)
  return t.prototype.energy_usage or 0
end

local function built_entity(t)
  local entity = t.entity
  if t.is_ghost or not (entity and entity.valid) then return nil end
  return entity
end

-- Seconds of base draw that one second of recipe energy costs in this target.
-- Modules and beacons change the speed and draw together, but a primed
-- blueprint carries no modules, so the larger of the bare and the moduled
-- figure is used: exact for speed and productivity modules, and never short
-- for a copy stamped from an efficiency-moduled machine.
local function draw_per_recipe_second(t)
  local speed = t.prototype.get_crafting_speed(t.quality)
  return math.max(1 / speed, effects.consumption_factor(t) / (speed * effects.speed_factor(t)))
end

function fuel.joules_per_craft(t, recipe_name)
  local recipe = recipe_name and prototypes.recipe[recipe_name]
  if not (t.burner and recipe) then return 0 end
  return recipe.energy * draw_per_recipe_second(t) * base_usage(t) * const.TICKS_PER_SECOND
    / t.burner.effectivity
end

-- One second of draw covers the fixed start-up cost the spike measured, so a
-- craft count landing exactly on a fuel-item boundary still finishes.
local function margin(t)
  local factor = math.max(1, effects.consumption_factor(t))
  return base_usage(t) * factor * const.TICKS_PER_SECOND * const.FUEL_MARGIN_SECONDS / t.burner.effectivity
end

local function fuel_value(item)
  local prototype = item and prototypes.item[item]
  return prototype and prototype.fuel_value or 0
end

function fuel.estimate(t, recipe_name, crafts, fuel_item)
  local value = fuel_value(fuel_item)
  if not t.burner or value <= 0 then return 1 end
  local joules = crafts * fuel.joules_per_craft(t, recipe_name) + margin(t)
  return math.max(1, math.ceil(joules / value - const.FLOAT_EPSILON))
end

function fuel.capacity(t, fuel_item)
  local prototype = fuel_item and prototypes.item[fuel_item]
  if not (t.burner and prototype) then return 0 end
  return t.burner.fuel_inventory_size * prototype.stack_size
end

-- Solved in closed form, then nudged so it agrees with fuel.estimate's own
-- rounding: estimate(result) <= capacity < estimate(result + 1).
function fuel.max_crafts(t, recipe_name, fuel_item)
  local per_craft = fuel.joules_per_craft(t, recipe_name)
  local capacity = fuel.capacity(t, fuel_item)
  if per_craft <= 0 then return math.huge end -- no burner or free recipe: fuel never caps
  if capacity <= 0 then return 0 end
  local crafts = math.floor((capacity * fuel_value(fuel_item) - margin(t)) / per_craft)
  crafts = math.max(0, crafts)
  while fuel.estimate(t, recipe_name, crafts + 1, fuel_item) <= capacity do crafts = crafts + 1 end
  while crafts > 0 and fuel.estimate(t, recipe_name, crafts, fuel_item) > capacity do crafts = crafts - 1 end
  return crafts
end

-- A fuel with a burnt result needs somewhere to put it.
function fuel.accepts(t, item)
  local burner = t.burner
  local prototype = burner and item and prototypes.item[item]
  if not prototype or prototype.parameter then return false end
  local category = prototype.fuel_category
  if not category or prototype.fuel_value <= 0 or not burner.fuel_categories[category] then return false end
  return not (prototype.burnt_result and burner.burnt_inventory_size == 0)
end

-- "and" binds tighter than "or", so the exclusions repeat per category.
function fuel.filters(t)
  local filters = {}
  if not t.burner then return filters end
  for category in pairs(t.burner.fuel_categories) do
    filters[#filters + 1] = { filter = "fuel-category", ["fuel-category"] = category, mode = "or" }
    filters[#filters + 1] = { filter = "hidden", invert = true, mode = "and" }
    filters[#filters + 1] = { filter = "is-parameter", invert = true, mode = "and" }
  end
  return filters
end

-- A built machine already burning something is topped up with that: its
-- fuel slots could not take another fuel anyway (request.apply refuses).
-- Returns the first stack this burner takes (of `item`, when given) as
-- name and quality.
local function held_fuel(t, item)
  local entity = built_entity(t)
  local inventory = entity and entity.get_inventory(defines.inventory.fuel)
  if not inventory then return nil end
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack.valid_for_read and (not item or stack.name == item) and fuel.accepts(t, stack.name) then
      return stack.name, stack.quality.name
    end
  end
  return nil
end

-- The quality to request `item` at: what a built machine already burns of
-- it (uncommon coal from quality mining), since a stack never mixes
-- qualities; normal otherwise. Fuel value does not depend on quality.
function fuel.quality_for(t, item)
  local _, quality = held_fuel(t, item)
  return quality or NORMAL
end

-- Returns the fuel item and the quality to request it at.
function fuel.default(t, player_index)
  if not t.burner then return nil end
  local held, quality = held_fuel(t)
  if held then return held, quality end
  local remembered = state.player(player_index).fuel_by_category
  for category in pairs(t.burner.fuel_categories) do
    local item = remembered[category]
    if item and fuel.accepts(t, item) then return item, NORMAL end
  end
  return fuel.earliest(t), NORMAL
end

local function rank_of(name, prototype)
  return { const.NEVER_DEFAULT_FUEL[name] and 1 or 0, fuel_tier.of(name), prototype.order, name }
end

local function ranks_before(a, b)
  for i = 1, #a do
    if a[i] ~= b[i] then return a[i] < b[i] end
  end
  return false
end

-- Wood ranks after every other fuel instead of being dropped, so it is still
-- chosen when it is the only fuel the burner takes.
function fuel.earliest(t)
  if not t.burner then return nil end
  local best, best_rank
  for name, prototype in pairs(prototypes.get_item_filtered(fuel.filters(t))) do
    if fuel.accepts(t, name) then
      local rank = rank_of(name, prototype)
      if not best or ranks_before(rank, best_rank) then best, best_rank = name, rank end
    end
  end
  return best
end

function fuel.remember(player_index, t, item)
  local prototype = item and prototypes.item[item]
  if not (prototype and prototype.fuel_category and fuel.accepts(t, item)) then return end
  state.player(player_index).fuel_by_category[prototype.fuel_category] = item
end

return fuel
