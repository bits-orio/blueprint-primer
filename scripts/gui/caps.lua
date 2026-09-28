-- The limits a Priming's numbers stay within (the slot cap, a chest's chest
-- cap and row caps, the fuel capacity) and settling: re-fitting every
-- derived number after the recipe, the fuel or the target changed. Pure
-- state over the core modules; priming.lua re-exports the caps.

local const = require("scripts.const")
local craft = require("scripts.craft")
local fuel = require("scripts.fuel")
local placement = require("scripts.placement")
local items = require("scripts.gui.items")

local caps = {}

function caps.clamp(n, low, high)
  return math.max(low, math.min(high, n))
end

-- Half stands in for vanilla's "half stack": half the cap, whole units.
function caps.share(cap, full)
  if full then return cap end
  return math.max(1, math.floor(cap / 2))
end

local function is_fuel_only(p)
  return p.target.kind == const.KIND_FUEL_ONLY
end

-- The largest craft count the slider may reach: the slot cap and, for
-- burners, an estimate that still fits the fuel inventory. A chest's is its
-- chest cap: the ingredients packed into whole stacks of a fresh chest.
function caps.crafts(p)
  if not p.recipe then return 0 end
  if p.target.kind == const.KIND_CHEST then return placement.cap(p.target, p.recipe) end
  local cap = craft.slot_cap(p.recipe)
  if p.target.burner and p.fuel then
    cap = math.min(cap, fuel.max_crafts(p.target, p.recipe, p.fuel))
  end
  return cap
end

function caps.fuel(p)
  if not p.fuel then return 0 end
  return fuel.capacity(p.target, p.fuel)
end

function caps.estimate(p)
  if is_fuel_only(p) or not (p.recipe and p.fuel) or p.crafts < 1 then return nil end
  return fuel.estimate(p.target, p.recipe, p.crafts, p.fuel)
end

-- A typed fuel amount survives until the craft count changes; otherwise
-- the fuel follows the crafts.
function caps.refuel(p)
  if not p.fuel then
    p.fuel_count = 0
  elseif is_fuel_only(p) or p.fuel_edited then
    p.fuel_count = caps.clamp(p.fuel_count, 1, math.max(1, caps.fuel(p)))
  else
    p.fuel_count = caps.estimate(p) or 0
  end
end

-- Re-fit every derived number after the recipe or the fuel changed. A
-- chest's rows are fitted too, so they always fit this chest.
function caps.settle(p)
  if not is_fuel_only(p) then
    local cap = caps.crafts(p)
    if cap < 1 then
      p.crafts = 0
    elseif p.crafts < 1 then
      p.crafts = caps.share(cap, false)
    else
      p.crafts = caps.clamp(p.crafts, 1, cap)
    end
  end
  if p.items then items.fit(p) end
  caps.refuel(p)
end

return caps
