-- copy.lua: a blueprint of a built machine gets back the pending ingredients
-- vanilla drops (ADR-0008). The event cannot be raised headless, so the
-- blueprint and its mapping come from create_blueprint over a known area.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local copy = require("__BlueprintPrimer__/scripts/copy")

local cases = {}

local Y = -40
local PLAYER = 9
local STAMP_Y = -35
local line = check.plan_line

local function inv()
  return defines.inventory.crafter_input, defines.inventory.fuel, defines.inventory.crafter_modules
end

local function prime(entity, fields)
  local t = assert(target.from_entity(entity, rig.FORCE))
  assert(request.apply(t, rig.priming(t, fields)))
end

-- A blueprint of the area around (dx, Y); returns its stack (in a script
-- inventory the caller destroys), its entities and the mapping.
local function snapshot(surface, dx, width)
  local inventory = game.create_inventory(1)
  local stack = inventory[1]
  stack.set_stack { name = "blueprint" }
  local mapping = stack.create_blueprint {
    surface = surface, force = rig.FORCE, area = { rig.at(dx - 2, Y - 2), rig.at(dx + width, Y + 2) },
  }
  return inventory, stack.get_blueprint_entities() or {}, mapping
end

local function named(entities, name)
  for _, entity in ipairs(entities) do
    if entity.name == name then return entity end
  end
end

