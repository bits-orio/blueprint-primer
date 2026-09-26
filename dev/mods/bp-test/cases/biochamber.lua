-- Space Age's biochamber (space-age set only): the vanilla burner crafter
-- with module slots and fluid-only recipes, where fuel meets both.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local fuel = require("__BlueprintPrimer__/scripts/fuel")
local request = require("__BlueprintPrimer__/scripts/request")
local blueprint = require("__BlueprintPrimer__/scripts/blueprint")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")
local stamp = require("cases.blueprint").stamp

local cases = {}

local Y = -20
local PLAYER = 8 -- no other case remembers a fuel for this player
local CRACKING = "light-oil-cracking"

local function recipe_name(entity)
  local recipe = entity.get_recipe()
  return recipe and recipe.name
end

local function nutrients_only(count)
  return check.lines { check.plan_line("nutrients", defines.inventory.fuel, 0, count) }
end

-- Cracking takes only fluids, so nutrients are all robots can bring: the
-- machine is fuel-only, and Request must not touch the recipe it is on.
local function cracking_ghost(surface)
  local ghost = rig.ghost(surface, "biochamber", rig.at(-30, Y), { recipe = CRACKING })
  local p = priming.new(assert(target.from_entity(ghost, rig.FORCE)), PLAYER)
  check.same("biochamber cracking ghost is fuel-only on nutrients",
    { p.target.kind, p.fuel, p.fuel_count >= 1, priming.blocker(p) }, { "fuel-only", "nutrients", true })
  check.eq("biochamber cracking ghost apply", request.apply(p.target, p), true)
  check.same("biochamber cracking ghost plan is nutrients only", check.plan_summary(ghost.insert_plan),
    nutrients_only(p.fuel_count))
  check.eq("biochamber cracking ghost keeps its recipe", recipe_name(ghost), CRACKING)
end

local function cracking_built(surface)
  local built = rig.built(surface, "biochamber", rig.at(-24, Y), { recipe = CRACKING })
  local p = priming.new(assert(target.from_entity(built, rig.FORCE)), PLAYER)
  check.same("biochamber cracking built is fuel-only and ready",
    { p.target.kind, p.fuel, priming.blocker(p) }, { "fuel-only", "nutrients" })
  check.eq("biochamber cracking built apply", request.apply(p.target, p), true)
  local proxy = built.item_request_proxy
  check.same("biochamber cracking built proxy is nutrients only", proxy and check.plan_summary(proxy.insert_plan),
    nutrients_only(p.fuel_count))
  check.eq("biochamber cracking built keeps its recipe", recipe_name(built), CRACKING)
  local entity = blueprint.entity(p.target, p)
  check.same("biochamber cracking blueprint carries the recipe", { entity.recipe, entity.recipe_quality },
    { CRACKING, "normal" })
  local copy = stamp(surface, entity, rig.at(-18, Y))
  check.same("biochamber cracking stamped copy keeps recipe and nutrients",
    { copy and recipe_name(copy), copy and check.plan_summary(copy.insert_plan) },
    { CRACKING, nutrients_only(p.fuel_count) })
end

local function modules(name, count)
  local positions = {}
  for stack = 0, count - 1 do
    positions[#positions + 1] = { inventory = defines.inventory.crafter_modules, stack = stack, count = 1 }
  end
  return { { id = { name = name }, items = { in_inventory = positions } } }
end

-- A biochamber holding `count` efficiency modules, with a proxy swapping
-- them for speed modules, as an upgrade planner leaves it.
local function swapping(surface, dx, count)
  local e = rig.built(surface, "biochamber", rig.at(dx, Y))
  local inserted = e.get_inventory(defines.inventory.crafter_modules).insert { name = "efficiency-module", count = count }
  check.eq("biochamber took " .. count .. " efficiency modules", inserted, count)
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = modules("speed-module", count), removal_plan = modules("efficiency-module", count) }
  return assert(target.from_entity(e, rig.FORCE))
end

-- Until robots come, the outgoing efficiency modules are still in the live
-- bonus; the estimate must already be the speed-moduled draw.
local function module_swap(surface)
  storage.biochamber = {
    bare = assert(target.from_entity(rig.built(surface, "biochamber", rig.at(-12, Y)), rig.FORCE)),
    two = swapping(surface, -6, 2),
    four = swapping(surface, 0, 4),
  }
end

local function ratio(t, bare)
  local recipe = "nutrients-from-spoilage"
  return fuel.joules_per_craft(t, recipe) / fuel.joules_per_craft(bare, recipe)
end

-- Module effects settle on the machine after the insert, so compare later.
-- Speed module 1 is +0.2 speed and +0.5 draw; efficiency module 1 is -0.3.
function cases.verify()
  local b = storage.biochamber
  if not b then return end
  check.near("biochamber two-module swap costs the incoming draw (2.0/1.4)", ratio(b.two, b.bare), 2.0 / 1.4, 1e-6)
  -- Four efficiency modules (-1.2) hit the engine's -0.8 floor, and the live
  -- bonus reads back clamped: taking the full -1.2 off it over-estimates,
  -- the safe direction, and never falls short of the real 3.0/1.8.
  local four, live = ratio(b.four, b.bare), b.four.entity.consumption_bonus
  check.info(string.format("biochamber four-module swap: live consumption_bonus=%s ratio=%s", live, four))
  check.near("biochamber four-module swap removes from the clamped bonus", four, (1 + live + 2.0 + 1.2) / 1.8, 1e-6)
  check.truthy("biochamber four-module swap is never short of 3.0/1.8", four >= 3.0 / 1.8 - 1e-9, "got " .. four)
end

function cases.run(surface)
  check.run("biochamber.cracking_ghost", function() cracking_ghost(surface) end)
  check.run("biochamber.cracking_built", function() cracking_built(surface) end)
  check.run("biochamber.module_swap", function() module_swap(surface) end)
end

return cases
