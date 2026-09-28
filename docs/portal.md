# Blueprint Primer

> Exact item requests for a machine or a chest, not a whole stack.

[![Discord](https://img.shields.io/badge/Discord-join%20the%20server-5865F2?logo=discord&logoColor=white)](https://discord.gg/tWz4FT74pH) [![GitHub](https://img.shields.io/badge/GitHub-source-181717?logo=github&logoColor=white)](https://github.com/bits-orio/blueprint-primer)

Point the primer tool at a furnace, assembler or chest, ghost or built, and ask for exactly what it needs instead of a full stack. A stone furnace smelting 25 ore asks for 25 ore and 2 coal, not a stack of each. A chest can request a recipe's ingredients the same way, or just hold exactly the items you list, at whatever counts you pick. Construction robots deliver the request; the mod only writes it, the same way vanilla module requests work. Prime one directly, or take a primed blueprint and stamp down a whole row of identically-set-up furnaces, assemblers or chests at once.

## Status

This is a ground-up rewrite of the 1.1 version for Factorio 2.0 and 2.1: 0.3.x releases are for 2.0 and 0.4.x for 2.1, with the same features. A 1.1 save that had the old version keeps working when opened in 2.0, but the old whole-blueprint window and its top-bar button are gone. Covered by a headless test suite in base and Space Age, and smoke-tested in the game client. Young, so expect rough edges. A chest's recipe list holds every crafting recipe in the game, so it is long with Space Age.

## Quick start

1. Install the mod and start or load a 2.0 or 2.1 game.
2. Grab the primer tool from the shortcut bar, or hover a furnace, assembler or chest and press ALT + P.
3. With the tool, click it to open the priming window (ALT + P skips this step).
4. Pick a recipe and drag the output slider to the amount you want; ingredients and fuel scale with it automatically. A chest can do the same, or switch to Items mode to list exact items and counts instead.
5. Press Request to write it onto that machine or chest, or Blueprint to take a primed copy into your cursor. Then copy-paste it or Shift+click paste its settings to prime the rest.

## Features

### Priming
- Works on furnaces, assemblers and chests, ghost or already built
- Output slider drives everything: ingredients and fuel scale together, never past what fits
- Unresearched recipes show red in the picker and can still be planned
- Drag over a row of one kind to prime them all, or blueprint the whole area primed

### Chests
- A chest that feeds a machine through an inserter opens on that machine's recipe
- Items mode: set each item to half the chest, a full chest, a slot count or an exact count
- Plain chests only: robots would move primed items back out of logistic chests

### Fuel and blueprints
- Fuel is calculated from the recipe, the machine's speed and the fuel's energy value
- Boilers, burner drills, burner inserters and locomotives get a fuel-only window
- Primed blueprints, copy-paste and Shift+click settings paste all carry the request

## Compatibility

Standalone. No other mod is required, and it adds nothing to the top bar or side flow beyond one shortcut-bar button. Works with or without Space Age and Quality: quality recipes and chest items request the right quality, and biochambers get nutrients. Requests are written the same way vanilla module requests are, so anything that delivers to those (construction robots from a roboport or a personal roboport) works with it automatically.

## Works with

Part of the MTS family. Blueprint Primer is fully standalone and needs nothing else installed, but it sits well beside:

- [Multi-Team Support](https://mods.factorio.com/mod/multi-team-support) gives every team its own copy of the map. Blueprint Primer's state is per player and per force, so every team primes its own machines.
- [Land Title Registry](https://mods.factorio.com/mod/land-title-registry) governs what you may build where. Priming builds nothing, and a primed blueprint obeys land rights like any other blueprint.

## Links

- [GitHub](https://github.com/bits-orio/blueprint-primer)
- [Discord](https://discord.gg/tWz4FT74pH)

## Development

Developed with AI coding assistants alongside human review and in-game testing. Issues and pull requests are welcome on [GitHub](https://github.com/bits-orio/blueprint-primer).

License: MIT
