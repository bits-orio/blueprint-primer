# Quantity is a craft count, driven by an output slider capped at the slot cap

The window edits one number: the **craft count**. The player moves a slider (or types into the field beside it) in units of **output count**, and every ingredient amount follows in proportion, so the ingredients can never drift out of step with each other.

The slider's maximum is the **slot cap**: the largest craft count whose every ingredient still fits its slot, where a slot holds one stack, or one craft's worth when a single craft needs more than a stack (a satellite takes 100 low density structures at stack 50; robots were measured delivering over-stack amounts into one crafter slot through both a ghost plan and a proxy). Ingredients fill at different rates, so the tightest one decides, a recipe needing 1 of a 50-stack item and 5 of a 100-stack item caps at 20 crafts even though the second slot is only a fifth full.

Half and Max buttons stand in for "half stack" and "full stack": Max is the slot cap, Half is half of it rounded down to a whole craft.

## Consequences

- There are no per-ingredient overrides. A player who wants an unbalanced load edits the machine's slots in vanilla.
- Fluid ingredients cannot be requested and are ignored by the cap; the window says so.
- For a furnace the player picks the recipe (the output) with a recipe picker filtered to that furnace's crafting categories and to recipes with an item ingredient (unresearched recipes are offered and marked, per ADR-0009, which supersedes the earlier refusal), and preset from any request already pending on it, else from the furnace's current or last recipe when it has one.
- Reopening the window on a target that already carries a primed request presets the craft count and fuel from that request, so the window always starts from what is really pending.

**Amended (0.3.4):** a chest's window (ADR-0013) keeps this rule for its Recipe mode, craft count and all, but also offers an Items mode, where the player edits an item count directly, row by row, with no craft count in sight. That is not a second slider bolted onto this one; it is a genuinely different way to say what a target should hold, offered only where there is no machine actually consuming the result. Recipe mode and Items mode keep independent state, and only the mode showing is ever requested.
