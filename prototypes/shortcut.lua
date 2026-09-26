-- Two entry points. The shortcut-bar button always hands out the primer
-- tool. The hotkey primes the machine under the cursor directly and falls
-- back to handing out the tool, so both need script: action = "lua"
-- rather than the engine's spawn-item.

local const = require("scripts.const")

data:extend({
  {
    type = "shortcut",
    name = const.SHORTCUT,
    action = "lua",
    associated_control_input = const.INPUT_PRIME,
    -- Blueprint paper with Factorio's request marker (tools/gen_icons.py), on
    -- the blue button style vanilla's own blueprint shortcuts use.
    style = "blue",
    icon = "__BlueprintPrimer__/graphics/primer-shortcut.png",
    icon_size = 56,
    small_icon = "__BlueprintPrimer__/graphics/primer-shortcut-24.png",
    small_icon_size = 24,
    order = "b[blueprints]-z[blueprint-primer]",
  },
  {
    -- ALT + P is unbound in vanilla 2.0 (base binds ALT + A/B/C/D/E/F/G/L/
    -- R/T/U/Y). Rebindable like every custom input.
    type = "custom-input",
    name = const.INPUT_PRIME,
    key_sequence = "ALT + P",
    consuming = "none",
  },
})
