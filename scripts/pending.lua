-- The request already waiting on a target: a ghost's own insert_plan, or
-- the plan of the item-request-proxy on a built machine. Read back to find
-- a furnace's intended recipe, to preset a reopened window, and to count
-- modules robots have yet to deliver or take out.

local const = require("scripts.const")

local pending = {}

local NORMAL = const.NORMAL_QUALITY

function pending.plans(t)
  local entity = t.entity
  if not (entity and entity.valid) then return {} end
  if t.is_ghost then return entity.insert_plan end
  local proxy = entity.item_request_proxy
  return proxy and proxy.valid and proxy.insert_plan or {}
end

-- What a built machine's proxy will take out, such as the old modules of a
-- module swap. A ghost holds nothing to remove.
function pending.removals(t)
  local entity = t.entity
  if t.is_ghost or not (entity and entity.valid) then return {} end
  local proxy = entity.item_request_proxy
  return proxy and proxy.valid and proxy.removal_plan or {}
end

local function counted(plan, inventory)
  local total = 0
  for _, position in ipairs(plan.items.in_inventory or {}) do
    if position.inventory == inventory then total = total + (position.count or 1) end
  end
  return total
end

-- Items of one name and quality requested into one inventory, all stacks.
function pending.count(plans, inventory, name, quality)
  local total = 0
  for _, plan in ipairs(plans) do
    if plan.id.name == name and (plan.id.quality or NORMAL) == (quality or NORMAL) then
      total = total + counted(plan, inventory)
    end
  end
  return total
end

-- The plans cut down to their positions in one inventory, leaving out any
-- plan with none there: what a copy carries from a proxy (copy.lua).
function pending.within(plans, inventory)
  local list = {}
  for _, plan in ipairs(plans) do
    local positions = {}
    for _, position in ipairs(plan.items.in_inventory or {}) do
      if position.inventory == inventory then positions[#positions + 1] = position end
    end
    if #positions > 0 then list[#list + 1] = { id = plan.id, items = { in_inventory = positions } } end
  end
  return list
end

-- Every item requested into one inventory, in plan order, as
-- `{ name, quality, count }`.
function pending.items_in(plans, inventory)
  local list = {}
  for _, plan in ipairs(plans) do
    local count = counted(plan, inventory)
    if count > 0 then
      list[#list + 1] = { name = plan.id.name, quality = plan.id.quality or NORMAL, count = count }
    end
  end
  return list
end

return pending
