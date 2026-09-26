-- paste.lua: Shift+click settings paste carries a pending primed request
-- (ADR-0008). The event cannot be raised headless, so paste.apply is called
-- as the handler calls it, after vanilla's own paste.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local paste = require("__BlueprintPrimer__/scripts/paste")

local cases = {}

local Y = -46
-- A player index no other case remembers a fuel for, so the default is coal.
local PLAYER = 9
local line = check.plan_line

local function primed(entity, fields)
  local t = assert(target.from_entity(entity, rig.FORCE))
  assert(request.apply(t, rig.priming(t, fields)))
  return entity
end

local function plan_of(entity)
  if entity.type == "entity-ghost" then return check.plan_summary(entity.insert_plan) end
  local proxy = entity.item_request_proxy
  return check.plan_summary(proxy and proxy.insert_plan)
end

local function pasted(source, destination)
  return paste.apply(source, destination, rig.FORCE, PLAYER) ~= nil
end

local function furnaces(surface)
  local input, fuel = defines.inventory.crafter_input, defines.inventory.fuel
  local source = primed(rig.ghost(surface, "stone-furnace", rig.at(-40, Y)),
    { recipe = "iron-plate", crafts = 50, fuel = "coal", fuel_count = 4 })
  local same = rig.ghost(surface, "stone-furnace", rig.at(-36, Y))
  check.same("paste ghost furnace gets the ore and its own estimate", { pasted(source, same), plan_of(same) },
    { true, check.lines { line("iron-ore", input, 0, 50), line("coal", fuel, 0, 4) } })
  local steel = rig.ghost(surface, "steel-furnace", rig.at(-32, Y))
  check.same("paste steel furnace gets the ore and steel's smaller estimate", { pasted(source, steel), plan_of(steel) },
    { true, check.lines { line("iron-ore", input, 0, 50), line("coal", fuel, 0, 2) } })
  local half = rig.built(surface, "stone-furnace", rig.at(-28, Y))
  half.insert { name = "iron-ore", count = 20 }
  check.same("paste tops up a half-full built furnace", { pasted(source, half), plan_of(half) },
    { true, check.lines { line("iron-ore", input, 0, 30), line("coal", fuel, 0, 4) } })
  local typed = primed(rig.ghost(surface, "stone-furnace", rig.at(-24, Y)),
    { recipe = "iron-plate", crafts = 20, fuel = "coal", fuel_count = 10 })
  local steel_typed = rig.ghost(surface, "steel-furnace", rig.at(-20, Y))
  check.same("paste carries a typed fuel amount as typed", { pasted(typed, steel_typed), plan_of(steel_typed) },
    { true, check.lines { line("iron-ore", input, 0, 20), line("coal", fuel, 0, 10) } })
  local electric = rig.ghost(surface, "electric-furnace", rig.at(13.5, Y + 0.5))
  check.same("paste onto an electric furnace carries the ore alone", { pasted(source, electric), plan_of(electric) },
    { true, { line("iron-ore", input, 0, 50) } })
  return source
end

local function assemblers(surface)
  local input = defines.inventory.crafter_input
  local source = primed(rig.ghost(surface, "assembling-machine-2", rig.at(-15.5, Y + 0.5), { recipe = "electronic-circuit" }),
    { recipe = "electronic-circuit", crafts = 5 })
  -- Vanilla's paste has already set the destination's recipe.
  local destination = rig.ghost(surface, "assembling-machine-2", rig.at(-11.5, Y + 0.5), { recipe = "electronic-circuit" })
  check.same("paste assembler gets both ingredient slots", { pasted(source, destination), plan_of(destination) },
    { true, check.lines { line("iron-plate", input, 0, 5), line("copper-cable", input, 1, 15) } })
end

-- Nothing primed on the source (no request, or only vanilla's module
-- request), or a destination of another kind.
local function left_alone(surface, source)
  local modules = defines.inventory.crafter_modules
  local bare = rig.ghost(surface, "stone-furnace", rig.at(-6, Y))
  local target_ghost = rig.ghost(surface, "stone-furnace", rig.at(-3, Y))
  check.same("paste from an unprimed source does nothing", { pasted(bare, target_ghost), plan_of(target_ghost) }, { false, {} })
  local gears = rig.built(surface, "assembling-machine-2", rig.at(1.5, Y + 0.5), { recipe = "iron-gear-wheel" })
  surface.create_entity { name = "item-request-proxy", target = gears, position = gears.position, force = gears.force,
    modules = { { id = { name = "speed-module" }, items = { in_inventory = { { inventory = modules, stack = 0, count = 1 } } } } } }
  local gears_to = rig.ghost(surface, "assembling-machine-2", rig.at(5.5, Y + 0.5), { recipe = "iron-gear-wheel" })
  check.same("paste ignores a vanilla module request", { pasted(gears, gears_to), plan_of(gears_to) }, { false, {} })
  local assembler = rig.ghost(surface, "assembling-machine-2", rig.at(9.5, Y + 0.5))
  check.same("paste furnace onto an assembler does nothing", { pasted(source, assembler), plan_of(assembler) }, { false, {} })
end

function cases.run(surface)
  local source
  check.run("paste.furnaces", function() source = furnaces(surface) end)
  check.run("paste.assemblers", function() assemblers(surface) end)
  check.run("paste.left_alone", function() left_alone(surface, assert(source)) end)
end

return cases
