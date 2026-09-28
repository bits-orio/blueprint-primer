-- Chests as Targets (ADR-0012): which containers are chests, the families a
-- drag keeps apart, a chest's recipe questions, and its fed machines.
-- Everything stands on the chest floor, far from any robot.

local check = require("lib.check")
local rig = require("lib.rig")
local target = require("__BlueprintPrimer__/scripts/target")
local selection = require("__BlueprintPrimer__/scripts/selection")
local placement = require("__BlueprintPrimer__/scripts/placement")
local priming = require("__BlueprintPrimer__/scripts/gui/priming")

local cases = {}

local at = rig.chest_at
local PLAYER = 9
local WEST, EAST = defines.direction.west, defines.direction.east

local function chest_target(surface, make, name, position, opts)
  return assert(target.from_entity(make(surface, name, position, opts), rig.FORCE))
end

local function resolve(surface)
  for i, name in ipairs({ "wooden-chest", "iron-chest", "steel-chest" }) do
    local g = target.from_entity(rig.ghost(surface, name, at(-40.5 + 4 * i, -44.5)), rig.FORCE)
    local b = target.from_entity(rig.built(surface, name, at(-40.5 + 4 * i, -42.5)), rig.FORCE)
    check.truthy("chest resolve " .. name .. " ghost and built",
      g and b and g.kind == "chest" and b.kind == "chest" and g.is_ghost and not b.is_ghost and g.burner == nil,
      serpent.line({ g and g.kind, b and b.kind }))
  end
  local _, why = target.from_entity(rig.built(surface, "requester-chest", at(-24.5, -44.5)), rig.FORCE)
  check.eq("chest resolve refuses a requester chest", why, "bp-primer.logistic-chest")
  _, why = target.from_entity(rig.ghost(surface, "passive-provider-chest", at(-22.5, -44.5)), rig.FORCE)
  check.eq("chest resolve refuses a passive provider ghost", why, "bp-primer.logistic-chest")
  local slots = {}
  for i, name in ipairs({ "wooden-chest", "iron-chest", "steel-chest" }) do
    slots[i] = placement.slots(chest_target(surface, rig.ghost, name, at(-18.5 + 2 * i, -44.5)))
  end
  check.same("chest slots wooden, iron, steel", slots, { 16, 32, 48 })
end

