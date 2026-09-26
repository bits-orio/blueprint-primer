# Blueprint Primer

Exact, partial item requests for a single machine. Vanilla 2.0 only lets a player request whole stacks into a machine's slots; Blueprint Primer lets them ask for "10 iron ore and 3 coal" instead, and works out the fuel for them. Construction robots do all the delivering; the mod only writes requests.

> Keep this glossary and the code in the same vocabulary. Decisions live in `docs/adr/`.

## Language

**Prime / priming**:
Writing item requests onto one machine so that, once robots deliver, it can run a chosen number of crafts. Priming never moves items itself.
_Avoid_: fill, load, insert (insertion is what robots do, not the mod)

**Target**:
One machine being primed: an entity ghost or a built entity in the world. The window's numbers are always per target.
_Avoid_: selection (that is the drag gesture, which may cover several entities)

**Group**:
The targets one drag primes together: every selected machine of the same prototype and kind as the one nearest the middle of the drag (ADR-0011). Machines of other kinds in the drag are skipped. A click or the hotkey gives a group of one.

**Primed request**:
The item requests Blueprint Primer writes onto a target, as insert plans on the ghost or on an item-request-proxy for a built entity. Only covers the target's ingredient and fuel inventories; requests for any other inventory (modules above all) are never touched.

**Carried request**:
A primed request that travels to another machine by a vanilla copy, blueprint or Shift+click settings paste of the primed one. A machine counts as primed while its ingredients are still pending; the copy then gets the source's whole priming (full ingredient amounts and fuel, as a reopened window would show it), not just what is in flight. Once robots have delivered the ingredients, there is nothing to carry.

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

**Priming window**:
The one small screen GUI through which every priming happens. Opened by the primer tool or the hover hotkey.

**Primer tool**:
The selection tool the shortcut-bar button toggles into the cursor (the hotkey does too when nothing primable is hovered). Clicking or dragging over a machine opens the priming window for it.
