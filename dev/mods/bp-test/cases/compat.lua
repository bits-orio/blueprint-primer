-- Factorio 2.1 compatibility, checked on both versions: an assembler with a
-- fixed recipe that takes items (bp-test's own), whose fixed_recipe reads
-- back as a string in 2.0 and a LuaRecipePrototype in 2.1.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local request = require("__BlueprintPrimer__/scripts/request")
local blueprint = require("__BlueprintPrimer__/scripts/blueprint")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")

local cases = {}

local PLAYER = 9
local NAME = "bp-test-fixed"

local function fixed_recipe(surface)
  local ghost = assert(target.from_entity(rig.ghost(surface, NAME, rig.at(20.5, 16.5)), rig.FORCE))
  local built = assert(target.from_entity(rig.built(surface, NAME, rig.at(26.5, 16.5)), rig.FORCE))
  for _, t in ipairs({ ghost, built }) do
    local how = t.is_ghost and "ghost" or "built"
    local p = priming.new(t, PLAYER)
    check.same("compat fixed recipe reads as a name, locked (" .. how .. ")",
      { target.current_recipe(t), p.recipe, type(p.recipe), priming.recipe_locked(p), priming.blocker(p) == nil },
      { "iron-gear-wheel", "iron-gear-wheel", "string", true, true })
    p.crafts = 5
    check.same("compat fixed recipe plans its items (" .. how .. ")", check.plan_summary(request.plans(t, p, {})),
      { check.plan_line("iron-plate", defines.inventory.crafter_input, 0, 10) })
    check.eq("compat fixed recipe blueprint names it (" .. how .. ")", blueprint.entity(t, p).recipe, "iron-gear-wheel")
  end
  check.same("compat fixed recipe Request on a ghost", { request.apply(ghost, priming.new(ghost, PLAYER)) },
    { true, "bp-primer.requested" })
end

function cases.run(surface)
  check.run("compat.fixed_recipe", function() fixed_recipe(surface) end)
end

return cases
