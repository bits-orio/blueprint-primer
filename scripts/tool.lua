-- The three ways into the priming window: the primer tool's selection, the
-- shortcut-bar button, and the hover hotkey. A drag resolves one kind of
-- machine (scripts/selection.lua); the hotkey, one machine. Each opens the
-- window, or hands the player the tool to pick with.

local const = require("scripts.const")
local target = require("scripts.target")
local selection = require("scripts.selection")
local window = require("scripts.gui.window")

local tool = {}

local function holding_tool(player)
  local cursor = player.cursor_stack
  return cursor and cursor.valid_for_read and cursor.name == const.TOOL
end

-- Once a machine is picked the tool has done its job, so it leaves the
-- cursor as the window opens. Only the tool is ever cleared: anything else
-- the player holds stays put.
local function open(player, t, picked)
  if holding_tool(player) then player.clear_cursor() end
  window.open(player, t, picked)
end

local function outline(player, entity, box_type)
  entity.surface.create_entity({
    name = "highlight-box", position = entity.position, bounding_box = entity.selection_box,
    box_type = box_type, render_player_index = player.index,
    time_to_live = const.HINT_TICKS, blink_interval = const.HINT_BLINK_TICKS,
  })
end

-- Just above the middle of the dragged area, where the eye already is; the
-- cursor sits at the drag's far corner, often at the screen edge.
local function above(area)
  local left_top, right_bottom = area.left_top or area[1], area.right_bottom or area[2]
  local x1, y1 = left_top.x or left_top[1], left_top.y or left_top[2]
  local x2 = right_bottom.x or right_bottom[1]
  return { x = (x1 + x2) / 2, y = y1 - 1 }
end

-- After a drag over several machines, show briefly which are being primed
-- (vanilla's copy colour) and which were skipped as another kind (its red
-- "not allowed"), for this player only (ADR-0011). Skipping also gets a
-- line of flying text naming what is primed.
local function hint(player, picked)
  if #picked.group < 2 and #picked.skipped == 0 then return end
  for _, t in ipairs(picked.group) do outline(player, t.entity, "copy") end
  for _, entity in ipairs(picked.skipped) do outline(player, entity, "not-allowed") end
  if #picked.skipped == 0 then return end
  window.notify(player, { const.NOTICE.ONE_KIND, #picked.group, picked.primary.prototype.localised_name, #picked.skipped },
    above(picked.area))
end

-- Pressing the button while already holding the tool puts it away, like
-- vanilla's planner shortcuts. No cursor at all means a spectator.
local function toggle_tool(player)
  local cursor = player.cursor_stack
  if not cursor then return end
  if holding_tool(player) then
    player.clear_cursor()
    return
  end
  if not player.clear_cursor() then return window.notify(player, const.REASON.CURSOR_BLOCKED) end
  cursor.set_stack({ name = const.TOOL })
end

-- A hovered machine the tool could never prime says why, as a click with
-- the tool would. Anything else hovered (a chest, a tree, bare ground)
-- hands over the tool instead; a neutral tree must not claim another force.
local function refusal_worth_saying(entity, why)
  if why == const.REASON.UNSUPPORTED then return true end
  return why == const.REASON.OTHER_FORCE and target.from_entity(entity) ~= nil
end

function tool.on_selected(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  local picked, reason = selection.resolve(event.entities or {}, event.area, player.force)
  if not picked then return window.notify(player, reason or "bp-primer.nothing-to-prime") end
  picked.area = event.area
  open(player, picked.primary, picked)
  hint(player, picked)
end

function tool.on_shortcut(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  toggle_tool(player)
end

-- A spectator can hover machines but, as in vanilla, not change them.
function tool.on_hotkey(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end
  if player.controller_type == defines.controllers.spectator then return end
  local selected = player.selected
  if selected and selected.valid then
    local t, why = target.from_entity(selected, player.force)
    if t then return open(player, t) end
    if refusal_worth_saying(selected, why) then return window.notify(player, why) end
  end
  toggle_tool(player)
end

return tool
