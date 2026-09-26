-- request.lua: insert plans, top-up, merging onto foreign requests, refusals.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")

local cases = {}

local Y = 10
local line = check.plan_line

local function inv()
  return defines.inventory.crafter_input, defines.inventory.fuel, defines.inventory.crafter_modules
end

local function furnace_plans(surface)
  local input, fuel = inv()
  local built = rig.built(surface, "stone-furnace", rig.at(-30, Y))
  built.get_inventory(input).insert { name = "iron-ore", count = 20 }
  built.get_inventory(fuel).insert { name = "coal", count = 1 }
  local t = target.from_entity(built, rig.FORCE)
  local p = rig.priming(t, { recipe = "iron-plate", crafts = 50, fuel = "coal", fuel_count = 4 })
  check.same("request.plans without top_up", check.plan_summary(request.plans(t, p, { top_up = false })),
    check.lines { line("iron-ore", input, 0, 50), line("coal", fuel, 0, 4) })
  check.same("request.plans with top_up", check.plan_summary(request.plans(t, p, { top_up = true })),
    check.lines { line("iron-ore", input, 0, 30), line("coal", fuel, 0, 3) })
end

local function assembler_plans(surface)
  local input = inv()
  local t = target.from_entity(rig.ghost(surface, "assembling-machine-2", rig.at(-24, Y)), rig.FORCE)
  local p = rig.priming(t, { recipe = "electronic-circuit", crafts = 5 })
  check.same("request.plans assembler slots", check.plan_summary(request.plans(t, p, { top_up = true })),
    check.lines { line("iron-plate", input, 0, 5), line("copper-cable", input, 1, 15) })
end

local function fuel_spread(surface)
  local _, fuel = inv()
  local ghost = target.from_entity(rig.ghost(surface, "tank", rig.at(-18, Y)), rig.FORCE)
  local p = rig.priming(ghost, { fuel = "coal", fuel_count = 70 })
  check.same("request.plans fuel spreads over stacks", check.plan_summary(request.plans(ghost, p, {})),
    check.lines { line("coal", fuel, 0, 50), line("coal", fuel, 1, 20) })
  local built = rig.built(surface, "tank", rig.at(-10, Y))
  built.get_inventory(fuel).insert { name = "wood", count = 5 }
  local t = target.from_entity(built, rig.FORCE)
  local plans, shortfall = request.plans(t, rig.priming(t, { fuel = "coal", fuel_count = 30 }), { top_up = true })
  check.same("request.plans fuel skips a stack holding another fuel", check.plan_summary(plans),
    check.lines { line("coal", fuel, 1, 30) })
  check.eq("request.plans no shortfall when a free slot takes it all", shortfall, 0)
end

-- A one-slot furnace burning wood has no room for coal: the whole request
-- is refused rather than written without its fuel.
local function fuel_slot_taken(surface)
  local input, fuel = inv()
  local e = rig.built(surface, "stone-furnace", rig.at(-18, 42))
  e.get_inventory(fuel).insert { name = "wood", count = 5 }
  local t = target.from_entity(e, rig.FORCE)
  local _, shortfall = request.plans(t, rig.priming(t, { recipe = "iron-plate", crafts = 10, fuel = "coal", fuel_count = 4 }), { top_up = true })
  check.eq("request.plans reports fuel that does not fit", shortfall, 4)
  local ok, why = request.apply(t, rig.priming(t, { recipe = "iron-plate", crafts = 10, fuel = "coal", fuel_count = 4 }))
  check.same("request.apply refuses fuel that cannot fit", { ok, why }, { false, "bp-primer.fuel-slot-taken" })
  check.eq("request.apply fuel refusal writes nothing", e.item_request_proxy, nil)
  ok = request.apply(t, rig.priming(t, { recipe = "iron-plate", crafts = 10, fuel = "wood", fuel_count = 8 }))
  check.truthy("request.apply tops up the held fuel", ok and e.item_request_proxy)
  check.same("request.apply held fuel plan", check.plan_summary(e.item_request_proxy.insert_plan),
    check.lines { line("iron-ore", input, 0, 10), line("wood", fuel, 0, 3) })
end

-- One craft needing more than a stack is requested whole, into one slot.
local function over_stack(surface)
  local input = inv()
  local ghost = rig.ghost(surface, "assembling-machine-2", rig.at(-24.5, 42.5), { recipe = "bp-test-bulk" })
  local t = target.from_entity(ghost, rig.FORCE)
  check.same("request.plans over-stack ingredient not clamped to a stack",
    check.plan_summary(request.plans(t, rig.priming(t, { recipe = "bp-test-bulk", crafts = 1 }), {})),
    check.lines { line("bp-test-brick", input, 0, 25) })
end

