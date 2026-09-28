-- Handlers for a chest window's own controls: the mode switch and items
-- mode's lines (ADR-0013). events.lua merges these tables into its own, by
-- event kind, and dispatches as for every other control. Each line's
-- elements share one handler, named in their tags beside the row id.

local const = require("scripts.const")
local names = require("scripts.gui.names")
local items = require("scripts.gui.items")
local picker = require("scripts.gui.picker")
local priming = require("scripts.gui.priming")
local window = require("scripts.gui.window")
local view = require("scripts.gui.view")

local function row_of(element)
  return element.tags.row
end

-- Left is Recipe, right is Items. The picker belongs to recipe mode.
local function on_switch(player, p, element)
  local mode = element.switch_state == "right" and const.MODE_ITEMS or const.MODE_RECIPE
  if mode == const.MODE_ITEMS then
    local container = view.find(player, names.picker)
    if container then picker.close(container) end
  end
  priming.set_mode(p, mode)
end

local function say(player, ok, notice)
  if not ok and notice then window.notify(player, notice) end
end

-- The trailing chooser: a pick adds a row; the refresh empties it again.
local function on_add(player, p, element)
  local item = element.elem_value
  if item then say(player, items.add(p, item.name, item.quality)) end
end

-- Cleared removes the row. A refused pick is put back by the refresh.
local function on_row_item(player, p, element)
  local item = element.elem_value
  say(player, items.set_item(p, row_of(element), item and item.name, item and item.quality))
end

-- Only a move to other slots changes the count, so a slider echoing the
-- position the view wrote keeps an exact count typed in the items field.
local function on_row_slider(_, p, element)
  local row = items.row(p, row_of(element))
  local slots = math.floor(element.slider_value + 0.5)
  if row and slots ~= items.row_slots(row) then items.set_slots(p, row.id, slots) end
end

-- An empty or partial field changes nothing, as for the output field.
local function number_handler(set)
  return function(_, p, element)
    local number = tonumber(element.text)
    if number then set(p, row_of(element), number) end
  end
end

return {
  click = {
    [names.row_half] = function(_, p, element) items.half(p, row_of(element)) end,
    [names.row_max] = function(_, p, element) items.max(p, row_of(element)) end,
  },
  slider = { [names.row_slider] = on_row_slider },
  text = {
    [names.row_slots] = number_handler(items.set_slots),
    [names.row_count] = number_handler(items.set_count),
  },
  elem = {
    [names.item_add] = on_add,
    [names.row_item] = on_row_item,
  },
  switch = { [names.mode] = on_switch },
}
