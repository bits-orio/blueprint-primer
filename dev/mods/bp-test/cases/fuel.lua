-- fuel.lua: the estimate, capacity, accepted fuels and the default-fuel rule.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local fuel = require("__BlueprintPrimer__/scripts/fuel")
local fuel_tier = require("__BlueprintPrimer__/scripts/fuel_tier")

local cases = {}

local function ghost_target(surface, name, dx, opts)
  return assert(target.from_entity(rig.ghost(surface, name, rig.at(dx, -30), opts), rig.FORCE))
end

local function usage_basis_for(name)
  local p = prototypes.entity[name]
  if not p then return end
  for quality in pairs(prototypes.quality) do
    if quality ~= "quality-unknown" then
      local max = p.get_max_energy_usage(quality)
      check.info(string.format("usage %s@%s energy_usage=%s max=%s speed=%s", name, quality,
        p.energy_usage, max, p.get_crafting_speed(quality)))
      check.near("fuel.usage_basis " .. name .. "@" .. quality, max, p.energy_usage, 1e-9)
    end
  end
end

-- Which energy figure the formula must use: bp-test asserts, rather than
-- assumes, that quality never changes a burner crafter's energy usage.
local function usage_basis()
  for _, name in ipairs { "stone-furnace", "steel-furnace", "biochamber" } do usage_basis_for(name) end
end

local function estimate(surface)
  local stone = ghost_target(surface, "stone-furnace", -20)
  local steel = ghost_target(surface, "steel-furnace", -16)
  check.near("fuel.joules_per_craft stone iron-plate", fuel.joules_per_craft(stone, "iron-plate"), 288000, 1e-6)
  check.eq("fuel.estimate stone 50 iron coal", fuel.estimate(stone, "iron-plate", 50, "coal"), 4)
  check.eq("fuel.estimate steel 50 iron coal", fuel.estimate(steel, "iron-plate", 50, "coal"), 2)
  check.eq("fuel.estimate stone 10 bricks coal", fuel.estimate(stone, "stone-brick", 10, "coal"), 1)
  -- 25 steel = 36 MJ = exactly 9 coal: only the margin makes it 10.
  check.eq("fuel.estimate margin applied at boundary", fuel.estimate(stone, "steel-plate", 25, "coal"), 10)
  check.eq("fuel.estimate test fuel boundary", fuel.estimate(stone, "iron-plate", 10, "bp-test-fuel"), 2)
  check.eq("fuel.estimate zero crafts still >= 1", fuel.estimate(stone, "iron-plate", 0, "coal"), 1)
end

local function capacity(surface)
  local stone = ghost_target(surface, "stone-furnace", -12)
  local tank = ghost_target(surface, "tank", -6)
  check.eq("fuel.capacity stone coal", fuel.capacity(stone, "coal"), 50)
  check.eq("fuel.capacity tank coal", fuel.capacity(tank, "coal"), 100)
  local max = fuel.max_crafts(stone, "iron-plate", "coal")
  check.eq("fuel.max_crafts stone iron coal", max, 694)
  check.truthy("fuel.max_crafts is the largest that fits",
    fuel.estimate(stone, "iron-plate", max, "coal") <= 50 and fuel.estimate(stone, "iron-plate", max + 1, "coal") > 50,
    "estimate(max)/estimate(max+1) straddle the capacity")
  local assembler = assert(target.from_entity(rig.ghost(surface, "assembling-machine-2", rig.at(0, -30)), rig.FORCE))
  check.eq("fuel.max_crafts electric is unlimited", fuel.max_crafts(assembler, "iron-gear-wheel", "coal"), math.huge)
  local boiler = ghost_target(surface, "boiler", 36)
  check.eq("fuel.estimate fuel-only without recipe", fuel.estimate(boiler, nil, 0, "coal"), 1)
  check.eq("fuel.capacity boiler coal", fuel.capacity(boiler, "coal"), 50)
end

local function accepts(surface)
  local stone = ghost_target(surface, "stone-furnace", 4)
  check.truthy("fuel.accepts stone coal", fuel.accepts(stone, "coal"))
  check.truthy("fuel.accepts stone wood", fuel.accepts(stone, "wood"))
  check.truthy("fuel.accepts stone rejects iron-plate", not fuel.accepts(stone, "iron-plate"))
  check.truthy("fuel.accepts stone rejects uranium cell", not fuel.accepts(stone, "uranium-fuel-cell"))
  local reactor = ghost_target(surface, "nuclear-reactor", 12)
  check.truthy("fuel.accepts reactor uranium cell", fuel.accepts(reactor, "uranium-fuel-cell"))
  local listed = prototypes.get_item_filtered(fuel.filters(stone))
  check.truthy("fuel.filters lists coal and solid-fuel", listed["coal"] and listed["solid-fuel"])
  check.truthy("fuel.filters excludes non-fuel and hidden",
    not listed["iron-plate"] and not listed["uranium-fuel-cell"] and not listed["bp-test-fuel"])
end

local function default(surface)
  local stone = ghost_target(surface, "stone-furnace", 20)
  check.eq("fuel.earliest stone furnace", fuel.earliest(stone), "coal")
  check.eq("fuel.default with no memory", fuel.default(stone, 1), "coal")
  fuel.remember(1, stone, "solid-fuel")
  check.eq("fuel.default remembers per category", fuel.default(stone, 1), "solid-fuel")
  fuel.remember(1, stone, "iron-plate")
  check.eq("fuel.remember ignores non-fuel", storage.players[1].fuel_by_category["chemical"], "solid-fuel")
  check.eq("fuel.default is per player", fuel.default(stone, 2), "coal")
  -- A built furnace already burning wood tops up wood, whatever is remembered.
  local burning = rig.built(surface, "stone-furnace", rig.at(30, -30))
  burning.get_inventory(defines.inventory.fuel).insert { name = "wood", count = 5 }
  check.eq("fuel.default prefers the fuel a built machine holds",
    fuel.default(assert(target.from_entity(burning, rig.FORCE)), 1), "wood")
  if script.active_mods["space-age"] then
    local bio = ghost_target(surface, "biochamber", 26)
    check.eq("fuel.earliest biochamber (space-age)", fuel.earliest(bio), "nutrients")
    check.eq("fuel.default biochamber ignores chemical memory", fuel.default(bio, 1), "nutrients")
  end
end

-- Recycling recipes (quality) are enabled from the start; the tier must not
-- let them make every fuel look research-free.
local function tiers()
  local coal, solid = fuel_tier.of("coal"), fuel_tier.of("solid-fuel")
  local rocket, nuclear = fuel_tier.of("rocket-fuel"), fuel_tier.of("nuclear-fuel")
  check.info(string.format("tiers coal=%s solid=%s rocket=%s nuclear=%s", coal, solid, rocket, nuclear))
  check.eq("fuel_tier coal is research-free", coal, 0)
  check.eq("fuel_tier iron-plate recipe enabled from start", fuel_tier.of("iron-plate"), 0)
  check.truthy("fuel_tier follows the tech tree", 0 < solid and solid < rocket and rocket < nuclear and nuclear < math.huge)
  check.eq("fuel_tier unknown item unreachable", fuel_tier.of("no-such-item"), math.huge)
end

function cases.run(surface)
  check.run("fuel.tiers", tiers)
  check.run("fuel.usage_basis", usage_basis)
  check.run("fuel.estimate", function() estimate(surface) end)
  check.run("fuel.capacity", function() capacity(surface) end)
  check.run("fuel.accepts", function() accepts(surface) end)
  check.run("fuel.default", function() default(surface) end)
end

return cases
