# One window, two outputs: prime the target, or take a primed blueprint

The priming window always ends in one of two buttons. **Request** writes the primed request onto the target in the world, ghost or built. **Blueprint** puts a primed blueprint of that one machine (entity, quality, direction, recipe and request) into the player's cursor instead, leaving the target untouched.

Both came out of the design interview as real needs: topping up a furnace that is already smelting wants the first, and laying down a row of identically-primed furnaces wants the second. They share every number in the window, so offering both costs one button, not a second UI.

## Consequences

- A primed blueprint needs something to copy, so the player points the primer tool at a ghost or built machine first. There is no "blank" blueprint mode.
- A machine with a `fixed_recipe` has its recipe chooser locked, ghost or built. So is a built assembler that already has a recipe, and a built furnace that is still smelting (its recipe is implied by what is inside). To get a primed blueprint with a different recipe, point the tool at a ghost.
- Recipes are only written to a target that has none yet, or to a ghost. Changing the recipe of a built, running assembler is left to the vanilla GUI, because doing it from here would silently return its contents.
