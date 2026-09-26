-- End to end: requests written by the real modules, delivered by real robots,
-- smelted by real furnaces. setup() runs at tick 0; verify() after CHECK_TICK.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local fuel = require("__BlueprintPrimer__/scripts/fuel")
local request = require("__BlueprintPrimer__/scripts/request")
local blueprint = require("__BlueprintPrimer__/scripts/blueprint")
local stamp = require("cases.blueprint").stamp

local delivery = {}

local COAL_J = 4000000
local IRON_J = 288000 -- one stone-furnace iron-plate craft

local function prime(entity, fields)
  local t = assert(target.from_entity(entity, rig.FORCE))
  local p = rig.priming(t, fields)
  local ok, why = request.apply(t, p)
  check.truthy("delivery apply " .. entity.position.x, ok, why)
  return t, p
end

local function ghost_furnace(surface)
  local pos = { x = -20, y = 10 }
  local ghost = rig.ghost(surface, "stone-furnace", pos)
  local est = fuel.estimate(assert(target.from_entity(ghost, rig.FORCE)), "iron-plate", 30, "coal")
  local t = prime(ghost, { recipe = "iron-plate", crafts = 30, fuel = "coal", fuel_count = est })
  check.same("delivery a ghost requests 30 ore and the estimate", check.plan_summary(ghost.insert_plan), check.lines {
    check.plan_line("iron-ore", defines.inventory.crafter_input, 0, 30), check.plan_line("coal", defines.inventory.fuel, 0, 3) })
  storage.delivery.a = { t = t, pos = pos, coal = est }
end

local function built_top_up(surface)
  local input, fuel_inv = defines.inventory.crafter_input, defines.inventory.fuel
  local pos = { x = -14, y = 10 }
  local e = rig.built(surface, "stone-furnace", pos)
  e.get_inventory(input).insert { name = "iron-ore", count = 20 }
  prime(e, { recipe = "iron-plate", crafts = 50, fuel = "coal", fuel_count = 4 })
  check.same("delivery b proxy requests only the top-up", check.plan_summary(e.item_request_proxy.insert_plan),
    check.lines { check.plan_line("iron-ore", input, 0, 30), check.plan_line("coal", fuel_inv, 0, 4) })
  storage.delivery.b = { pos = pos }
end

local function assembler_with_module(surface)
  local input, modules = defines.inventory.crafter_input, defines.inventory.crafter_modules
  local pos = { x = 14.5, y = 20.5 }
  local ghost = rig.ghost(surface, "assembling-machine-2", pos)
  ghost.insert_plan = { { id = { name = "speed-module" }, items = { in_inventory = { { inventory = modules, stack = 0, count = 1 } } } } }
  prime(ghost, { recipe = "electronic-circuit", crafts = 5 })
  check.same("delivery c plan keeps the module", check.plan_summary(ghost.insert_plan), check.lines {
    check.plan_line("speed-module", modules, 0, 1), check.plan_line("iron-plate", input, 0, 5), check.plan_line("copper-cable", input, 1, 15) })
  storage.delivery.c = { pos = pos }
end

local function from_blueprint(surface)
  local t = assert(target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(40, 40)), rig.FORCE))
  local p = rig.priming(t, { recipe = "stone-brick", crafts = 10, fuel = "coal", fuel_count = fuel.estimate(t, "stone-brick", 10, "coal") })
  local ghost = stamp(surface, blueprint.entity(t, p), { x = 6, y = 10 })
  storage.delivery.e = { pos = ghost.position }
end

-- The same 10 ore twice: fuel for exactly 2.88 MJ starves the last craft,
-- the estimate (with its one-second margin) does not.
local function margin(surface)
  local input, fuel_inv = defines.inventory.crafter_input, defines.inventory.fuel
  local bare = rig.ghost(surface, "stone-furnace", { x = -8, y = 16 })
  bare.insert_plan = {
    { id = { name = "iron-ore" }, items = { in_inventory = { { inventory = input, stack = 0, count = 10 } } } },
    { id = { name = "bp-test-fuel" }, items = { in_inventory = { { inventory = fuel_inv, stack = 0, count = 1 } } } },
  }
  local t = assert(target.from_entity(rig.ghost(surface, "stone-furnace", { x = -2, y = 16 }), rig.FORCE))
  local est = fuel.estimate(t, "iron-plate", 10, "bp-test-fuel")
  request.apply(t, rig.priming(t, { recipe = "iron-plate", crafts = 10, fuel = "bp-test-fuel", fuel_count = est }))
  storage.delivery.f = { bare = { x = -8, y = 16 }, primed = { x = -2, y = 16 } }
end

