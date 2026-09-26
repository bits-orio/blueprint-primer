-- target.lua: resolving entities, reading recipes, following a revived ghost.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local pending = require("__BlueprintPrimer__/scripts/pending")

local cases = {}

local Y = -10

local function resolve(surface)
  local g = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(-30, Y)), rig.FORCE)
  check.truthy("target.from_entity ghost furnace",
    g and g.is_ghost and g.name == "stone-furnace" and g.kind == "furnace" and g.burner and g.quality == "normal",
    "got " .. serpent.line(g and { g.is_ghost, g.name, g.kind, g.quality }))
  local a = target.from_entity(rig.built(surface, "assembling-machine-2", rig.at(-24, Y)), game.forces.player)
  check.truthy("target.from_entity built assembler",
    a and not a.is_ghost and a.kind == "assembler" and a.burner == nil and a.prototype.name == "assembling-machine-2")
  local b = target.from_entity(rig.built(surface, "boiler", rig.at(-18, Y)), rig.FORCE)
  check.truthy("target.from_entity boiler is fuel-only", b and b.kind == "fuel-only" and b.burner)
end

local function rejects(surface)
  local _, why = target.from_entity(rig.built(surface, "electric-mining-drill", rig.at(-12, Y)), rig.FORCE)
  check.eq("target.from_entity rejects non-burner non-crafter", why, "bp-primer.not-primable")
  _, why = target.from_entity(rig.built(surface, "iron-chest", rig.at(-8, Y)), rig.FORCE)
  check.eq("target.from_entity rejects chest", why, "bp-primer.not-primable")
  local other = game.forces["bp-other"] or game.create_force("bp-other")
  _, why = target.from_entity(rig.built(surface, "stone-furnace", rig.at(-4, Y), { force = other }), rig.FORCE)
  check.eq("target.from_entity rejects other force", why, "bp-primer.other-force")
  _, why = target.from_entity(rig.built(surface, "rocket-silo", rig.at(10, Y)), rig.FORCE)
  check.eq("target.from_entity rejects rocket silo", why, "bp-primer.unsupported-crafter")
  local gone = rig.built(surface, "stone-furnace", rig.at(0, Y))
  gone.destroy()
  _, why = target.from_entity(gone, rig.FORCE)
  check.eq("target.from_entity rejects invalid", why, "bp-primer.invalid-target")
end

local function current_recipe(surface)
  local a = target.from_entity(rig.ghost(surface, "assembling-machine-2", rig.at(-30, Y + 8), { recipe = "iron-gear-wheel" }), rig.FORCE)
  check.same("target.current_recipe assembler ghost", { target.current_recipe(a) }, { "iron-gear-wheel", "normal" })
  local b = target.from_entity(rig.built(surface, "assembling-machine-2", rig.at(-24, Y + 8), { recipe = "copper-cable" }), rig.FORCE)
  check.same("target.current_recipe built assembler", { target.current_recipe(b) }, { "copper-cable", "normal" })
  local empty = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(-18, Y + 8)), rig.FORCE)
  check.same("target.current_recipe bare furnace ghost", { target.current_recipe(empty) }, {})
  local planned = rig.ghost(surface, "stone-furnace", rig.at(-14, Y + 8))
  planned.insert_plan = { { id = { name = "copper-ore" },
    items = { in_inventory = { { inventory = defines.inventory.crafter_input, stack = 0, count = 5 } } } } }
  local p = target.from_entity(planned, rig.FORCE)
  check.same("target.current_recipe furnace ghost from plan", { target.current_recipe(p) }, { "copper-plate", "normal" })
  local boiler = target.from_entity(rig.ghost(surface, "boiler", rig.at(-8, Y + 8)), rig.FORCE)
  check.same("target.current_recipe fuel-only", { target.current_recipe(boiler) }, {})
end

local function revalidate(surface)
  local ghost = rig.ghost(surface, "stone-furnace", rig.at(0, Y + 8))
  local t = target.from_entity(ghost, rig.FORCE)
  local _, built = ghost.revive()
  check.truthy("target.revalidate follows a revived ghost",
    target.revalidate(t) and not t.is_ghost and t.entity == built and t.entity.type == "furnace")
  local lost = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(4, Y + 8)), rig.FORCE)
  lost.entity.destroy()
  check.eq("target.revalidate false when ghost is gone", target.revalidate(lost), false)
end

local function recipes(surface)
  local f = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(10, Y + 8)), rig.FORCE)
  local a = target.from_entity(rig.ghost(surface, "assembling-machine-2", rig.at(16, Y + 8)), rig.FORCE)
  local chem = target.from_entity(rig.ghost(surface, "chemical-plant", rig.at(22, Y + 8)), rig.FORCE)
  check.eq("target.allows_recipe furnace iron-plate", target.allows_recipe(f, "iron-plate"), true)
  check.eq("target.allows_recipe furnace gear", target.allows_recipe(f, "iron-gear-wheel"), false)
  check.eq("target.allows_recipe assembler circuit", target.allows_recipe(a, "electronic-circuit"), true)
  check.eq("target.allows_recipe assembler smelting", target.allows_recipe(a, "iron-plate"), false)
  check.eq("target.allows_recipe fluid-only recipe", target.allows_recipe(chem, "lubricant"), false)
  check.eq("target.allows_recipe unknown", target.allows_recipe(f, "no-such-recipe"), false)
  local listed = prototypes.get_recipe_filtered(target.recipe_filters(f))
  check.truthy("target.recipe_filters furnace", listed["iron-plate"] and listed["stone-brick"] and not listed["iron-gear-wheel"])
  local all_visible = true
  for name, recipe in pairs(listed) do
    if recipe.hidden then all_visible = false; check.info("hidden recipe listed: " .. name) end
  end
  check.truthy("target.recipe_filters excludes hidden", all_visible)
  local chem_listed = prototypes.get_recipe_filtered(target.recipe_filters(chem))
  check.truthy("target.recipe_filters excludes fluid-only recipes",
    chem_listed["plastic-bar"] and not chem_listed["lubricant"] and not chem_listed["light-oil-cracking"])
