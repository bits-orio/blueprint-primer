-- Resolve a world entity (ghost or built) into the one Target being primed,
-- and answer the questions the window asks about it. The recipe questions
-- live in target_recipe.lua and are re-exported here.

local const = require("scripts.const")
local target_recipe = require("scripts.target_recipe")

local target = {}

local REASON = const.REASON
local NORMAL = const.NORMAL_QUALITY

target.current_recipe = target_recipe.current
target.allows_recipe = target_recipe.allows
target.recipe_filters = target_recipe.filters
target.recipe_locked = target_recipe.locked

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

local function kind_of(prototype)
  if const.CRAFTING_MACHINE_TYPES[prototype.type] then return crafter_kind(prototype) end
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

function target.inventory_count(t, inventory_define, item, quality)
  local entity = t.entity
  if t.is_ghost or not (entity and entity.valid) then return 0 end
  local inventory = entity.get_inventory(inventory_define)
  if not inventory then return 0 end
  return inventory.get_item_count({ name = item, quality = quality or NORMAL })
end

return target
