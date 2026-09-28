-- Placement (ADR-0012): how a chest's want list becomes insert-plan
-- positions in its inventory, and the chest cap recipe mode is limited by.
-- One core for both modes, for Request, the primed blueprint, copies and
-- group totals, so what the window promises is what gets requested.
--
-- Engine facts it stands on (measured on 2.0.77 and 2.1.17): a position into
-- a slot holding another item is silently dropped, a position over a stack
-- is cut to a stack, a partial stack of the same item tops up, and the bar
-- does not stop a slot-targeted delivery. So one occupancy map runs across
-- the whole want list, and no position asks for more than one stack.

local const = require("scripts.const")
local craft = require("scripts.craft")

local placement = {}

local NORMAL = const.NORMAL_QUALITY

-- Slots of a fresh chest of this prototype and quality.
function placement.slots(t)
  return t.prototype.get_inventory_size(defines.inventory.chest, t.quality)
end

function placement.stack(name)
  local prototype = prototypes.item[name]
  return prototype and prototype.stack_size or 1
end

local function recipe_wants(recipe, quality, crafts)
  local wants = {}
  for _, ingredient in ipairs(craft.ingredients(recipe)) do
    if ingredient.type == "item" and ingredient.amount > 0 then
      wants[#wants + 1] = { name = ingredient.name, quality = quality, count = math.ceil(crafts * ingredient.amount) }
    end
  end
  return wants
end

-- The total item counts a chest Priming asks for, `{ name, quality, count }`
-- in order: one per item ingredient in recipe mode, the rows with anything
-- to bring in items mode. Only the active mode counts.
function placement.wants(p)
  if p.mode == const.MODE_ITEMS then
    local wants = {}
    for _, row in ipairs(p.items or {}) do
      if row.count >= 1 then wants[#wants + 1] = { name = row.name, quality = row.quality, count = row.count } end
    end
    return wants
  end
  if not (p.recipe and (p.crafts or 0) > 0) then return {} end
  return recipe_wants(p.recipe, p.quality or NORMAL, p.crafts)
end

-- Whole stacks the wants fill in a fresh chest.
function placement.slots_needed(wants)
  local slots = 0
  for _, want in ipairs(wants) do slots = slots + math.ceil(want.count / placement.stack(want.name)) end
  return slots
end

-- The largest craft count whose item ingredients, each packed into whole
-- stacks, fit a fresh chest: sum of ceil(ceil(N * amount) / stack) <= slots.
-- Every term grows with N, so a binary search agrees with the placement.
-- 0 when the recipe has no item ingredient.
function placement.cap(t, recipe)
  local slots, high = placement.slots(t), nil
  for _, want in ipairs(recipe_wants(recipe, NORMAL, 1)) do
    local alone = math.floor(slots * placement.stack(want.name) / want.count)
    high = math.min(high or alone, alone)
  end
  if not high then return 0 end
  local low = 0
  while low < high do
    local mid = math.ceil((low + high) / 2)
    if placement.slots_needed(recipe_wants(recipe, NORMAL, mid)) <= slots then low = mid else high = mid - 1 end
  end
  return low
end

local function position(list, want, stack, count)
  list[#list + 1] = {
    name = want.name, quality = want.quality or NORMAL,
    position = { inventory = defines.inventory.chest, stack = stack, count = count },
  }
end

-- A fresh chest fills from its last slot down, each item's stacks together:
-- the engine and players fill from slot 0 up, so items inserted before the
-- robots arrive (or a built chest a primed blueprint is stamped over) meet
-- these positions last.
local function fresh(t, wants)
  local list, short, slot = {}, 0, placement.slots(t) - 1
  for _, want in ipairs(wants) do
    local left, size = want.count, placement.stack(want.name)
    while left > 0 and slot >= 0 do
      local count = math.min(left, size)
      position(list, want, slot, count)
      left, slot = left - count, slot - 1
    end
    short = short + left
  end
  return list, short
end

local function same(stack, want)
  return stack.valid_for_read and stack.name == want.name and stack.quality.name == (want.quality or NORMAL)
end

-- Tops up partial stacks of this item and quality, anywhere in the chest.
local function top_partial(inventory, want, left, list)
  local size = placement.stack(want.name)
  for index = 1, #inventory do
    if left <= 0 then break end
    local stack = inventory[index]
    if same(stack, want) and stack.count < size then
      local count = math.min(left, size - stack.count)
      position(list, want, index - 1, count)
      left = left - count
    end
  end
  return left
end

-- Then takes empty slots from the highest down. `taken` holds the empty
-- slots earlier wants claimed; slots holding anything else are unavailable.
local function take_empty(inventory, want, left, list, taken)
  local size = placement.stack(want.name)
  for index = #inventory, 1, -1 do
    if left <= 0 then break end
    if not taken[index] and not inventory[index].valid_for_read then
      local count = math.min(left, size)
      position(list, want, index - 1, count)
      taken[index], left = true, left - count
    end
  end
  return left
end

-- A built chest's top-up: each want minus what it already holds at that
-- quality, never below 0.
local function top_up(inventory, wants)
  local list, short, taken = {}, 0, {}
  for _, want in ipairs(wants) do
    local held = inventory.get_item_count({ name = want.name, quality = want.quality or NORMAL })
    local left = math.max(0, want.count - held)
    left = take_empty(inventory, want, top_partial(inventory, want, left, list), list, taken)
    short = short + left
  end
  return list, short
end

-- `{ name, quality, position }` entries (merge them into one plan per item
-- and quality) and the items that found no room. A top-up on a built chest
-- subtracts what it holds and works around it; anything else (a ghost, a
-- primed blueprint, a copy) is placed as into a fresh chest.
function placement.place(t, wants, is_top_up)
  local entity = t.entity
  if is_top_up and not t.is_ghost and entity and entity.valid then
    local inventory = entity.get_inventory(defines.inventory.chest)
    if inventory then return top_up(inventory, wants) end
  end
  return fresh(t, wants)
end

return placement
