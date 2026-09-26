# Blueprint Primer

> Exact item requests for one machine, not a whole stack.

[![Discord](https://img.shields.io/badge/Discord-join%20the%20server-5865F2?logo=discord&logoColor=white)](https://discord.gg/tWz4FT74pH) [![GitHub](https://img.shields.io/badge/GitHub-source-181717?logo=github&logoColor=white)](https://github.com/bits-orio/blueprint-primer)

Point the primer tool at a furnace or assembler, ghost or built, and ask for exactly the ingredients and fuel its recipe needs instead of a full stack. A stone furnace smelting 25 ore asks for 25 ore and 2 coal, not a stack of each. Construction robots deliver the request; the mod only writes it, the same way vanilla module requests work. Prime a machine directly, or take a primed blueprint and stamp down a whole row of identically-set-up furnaces at once.

## Status

This is a ground-up rewrite of the 1.1 version for Factorio 2.0. A 1.1 save that had the old version keeps working when opened in 2.0, but the old whole-blueprint window and its top-bar button are gone. Covered by a headless test suite in base and Space Age, and smoke-tested in the game client. Young, so expect rough edges.

## Quick start

1. Install the mod and start or load a 2.0 game.
2. Grab the primer tool from the shortcut bar, or hover a furnace or assembler and press ALT + P.
3. With the tool, click the machine to open the priming window (ALT + P skips this step).
4. Pick a recipe and drag the output slider to the amount you want; ingredients and fuel scale with it automatically.
5. Press Request to write it onto that machine, or Blueprint to take a primed copy into your cursor. Then copy-paste it or Shift+click paste its settings to prime the rest.

## Features

### Priming
- Works on one furnace or assembler at a time, ghost or already built
- Output slider drives everything: ingredients and fuel scale together, never past what one input slot holds
- Recipe picker filtered to what the machine can make; unresearched recipes show red and can still be planned
- Fluid ingredients are shown but left out of the request, since bots can't carry them

### Fuel and blueprints
- Fuel amount is calculated from the recipe, the machine's speed, and the fuel's energy value, not a fixed table
- Default fuel: what the machine already burns, else your last pick, else the earliest fuel (coal in vanilla)
- Boilers, burner drills, burner inserters and locomotives get a fuel-only window, up to what their fuel slots hold
- Primed blueprints copy the machine, recipe, and request into your cursor for stamping down a row
- Drag over a row of one kind of machine to prime them all, or blueprint the whole area primed
- Copy-paste, blueprints and Shift+click settings paste of a primed machine carry its request
- Existing requests for other inventories, like modules, are left untouched

## Compatibility

Standalone. No other mod is required, and it adds nothing to the top bar or side flow beyond one shortcut-bar button. Works with or without Space Age and Quality: quality recipes request quality ingredients, and biochambers get nutrients. Requests are written the same way vanilla module requests are, so anything that delivers to those (construction robots from a roboport or a personal roboport) works with it automatically.

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
