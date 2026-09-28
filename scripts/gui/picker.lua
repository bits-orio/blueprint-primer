-- The recipe picker (ADR-0009). The engine's choose-elem picker cannot mark
-- individual recipes, so the recipe slot opens this one instead: the
-- machine's candidate recipes grouped by item group, like vanilla's, each a
-- slot button that is red when the force has not researched it yet. Built
-- only while open, so a closed window holds no hidden buttons.

local target = require("scripts.target")
local names = require("scripts.gui.names")

local picker = {}

local COLUMNS = 10
local MAX_ROWS = 6
local SLOT = 40

-- Candidates split by item group, groups in inventory order.
local function by_group(t)
  local groups, order = {}, {}
  for _, name in ipairs(target.recipe_candidates(t.prototype)) do
    local group = prototypes.recipe[name].group.name
    if not groups[group] then
      groups[group] = {}
      order[#order + 1] = group
    end
    table.insert(groups[group], name)
  end
  return groups, order
end

local function add_slots(parent, t, recipes)
  local scroll = parent.add({ type = "scroll-pane", horizontal_scroll_policy = "never" })
  scroll.style.maximal_height = SLOT * MAX_ROWS
  local slots = scroll.add({ type = "table", column_count = COLUMNS, style = "filter_slot_table" })
  for _, name in ipairs(recipes) do
    -- Unnamed, since names must be unique among siblings; events dispatch
    -- on the tag instead, which carries the same mod prefix.
    slots.add({
      type = "sprite-button",
      style = target.recipe_unlocked(t, name) and "slot_button" or "red_slot_button",
      sprite = "recipe/" .. name,
      elem_tooltip = { type = "recipe", name = name },
      tags = { handler = names.pick, recipe = name },
    })
  end
end

-- One group needs no tabs; several get vanilla's group tabs, opening on the
-- current recipe's group, else the first (the engine would show the last).
local function add_groups(frame, t, current)
  local groups, order = by_group(t)
  if #order == 1 then return add_slots(frame, t, groups[order[1]]) end
  local tabs = frame.add({ type = "tabbed-pane" })
  local selected = 1
  for i, group in ipairs(order) do
    if current and prototypes.recipe[current] and prototypes.recipe[current].group.name == group then selected = i end
    local tab = tabs.add({
      type = "tab", caption = "[item-group=" .. group .. "]",
      tooltip = prototypes.item_group[group].localised_name,
    })
    local page = tabs.add({ type = "flow", direction = "vertical" })
    add_slots(page, t, groups[group])
    tabs.add_tab(tab, page)
  end
  tabs.selected_tab_index = selected
end

function picker.is_open(container)
  return container.visible and #container.children > 0
end

function picker.close(container)
  container.clear()
  container.visible = false
end

function picker.toggle(container, t, current)
  if picker.is_open(container) then return picker.close(container) end
  add_groups(container, t, current)
  container.visible = true
end

return picker
