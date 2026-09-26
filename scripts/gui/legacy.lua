-- GUI left behind by 0.1.x (Factorio 1.1): a "Prime Blueprint" button in
-- the mod_gui top bar and its frame in the left flow. Mod-owned elements
-- survive an upgrade of the same mod, and nothing in 0.2 answers them, so
-- they would sit there dead forever (ADR-0005: nothing in top or left).
--
-- The containers are looked up by name rather than through mod-gui, whose
-- getters create them; an emptied container is removed only if this mod
-- made it, since another mod's buttons may share it.

local legacy = {}

local BUTTON = "blueprint_primer_button"
local FRAME = "blueprint_primer_frame"

local function child(parent, name)
  local element = parent and parent.valid and parent[name]
  return element and element.valid and element or nil
end

local function destroy(element)
  if element then element.destroy() end
end

local function destroy_if_ours_and_empty(element)
  if element and #element.children == 0 and element.get_mod() == script.mod_name then
    element.destroy()
  end
end

-- mod-gui kept its buttons in `mod_gui_button_flow` before 2.0, and in
-- `mod_gui_top_frame.mod_gui_inner_frame` since.
local function remove_button(top)
  local flow = child(top, "mod_gui_button_flow")
  destroy(child(flow, BUTTON))
  destroy_if_ours_and_empty(flow)
  local outer = child(top, "mod_gui_top_frame")
  local inner = child(outer, "mod_gui_inner_frame")
  destroy(child(inner, BUTTON))
  destroy_if_ours_and_empty(inner)
  destroy_if_ours_and_empty(child(top, "mod_gui_top_frame"))
end

local function remove_frame(left)
  local flow = child(left, "mod_gui_frame_flow")
  destroy(child(flow, FRAME))
  destroy_if_ours_and_empty(flow)
end

-- Idempotent, so on_configuration_changed runs it every time without a
-- version check.
function legacy.remove_gui()
  for _, player in pairs(game.players) do
    remove_button(player.gui.top)
    remove_frame(player.gui.left)
  end
end

return legacy
