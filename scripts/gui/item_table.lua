-- Items mode's table (ADR-0013): a header line (Item | Slots | Items), one
-- line per row of the record, and a trailing empty chooser that adds a row,
-- in a scroll pane about eight lines tall. Each line's elements are named
-- from the row's stable id, so view.refresh can skip the one field being
-- typed into, and tagged with a handler every line shares (the picker's
-- pattern), which events dispatch on. A line is rebuilt only when its row's
-- identity changed (added, removed, another item); numbers are rewritten
-- in place.

local names = require("scripts.gui.names")
local items = require("scripts.gui.items")
local widgets = require("scripts.gui.widgets")

local item_table = {}

local SLOT = 40
local SPACING = 8
local LINE_SPACING = 4
local SLIDER_WIDTH = 120
local SLOTS_WIDTH = 56
local COUNT_WIDTH = 80
local MAX_LINES = 8
-- Chooser, slider, two fields and two buttons, and the gaps between them.
local LINE_WIDTH = SLOT + SLIDER_WIDTH + SLOTS_WIDTH + COUNT_WIDTH + 2 * widgets.BUTTON_WIDTH + 5 * SPACING

local function row_name(handler, id)
  return handler .. "_" .. id
end

local function line_flow(parent, spec)
  spec.type, spec.direction = "flow", "horizontal"
  local flow = parent.add(spec)
  flow.style.horizontal_spacing = SPACING
  flow.style.vertical_align = "center"
  return flow
end

-- As wide as a line, so the window keeps its width with no rows yet.
local function add_header(block)
  local header = line_flow(block, {})
  header.style.minimal_width = LINE_WIDTH
  local function column(key, width)
    header.add({ type = "label", style = "caption_label", caption = { "bp-primer." .. key } }).style.width = width
  end
  column("items-item", SLOT)
  column("items-slots", SLIDER_WIDTH + SPACING + SLOTS_WIDTH)
  column("items-count", COUNT_WIDTH)
end

local function chooser(parent, name, tooltip, tags)
  return parent.add({
    type = "choose-elem-button", name = name, elem_type = "item-with-quality",
    elem_filters = items.filters(), tooltip = tooltip, tags = tags,
  })
end

-- Hidden until the view shows items mode.
function item_table.build(parent)
  local block = parent.add({ type = "flow", name = names.items, direction = "vertical" })
  block.visible = false
  add_header(block)
  local scroll = block.add({ type = "scroll-pane", style = "naked_scroll_pane", horizontal_scroll_policy = "never" })
  scroll.style.maximal_height = MAX_LINES * (SLOT + LINE_SPACING)
  local list = scroll.add({ type = "flow", name = names.item_rows, direction = "vertical" })
  list.style.vertical_spacing = LINE_SPACING
  chooser(scroll, names.item_add, { "bp-primer.item-add-tooltip" })
end

-- The line carries its row's identity in its tags.
local function build_line(list, row, index)
  local id = row.id
  local line = line_flow(list, { index = index, tags = { row = id, name = row.name, quality = row.quality } })
  local function tags(handler) return { handler = handler, row = id } end
  chooser(line, row_name(names.row_item, id), { "bp-primer.item-tooltip" }, tags(names.row_item))
  local tip = { "bp-primer.item-slots-tooltip" }
  widgets.slider(line, row_name(names.row_slider, id), tip, tags(names.row_slider)).style.width = SLIDER_WIDTH
  widgets.number_field(line, row_name(names.row_slots, id), tip, tags(names.row_slots)).style.width = SLOTS_WIDTH
  widgets.number_field(line, row_name(names.row_count, id), { "bp-primer.item-count-tooltip" },
    tags(names.row_count)).style.width = COUNT_WIDTH
  widgets.button(line, row_name(names.row_half, id), "half", { "bp-primer.item-half-tooltip" }, tags(names.row_half))
  widgets.button(line, row_name(names.row_max, id), "max", { "bp-primer.item-max-tooltip" }, tags(names.row_max))
end

-- Destroys every line whose row is gone or holds another item, and any
-- line out of the record's order, so the survivors run in record order.
local function prune(list, p)
  local position = {}
  for index, row in ipairs(p.items) do position[row.id] = index end
  local last = 0
  for _, line in ipairs(list.children) do
    local index = position[line.tags.row]
    local row = index and p.items[index]
    if row and index > last and row.name == line.tags.name and row.quality == line.tags.quality then
      last = index
    else
      line.destroy()
    end
  end
end

-- Builds the missing lines, each at its row's place.
local function add_missing(list, p)
  local lines, next_line = list.children, 1
  for index, row in ipairs(p.items) do
    local line = lines[next_line]
    if line and line.tags.row == row.id then
      next_line = next_line + 1
    else
      build_line(list, row, index)
    end
  end
end

-- A refused pick is put back to the row's item here.
local function refresh_line(line, p, row, skip)
  local id, slots, cap = row.id, items.row_slots(row), items.row_cap(p, row.id)
  line[row_name(names.row_item, id)].elem_value = { name = row.name, quality = row.quality }
  widgets.set_slider(line[row_name(names.row_slider, id)], slots, items.slot_cap(p, id))
  widgets.set_text(line[row_name(names.row_slots, id)], slots, skip)
  widgets.set_text(line[row_name(names.row_count, id)], row.count, skip)
  line[row_name(names.row_half, id)].enabled = cap >= 2
  line[row_name(names.row_max, id)].enabled = cap >= 2
end

-- `found`: the window's elements by name. skip: the field being typed into.
-- After pruning and adding, line i shows row i.
function item_table.refresh(found, p, skip)
  local list = found[names.item_rows]
  if not (list and p.items) then return end
  found[names.item_add].elem_value = nil
  prune(list, p)
  add_missing(list, p)
  for index, line in ipairs(list.children) do
    refresh_line(line, p, p.items[index], skip)
  end
end

return item_table