local function merge_keeps_modules(surface)
  local input, fuel, modules = inv()
  local ghost = rig.ghost(surface, "assembling-machine-2", rig.at(-2, Y), { recipe = "electronic-circuit" })
  ghost.insert_plan = {
    { id = { name = "speed-module" }, items = { in_inventory = { { inventory = modules, stack = 0, count = 1 } } } },
    { id = { name = "iron-plate" }, items = { in_inventory = { { inventory = input, stack = 0, count = 99 } } } },
  }
  local t = target.from_entity(ghost, rig.FORCE)
  local ok, notice = request.apply(t, rig.priming(t, { recipe = "electronic-circuit", crafts = 5 }))
  check.same("request.apply ghost ok", { ok, notice }, { true, "bp-primer.requested" })
  check.same("request.apply keeps module plan, replaces ours", check.plan_summary(ghost.insert_plan),
    check.lines { line("speed-module", modules, 0, 1), line("iron-plate", input, 0, 5), line("copper-cable", input, 1, 15) })
  local g2 = rig.ghost(surface, "assembling-machine-2", rig.at(4, Y), { recipe = "iron-gear-wheel" })
  local t2 = target.from_entity(g2, rig.FORCE)
  request.apply(t2, rig.priming(t2, { recipe = "electronic-circuit", crafts = 2 }))
  check.eq("request.apply sets a ghost's recipe", (g2.get_recipe() or {}).name, "electronic-circuit")
end

local function refusals(surface)
  local busy = rig.built(surface, "assembling-machine-2", rig.at(10, Y), { recipe = "iron-gear-wheel" })
  local t = target.from_entity(busy, rig.FORCE)
  local ok, why = request.apply(t, rig.priming(t, { recipe = "electronic-circuit", crafts = 5 }))
  check.same("request.apply refuses a built assembler on another recipe", { ok, why }, { false, "bp-primer.recipe-mismatch" })
  check.eq("request.apply refusal leaves no proxy", busy.item_request_proxy, nil)
  local idle = rig.built(surface, "assembling-machine-2", rig.at(16, Y))
  local t2 = target.from_entity(idle, rig.FORCE)
  ok = request.apply(t2, rig.priming(t2, { recipe = "electronic-circuit", crafts = 5 }))
  check.truthy("request.apply sets recipe on an idle built assembler",
    ok and (idle.get_recipe() or {}).name == "electronic-circuit" and idle.item_request_proxy)
  local f = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(22, Y)), rig.FORCE)
  ok, why = request.apply(f, rig.priming(f, { recipe = "iron-gear-wheel", crafts = 5 }))
  check.same("request.apply refuses a recipe the machine cannot make", { ok, why }, { false, "bp-primer.recipe-not-allowed" })
end

local function proxy_reuse(surface)
  local input, fuel, modules = inv()
  local e = rig.built(surface, "assembling-machine-2", rig.at(28, Y), { recipe = "electronic-circuit" })
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = { { id = { name = "speed-module" }, items = { in_inventory = { { inventory = modules, stack = 1, count = 1 } } } } } }
  local t = target.from_entity(e, rig.FORCE)
  request.apply(t, rig.priming(t, { recipe = "electronic-circuit", crafts = 3 }))
  local proxies = surface.find_entities_filtered { type = "item-request-proxy", position = e.position, radius = 1 }
  check.eq("request.apply reuses the existing proxy", #proxies, 1)
  check.same("request.apply proxy keeps module plan", check.plan_summary(e.item_request_proxy.insert_plan),
    check.lines { line("speed-module", modules, 1, 1), line("iron-plate", input, 0, 3), line("copper-cable", input, 1, 9) })
end

local function full_is_noop(surface)
  local input, fuel = inv()
  local e = rig.built(surface, "stone-furnace", rig.at(34, Y))
  e.get_inventory(input).insert { name = "iron-ore", count = 10 }
  e.get_inventory(fuel).insert { name = "coal", count = 2 }
  local t = target.from_entity(e, rig.FORCE)
  local p = rig.priming(t, { recipe = "iron-plate", crafts = 10, fuel = "coal", fuel_count = 2 })
  check.same("request.apply already full is ok, and says nothing is coming", { request.apply(t, p) },
    { true, "bp-primer.already-stocked" })
  check.eq("request.apply already full makes no proxy", e.item_request_proxy, nil)
  surface.create_entity { name = "item-request-proxy", target = e, position = e.position, force = e.force,
    modules = { { id = { name = "iron-ore" }, items = { in_inventory = { { inventory = input, stack = 0, count = 5 } } } } } }
  request.apply(t, p)
  check.eq("request.apply clears a stale proxy of ours", e.item_request_proxy, nil)
end

function cases.run(surface)
  check.run("request.furnace_plans", function() furnace_plans(surface) end)
  check.run("request.assembler_plans", function() assembler_plans(surface) end)
  check.run("request.fuel_spread", function() fuel_spread(surface) end)
  check.run("request.merge_keeps_modules", function() merge_keeps_modules(surface) end)
  check.run("request.refusals", function() refusals(surface) end)
  check.run("request.proxy_reuse", function() proxy_reuse(surface) end)
  check.run("request.full_is_noop", function() full_is_noop(surface) end)
  check.run("request.fuel_slot_taken", function() fuel_slot_taken(surface) end)
  check.run("request.over_stack", function() over_stack(surface) end)
end

return cases
