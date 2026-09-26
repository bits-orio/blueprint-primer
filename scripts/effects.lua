-- A Target's module and beacon effects on its energy draw and crafting
-- speed, as the factors fuel.lua scales its estimate by: a built machine's
-- live bonuses, adjusted for the module swap its request is waiting on.

local const = require("scripts.const")
local pending = require("scripts.pending")

local effects = {}

local NORMAL = const.NORMAL_QUALITY

local function built_entity(t)
  local entity = t.entity
  if t.is_ghost or not (entity and entity.valid) then return nil end
  return entity
end

-- One requested module's effect at a quality; 0 for anything not a module.
local function module_effect(item, effect, quality)
  local prototype = prototypes.item[item.name]
  if not (prototype and prototype.type == "module") then return 0 end
  local values = prototype.get_module_effects(quality)
  return (values and values[effect] or 0) * item.count
end

-- Modules robots have not delivered yet (the ghost's plan or the built
-- machine's proxy) change the draw the moment they land. Each counts at
-- normal quality: quality strengthens a module's bonus and never its
-- penalty, so this can only over-estimate the fuel. Modules a proxy will
-- take out are still in the live bonus at their own quality, so they come
-- off at that quality, and a clamped live bonus only makes the result
-- higher. Inventory ids are per entity type, so only crafters are read.
local function pending_effect(t, effect)
  if t.kind == const.KIND_FUEL_ONLY then return 0 end
  local total, modules = 0, defines.inventory.crafter_modules
  for _, item in ipairs(pending.items_in(pending.plans(t), modules)) do
    total = total + module_effect(item, effect, NORMAL)
  end
  for _, item in ipairs(pending.items_in(pending.removals(t), modules)) do
    total = total - module_effect(item, effect, item.quality)
  end
  return total
end

-- Energy draw relative to the base figure, never below the engine's floor.
function effects.consumption_factor(t)
  local entity = built_entity(t)
  local live = entity and entity.consumption_bonus or 0
  return math.max(const.MIN_CONSUMPTION_FACTOR, 1 + live + pending_effect(t, "consumption"))
end

-- Crafting speed relative to the machine's own (quality-scaled) speed.
function effects.speed_factor(t)
  local entity = built_entity(t)
  local live = entity and entity.speed_bonus or 0
  return math.max(const.MIN_SPEED_FACTOR, 1 + live + pending_effect(t, "speed"))
end

return effects
