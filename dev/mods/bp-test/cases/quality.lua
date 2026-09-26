-- Quality and module effects (space-age set only: base has no quality mod).

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local fuel = require("__BlueprintPrimer__/scripts/fuel")
local request = require("__BlueprintPrimer__/scripts/request")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")

local cases = {}

local Y = 50
local PLAYER = 9 -- no other case remembers a fuel for this player

local function legendary_furnace(surface)
  local ghost = rig.ghost(surface, "stone-furnace", rig.at(-30, Y), { quality = "legendary" })
  local t = assert(target.from_entity(ghost, rig.FORCE))
  check.eq("quality ghost target quality", t.quality, "legendary")
  check.near("quality legendary stone furnace speed", t.prototype.get_crafting_speed(t.quality), 2.5)
  check.near("quality legendary joules per craft", fuel.joules_per_craft(t, "iron-plate"), 3.2 / 2.5 * 90000, 1e-6)
  check.eq("quality legendary estimate 50 iron coal", fuel.estimate(t, "iron-plate", 50, "coal"), 2)
  local built = rig.built(surface, "stone-furnace", rig.at(-24, Y), { quality = "legendary" })
  local b = assert(target.from_entity(built, rig.FORCE))
  check.near("quality built legendary live speed", built.crafting_speed, 2.5)
  check.near("quality built legendary joules agree", fuel.joules_per_craft(b, "iron-plate"), 3.2 / 2.5 * 90000, 1e-6)
end

local function biochamber(surface)
  local bare = assert(target.from_entity(rig.built(surface, "biochamber", rig.at(-16, Y)), rig.FORCE))
  check.eq("quality biochamber is an assembler with a burner", bare.kind == "assembler" and bare.burner ~= nil, true)
  local moduled = rig.built(surface, "biochamber", rig.at(-10, Y))
  local inserted = moduled.get_inventory(defines.inventory.crafter_modules).insert { name = "speed-module", count = 1 }
  check.eq("quality biochamber took a speed module", inserted, 1)
  storage.moduled = { bare = bare, moduled = assert(target.from_entity(moduled, rig.FORCE)) }
end

local function new(entity)
  return priming.new(assert(target.from_entity(entity, rig.FORCE)), PLAYER)
end

local function name_of(id)
  if id == nil or type(id) == "string" then return id end
  return id.name
end

-- An idle furnace that last smelted one uncommon ore: the window cannot
-- choose a quality, so the next recipe must not inherit that one.
local function last_quality_verify()
  local furnace = storage.last_quality
  local previous = furnace.previous_recipe or {}
  check.same("quality idle furnace last smelted uncommon", { name_of(previous.name), name_of(previous.quality) },
    { "iron-plate", "uncommon" })
  local p = new(furnace)
  check.same("quality last recipe presets its name at normal", { p.recipe, p.quality, priming.recipe_locked(p) },
    { "iron-plate", "normal", false })
  priming.set_recipe(p, "copper-plate")
  check.same("quality next recipe is requested at normal", check.plan_summary(request.plans(p.target, p, {})),
    check.lines { check.plan_line("copper-ore", defines.inventory.crafter_input, 0, p.crafts),
      check.plan_line("coal", defines.inventory.fuel, 0, p.fuel_count) })
end

-- Module effects settle on the machine after the insert, so compare later.
function cases.verify()
  check.run("quality.last_quality_verify", last_quality_verify)
  local m = storage.moduled
  if not m then return end
  local recipe = "nutrients-from-spoilage"
  local ratio = fuel.joules_per_craft(m.moduled, recipe) / fuel.joules_per_craft(m.bare, recipe)
  check.info(string.format("biochamber speed-module: speed=%s consumption_bonus=%s ratio=%s",
    m.moduled.entity.crafting_speed, m.moduled.entity.consumption_bonus, ratio))
  check.near("quality speed module raises joules per craft (1.5/1.2)", ratio, 1.5 / 1.2, 1e-6)
  local entity = m.moduled.entity
  check.near("quality crafting_speed is base times (1 + speed_bonus)", entity.crafting_speed,
    entity.prototype.get_crafting_speed(entity.quality) * (1 + entity.speed_bonus), 1e-6)
end