local function quality_slots(surface)
  if not script.active_mods["quality"] then return end
  local t = chest_target(surface, rig.ghost, "iron-chest", at(-8.5, -44.5), { quality = "legendary" })
  local built = rig.built(surface, "iron-chest", at(-6.5, -44.5), { quality = "legendary" })
  check.same("chest legendary iron chest slots, ghost and built",
    { placement.slots(t), #built.get_inventory(defines.inventory.chest) }, { 80, 80 })
end

local function families(surface)
  local machine = rig.built(surface, "stone-furnace", at(0, -44))
  local chest = rig.built(surface, "wooden-chest", at(2.5, -44.5))
  local logistic = rig.built(surface, "requester-chest", at(4.5, -44.5))
  check.same("chest families: machine, chest, none",
    { target.family(machine), target.family(chest), target.family(logistic) == nil, target.is_machine(chest) },
    { "machine", "chest", true, false })
end

local function inner(entity)
  return entity.type == "entity-ghost" and entity.ghost_name or entity.name
end

-- Inner names of Targets or entities, sorted.
local function names(list)
  local out = {}
  for i, entry in ipairs(list) do out[i] = inner(type(entry) == "table" and entry.entity or entry) end
  table.sort(out)
  return out
end

-- Two stone furnace ghosts, two wooden chests, an iron chest, then a steel
-- furnace ghost. The narrow drag stops before the iron chest.
local function drag_row(surface)
  local y = -34
  rig.ghost(surface, "stone-furnace", at(-40, y))
  rig.ghost(surface, "stone-furnace", at(-37, y))
  rig.built(surface, "wooden-chest", at(-34.5, y - 0.5))
  rig.ghost(surface, "wooden-chest", at(-33.5, y - 0.5))
  rig.built(surface, "iron-chest", at(-31.5, y - 0.5))
  rig.ghost(surface, "steel-furnace", at(-29, y))
  local function within(right) return surface.find_entities_filtered({ area = { at(-42, y - 2), at(right, y + 2) } }) end
  return within(-32.5), within(-27)
end

local function drags(surface)
  local narrow, wide = drag_row(surface)
  local on_furnace, on_chest = { at(-41, -35), at(-39, -33) }, { at(-35, -35), at(-34, -34) }
  local picked = assert(selection.resolve(narrow, on_furnace, rig.FORCE))
  check.same("chest drag centred on a furnace: furnaces grouped, chests neither grouped nor skipped",
    { names(picked.group), names(picked.skipped) }, { { "stone-furnace", "stone-furnace" }, {} })
  picked = assert(selection.resolve(wide, on_furnace, rig.FORCE))
  check.same("chest drag centred on a furnace skips only the other furnace",
    { names(picked.group), names(picked.skipped) }, { { "stone-furnace", "stone-furnace" }, { "steel-furnace" } })
  picked = assert(selection.resolve(wide, on_chest, rig.FORCE))
  check.same("chest drag centred on a chest: chests grouped, the other chest kind skipped, furnaces ignored",
    { names(picked.group), names(picked.skipped) }, { { "wooden-chest", "wooden-chest" }, { "iron-chest" } })
end

local function index_of(list, name)
  for i, entry in ipairs(list) do
    if entry == name then return i end
  end
end

local function recipe_questions(surface)
  local ghost = chest_target(surface, rig.ghost, "wooden-chest", at(-40.5, -28.5))
  local built = chest_target(surface, rig.built, "wooden-chest", at(-38.5, -28.5))
  check.same("chest allows a furnace and an assembler recipe, not a fluid-only one",
    { target.allows_recipe(ghost, "iron-plate"), target.allows_recipe(ghost, "electronic-circuit"),
      target.allows_recipe(ghost, "lubricant") }, { true, true, false })
  local list = target.recipe_candidates(ghost)
  check.truthy("chest candidates hold furnace and assembler recipes, no fluid-only one",
    index_of(list, "iron-plate") and index_of(list, "electronic-circuit") and not index_of(list, "lubricant"))
  check.eq("chest candidates are memoised", target.recipe_candidates(built), list)
  for _, t in ipairs({ ghost, built }) do
    local ok, err = pcall(function()
      return target.current_recipe(t), target.recipe_filters(t), target.recipe_locked(t),
        target.recipe_unlocked(t, "iron-plate"), target.recipe_deliverable(t, "iron-plate")
    end)
    check.truthy("chest recipe questions do not error (" .. (t.is_ghost and "ghost" or "built") .. ")", ok, err)
  end
  check.same("chest: no current recipe, never locked, always deliverable",
    { target.current_recipe(built) == nil, target.recipe_locked(built), target.recipe_deliverable(built, "steel-plate") },
    { true, false, true })
end

-- chest -> inserter (facing west: picks up west, drops east) -> assembler.
local function chain(surface, make, x, y, recipe, inserter)
  local chest = chest_target(surface, make, "wooden-chest", at(x, y))
  local gap = inserter == "long-handed-inserter" and 2 or 1
  make(surface, inserter or "inserter", at(x + gap, y), { direction = WEST })
  make(surface, "assembling-machine-2", at(x + gap + 2, y), { recipe = recipe })
  return chest
end

local function fed_recipe(t)
  return { target.fed_recipe(t) }
end

local function fed_machines(surface)
  local ghost = chain(surface, rig.ghost, -40.5, -22.5, "iron-gear-wheel")
  check.same("chest fed recipe: ghost chest, ghost inserter, ghost assembler", fed_recipe(ghost), { "iron-gear-wheel", "normal" })
  local p = priming.new(ghost, PLAYER)
  check.same("chest opens in recipe mode on its fed recipe, at half the chest cap",
    { p.mode, p.recipe, p.crafts, priming.cap(p) }, { "recipe", "iron-gear-wheel", 400, 800 })
  local built = chain(surface, rig.built, -30.5, -22.5, "copper-cable")
  check.same("chest fed recipe: all built", fed_recipe(built), { "copper-cable", "normal" })
  local long = chain(surface, rig.ghost, -20.5, -22.5, "electronic-circuit", "long-handed-inserter")
  check.same("chest fed recipe: long-handed inserter", fed_recipe(long), { "electronic-circuit", "normal" })
  local into = chest_target(surface, rig.ghost, "wooden-chest", at(-8.5, -22.5))
  rig.ghost(surface, "inserter", at(-7.5, -22.5), { direction = EAST })
  rig.ghost(surface, "assembling-machine-2", at(-5.5, -22.5), { recipe = "iron-gear-wheel" })
  check.same("chest fed recipe ignores an inserter dropping into the chest", fed_recipe(into), {})
  check.eq("chest with no fed recipe opens in items mode", priming.new(into, PLAYER).mode, "items")
end

-- One chest between two assemblers, each fed by its own inserter.
local function two_fed(surface, x, left, right)
  local chest = chain(surface, rig.ghost, x, -14.5, right)
  rig.ghost(surface, "inserter", at(x - 1, -14.5), { direction = EAST })
  rig.ghost(surface, "assembling-machine-2", at(x - 3, -14.5), { recipe = left })
  return chest
end

local function fed_disagree(surface)
  check.same("chest fed by two machines on different recipes has none",
    fed_recipe(two_fed(surface, -30.5, "copper-cable", "iron-gear-wheel")), {})
  check.same("chest fed by two machines on one recipe has it",
    fed_recipe(two_fed(surface, -12.5, "iron-gear-wheel", "iron-gear-wheel")), { "iron-gear-wheel", "normal" })
end

function cases.run(surface)
  check.run("chest.resolve", function() resolve(surface) end)
  check.run("chest.quality_slots", function() quality_slots(surface) end)
  check.run("chest.families", function() families(surface) end)
  check.run("chest.drags", function() drags(surface) end)
  check.run("chest.recipe_questions", function() recipe_questions(surface) end)
  check.run("chest.fed_machines", function() fed_machines(surface) end)
  check.run("chest.fed_disagree", function() fed_disagree(surface) end)
end

cases.chain = chain

return cases
