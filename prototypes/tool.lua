-- The primer tool: the selection tool through which every priming starts.
-- Only-in-cursor and never craftable; the shortcut and the hotkey put it in
-- the cursor. A click or drag resolves to one kind of machine in script
-- (scripts/selection.lua); data-final-fixes.lua narrows what lights up.

local const = require("scripts.const")

-- The marker's share of the icon; tools/gen_icons.py previews the same.
local MARKER_SCALE = 0.78

-- "any-entity" does not promise to include ghosts, so "entity-ghost" is
-- listed explicitly; "same-force" only narrows the set. The entity filters
-- are added in data-final-fixes (prototypes/tool_filters.lua), once every
-- mod's machines exist.
local function mode()
  return {
    border_color = { r = 0.35, g = 0.75, b = 0.95 },
    cursor_box_type = "entity",
    mode = { "any-entity", "entity-ghost", "same-force" },
    started_sound = { filename = "__core__/sound/blueprint-select.ogg" },
  }
end

data:extend({
  {
    type = "selection-tool",
    name = const.TOOL,
    -- Vanilla's own item-request marker, the icon the game uses for requests,
    -- on a square of our own so the tool reads as distinct from it. Item
    -- icons default to scale 32 / icon_size, so 0.5 is full size here.
    icons = {
      { icon = "__BlueprintPrimer__/graphics/primer-tool-frame.png", icon_size = 64, scale = 0.5 },
      { icon = "__core__/graphics/icons/mip/item-request-slot.png", icon_size = 64, scale = 0.5 * MARKER_SCALE },
    },
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    auto_recycle = false,
    hidden = true,
    subgroup = "tool",
    order = "c[automated-construction]-z[blueprint-primer]",
    stack_size = 1,
    -- Shift-drag does the same as drag: there is only one thing to do.
    select = mode(),
    alt_select = mode(),
  },
})
