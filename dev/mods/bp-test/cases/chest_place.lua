-- Placement and the chest cap (ADR-0012), and items mode's row rules
-- (ADR-0013): one occupancy map across the want list, fresh chests filled
-- from the last slot down, a built chest topped up around what it holds.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local placement = require("__BlueprintPrimer__/scripts/placement")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")

local cases = {}

local at = rig.chest_at
local CHEST = defines.inventory.chest
local line = check.plan_line

local function chest(surface, make, name, x, y, opts)
  return assert(target.from_entity(make(surface, name, at(x, y), opts), rig.FORCE))
end

-- No two plans share a slot, and no position asks for more than a stack.
local function well_placed(plans)
  local seen = {}
  for _, plan in ipairs(plans) do
    local size = prototypes.item[plan.id.name].stack_size
    for _, position in ipairs(plan.items.in_inventory) do
      if seen[position.stack] or position.count > size then return false end
      seen[position.stack] = true
    end
  end
  return true
end

-- Electronic circuits take 1 plate (stack 100) and 3 cable (stack 200):
-- 600 crafts fill 6 + 9 = 15 of a wooden chest's 16 slots, 601 need 7 + 10.
local function chest_cap(surface)
  local wooden = chest(surface, rig.ghost, "wooden-chest", -40.5, -6.5)
  check.eq("chest cap: circuits in a wooden chest (hand-computed)", placement.cap(wooden, "electronic-circuit"), 600)
  check.eq("chest cap: 0 without an item ingredient", placement.cap(wooden, "lubricant"), 0)
  local p = rig.priming(wooden, { recipe = "electronic-circuit", crafts = 1 })
  check.eq("chest cap is the Priming's cap", priming.cap(p), 600)
  if not script.active_mods["quality"] then return end
  local legendary = chest(surface, rig.ghost, "wooden-chest", -38.5, -6.5, { quality = "legendary" })
  check.eq("chest cap: circuits in a legendary wooden chest (40 slots)", placement.cap(legendary, "electronic-circuit"), 1600)
end

local function fresh(surface)
  local wooden = chest(surface, rig.ghost, "wooden-chest", -34.5, -6.5)
  local plans = request.plans(wooden, rig.priming(wooden, { recipe = "electronic-circuit", crafts = 150 }), {})
  check.same("chest fresh placement fills from the last slot down", check.plan_summary(plans), check.lines {
    line("iron-plate", CHEST, 15, 100), line("iron-plate", CHEST, 14, 50), line("copper-cable", CHEST, 13, 200),
    line("copper-cable", CHEST, 12, 200), line("copper-cable", CHEST, 11, 50) })
  check.truthy("chest fresh placement: no shared slot, at most a stack each", well_placed(plans))
  local iron = chest(surface, rig.ghost, "iron-chest", -32.5, -6.5)
  plans = request.plans(iron, rig.items_priming(iron, rig.rows({ "iron-plate", 250 }, { "coal", 60 })), {})
  check.same("chest fresh placement of items rows", check.plan_summary(plans), check.lines {
    line("iron-plate", CHEST, 31, 100), line("iron-plate", CHEST, 30, 100), line("iron-plate", CHEST, 29, 50),
    line("coal", CHEST, 28, 50), line("coal", CHEST, 27, 10) })
end

-- A built wooden chest: 30 plates in slot 0, stone in the last slot, and
-- (with quality) 5 uncommon plates in slot 1, which count for nothing.
local function stocked(surface, x)
  local e = rig.built(surface, "wooden-chest", at(x, -6.5))
  local inventory = e.get_inventory(CHEST)
  inventory[1].set_stack({ name = "iron-plate", count = 30 })
  inventory[16].set_stack({ name = "stone", count = 10 })
  if script.active_mods["quality"] then inventory[2].set_stack({ name = "iron-plate", count = 5, quality = "uncommon" }) end
  return assert(target.from_entity(e, rig.FORCE)), e
end

local function top_up(surface)
  local t = stocked(surface, -28.5)
  local p = rig.items_priming(t, rig.rows({ "iron-plate", 150 }, { "copper-cable", 300 }))
  local plans, short = request.plans(t, p, { top_up = true })
  check.same("chest top-up: partial stack first, then free slots from the top, around foreign items",
    { check.plan_summary(plans), short }, { check.lines {
      line("iron-plate", CHEST, 0, 70), line("iron-plate", CHEST, 14, 50),
      line("copper-cable", CHEST, 13, 200), line("copper-cable", CHEST, 12, 100) }, 0 })
  check.truthy("chest top-up: no shared slot, at most a stack each", well_placed(plans))
  check.eq("chest top-up fits: no CHEST_FULL pre-check", priming.chest_full(p), false)
  check.same("chest top-up Request", { request.apply(t, p) }, { true, "bp-primer.requested" })
end

local function full(surface)
  local e = rig.built(surface, "wooden-chest", at(-26.5, -6.5))
  local inventory = e.get_inventory(CHEST)
  for index = 1, 15 do inventory[index].set_stack({ name = "stone", count = 50 }) end
  local t = assert(target.from_entity(e, rig.FORCE))
  local p = rig.items_priming(t, rig.rows({ "iron-plate", 150 }))
  local _, short = request.plans(t, p, { top_up = true })
  check.same("chest shortfall and pre-check", { short, priming.chest_full(p) }, { 50, true })
  check.same("chest shortfall refuses Request", { request.apply(t, p) }, { false, "bp-primer.chest-full" })
  check.eq("chest refusal writes nothing", e.item_request_proxy, nil)
  check.eq("chest shortfall never blocks a fresh placement", select(2, request.plans(t, p, {})), 0)
end

function cases.run(surface)
  check.run("chest_place.cap", function() chest_cap(surface) end)
  check.run("chest_place.fresh", function() fresh(surface) end)
  check.run("chest_place.top_up", function() top_up(surface) end)
  check.run("chest_place.full", function() full(surface) end)
end

return cases
