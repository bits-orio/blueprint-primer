-- Resolve a click or drag into the machines to prime (ADR-0011): the one
-- nearest the middle picks the kind, and every selected machine of that
-- same prototype and kind joins its group. Other machines are skipped,
-- because their fuel use, and so their numbers, differ.

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

-- Nearest the drag's centre picks the kind. target.from_entity only runs on
-- entities closer than the best so far, so a drag across a whole base stays
-- cheap. Returns the target, or the reason the nearest entity failed.
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
-- cracking oil is fuel-only), so it must match too.
local function member(entity, primary, force)
  if entity == primary.entity then return primary end
  if inner_name(entity) ~= primary.name then return nil end
  local t = target.from_entity(entity, force)
  return t and t.kind == primary.kind and t or nil
end

-- { primary, group = { Target... }, skipped = { LuaEntity... } }, or nil and
-- the reason the nearest entity cannot be primed. The primary comes first.
function selection.resolve(entities, area, force)
  local cx, cy = centre(area)
  local primary, reason = nearest(entities, cx, cy, force)
  if not primary then return nil, reason end
  local group, skipped = { primary }, {}
  for _, entity in pairs(entities) do
    if entity.valid and entity ~= primary.entity then
      local t = member(entity, primary, force)
      if t then
        group[#group + 1] = t
      elseif target.is_machine(entity) then
        skipped[#skipped + 1] = entity
      end
    end
  end
  return { primary = primary, group = group, skipped = skipped }
end

return selection
