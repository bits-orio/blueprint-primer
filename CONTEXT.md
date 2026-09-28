# Blueprint Primer

Exact, partial item requests for a machine or a chest. Vanilla 2.0 only lets a player request whole stacks into a machine's slots, or a chest's; Blueprint Primer lets them ask for "10 iron ore and 3 coal" instead, works out the fuel for a machine, and lets a chest hold exact items with no recipe involved at all. Construction robots do all the delivering; the mod only writes requests.

> Keep this glossary and the code in the same vocabulary. Decisions live in `docs/adr/`.

## Language

**Prime / priming**:
Writing item requests onto one machine so that, once robots deliver, it can run a chosen number of crafts. Priming never moves items itself.
_Avoid_: fill, load, insert (insertion is what robots do, not the mod)

**Target**:
One machine or chest being primed: an entity ghost or a built entity in the world. The window's numbers are always per target.
_Avoid_: selection (that is the drag gesture, which may cover several entities)

**Chest**:
A plain container target: a wooden, iron or steel chest (or a modded equivalent), ghost or built. It has no recipe of its own, so its window offers Recipe mode and Items mode instead of a machine's single recipe view. Logistic chests are never chests here: their contents belong to the robot network, not to a primed request.
_Avoid_: container (the engine's word; a filtered, custom-stack or weight-limited container is never primable)

**Family**:
Machine or chest: which of the two a target is. A drag's group is always one family, decided by whichever target is nearest the drag's centre; other kinds of that same family are skipped and outlined red, while every entity of the *other* family is ignored outright, not even counted as skipped.

**Group**:
The targets one drag primes together: every selected target of the same prototype and kind as the one nearest the middle of the drag, and, for a chest, the same quality too, since quality changes its slot count (ADR-0011, ADR-0012). Other targets of the same family in the drag are skipped, a mismatched-quality chest included; targets of the other family are ignored outright. A click or the hotkey gives a group of one.

**Primed request**:
The item requests Blueprint Primer writes onto a target, as insert plans on the ghost or on an item-request-proxy for a built entity. Only covers the target's ingredient and fuel inventories; requests for any other inventory (modules above all) are never touched.

**Carried request**:
A primed request that travels to another machine by a vanilla copy, blueprint or Shift+click settings paste of the primed one. A machine counts as primed while its ingredients are still pending; the copy then gets the source's whole priming (full ingredient amounts and fuel, as a reopened window would show it), not just what is in flight. Once robots have delivered the ingredients, there is nothing to carry. A chest counts as primed the same way, by pending positions in its own inventory rather than a crafter's ingredient slots, and only pastes onto another chest.

**Primed blueprint**:
A blueprint holding exactly one machine, carrying the same recipe and primed request as the window shows. Placed like any vanilla blueprint, as often as the player likes.
_Avoid_: template, preset

**Craft count**:
The quantity the window really edits: how many times the target's recipe will run. Every other number (the output count the slider shows, each ingredient amount, the fuel estimate) is derived from it.

**Output count**:
Craft count times the recipe's main product amount. What the slider displays and steps by.

**Slot cap**:
The largest craft count whose ingredients all still fit their slots (one stack per slot, or one craft's worth when a single craft needs more than a stack) and, for burner machines, whose fuel fits the fuel inventory. The tightest ingredient decides it; the slider never goes past it.

**Fuel estimate**:
The minimum whole number of fuel items that covers the energy of the chosen crafts in this target: `ceil((crafts × recipe energy × energy usage ÷ crafting speed + one second of energy usage) ÷ (fuel value × burner effectivity))`, with the machine's quality and module effects applied. A starting value the player may overwrite.

**Default fuel**:
The fuel pre-selected for a burner: the fuel a built machine already holds, at its quality; else the fuel the player last chose for that fuel category, if this burner accepts it; else the earliest-available one (obtainable without research, else unlocked lowest in the tech tree), never wood while anything else is accepted.

**Fuel-only target**:
A burner entity that is not a crafting machine (boiler, burner mining drill, burner inserter, locomotive), or a burner crafter with nothing to deliver, either by prototype (Space Age's captive biter spawner) or by its current recipe (a biochamber cracking oil). It gets a fuel count slider and no craft count, no steam or mining math.

**Fed machine**:
A crafter that an inserter takes a chest's items into. A chest has no recipe of its own, so Recipe mode looks at its fed machines instead of asking the chest.

**Fed recipe**:
The recipe every one of a chest's fed machines agrees on, at one quality. Nil if the chest feeds nothing, or if its fed machines disagree (one furnace smelting iron, another copper).

**Chest cap**:
A chest's Slot cap: the largest craft count whose ingredients, packed into whole stacks, still fit a fresh chest of that prototype and quality. Recipe mode's slider never goes past it.

**Recipe mode**:
One of a chest window's two modes: pick a recipe and a craft count exactly as a machine would, capped by the chest cap instead of a slot. No fuel row; a chest never burns fuel.

**Items mode**:
A chest window's other mode: a table of rows, one item, quality and count each, for when there is nothing to point a recipe at, or the player wants specific items rather than a recipe's fixed ratio.

**Row**:
One line of an items-mode table: an item, a quality and a count. Addressed by a stable id rather than its position, so removing or retyping one row never disturbs another mid-edit.

**Row cap**:
The most a row can hold, in items: whatever whole stacks the chest's other rows leave it. A row can never be set above its row cap, and a row whose cap is zero cannot be added.

**Want list**:
A chest priming's item totals, one entry per item and quality: one per ingredient in Recipe mode, or every row with anything to bring in Items mode. The Request, the primed blueprint and group totals all read the want list, never the mode directly.

**Placement**:
Turning a chest's want list into exact inventory positions. A fresh chest (ghost, blueprint, copy) fills from its last slot downward; a built chest's Request tops up around what is already inside. One occupancy map runs across the whole want list, so two items are never sent to the same slot.

**Priming window**:
The one small screen GUI through which every priming happens. Opened by the primer tool or the hover hotkey.

**Primer tool**:
The selection tool the shortcut-bar button toggles into the cursor (the hotkey does too when nothing primable is hovered). Clicking or dragging over a machine opens the priming window for it.
