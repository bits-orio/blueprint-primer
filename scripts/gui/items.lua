-- Items mode's rows (ADR-0013): a chest Priming's list of `{ id, name,
-- quality, count }`, where count is the only stored amount, an exact item
-- count for a fresh chest. Pure state like priming.lua: the four ways to set
-- a row (Half, Max, slots, items) and the row cap they all respect. Rows are
-- addressed by id, a per-Priming increasing integer, never by position.

local const = require("scripts.const")
local placement = require("scripts.placement")

local items = {}

local NORMAL = const.NORMAL_QUALITY
local stack = placement.stack

local function clamp(n, low, high)
  return math.max(low, math.min(high, n))
end

-- Whole stacks a row fills: also where its slots slider sits.
function items.row_slots(row)
  return math.ceil(row.count / stack(row.name))
end

function items.row(p, id)
  for index, row in ipairs(p.items) do
    if row.id == id then return row, index end
  end
  return nil
end

-- Slots the rows fill, leaving out the row `except` (an id) when given.
function items.slots_used(p, except)
  local used = 0
  for _, row in ipairs(p.items) do
    if row.id ~= except then used = used + items.row_slots(row) end
  end
  return used
end

-- Whole slots left for row `id` (or for a new row when nil) beside the others.
function items.slot_cap(p, id)
  return math.max(0, placement.slots(p.target) - items.slots_used(p, id))
end

-- The most of `name` a row may hold: the slots the other rows leave, full.
local function cap_for(p, name, id)
  return items.slot_cap(p, id) * stack(name)
end

function items.row_cap(p, id)
  local row = items.row(p, id)
  return row and cap_for(p, row.name, id) or 0
end

-- Half the chest (Half + Half on two items splits it evenly; Half then Max
-- fills it), within the row cap, never below one item.
local function half_of(p, name, id)
  local half = math.floor(placement.slots(p.target) / 2) * stack(name)
  return math.max(1, math.min(cap_for(p, name, id), half))
end

local function listed(p, name, quality, except)
  for _, row in ipairs(p.items) do
    if row.id ~= except and row.name == name and row.quality == quality then return true end
  end
  return false
end

local function new_row(p, name, quality, count)
  local row = { id = p.next_row_id, name = name, quality = quality or NORMAL, count = count }
  p.next_row_id = p.next_row_id + 1
  p.items[#p.items + 1] = row
  return row
end

-- The trailing empty chooser's pick: a new row at Half. `true` or `false,
-- notice` (already listed, or no room left).
function items.add(p, name, quality)
  quality = quality or NORMAL
  if not (name and prototypes.item[name]) then return false end
  if listed(p, name, quality) then return false, const.NOTICE.ITEM_LISTED end
  if cap_for(p, name) < 1 then return false, const.NOTICE.CHEST_NO_ROOM end
  new_row(p, name, quality, half_of(p, name))
  return true
end

function items.remove(p, id)
  local _, index = items.row(p, id)
  if index then table.remove(p.items, index) end
end

-- A row's chooser changed: cleared removes the row; another item keeps the
-- row's slots, within the new row cap.
function items.set_item(p, id, name, quality)
  local row = items.row(p, id)
  if not row then return false end
  if not name then
    items.remove(p, id)
    return true
  end
  quality = quality or NORMAL
  if not prototypes.item[name] then return false end
  if row.name == name and row.quality == quality then return true end
  if listed(p, name, quality, id) then return false, const.NOTICE.ITEM_LISTED end
  local slots = items.row_slots(row)
  row.name, row.quality = name, quality
  row.count = math.max(1, math.min(slots * stack(name), cap_for(p, name, id)))
  return true
end

-- The items field: an exact count, 1 .. row cap.
function items.set_count(p, id, count)
  local row = items.row(p, id)
  if not row then return end
  row.count = clamp(math.floor(count), 1, math.max(1, cap_for(p, row.name, id)))
end

-- The slots slider and field: whole stacks, within the row cap.
function items.set_slots(p, id, slots)
  local row = items.row(p, id)
  if row then items.set_count(p, id, math.floor(slots) * stack(row.name)) end
end

function items.half(p, id)
  local row = items.row(p, id)
  if row then row.count = half_of(p, row.name, id) end
end

function items.max(p, id)
  local row = items.row(p, id)
  if row then items.set_count(p, id, cap_for(p, row.name, id)) end
end

-- Fits the rows to this chest in row order, earlier rows first: each keeps
-- what the rows before it leave room for, and a row left with nothing is
-- dropped. How a copy onto a smaller chest keeps what fits.
function items.fit(p)
  local slots, used, kept = placement.slots(p.target), 0, {}
  for _, row in ipairs(p.items) do
    row.count = math.min(math.floor(row.count), (slots - used) * stack(row.name))
    if row.count >= 1 then
      kept[#kept + 1] = row
      used = used + items.row_slots(row)
    end
  end
  p.items = kept
end

-- Replaces the rows with `list` (a want list, or another Priming's rows),
-- copied under fresh ids.
function items.fill(p, list)
  p.items, p.next_row_id = {}, 1
  for _, entry in ipairs(list or {}) do new_row(p, entry.name, entry.quality, entry.count) end
end

-- Items mode needs something to bring.
function items.blocker(p)
  for _, row in ipairs(p.items) do
    if row.count >= 1 then return nil end
  end
  return const.REASON.NO_ITEMS
end

-- Item types robots cannot deliver exactly: planners and remotes fetch any
-- copy, items with an inventory, label or tags whichever one they find.
local UNDELIVERABLE_TYPES = {
  "blueprint", "blueprint-book", "deconstruction-item", "upgrade-item", "copy-paste-tool",
  "selection-tool", "item-with-inventory", "item-with-label", "item-with-tags", "spidertron-remote",
}

-- elem_filters for the rows' `item-with-quality` choosers.
function items.filters()
  return {
    { filter = "hidden", invert = true, mode = "and" },
    { filter = "is-parameter", invert = true, mode = "and" },
    { filter = "flag", flag = "only-in-cursor", invert = true, mode = "and" },
    { filter = "flag", flag = "spawnable", invert = true, mode = "and" },
    { filter = "type", type = UNDELIVERABLE_TYPES, invert = true, mode = "and" },
  }
end

return items
