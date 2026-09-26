-- gui/priming.lua: the Priming record the window edits. It has no GUI access,
-- so its rules (defaults, slot cap, fuel following the crafts, recipe lock)
-- run here against real prototypes and entities. setup() runs at tick 0;
-- verify() after CHECK_TICK, once the rig's furnaces have smelted.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")

local cases = {}

local Y = 23
-- A player index no other case remembers a fuel for, so the default is coal.
local PLAYER = 7

local function new(entity)
  return priming.new(assert(target.from_entity(entity, rig.FORCE)), PLAYER)
end

local function furnace_defaults(surface)
  local p = new(rig.ghost(surface, "stone-furnace", rig.at(-30, Y)))
  check.same("priming.new furnace ghost", { p.recipe, p.crafts, p.fuel, p.fuel_count }, { nil, 0, "coal", 0 })
  check.eq("priming.blocker without a recipe", priming.blocker(p), "bp-primer.pick-recipe")
  check.truthy("priming.set_recipe iron-plate", priming.set_recipe(p, "iron-plate"))
  -- Opens at half the slot cap (50 ore), with the estimate for 25 crafts.
  check.same("priming opens at half the cap", { priming.cap(p), p.crafts, p.fuel_count }, { 50, 25, 2 })
  check.eq("priming.blocker once ready", priming.blocker(p), nil)
  check.eq("priming.set_recipe refuses gears in a furnace", priming.set_recipe(p, "iron-gear-wheel"), false)
end

-- The fuel follows the crafts until the player types one; only a real
-- change of the craft count drops what they typed.
local function fuel_follows(surface)
  local p = new(rig.ghost(surface, "stone-furnace", rig.at(-24, Y)))
  priming.set_recipe(p, "iron-plate")
  priming.preset_crafts(p, true)
  check.same("priming max", { p.crafts, p.fuel_count, p.fuel_edited }, { 50, 4, false })
  priming.set_fuel_count(p, 9)
  check.same("priming typed fuel", { p.fuel_count, p.fuel_edited }, { 9, true })
  priming.preset_crafts(p, true)
  priming.set_crafts(p, 999)
  check.same("priming same crafts keeps typed fuel", { p.crafts, p.fuel_count }, { 50, 9 })
  priming.set_crafts(p, 10)
  check.same("priming new crafts re-estimate fuel", { p.crafts, p.fuel_count, p.fuel_edited }, { 10, 1, false })
  priming.set_fuel_count(p, 1000)
  check.eq("priming fuel clamps to capacity", p.fuel_count, 50)
end

local function outputs_and_fuel_only(surface)
  local p = new(rig.ghost(surface, "assembling-machine-2", rig.at(-16, Y)))
  priming.set_recipe(p, "copper-cable")
  priming.set_outputs(p, 5)
  check.same("priming typed outputs round up to whole crafts", { p.crafts, priming.outputs(p) }, { 3, 6 })
  check.eq("priming electric crafter has no fuel", p.fuel, nil)
  local b = new(rig.ghost(surface, "boiler", rig.at(-8, Y)))
  check.same("priming fuel-only opens at half the fuel slots", { b.fuel, b.fuel_count, priming.blocker(b) }, { "coal", 25, nil })
  priming.preset_fuel(b, true)
  check.eq("priming fuel-only max", b.fuel_count, 50)
end

local function lock_at_setup(surface)
  local busy = new(rig.built(surface, "assembling-machine-2", rig.at(0, Y), { recipe = "iron-gear-wheel" }))
  check.same("priming locks a built assembler's recipe", { busy.recipe, priming.recipe_locked(busy) }, { "iron-gear-wheel", true })
  local ghost = new(rig.ghost(surface, "stone-furnace", rig.at(6, Y)))
  check.eq("priming never locks a ghost furnace", priming.recipe_locked(ghost), false)
  -- Still smelting at CHECK_TICK: 20 steel crafts at 16 s each take 320 s.
  local running = rig.built(surface, "stone-furnace", rig.at(12, Y))
  running.insert { name = "iron-plate", count = 100 }
  running.insert { name = "coal", count = 10 }
  -- Finished long before CHECK_TICK: 10 iron plates at 3.2 s each.
  local idle = rig.built(surface, "stone-furnace", rig.at(18, Y))
  idle.insert { name = "iron-ore", count = 10 }
  idle.insert { name = "coal", count = 1 }
  storage.priming_case = { running = running, idle = idle }
end

local function state_of(p)
  return { p.recipe, p.crafts, p.fuel, p.fuel_count, p.fuel_edited }
end

-- Reopening a primed machine starts from its request, so Request without
-- touching anything rewrites the same request.
local function reopen(surface)
  local ghost = rig.ghost(surface, "stone-furnace", rig.at(-12, 42))
  local t = assert(target.from_entity(ghost, rig.FORCE))
  request.apply(t, rig.priming(t, { recipe = "iron-plate", crafts = 50, fuel = "coal", fuel_count = 4 }))
  check.same("priming reopens a ghost at its request", state_of(new(ghost)), { "iron-plate", 50, "coal", 4, false })
  local other = rig.ghost(surface, "stone-furnace", rig.at(-6, 42))
  t = assert(target.from_entity(other, rig.FORCE))
  request.apply(t, rig.priming(t, { recipe = "iron-plate", crafts = 20, fuel = "solid-fuel", fuel_count = 10 }))
  check.same("priming reopens with the requested fuel, kept as typed", state_of(new(other)),
    { "iron-plate", 20, "solid-fuel", 10, true })
  local built = rig.built(surface, "stone-furnace", rig.at(0, 42))
  t = assert(target.from_entity(built, rig.FORCE))
  request.apply(t, rig.priming(t, { recipe = "copper-plate", crafts = 20, fuel = "coal", fuel_count = 2 }))
  check.same("priming reopens a built furnace at its pending proxy", state_of(new(built)),
    { "copper-plate", 20, "coal", 2, false })
