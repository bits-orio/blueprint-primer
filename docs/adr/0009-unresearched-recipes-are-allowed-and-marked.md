# Unresearched recipes are allowed, and marked the way vanilla marks them

Through 0.3.0 the recipe chooser was vanilla's `choose-elem-button`, which lists every recipe the machine could craft, and picking one the force had not researched was refused. Playtesting called that wrong on both counts: the list gave no hint which recipes were locked, and the refusal stopped the player from planning ahead — the tool should not decide what a player may blueprint. Vanilla agrees: a parameterised blueprint happily places an assembler on an unresearched recipe, which then shows the red "not unlocked" sign until the research lands.

So any recipe the machine can craft may be picked, and a locked one is marked with vanilla's own visuals: a red slot (the `red_slot_button` style vanilla uses for recipes you cannot hand-craft) in the picker, and vanilla's `crafting_machine_recipe_not_unlocked` sign over the chosen recipe.

The engine's choose-elem picker cannot colour individual entries, so the recipe row now opens a small picker of the mod's own: the machine's candidate recipes (its crafting categories, not hidden, with an item ingredient, never a blueprint-parameter placeholder, and for a furnace exactly one item ingredient), grouped by item group like vanilla's, each a slot button, red when the force has not researched it.

Headless probes on 2.0.77 decided what an unresearched recipe can actually do:

- `set_recipe` takes an unresearched recipe on a built assembler and on a ghost, and robots deliver its ingredients exactly (3 gears and 6 pipes for engine units, both cases). The machine simply waits for the research.
- A **built furnace** refuses them: a furnace only accepts an item that feeds an unlocked recipe. A proxy asking a stone furnace for iron plate before steel is researched had its ingredient part dropped (robots returned the plates) while the coal was delivered.

## Consequences

- Picking an unresearched recipe is always allowed; the window says it is not researched yet.
- Request on a **built furnace** with an unresearched recipe is refused with a message saying why and pointing to Blueprint — it could never be delivered. A ghost furnace may still take the request: if it is built after the research, it works.
- Blueprint is never refused for being unresearched. A primed blueprint of such a recipe is a plan for later, as in vanilla.
- The picker is built only when opened, so a window never creates hundreds of buttons it does not show.
- Supersedes the "a recipe the force has not unlocked is refused when picked" consequence of ADR-0003.