-- The engine fact craft.slot_limit stands on: one craft needing more than a
-- stack (25 of a stack-10 item) is delivered whole into one input slot, via
-- a ghost's plan and via a built machine's proxy. Unpowered, so it stays.
local function over_stack(surface)
  local ghost = rig.ghost(surface, "assembling-machine-2", { x = -20.5, y = 22.5 }, { recipe = "bp-test-bulk" })
  prime(ghost, { recipe = "bp-test-bulk", crafts = 1 })
  local built = rig.built(surface, "assembling-machine-2", { x = -14.5, y = 22.5 }, { recipe = "bp-test-bulk" })
  prime(built, { recipe = "bp-test-bulk", crafts = 1 })
  storage.delivery.g = { { x = -20.5, y = 22.5 }, { x = -14.5, y = 22.5 } }
end

function delivery.setup(surface)
  storage.delivery = {}
  check.run("delivery.a setup", function() ghost_furnace(surface) end)
  check.run("delivery.b setup", function() built_top_up(surface) end)
  check.run("delivery.c setup", function() assembler_with_module(surface) end)
  check.run("delivery.e setup", function() from_blueprint(surface) end)
  check.run("delivery.f setup", function() margin(surface) end)
  check.run("delivery.g setup", function() over_stack(surface) end)
end

local function counts(e)
  local input, output, fuel_inv = defines.inventory.crafter_input, defines.inventory.crafter_output, defines.inventory.fuel
  return e.get_inventory(input).get_contents(), e.get_inventory(output).get_contents(),
    e.get_inventory(fuel_inv) and e.get_inventory(fuel_inv).get_item_count() or 0
end

local function out_count(e, item)
  return e.get_inventory(defines.inventory.crafter_output).get_item_count(item)
end

local function verify_a(surface)
  local d = storage.delivery.a
  local e = assert(rig.machine_at(surface, d.pos), "furnace a never built")
  local input, _, fuel_left = counts(e)
  check.truthy("delivery a smelted exactly 30", out_count(e, "iron-plate") == 30 and #input == 0 and fuel_left == 0,
    serpent.line { out = out_count(e, "iron-plate"), input = input, fuel_left = fuel_left })
  local spare = d.coal * COAL_J - 30 * IRON_J - e.burner.remaining_burning_fuel
  check.truthy("delivery a delivered exactly the estimate", spare >= 0 and spare < 10000, "unaccounted J " .. spare)
  check.truthy("target.revalidate after robots revived", target.revalidate(d.t) and not d.t.is_ghost and d.t.entity == e)
  check.same("target.current_recipe built furnace (previous)", { target.current_recipe(d.t) }, { "iron-plate", "normal" })
end

local function verify_b(surface)
  local e = assert(rig.machine_at(surface, storage.delivery.b.pos), "furnace b missing")
  local input = e.get_inventory(defines.inventory.crafter_input).get_item_count()
  check.truthy("delivery b topped up to 50 total", out_count(e, "iron-plate") == 50 and input == 0,
    "plates " .. out_count(e, "iron-plate") .. " ore left " .. input)
end

local function verify_c(surface)
  local e = assert(rig.machine_at(surface, storage.delivery.c.pos), "assembler c never built")
  local modules = e.get_inventory(defines.inventory.crafter_modules)
  local input = e.get_inventory(defines.inventory.crafter_input)
  check.truthy("delivery c module and partial ingredients delivered",
    modules.get_item_count("speed-module") == 1 and input.get_item_count("iron-plate") == 5
      and input.get_item_count("copper-cable") == 15,
    serpent.line { modules = modules.get_contents(), input = input.get_contents() })
end

local function verify_e(surface)
  local e = assert(rig.machine_at(surface, storage.delivery.e.pos), "blueprint furnace never built")
  check.eq("delivery e blueprint furnace made 10 bricks", out_count(e, "stone-brick"), 10)
end

local function verify_f(surface)
  local bare = assert(rig.machine_at(surface, storage.delivery.f.bare), "bare furnace missing")
  local primed = assert(rig.machine_at(surface, storage.delivery.f.primed), "primed furnace missing")
  check.info("margin: bare fuel smelted " .. out_count(bare, "iron-plate") .. ", estimate smelted " .. out_count(primed, "iron-plate"))
  check.truthy("delivery f margin matters (exact energy starves the last craft)", out_count(bare, "iron-plate") < 10)
  check.eq("delivery f estimate with margin finishes all 10", out_count(primed, "iron-plate"), 10)
end

local function verify_g(surface)
  for i, pos in ipairs(storage.delivery.g) do
    local e = assert(rig.machine_at(surface, pos), "bulk assembler " .. i .. " missing")
    local input = e.get_inventory(defines.inventory.crafter_input)
    check.truthy("delivery g over-stack ingredient delivered whole into one slot (" .. i .. ")",
      input[1].valid_for_read and input[1].name == "bp-test-brick" and input[1].count == 25,
      serpent.line(input.get_contents()))
  end
end

function delivery.verify(surface)
  check.run("delivery.a", function() verify_a(surface) end)
  check.run("delivery.b", function() verify_b(surface) end)
  check.run("delivery.c", function() verify_c(surface) end)
  check.run("delivery.e", function() verify_e(surface) end)
  check.run("delivery.f", function() verify_f(surface) end)
  check.run("delivery.g", function() verify_g(surface) end)
end

return delivery