local function speed_modules(count)
  local positions = {}
  for stack = 0, count - 1 do
    positions[#positions + 1] = { inventory = defines.inventory.crafter_modules, stack = stack, count = 1 }
  end
  return { { id = { name = "speed-module" }, items = { in_inventory = positions } } }
end

-- Module requests robots have not delivered yet already count: speed module
-- 1 is +20% speed and +50% draw, so each craft costs (1 + 0.5n) / (1 + 0.2n).
local function pending_modules(surface)
  local recipe = "nutrients-from-spoilage"
  local bare = assert(target.from_entity(rig.ghost(surface, "biochamber", rig.at(12, Y)), rig.FORCE))
  local ghost = rig.ghost(surface, "biochamber", rig.at(18, Y))
  ghost.insert_plan = speed_modules(4)
  local planned = assert(target.from_entity(ghost, rig.FORCE))
  check.near("quality ghost module requests raise joules per craft (3.0/1.8)",
    fuel.joules_per_craft(planned, recipe) / fuel.joules_per_craft(bare, recipe), 3.0 / 1.8, 1e-6)
  local built = rig.built(surface, "biochamber", rig.at(24, Y))
  surface.create_entity { name = "item-request-proxy", target = built, position = built.position,
    force = built.force, modules = speed_modules(2) }
  local proxied = assert(target.from_entity(built, rig.FORCE))
  check.near("quality proxy module requests raise joules per craft (2.0/1.4)",
    fuel.joules_per_craft(proxied, recipe) / fuel.joules_per_craft(bare, recipe), 2.0 / 1.4, 1e-6)
  check.truthy("quality module requests raise the estimate",
    fuel.estimate(planned, recipe, 50, "nutrients") > fuel.estimate(bare, recipe, 50, "nutrients"))
end

local function recipe_quality(surface)
  local input, fuel_inv = defines.inventory.crafter_input, defines.inventory.fuel
  local ghost = rig.ghost(surface, "assembling-machine-2", rig.at(-2, Y))
  local t = assert(target.from_entity(ghost, rig.FORCE))
  local p = rig.priming(t, { recipe = "electronic-circuit", quality = "rare", crafts = 4 })
  check.eq("quality apply rare recipe", request.apply(t, p), true)
  local recipe, quality = ghost.get_recipe()
  check.same("quality ghost recipe quality set", { recipe and recipe.name, quality and quality.name }, { "electronic-circuit", "rare" })
  check.same("quality ingredients requested at recipe quality", check.plan_summary(ghost.insert_plan), check.lines {
    check.plan_line("iron-plate", input, 0, 4, "rare"), check.plan_line("copper-cable", input, 1, 12, "rare") })
  local f = assert(target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(4, Y), { quality = "epic" }), rig.FORCE))
  local plans = request.plans(f, rig.priming(f, { recipe = "iron-plate", quality = "rare", crafts = 5, fuel = "coal", fuel_count = 1 }), {})
  check.same("quality fuel stays normal", check.plan_summary(plans), check.lines {
    check.plan_line("iron-ore", input, 0, 5, "rare"), check.plan_line("coal", fuel_inv, 0, 1) })
end

local function last_quality(surface)
  local furnace = rig.built(surface, "stone-furnace", rig.at(6, -20))
  furnace.insert { name = "iron-ore", quality = "uncommon", count = 1 }
  furnace.insert { name = "coal", count = 1 }
  storage.last_quality = furnace
end

-- Coal from quality mining: a stack never mixes qualities, so a furnace
-- burning uncommon coal is topped up with uncommon coal, or not at all.
local function held_quality_fuel(surface)
  local input, fuel_inv = defines.inventory.crafter_input, defines.inventory.fuel
  local stocked = rig.built(surface, "stone-furnace", rig.at(12, -20))
  stocked.get_inventory(fuel_inv).insert { name = "coal", quality = "uncommon", count = 10 }
  local p = new(stocked)
  check.same("quality held fuel is the default, at its quality", { p.fuel, p.fuel_quality }, { "coal", "uncommon" })
  priming.set_recipe(p, "iron-plate")
  check.same("quality held fuel covers the estimate", { request.apply(p.target, p) }, { true, "bp-primer.requested" })
  check.same("quality held fuel: only the ore is requested", check.plan_summary(stocked.item_request_proxy.insert_plan),
    check.lines { check.plan_line("iron-ore", input, 0, 25) })
  local low = rig.built(surface, "stone-furnace", rig.at(16, -20))
  low.get_inventory(fuel_inv).insert { name = "coal", quality = "uncommon", count = 1 }
  local q = new(low)
  priming.set_recipe(q, "iron-plate")
  priming.set_fuel(q, "solid-fuel", PLAYER)
  priming.set_fuel(q, "coal", PLAYER)
  check.same("quality picking the held fuel again restores its quality", { q.fuel_quality, q.fuel_count }, { "uncommon", 2 })
  check.eq("quality short held fuel apply", request.apply(q.target, q), true)
  check.same("quality short held fuel is topped up at its quality", check.plan_summary(low.item_request_proxy.insert_plan),
    check.lines { check.plan_line("iron-ore", input, 0, 25), check.plan_line("coal", fuel_inv, 0, 1, "uncommon") })
  local again = new(low)
  check.same("quality reopen keeps the requested fuel quality", { again.fuel, again.fuel_quality, again.fuel_count },
    { "coal", "uncommon", 2 })
end

function cases.run(surface)
  check.run("quality.last_quality", function() last_quality(surface) end)
  check.run("quality.held_quality_fuel", function() held_quality_fuel(surface) end)
  check.run("quality.recipe_quality", function() recipe_quality(surface) end)
  check.run("quality.legendary_furnace", function() legendary_furnace(surface) end)
  check.run("quality.biochamber", function() biochamber(surface) end)
  check.run("quality.pending_modules", function() pending_modules(surface) end)
end

return cases
