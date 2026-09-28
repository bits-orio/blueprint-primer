-- Reopening a chest (ADR-0013): recipe mode only when the pending request
-- is exactly the fed recipe's, items mode otherwise, and never a recipe
-- guessed from the items alone. Then the one-chest primed blueprint.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local blueprint = require("__BlueprintPrimer__/scripts/blueprint")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")
local chain = require("cases.chest").chain
local stamp = require("cases.blueprint").stamp

local cases = {}

local at = rig.chest_at
local PLAYER = 9
local CHEST = defines.inventory.chest
local line = check.plan_line

local function counts(p)
  local list = {}
  for i, row in ipairs(p.items) do list[i] = row.name .. "@" .. row.quality .. "=" .. row.count end
  return list
end

local function primed_rows(t, rows)
  assert(request.apply(t, rig.items_priming(t, rows)))
  return priming.new(t, PLAYER)
end

local function round_trip(surface)
  local t = chain(surface, rig.ghost, -40.5, 10.5, "iron-gear-wheel")
  local p = priming.new(t, PLAYER)
  priming.set_crafts(p, 150)
  assert(request.apply(t, p))
  local before = check.plan_summary(t.entity.insert_plan)
  check.same("chest reopen: the request", before, check.lines {
    line("iron-plate", CHEST, 15, 100), line("iron-plate", CHEST, 14, 100), line("iron-plate", CHEST, 13, 100) })
  local q = priming.new(t, PLAYER)
  check.same("chest reopen: recipe mode at its crafts", { q.mode, q.recipe, q.crafts }, { "recipe", "iron-gear-wheel", 150 })
  assert(request.apply(t, q))
  check.same("chest reopen: an untouched Request rewrites the same request", check.plan_summary(t.entity.insert_plan), before)
end

local function items_reopen(surface)
  local lone = assert(target.from_entity(rig.ghost(surface, "wooden-chest", at(-30.5, 10.5)), rig.FORCE))
  local p = primed_rows(lone, rig.rows({ "iron-plate", 200 }))
  check.same("chest reopen: a stockpile with no fed machine is items, never a guessed recipe",
    { p.mode, p.recipe == nil, counts(p) }, { "items", true, { "iron-plate@normal=200" } })
  local fed = chain(surface, rig.ghost, -26.5, 10.5, "iron-gear-wheel")
  p = primed_rows(fed, rig.rows({ "iron-plate", 300 }, { "coal", 10 }))
  check.same("chest reopen: items that are not the fed recipe's request stay items",
    { p.mode, counts(p) }, { "items", { "iron-plate@normal=300", "coal@normal=10" } })
  local exact = chain(surface, rig.ghost, -18.5, 10.5, "iron-gear-wheel")
  p = primed_rows(exact, rig.rows({ "iron-plate", 300 }))
  check.same("chest reopen: one row that is exactly the fed recipe's request reopens as it (accepted)",
    { p.mode, p.recipe, p.crafts }, { "recipe", "iron-gear-wheel", 150 })
  if not script.active_mods["quality"] then return end
  local mixed = chain(surface, rig.ghost, -10.5, 10.5, "iron-gear-wheel")
  p = primed_rows(mixed, rig.rows({ "iron-plate", 40 }, { "iron-plate", 10, "rare" }))
  check.same("chest reopen: another quality keeps items mode",
    { p.mode, counts(p) }, { "items", { "iron-plate@normal=40", "iron-plate@rare=10" } })
end

-- The chest already holds the plates, so only the cable is pending.
local function top_up_reopen(surface)
  local t = chain(surface, rig.built, -2.5, 10.5, "electronic-circuit")
  t.entity.get_inventory(CHEST).insert({ name = "iron-plate", count = 10 })
  local p = priming.new(t, PLAYER)
  priming.set_crafts(p, 10)
  assert(request.apply(t, p))
  local proxy = t.entity.item_request_proxy
  check.same("chest top-up asks only for what is missing", check.plan_summary(proxy and proxy.insert_plan),
    { line("copper-cable", CHEST, 15, 30) })
  local q = priming.new(t, PLAYER)
  check.same("chest top-up reopens in recipe mode", { q.mode, q.recipe, q.crafts }, { "recipe", "electronic-circuit", 10 })
end

local function written(t, p)
  local inventory = game.create_inventory(1)
  blueprint.write(inventory[1], t, p)
  local icons = {}
  for _, icon in ipairs(inventory[1].preview_icons or {}) do icons[icon.index] = icon.signal.name end
  local label = inventory[1].label
  inventory.destroy()
  return label, icons
end

local function blueprints(surface)
  local t = assert(target.from_entity(rig.ghost(surface, "wooden-chest", at(-40.5, 18.5)), rig.FORCE))
  local p = rig.priming(t, { recipe = "electronic-circuit", crafts = 10 })
  local entity = blueprint.entity(t, p)
  check.same("chest blueprint entity: the chest, a fresh placement, no recipe",
    { entity.name, entity.recipe == nil, check.plan_summary(entity.items) },
    { "wooden-chest", true, check.lines { line("iron-plate", CHEST, 15, 10), line("copper-cable", CHEST, 14, 30) } })
  check.same("chest blueprint label and icons, recipe mode", { written(t, p) },
    { "[entity=wooden-chest] [item=electronic-circuit] x10", { "wooden-chest", "electronic-circuit" } })
  local rows = rig.items_priming(t, rig.rows({ "iron-plate", 250 }, { "coal", 60 }, { "stone", 10 }, { "copper-cable", 5 }))
  check.same("chest blueprint label and icons, items mode", { written(t, rows) },
    { "[entity=wooden-chest] [item=iron-plate] x250 +3", { "wooden-chest", "iron-plate", "coal", "stone" } })
  local ghost = stamp(surface, blueprint.entity(t, rows), at(-36.5, 18.5))
  check.same("chest blueprint stamps a ghost with the fresh placement", check.plan_summary(ghost and ghost.insert_plan),
    check.lines { line("iron-plate", CHEST, 15, 100), line("iron-plate", CHEST, 14, 100), line("iron-plate", CHEST, 13, 50),
      line("coal", CHEST, 12, 50), line("coal", CHEST, 11, 10), line("stone", CHEST, 10, 10), line("copper-cable", CHEST, 9, 5) })
  local barred = rig.built(surface, "wooden-chest", at(-32.5, 18.5))
  barred.get_inventory(CHEST).set_bar(5)
  local b = assert(target.from_entity(barred, rig.FORCE))
  check.same("chest blueprint keeps a built chest's bar", { blueprint.entity(b, rows).bar, blueprint.entity(t, rows).bar }, { 4 })
  if not script.active_mods["quality"] then return end
  check.eq("chest blueprint label shows a row's quality",
    (written(t, rig.items_priming(t, rig.rows({ "iron-plate", 40, "rare" })))), "[entity=wooden-chest] [item=iron-plate,quality=rare] x40")
end

function cases.run(surface)
  check.run("chest_reopen.round_trip", function() round_trip(surface) end)
  check.run("chest_reopen.items", function() items_reopen(surface) end)
  check.run("chest_reopen.top_up", function() top_up_reopen(surface) end)
  check.run("chest_reopen.blueprints", function() blueprints(surface) end)
end

return cases
