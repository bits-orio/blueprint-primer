-- Event wiring only: every handler lives under scripts/. Blueprint Primer
-- registers no on_tick; everything it does answers a player action.

local const = require("scripts.const")
local state = require("scripts.state")
local tool = require("scripts.tool")
local copy = require("scripts.copy")
local paste = require("scripts.paste")
local window = require("scripts.gui.window")
local legacy_gui = require("scripts.gui.legacy")
local gui_events = require("scripts.gui.events")

script.on_init(state.init)

-- Also the upgrade path from 0.1.x: state.init migrates its storage, and
-- its top-bar button and left frame are removed.
script.on_configuration_changed(function()
  state.init()
  window.close_all()
  legacy_gui.remove_gui()
end)

script.on_event(defines.events.on_player_removed, function(event)
  state.remove(event.player_index)
end)

script.on_event({
  defines.events.on_player_died,
  defines.events.on_player_left_game,
  defines.events.on_player_changed_force,
}, gui_events.on_player_away)
script.on_event(defines.events.on_player_controller_changed, gui_events.on_controller_changed)

local function on_area(event)
  if event.item == const.TOOL then tool.on_selected(event) end
end
script.on_event(defines.events.on_player_selected_area, on_area)
script.on_event(defines.events.on_player_alt_selected_area, on_area)

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == const.SHORTCUT then tool.on_shortcut(event) end
end)
script.on_event(const.INPUT_PRIME, tool.on_hotkey)

-- Copies, blueprints and settings paste carry a pending primed request (ADR-0008).
script.on_event(defines.events.on_player_setup_blueprint, copy.on_setup)
script.on_event(defines.events.on_entity_settings_pasted, paste.on_pasted)

script.on_event(defines.events.on_gui_click, gui_events.on_click)
script.on_event(defines.events.on_gui_value_changed, gui_events.on_value_changed)
script.on_event(defines.events.on_gui_text_changed, gui_events.on_text_changed)
script.on_event(defines.events.on_gui_confirmed, gui_events.on_confirmed)
script.on_event(defines.events.on_gui_elem_changed, gui_events.on_elem_changed)
script.on_event(defines.events.on_gui_closed, gui_events.on_closed)
