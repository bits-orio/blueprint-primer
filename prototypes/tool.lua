-- The primer tool: the selection tool through which every priming starts.
-- Only-in-cursor and never craftable; the shortcut and the hotkey put it in
-- the cursor. A click or drag resolves to one kind of machine in script
-- (scripts/selection.lua); data-final-fixes.lua narrows what lights up.

local const = require("scripts.const")

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
    icon = "__BlueprintPrimer__/graphics/primer-tool.png",
    icon_size = 64,
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
