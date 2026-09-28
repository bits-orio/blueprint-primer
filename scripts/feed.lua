-- Fed machines (ADR-0012): the crafters an inserter takes a chest's items
-- into, built or ghost, of the chest's force. Geometry only: which recipe
-- they agree on is target.lua's question, since it needs target.from_entity
-- and target_recipe.lua must never require target.lua.
--
-- Positions come from the inserter itself: pickup_position and drop_position
-- are readable on built inserters and on ghosts from creation, while
-- pickup_target and drop_target stay nil on a ghost forever. Direction is
-- never used to guess them. Loaders are ignored.

local const = require("scripts.const")

local feed = {}

local INSERTER = "inserter"

-- The longest pickup or drop vector of any inserter, plus a tile for the
-- inserter's own body: how far outside a chest an inserter can stand and
-- still take from it. Memoised in a file-level local, a pure function of
-- the prototypes (multiplayer-safe).
local reach

local function length(vector)
  if not vector then return 0 end
  local x, y = vector.x or vector[1], vector.y or vector[2]
  return math.sqrt(x * x + y * y)
end

local function longest_reach()
  if reach then return reach end
  reach = 0
  for _, prototype in pairs(prototypes.get_entity_filtered({ { filter = "type", type = INSERTER } })) do
    reach = math.max(reach, length(prototype.inserter_pickup_position), length(prototype.inserter_drop_position))
  end
  reach = reach + 1
  return reach
end

local function inside(position, box)
  local x, y = position.x or position[1], position.y or position[2]
  local left_top, right_bottom = box.left_top or box[1], box.right_bottom or box[2]
  return x >= (left_top.x or left_top[1]) and x <= (right_bottom.x or right_bottom[1])
    and y >= (left_top.y or left_top[2]) and y <= (right_bottom.y or right_bottom[2])
end

local function grown(box, by)
  local left_top, right_bottom = box.left_top or box[1], box.right_bottom or box[2]
  return {
    { (left_top.x or left_top[1]) - by, (left_top.y or left_top[2]) - by },
    { (right_bottom.x or right_bottom[1]) + by, (right_bottom.y or right_bottom[2]) + by },
  }
end

-- Built inserters and inserter ghosts of the force around the chest.
local function inserters_near(chest)
  local surface, area, force = chest.surface, grown(chest.bounding_box, longest_reach()), chest.force
  local found = surface.find_entities_filtered({ area = area, type = INSERTER, force = force })
  for _, ghost in ipairs(surface.find_entities_filtered({
    area = area, type = const.GHOST_TYPE, ghost_type = INSERTER, force = force,
  })) do
    found[#found + 1] = ghost
  end
  return found
end

local function is_crafter(entity)
  if entity.type == const.GHOST_TYPE then return const.CRAFTER_TYPES[entity.ghost_type] == true end
  return const.CRAFTER_TYPES[entity.type] == true
end

-- The crafters (built or ghost) of the force at the inserter's drop position.
local function crafters_at(inserter, force, into)
  local found = inserter.surface.find_entities_filtered({ position = inserter.drop_position, force = force })
  for _, entity in ipairs(found) do
    if is_crafter(entity) and entity.unit_number and not into.seen[entity.unit_number] then
      into.seen[entity.unit_number] = true
      into.list[#into.list + 1] = entity
    end
  end
end

-- Every crafter an inserter takes this chest's items into, each once.
function feed.machines(chest)
  if not (chest and chest.valid) then return {} end
  local box, fed = chest.bounding_box, { list = {}, seen = {} }
  for _, inserter in ipairs(inserters_near(chest)) do
    if inside(inserter.pickup_position, box) then crafters_at(inserter, chest.force, fed) end
  end
  return fed.list
end

return feed
