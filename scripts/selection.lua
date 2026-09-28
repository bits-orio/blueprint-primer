-- Resolve a click or drag into the machines or chests to prime (ADR-0011):
-- the one nearest the middle, of either family, picks the kind, and every
-- selected entity of that same prototype and kind joins its group. Other
-- kinds of its family are skipped, because their numbers differ; the other
-- family is ignored silently (a drag over a furnace row that clips its
-- output chests primes the furnaces).

local const = require("scripts.const")
local target = require("scripts.target")

local selection = {}

-- BoundingBox and MapPosition arrive either keyed or positional.
local function xy(position)
  return position.x or position[1], position.y or position[2]
end

local function centre(area)
  local x1, y1 = xy(area.left_top or area[1])
  local x2, y2 = xy(area.right_bottom or area[2])
  return (x1 + x2) / 2, (y1 + y2) / 2
end

local function distance_sq(entity, cx, cy)
  local x, y = xy(entity.position)
  return (x - cx) ^ 2 + (y - cy) ^ 2
end

-- Nearest the drag's centre picks the kind, machine or chest.
-- target.from_entity only runs on entities closer than the best so far, so
-- a drag across a whole base stays cheap. Returns the target, or the reason
-- the nearest entity failed.
local function nearest(entities, cx, cy, force)
  local best, best_distance, reason, reason_distance
  for _, entity in pairs(entities) do
    local distance = entity.valid and distance_sq(entity, cx, cy)
    if distance and (not best_distance or distance < best_distance) then
      local t, why = target.from_entity(entity, force)
      if t then
        best, best_distance = t, distance
      elseif not reason_distance or distance < reason_distance then
        reason, reason_distance = why, distance
      end
    end
  end
  return best, reason
end

local function inner_name(entity)
  return entity.type == "entity-ghost" and entity.ghost_name or entity.name
end

-- Same prototype is not quite enough: the kind is per entity (a biochamber
-- cracking oil is fuel-only), so it must match too. A chest of another
-- quality is not a member either, because quality changes its slot count
-- (chest cap, row caps); it goes to skipped instead. Machines keep grouping
-- across qualities.
local function member(entity, primary, force)
  if entity == primary.entity then return primary end
  if inner_name(entity) ~= primary.name then return nil end
  local t = target.from_entity(entity, force)
  if not (t and t.kind == primary.kind) then return nil end
  if t.kind == const.KIND_CHEST and t.quality ~= primary.quality then return nil end
  return t
end

-- { primary, group = { Target... }, skipped = { LuaEntity... } }, or nil and
-- the reason the nearest entity cannot be primed. The primary comes first;
-- skipped holds only other kinds of the primary's family.
function selection.resolve(entities, area, force)
  local cx, cy = centre(area)
  local primary, reason = nearest(entities, cx, cy, force)
  if not primary then return nil, reason end
  local family = target.family(primary.entity)
  local group, skipped = { primary }, {}
  for _, entity in pairs(entities) do
    if entity.valid and entity ~= primary.entity then
      local t = member(entity, primary, force)
      if t then
        group[#group + 1] = t
      elseif target.family(entity) == family then
        skipped[#skipped + 1] = entity
      end
    end
  end
  return { primary = primary, group = group, skipped = skipped }
end

return selection