-- Positions outside crafter_input: what vanilla wrote and carry must keep.
local function others(entity)
  local input, kept = inv(), {}
  for _, l in ipairs(check.plan_summary(entity.items)) do
    if not l:find(" " .. input .. "%[") then kept[#kept + 1] = l end
  end
  return kept
end

local function stamp_ghost(surface, inventory, entities, dx, name)
  local stack = inventory[1]
  stack.set_blueprint_entities(entities)
  for _, ghost in ipairs(stack.build_blueprint {
    surface = surface, force = rig.FORCE, position = rig.at(dx, STAMP_Y), build_mode = defines.build_mode.forced,
  }) do
    if ghost.valid and ghost.ghost_name == name then return ghost end
  end
end

local function furnace(surface)
  local input, fuel = inv()
  local e = rig.built(surface, "stone-furnace", rig.at(10, Y))
  rig.built(surface, "transport-belt", rig.at(12.5, Y - 0.5))
  rig.built(surface, "inserter", rig.at(13.5, Y - 0.5))
  prime(e, { recipe = "iron-plate", crafts = 10, fuel = "coal", fuel_count = 1 })
  local inventory, entities, mapping = snapshot(surface, 10, 5)
  check.eq("copy mapping covers every entity", table_size(mapping), #entities)
  local f = named(entities, "stone-furnace")
  check.same("copy vanilla drops a built furnace's pending ore", check.plan_summary(f.items), { line("coal", fuel, 0, 1) })
  local belt, inserter = serpent.line(named(entities, "transport-belt")), serpent.line(named(entities, "inserter"))
  check.eq("copy.carry built furnace changed", copy.carry(entities, mapping, rig.FORCE, PLAYER), true)
  check.same("copy.carry adds the ore back, coal as primed", check.plan_summary(f.items),
    check.lines { line("iron-ore", input, 0, 10), line("coal", fuel, 0, 1) })
  check.same("copy.carry leaves belt and inserter alone",
    { serpent.line(named(entities, "transport-belt")), serpent.line(named(entities, "inserter")) }, { belt, inserter })
  local ghost = stamp_ghost(surface, inventory, entities, 10, "stone-furnace")
  check.same("copy stamped furnace ghost has ore and coal", check.plan_summary(ghost and ghost.insert_plan),
    check.lines { line("iron-ore", input, 0, 10), line("coal", fuel, 0, 1) })
  local short = { table.unpack(entities, 1, #entities - 1) }
  check.eq("copy.carry leaves a reshaped blueprint alone", copy.carry(short, mapping, rig.FORCE, PLAYER), false)
  inventory.destroy()
end

local function unchanged(case, surface, dx)
  local inventory, entities, mapping = snapshot(surface, dx, 2)
  local before = serpent.line(entities)
  check.same(case, { copy.carry(entities, mapping, rig.FORCE, PLAYER), serpent.line(entities) }, { false, before })
  inventory.destroy()
end

local function delivered_and_ghost(surface)
  local e = rig.built(surface, "stone-furnace", rig.at(20, Y))
  e.insert { name = "iron-ore", count = 10 }
  e.insert { name = "coal", count = 1 }
  unchanged("copy.carry built furnace already stocked adds nothing", surface, 20)
  prime(rig.ghost(surface, "stone-furnace", rig.at(26, Y)), { recipe = "iron-plate", crafts = 10, fuel = "coal", fuel_count = 1 })
  unchanged("copy.carry ghost furnace left as vanilla wrote it", surface, 26)
end

-- The playtested case: the coal arrived first, so vanilla's copy keeps
-- nothing, and 5 ore were inside before priming. The copy must still be
-- primed like the source: 25 ore (5 inside + 20 pending) and the estimate.
local function fuel_arrived(surface)
  local input, fuel = inv()
  local e = rig.built(surface, "stone-furnace", rig.at(40, Y))
  e.insert { name = "iron-ore", count = 5 }
  e.insert { name = "coal", count = 2 }
  prime(e, { recipe = "iron-plate", crafts = 25, fuel = "coal", fuel_count = 2 })
  local inventory, entities, mapping = snapshot(surface, 40, 2)
  local f = named(entities, "stone-furnace")
  check.same("copy vanilla keeps nothing once the fuel arrived", check.plan_summary(f.items), {})
  check.eq("copy.carry fuel-arrived furnace changed", copy.carry(entities, mapping, rig.FORCE, PLAYER), true)
  check.same("copy.carry writes the whole priming, not what is in flight", check.plan_summary(f.items),
    check.lines { line("iron-ore", input, 0, 25), line("coal", fuel, 0, 2) })
  inventory.destroy()
end

-- Two ingredient slots and a pending module; mirrored, which must not move
-- the stack indices.
local function assembler(surface)
  local input, _, modules = inv()
  local e = rig.built(surface, "assembling-machine-2", rig.at(33.5, Y + 0.5), { recipe = "electric-engine-unit" })
  e.mirroring = true
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = { { id = { name = "speed-module" }, items = { in_inventory = { { inventory = modules, stack = 0, count = 1 } } } } } }
  prime(e, { recipe = "electric-engine-unit", crafts = 5 })
  local inventory, entities, mapping = snapshot(surface, 33, 2)
  local a = named(entities, "assembling-machine-2")
  local vanilla = others(a)
  check.same("copy vanilla keeps a built assembler's pending module", vanilla, { line("speed-module", modules, 0, 1) })
  check.eq("copy blueprint of a flipped assembler is flipped", a.mirror, true)
  check.eq("copy.carry built assembler changed", copy.carry(entities, mapping, rig.FORCE, PLAYER), true)
  check.same("copy.carry restores both ingredient slots", check.plan_summary(a.items),
    check.lines { line("electronic-circuit", input, 0, 10), line("engine-unit", input, 1, 5), table.unpack(vanilla) })
  check.same("copy.carry keeps the module request as vanilla wrote it", others(a), vanilla)
  local ghost = stamp_ghost(surface, inventory, entities, 33, "assembling-machine-2")
  check.same("copy stamped mirrored assembler keeps the slots", check.plan_summary(ghost and ghost.insert_plan),
    check.lines { line("electronic-circuit", input, 0, 10), line("engine-unit", input, 1, 5), table.unpack(vanilla) })
  inventory.destroy()
end

function cases.run(surface)
  check.run("copy.furnace", function() furnace(surface) end)
  check.run("copy.delivered_and_ghost", function() delivered_and_ghost(surface) end)
  check.run("copy.assembler", function() assembler(surface) end)
  check.run("copy.fuel_arrived", function() fuel_arrived(surface) end)
end

return cases
