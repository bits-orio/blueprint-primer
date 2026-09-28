-- Resolve a world entity (ghost or built) into the one Target being primed,
-- a machine or a chest, and answer the questions the window asks about it.
-- The recipe questions live in target_recipe.lua and are re-exported here.

local const = require("scripts.const")
local target_recipe = require("scripts.target_recipe")
local feed = require("scripts.feed")

local target = {}

local REASON = const.REASON
local NORMAL = const.NORMAL_QUALITY

target.current_recipe = target_recipe.current
target.allows_recipe = target_recipe.allows
target.recipe_filters = target_recipe.filters
target.recipe_locked = target_recipe.locked
target.recipe_unlocked = target_recipe.unlocked
target.recipe_deliverable = target_recipe.deliverable
target.recipe_candidates = target_recipe.candidates

local function describe(entity)
  if entity.type == const.GHOST_TYPE then
    return { is_ghost = true, name = entity.ghost_name, prototype = entity.ghost_prototype }
  end
  return { is_ghost = false, name = entity.name, prototype = entity.prototype }
end

-- A crafter with nothing a robot could deliver for any of its recipes
-- (the captive biter spawner, or the recycler without Space Age) is still
-- worth fuelling if it burns fuel; otherwise the window has nothing to offer.
local function crafter_kind(prototype)
  if not const.CRAFTER_TYPES[prototype.type] then return nil, REASON.UNSUPPORTED end
  if target_recipe.any_primable(prototype) then
    return prototype.type == "furnace" and const.KIND_FURNACE or const.KIND_ASSEMBLER
  end
  if prototype.burner_prototype then return const.KIND_FUEL_ONLY end
  return nil, REASON.UNSUPPORTED
end

-- A plain, visible container with room (ADR-0012); the same rule
-- prototypes/tool_filters.lua applies at the data stage.
local function is_chest(prototype)
  if prototype.type ~= const.CHEST_TYPE or prototype.hidden then return false end
  if not const.CHEST_INVENTORY_TYPES[prototype.inventory_type or "with_bar"] then return false end
  return prototype.get_inventory_size(defines.inventory.chest, NORMAL) >= 1
end

-- Logistic chests hand their contents to the network, or trash what they
-- were not asked for, so a primed request would not stay put.
local function kind_of(prototype)
  if const.CRAFTING_MACHINE_TYPES[prototype.type] then return crafter_kind(prototype) end
  if is_chest(prototype) then return const.KIND_CHEST end
  if prototype.type == const.LOGISTIC_CHEST_TYPE then return nil, REASON.LOGISTIC_CHEST end
  if prototype.burner_prototype then return const.KIND_FUEL_ONLY end
  return nil, REASON.NOT_PRIMABLE
end

local function same_force(entity, force)
  if not force then return true end
  if type(force) == "string" then force = game.forces[force] end
  return force ~= nil and entity.force.index == force.index
end

-- Vehicles and rolling stock face a smooth orientation, not a direction;
-- the primed blueprint copies whichever the machine has.
local function place(t, entity)
  t.surface, t.position = entity.surface, entity.position
  if const.ORIENTED_TYPES[t.prototype.type] then
    t.orientation = entity.orientation
  else
    t.direction = entity.direction
  end
end

-- A burner crafter set to a recipe with nothing to deliver (a biochamber
-- cracking oil) needs only fuel, like a fuel-only prototype. Priming it as
-- a crafter would refuse it, or overwrite its recipe with one that has items.
local function settle_kind(t)
  if t.burner and t.kind ~= const.KIND_FUEL_ONLY and target_recipe.on_fluid_only(t) then
    t.kind = const.KIND_FUEL_ONLY
  end
end

-- The family of anything the window could open for, by prototype alone:
-- cheap enough to ask of every entity in a drag (ADR-0011). nil when the
-- entity cannot be primed at all.
function target.family(entity)
  if not entity.valid then return nil end
  local kind = kind_of(describe(entity).prototype)
  if not kind then return nil end
  return kind == const.KIND_CHEST and const.FAMILY_CHEST or const.FAMILY_MACHINE
end

-- A machine never means a chest: callers that count machines skip chests.
function target.is_machine(entity)
  return target.family(entity) == const.FAMILY_MACHINE
end

function target.from_entity(entity, force)
  if not (entity and entity.valid) then return nil, REASON.INVALID end
  if not same_force(entity, force) then return nil, REASON.OTHER_FORCE end
  local t = describe(entity)
  local kind, reason = kind_of(t.prototype)
  if not kind then return nil, reason end
  t.entity, t.kind = entity, kind
  t.quality = entity.quality.name
  t.burner = t.prototype.burner_prototype
  t.force = entity.force
  settle_kind(t)
  place(t, entity)
  return t
end

local function find_revived(t)
  if not (t.surface and t.surface.valid and t.force and t.force.valid) then return nil end
  return t.surface.find_entities_filtered {
    name = t.name, position = t.position, force = t.force, limit = 1,
  }[1]
end

-- Robots may revive a ghost while its window is open; the built machine that
-- replaced it is the same target as far as the player is concerned.
function target.revalidate(t)
  local entity = t.entity
  if entity and entity.valid then return true end
  if not t.is_ghost then return false end
  local built = find_revived(t)
  if not built then return false end
  t.entity, t.is_ghost = built, false
  return true
end

-- The inventory a Target's items go into: a chest's own, or a crafter's
-- input. The one answer for request, reopen, carried and copy.
function target.input_inventory(t)
  if t.kind == const.KIND_CHEST then return defines.inventory.chest end
  return defines.inventory.crafter_input
end

-- The recipe and quality every fed machine agrees on (ADR-0012): each fed
-- crafter whose current recipe the chest allows has a say; one that is
-- fuel-only or on no primable recipe has none. None, or a disagreement (one
-- chest feeding an iron and a copper furnace), gives nil.
function target.fed_recipe(t)
  local recipe, quality
  for _, machine in ipairs(feed.machines(t.entity)) do
    local m = target.from_entity(machine, t.force)
    local name, q = nil, nil
    if m and m.kind ~= const.KIND_FUEL_ONLY then name, q = target_recipe.current(m) end
    if name and target_recipe.allows(t, name) then
      q = q or NORMAL
      if recipe and (recipe ~= name or quality ~= q) then return nil end
      recipe, quality = name, q
    end
  end
  return recipe, quality
end

function target.inventory_count(t, inventory_define, item, quality)
  local entity = t.entity
  if t.is_ghost or not (entity and entity.valid) then return 0 end
  local inventory = entity.get_inventory(inventory_define)
  if not inventory then return 0 end
  return inventory.get_item_count({ name = item, quality = quality or NORMAL })
end

return target
