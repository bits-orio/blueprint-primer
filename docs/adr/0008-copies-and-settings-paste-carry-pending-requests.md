# Copies and settings paste carry the pending primed request

Playtesting 0.2.0 showed a gap: after Request on a built furnace, Ctrl+C / Ctrl+V of that furnace carried its fuel request but not its ingredients. A headless probe (`LuaItemStack.create_blueprint` over three stone furnaces, 2.0.77) pinned down vanilla's rule:

- a **built** machine with a pending item-request-proxy: the blueprint keeps only the **fuel** part of the pending request; `crafter_input` positions are dropped;
- a built machine whose items were already delivered: nothing is carried (vanilla does not snapshot contents, fuel included);
- a **ghost** with an insert plan: everything is carried, ingredients included.

So priming already survives blueprinting for ghosts, and only the built-machine case loses the ingredients. Rather than widen the mod to multi-machine priming (considered and rejected: it would have replaced ADR-0001 and grown the window), two engine hooks close the gap and keep the mod one-machine-at-a-time:

1. **`on_player_setup_blueprint`**: when a blueprint or copy is set up, every blueprint entity whose source (from `event.mapping`) is a built machine with pending ingredients gets the source's whole priming written into its `items`: the full ingredient amounts and the fuel, derived exactly as Shift+click paste derives them. Modules and anything else vanilla wrote are kept.
2. **`on_entity_settings_pasted`**: Shift+click pasting from a machine that carries a pending primed request applies the same priming (recipe, craft count, fuel item, and a typed fuel amount if there was one) to the destination through the normal request path, so the destination still gets its own top-up and its own fuel estimate.

## Consequences

- "Pending only", matching vanilla's own fuel behaviour: once robots have delivered, there is nothing to carry. No per-entity memory is kept in storage.
- The blueprint to edit is found the way 2.0 mods do it in practice (`player.blueprint_to_setup`, else `event.stack`, else the cursor stack (or the active blueprint inside a book), else `event.record`). If none can be found, the hook does nothing and vanilla's blueprint stands.
- A paste onto a machine that cannot take the source's recipe or, if it burns fuel, the source's fuel does nothing beyond vanilla's own paste; no message is shown for a paste the player did not aim at priming.
- A request counts as primed while ingredients are pending, since vanilla only ever asks a built crafter for fuel and modules. So settings paste carries between furnaces and assemblers only; fuel-only targets are left to vanilla, and pasting a locomotive's schedule never starts a fuel delivery.
- ADR-0001 stands: the window still primes one machine. Priming a whole build is: prime one machine, then copy, stamp, or settings-paste it.
- Amended after the first real-client test of 0.3.0. The first cut added back only the ingredient positions still in flight. In play that gave a copy of 20 ore and no coal for a furnace primed for 25 with 5 already inside, whose coal had arrived within seconds: vanilla keeps no fuel once it is delivered. A copy is now primed like its source, which is also exactly what settings paste does, so the two paths share one rule (`scripts/carried.lua`).
