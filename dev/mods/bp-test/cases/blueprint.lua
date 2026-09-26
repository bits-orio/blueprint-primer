-- blueprint.lua: the primed blueprint's single entity, built back into a ghost.
-- (to_cursor needs a player, which headless runs do not have: see PLAYTEST.md.)

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local blueprint = require("__BlueprintPrimer__/scripts/blueprint")

local cases = {}

local Y = 30

-- Builds the one-entity blueprint at `where` and returns the ghost it made.
local function stamp(surface, entity, where)
  local inventory = game.create_inventory(1)
  inventory[1].set_stack { name = "blueprint" }
  inventory[1].set_blueprint_entities { entity }
  local built = inventory[1].build_blueprint {
    surface = surface, force = rig.FORCE, position = where, build_mode = defines.build_mode.forced,
  }
  inventory.destroy()
  return built[1]
end

local function furnace(surface)
  local input, fuel = defines.inventory.crafter_input, defines.inventory.fuel
  local t = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(-30, Y)), rig.FORCE)
  local p = rig.priming(t, { recipe = "stone-brick", crafts = 10, fuel = "coal", fuel_count = 1 })
  local entity = blueprint.entity(t, p)
  check.truthy("blueprint.entity furnace has no recipe field", entity.recipe == nil and entity.name == "stone-furnace")
  local where = rig.at(-20, Y)
  local ghost = stamp(surface, entity, where)
  check.truthy("blueprint build furnace ghost", ghost and ghost.ghost_name == "stone-furnace")
  check.same("blueprint furnace ghost plan", check.plan_summary(ghost.insert_plan),
    check.lines { check.plan_line("stone", input, 0, 20), check.plan_line("coal", fuel, 0, 1) })
  check.same("blueprint furnace lands where stamped", ghost.position, where)
end

local function assembler(surface)
  local input = defines.inventory.crafter_input
  local built = rig.built(surface, "assembling-machine-2", rig.at(-10, Y), { recipe = "iron-gear-wheel" })
  built.get_inventory(input).insert { name = "iron-plate", count = 7 }
  local t = target.from_entity(built, rig.FORCE)
  local p = rig.priming(t, { recipe = "electronic-circuit", crafts = 5 })
  local entity = blueprint.entity(t, p)
  check.same("blueprint.entity assembler recipe", { entity.recipe, entity.recipe_quality }, { "electronic-circuit", "normal" })
  local ghost = stamp(surface, entity, rig.at(0.5, Y + 0.5))
  check.truthy("blueprint build assembler ghost", ghost and ghost.ghost_name == "assembling-machine-2")
  check.eq("blueprint assembler ghost recipe", (ghost.get_recipe() or {}).name, "electronic-circuit")
  -- Not topped up: the source machine's 7 plates do not travel with it.
  check.same("blueprint assembler ghost plan", check.plan_summary(ghost.insert_plan),
    check.lines { check.plan_line("iron-plate", input, 0, 5), check.plan_line("copper-cable", input, 1, 15) })
  check.info("assembler stamped at " .. serpent.line(rig.at(0.5, Y + 0.5)) .. " landed at " .. serpent.line(ghost.position))
end

local function written(surface)
  local t = target.from_entity(rig.ghost(surface, "stone-furnace", rig.at(10, Y)), rig.FORCE)
  local p = rig.priming(t, { recipe = "iron-plate", crafts = 12, fuel = "coal", fuel_count = 1 })
  local inventory = game.create_inventory(1)
  local stack = inventory[1]
  check.eq("blueprint.write ok", blueprint.write(stack, t, p), true)
  check.eq("blueprint.write label", stack.label, "[entity=stone-furnace] [item=iron-plate] x12")
  local icons = {}
  for _, icon in ipairs(stack.preview_icons or {}) do icons[icon.index] = icon.signal.name end
  check.same("blueprint.write icons machine then output", icons, { "stone-furnace", "iron-plate" })
  local entities = stack.get_blueprint_entities() or {}
  check.truthy("blueprint.write one entity", #entities == 1 and entities[1].name == "stone-furnace")
  inventory.destroy()
end

-- A vehicle's blueprint entity faces by orientation; direction is ignored.
local function vehicle(surface)
  local tank = rig.built(surface, "tank", rig.at(16, 36))
  tank.orientation = 0.25
  local t = target.from_entity(tank, rig.FORCE)
  local entity = blueprint.entity(t, rig.priming(t, { fuel = "coal", fuel_count = 5 }))
  check.same("blueprint.entity vehicle orientation", { entity.orientation, entity.direction }, { 0.25 })
  local ghost = stamp(surface, entity, rig.at(24, 36))
  check.near("blueprint vehicle ghost faces the same way", ghost and ghost.orientation, 0.25, 1e-3)
end

function cases.run(surface)
  check.run("blueprint.vehicle", function() vehicle(surface) end)
  check.run("blueprint.furnace", function() furnace(surface) end)
  check.run("blueprint.assembler", function() assembler(surface) end)
  check.run("blueprint.write", function() written(surface) end)
end

cases.stamp = stamp

return cases