end

-- Crafters with no recipe a robot could deliver for: fuel-only if they burn
-- fuel (the captive biter spawner), refused otherwise (the recycler without
-- Space Age, modelled by bp-test's electric furnace with an empty category).
local function unprimable_crafters(surface)
  local burner = target.from_entity(rig.built(surface, "bp-test-empty-burner", rig.at(-30, 36)), rig.FORCE)
  check.truthy("target.from_entity burner crafter without recipes is fuel-only", burner and burner.kind == "fuel-only")
  local _, why = target.from_entity(rig.built(surface, "bp-test-empty-electric", rig.at(-24, 36)), rig.FORCE)
  check.eq("target.from_entity electric crafter without recipes is refused", why, "bp-primer.unsupported-crafter")
  if not script.active_mods["space-age"] then return end
  local spawner = target.from_entity(rig.ghost(surface, "captive-biter-spawner", rig.at(-16, 36)), rig.FORCE)
  check.truthy("target.from_entity captive biter spawner is fuel-only", spawner and spawner.kind == "fuel-only")
  local recycler = target.from_entity(rig.built(surface, "recycler", rig.at(-8, 36)), rig.FORCE)
  check.truthy("target.from_entity recycler with scrap recycling is a furnace", recycler and recycler.kind == "furnace")
end

-- A built furnace that has never smelted, or smelted something else, is
-- meant for whatever its pending proxy asks for.
local function furnace_proxy_recipe(surface)
  local e = rig.built(surface, "stone-furnace", rig.at(0, 36))
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = { { id = { name = "copper-ore" },
      items = { in_inventory = { { inventory = defines.inventory.crafter_input, stack = 0, count = 20 } } } } } }
  local t = target.from_entity(e, rig.FORCE)
  check.same("target.current_recipe built furnace from its proxy", { target.current_recipe(t) }, { "copper-plate", "normal" })
end

local function orientation(surface)
  local tank = rig.built(surface, "tank", rig.at(8, 36))
  tank.orientation = 0.25
  local t = target.from_entity(tank, rig.FORCE)
  check.same("target.from_entity vehicle keeps orientation, not direction", { t.orientation, t.direction }, { 0.25 })
  local ghost = target.from_entity(rig.ghost(surface, "tank", rig.at(12, 36)), rig.FORCE)
  check.truthy("target.from_entity vehicle ghost reads orientation", ghost and type(ghost.orientation) == "number")
end

local function inventory_count(surface)
  local built = rig.built(surface, "stone-furnace", rig.at(28, Y + 8))
  built.get_inventory(defines.inventory.crafter_input).insert { name = "iron-ore", count = 20 }
  local t = target.from_entity(built, rig.FORCE)
  check.eq("target.inventory_count built", target.inventory_count(t, defines.inventory.crafter_input, "iron-ore", "normal"), 20)
  local g = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(32, Y + 8)), rig.FORCE)
  check.eq("target.inventory_count ghost", target.inventory_count(g, defines.inventory.crafter_input, "iron-ore", "normal"), 0)
end

-- A module swap's outgoing modules wait on the proxy's removal plan, which
-- the fuel estimate reads; a ghost has nothing to remove.
local function removals(surface)
  local modules = defines.inventory.crafter_modules
  local function plan(name)
    return { { id = { name = name }, items = { in_inventory = { { inventory = modules, stack = 0, count = 1 } } } } }
  end
  local e = rig.built(surface, "assembling-machine-2", rig.at(-30, 16))
  e.get_inventory(modules).insert { name = "speed-module", count = 1 }
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = plan("efficiency-module"), removal_plan = plan("speed-module") }
  check.same("pending.removals reads a built machine's proxy",
    check.plan_summary(pending.removals(assert(target.from_entity(e, rig.FORCE)))),
    { check.plan_line("speed-module", modules, 0, 1) })
  local ghost = assert(target.from_entity(rig.ghost(surface, "assembling-machine-2", rig.at(-24, 16)), rig.FORCE))
  check.same("pending.removals is empty for a ghost", pending.removals(ghost), {})
end

function cases.run(surface)
  check.run("target.resolve", function() resolve(surface) end)
  check.run("target.rejects", function() rejects(surface) end)
  check.run("target.current_recipe", function() current_recipe(surface) end)
  check.run("target.revalidate", function() revalidate(surface) end)
  check.run("target.recipes", function() recipes(surface) end)
  check.run("target.inventory_count", function() inventory_count(surface) end)
  check.run("target.unprimable_crafters", function() unprimable_crafters(surface) end)
  check.run("target.furnace_proxy_recipe", function() furnace_proxy_recipe(surface) end)
  check.run("target.orientation", function() orientation(surface) end)
  check.run("target.removals", function() removals(surface) end)
end

return cases
