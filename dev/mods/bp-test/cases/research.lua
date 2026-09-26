-- ADR-0009: unresearched recipes may be picked and primed; only a built
-- furnace refuses them, since the engine drops its ingredients. The rig
-- enables every recipe, so each case locks what it needs and restores it.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local blueprint = require("__BlueprintPrimer__/scripts/blueprint")

local cases = {}

local Y = 3

local function locked(recipes, body)
  local force = game.forces[rig.FORCE]
  for _, name in ipairs(recipes) do force.recipes[name].enabled = false end
  local ok, err = pcall(body)
  for _, name in ipairs(recipes) do force.recipes[name].enabled = true end
  if not ok then error(err, 0) end
end

local function index_of(list, name)
  for i, entry in ipairs(list) do
    if entry == name then return i end
  end
end

local function candidate_lists()
  local furnace = target.recipe_candidates(prototypes.entity["stone-furnace"])
  check.truthy("research candidates for a furnace list its smelting recipes",
    index_of(furnace, "iron-plate") and index_of(furnace, "steel-plate") and index_of(furnace, "stone-brick"))
  check.eq("research candidates for a furnace skip multi-item recipes", index_of(furnace, "iron-gear-wheel"), nil)
  local assembler = target.recipe_candidates(prototypes.entity["assembling-machine-2"])
  check.truthy("research candidates for an assembler include engine units", index_of(assembler, "engine-unit"))
  local parameter = false
  for _, name in ipairs(assembler) do parameter = parameter or prototypes.recipe[name].parameter end
  check.eq("research candidates never list blueprint parameters", parameter, false)
  check.eq("research candidates are memoised", target.recipe_candidates(prototypes.entity["assembling-machine-2"]), assembler)
end

local function assembler_cases(surface)
  locked({ "engine-unit" }, function()
    local built = rig.built(surface, "assembling-machine-2", rig.at(-30, Y))
    local t = assert(target.from_entity(built, rig.FORCE))
    check.eq("research allows an unresearched recipe", target.allows_recipe(t, "engine-unit"), true)
    check.eq("research reports it as not unlocked", target.recipe_unlocked(t, "engine-unit"), false)
    local ok = request.apply(t, rig.priming(t, { recipe = "engine-unit", crafts = 3 }))
    check.truthy("research Request sets an unresearched recipe on a built assembler",
      ok and (built.get_recipe() or {}).name == "engine-unit" and built.item_request_proxy)
    local ghost = assert(target.from_entity(rig.ghost(surface, "assembling-machine-2", rig.at(-24, Y)), rig.FORCE))
    local p = rig.priming(ghost, { recipe = "engine-unit", crafts = 3 })
    check.eq("research blueprint keeps an unresearched recipe", blueprint.entity(ghost, p).recipe, "engine-unit")
  end)
end

local function furnace_cases(surface)
  locked({ "steel-plate" }, function()
    local built = assert(target.from_entity(rig.built(surface, "stone-furnace", rig.at(-18, Y)), rig.FORCE))
    local p = rig.priming(built, { recipe = "steel-plate", crafts = 2, fuel = "coal", fuel_count = 1 })
    check.eq("research built furnace cannot take an unresearched recipe", target.recipe_deliverable(built, "steel-plate"), false)
    check.same("research Request refuses it on a built furnace", { request.apply(built, p) },
      { false, "bp-primer.furnace-not-researched" })
    check.eq("research refusal leaves no proxy", built.entity.item_request_proxy, nil)
    local ghost = assert(target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(-12, Y)), rig.FORCE))
    local q = rig.priming(ghost, { recipe = "steel-plate", crafts = 2, fuel = "coal", fuel_count = 1 })
    check.eq("research Request primes a ghost furnace for later", (request.apply(ghost, q)), true)
  end)
end

function cases.run(surface)
  check.run("research.candidates", candidate_lists)
  check.run("research.assembler", function() assembler_cases(surface) end)
  check.run("research.furnace", function() furnace_cases(surface) end)
end

return cases