end

-- A built furnace primed for 10 plates whose ore arrived but whose coal did
-- not (the network has none): the proxy holds only the fuel. Checked in
-- verify(), since the furnace takes its recipe from the ore only once it ticks.
local function fuel_pending_setup(surface)
  local e = rig.built(surface, "stone-furnace", rig.at(24, Y))
  e.insert { name = "iron-ore", count = 10 }
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = { { id = { name = "coal" },
      items = { in_inventory = { { inventory = defines.inventory.fuel, stack = 0, count = 1 } } } } } }
  storage.priming_fuel_pending = e
end

-- The ore inside still sizes the pending coal, so an untouched Request asks
-- for the same single coal and no more ore.
local function fuel_pending_reopen()
  local e = storage.priming_fuel_pending
  local p = new(e)
  check.same("priming reopens a built furnace awaiting only its fuel", state_of(p), { "iron-plate", 10, "coal", 1, false })
  local ok = request.apply(p.target, p)
  check.same("priming untouched Request on a fuel-only proxy rewrites it",
    { ok, check.plan_summary(e.item_request_proxy and e.item_request_proxy.insert_plan) },
    { true, { check.plan_line("coal", defines.inventory.fuel, 0, 1) } })
end

local function held_fuel(surface)
  local e = rig.built(surface, "stone-furnace", rig.at(6, 42))
  e.get_inventory(defines.inventory.fuel).insert { name = "wood", count = 5 }
  check.eq("priming preselects the fuel a built machine burns", new(e).fuel, "wood")
end

-- Robots revive the ghost while the window is open: the locked chooser must
-- follow the built machine's recipe, not the one picked on the ghost.
local function sync_locked(surface)
  local ghost = rig.ghost(surface, "assembling-machine-2", rig.at(12.5, 42.5), { recipe = "iron-gear-wheel" })
  local p = new(ghost)
  priming.set_recipe(p, "electronic-circuit")
  check.eq("priming.sync_locked leaves an unlocked ghost alone", priming.sync_locked(p), false)
  ghost.revive()
  target.revalidate(p.target)
  check.same("priming.sync_locked follows the revived machine",
    { priming.sync_locked(p), p.recipe, priming.recipe_locked(p) }, { true, "iron-gear-wheel", true })
  check.eq("priming.sync_locked is quiet once in step", priming.sync_locked(p), false)
end

local function fuel_only_crafter(surface)
  if not script.active_mods["space-age"] then return end
  local p = new(rig.ghost(surface, "captive-biter-spawner", rig.at(22, 42)))
  check.truthy("priming captive spawner gets fuel only",
    p.fuel ~= nil and p.fuel_count >= 1 and priming.blocker(p) == nil, serpent.line(state_of(p)))
end

function cases.run(surface)
  check.run("priming.reopen", function() reopen(surface) end)
  check.run("priming.held_fuel", function() held_fuel(surface) end)
  check.run("priming.sync_locked", function() sync_locked(surface) end)
  check.run("priming.fuel_only_crafter", function() fuel_only_crafter(surface) end)
  check.run("priming.furnace_defaults", function() furnace_defaults(surface) end)
  check.run("priming.fuel_follows", function() fuel_follows(surface) end)
  check.run("priming.outputs_and_fuel_only", function() outputs_and_fuel_only(surface) end)
  check.run("priming.lock_at_setup", function() lock_at_setup(surface) end)
  check.run("priming.fuel_pending_setup", function() fuel_pending_setup(surface) end)
end

function cases.verify()
  local rigged = storage.priming_case
  local running, idle = new(rigged.running), new(rigged.idle)
  check.same("priming locks a furnace mid-recipe", { running.recipe, priming.recipe_locked(running) }, { "steel-plate", true })
  check.same("priming presets an idle furnace's last recipe, unlocked",
    { idle.recipe, priming.recipe_locked(idle) }, { "iron-plate", false })
  -- Request refuses exactly what the chooser locks.
  local ok, why = request.apply(running.target, rig.priming(running.target, { recipe = "iron-plate", crafts = 5 }))
  check.same("request.apply refuses a furnace mid-way through another recipe", { ok, why },
    { false, "bp-primer.recipe-mismatch" })
  -- A pending request is newer than the recipe the furnace last ran.
  local e = rigged.idle
  e.surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = { { id = { name = "copper-ore" },
      items = { in_inventory = { { inventory = defines.inventory.crafter_input, stack = 0, count = 5 } } } } } }
  check.eq("priming prefers the pending proxy's recipe to the last one", new(e).recipe, "copper-plate")
  fuel_pending_reopen()
end

return cases
