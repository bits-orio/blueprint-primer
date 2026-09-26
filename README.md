# Blueprint Primer

Exact, partial item requests for a single machine. Vanilla 2.0 lets you request items into a machine's ingredient slots, but only in whole stacks — there is no way to ask a furnace for 10 ore. Blueprint Primer fixes that: point it at a furnace or assembler, ghost or built, choose a recipe and a craft count, and it writes an exact request for exactly that much. Construction robots do the delivering; the mod only writes the request.

It's for anyone who is tired of a fresh furnace eating a full stack of ore and half a stack of coal for a batch they only needed ten of, or who wants to stamp down a row of identically-primed furnaces from one blueprint.

## Status

This is a ground-up rewrite of the 1.1 version for Factorio 2.0. A 1.1 save that had the old version keeps working when opened in 2.0, but the old whole-blueprint window and its top-bar button are gone. Covered by a headless test suite in base and Space Age, and smoke-tested in the game client. Young, so expect rough edges.

## Quick start

1. Install the mod and start or load a 2.0 game.
2. Grab the primer tool from the shortcut bar, or press **ALT + P** while hovering a furnace or assembler (ghost or built).
3. With the tool, click the machine to open the priming window (ALT + P skips this step).
4. Pick a recipe (a built assembler that already has one keeps it) and drag the output slider to the amount you want.
5. Hit **Request** to write the request onto that machine, or **Blueprint** to take a primed copy of it into your cursor instead.

## Fuel-only machines

Boilers, burner mining drills, burner inserters and locomotives get a fuel-only window: pick a fuel and a count up to what the fuel slots hold. There is no steam or mining math, since how much they burn depends on the rest of the factory. In Space Age, a biochamber set to a recipe that takes only fluids (oil cracking) gets the same fuel-only window, and keeps its recipe.

## How the fuel estimate works

For a burner machine, the window pre-fills the smallest whole number of fuel items that covers the energy the chosen crafts will use, computed from the recipe's energy cost, the machine's crafting speed and energy usage, and the fuel's own energy value — not a hardcoded table, so it works for modded machines and fuels too. It's a starting value; you can type over it.

Worked example, measured against the engine (see `dev/run-spike.sh`): smelting 50 iron ore takes **4 coal** in a stone furnace, but only **2 coal** in a steel furnace, because the steel furnace's higher crafting speed doesn't raise its energy use — it just does more work per joule. Ask a vanilla stack-based request for the same job and you'd get a full stack of coal (50) either way.

The formula (`DESIGN.md` has the exact contract):

```
draw       = max(1, consumption / speed)
per_craft  = recipe.energy / crafting_speed × energy_usage_per_tick × 60 × draw
margin     = energy_usage_per_tick × 60 × max(1, consumption)
fuel_count = ceil((crafts × per_craft + margin) / effectivity / fuel_value)
```

`crafting_speed` is the machine's own speed at its quality, and `consumption` and `speed` are its module and beacon factors (1 with none). `draw` never drops below the bare machine's, because a primed blueprint carries no modules. `margin` is one second of the machine's energy usage, added so a craft count landing exactly on a fuel-item boundary doesn't starve its last craft.

A built machine's modules and beacons count, and so do module requests robots have not delivered yet, on a ghost or a built machine (a pending module swap counts the modules going in, not the ones coming out). Beacons around a ghost do not, so for a biochamber ghost in beacon range, reopen the window once it is built or raise the fuel.

The default fuel is whatever a built machine is already burning, at its quality (uncommon coal is topped up with uncommon coal), else the one you last picked for that fuel type, else the earliest fuel in the tech tree (coal in vanilla). Wood is picked only if nothing else burns.

## Limitations

- One machine at a time. A primed blueprint holds exactly one entity; there's no multi-machine blueprint priming (see `docs/adr/0001-one-machine-at-a-time.md`).
- Fluid ingredients can't be requested — the window flags them and leaves them out of the slider's cap.
- No inventory-transfer button. Requests wait for construction robots, exactly like any other vanilla request (see `docs/adr/0002-requests-only-robots-deliver.md`).

## Links

- [GitHub](https://github.com/bits-orio/blueprint-primer)
- [Mod portal](https://mods.factorio.com/mod/BlueprintPrimer)
- [Discord](https://discord.gg/tWz4FT74pH)

## Development

- `dev/run-tests.sh` runs the headless test suite (two mod sets: base only, and base + quality + space-age) and exits non-zero on any failure.
- `tools/pack.sh` builds the distributable zip the same way a release would.
- The design contract is in [DESIGN.md](DESIGN.md), the vocabulary in [CONTEXT.md](CONTEXT.md), and the reasoning behind each decision in [docs/adr/](docs/adr/).

Developed with AI coding assistants alongside human review and in-game testing.

## License

MIT. See [LICENSE](LICENSE).
