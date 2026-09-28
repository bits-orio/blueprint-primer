# Chests are primed like machines

Blueprint Primer's window makes an exact item request; nothing about that is specific to a crafter. A chest is a request too, just one nothing crafts from: stockpile ore beside an outpost, stage items for a train, or feed a machine by hand until the base catches up. Vanilla asks for whole stacks into a chest exactly as coarsely as it asks into a furnace, so the same fix applies.

So a chest becomes a second kind of target, a **chest**, joining the existing **machine** family (`target.family`), primed by the same tool, the same drag, and the same Request/Blueprint pair as a furnace or assembler.

## What counts as a chest

A chest is a plain container: `type == "container"`, not hidden, a chest inventory of at least one slot, with a plain or barred inventory (`inventory_type` "normal" or "with_bar"). Filtered, custom-stack and weight-limited containers are excluded, because the engine silently drops or truncates a slot-targeted request there, the same failure mode that would make priming them worse than not priming them at all.

`logistic-container` (storage, passive/active provider, buffer, requester) is deliberately **not** a chest here, even though it is also a plain box that holds items. A provider chest hands its contents to the logistic network the moment a robot wants them, so a primed passive provider is drained mid-delivery (measured directly: a request survives exactly until the first robot passes by). A requester chest with "trash unrequested" enabled, or any request slot with a maximum, throws primed items straight back out. Priming either would be actively worse than vanilla's own request row, which the player already has for logistic chests. So a click, ALT + P, or a drag that selects nothing else primable refuses with a message (`LOGISTIC_CHEST`) rather than quietly doing nothing or doing the wrong thing; the tool's drag filters leave logistic chests dark for the same reason a boiler ghost lights up and a belt does not. A logistic chest caught in a *wider* drag, alongside something the tool could prime, stays dark and is left out silently, the same as any other entity the tool cannot prime.

## Families, and the drag

ADR-0011 grouped a drag by "kind", meaning a machine's prototype. That is still true within a family, but the family itself is now the first choice: the entity nearest the drag's centre decides not just which prototype but which of **machine** or **chest** the whole group will be. Every other entity of the *same* family joins the skip list and gets outlined red if it does not match the primary's exact prototype and kind, precisely as before. An entity of the *other* family is invisible to this drag: not skipped, not outlined, not counted in the "one kind at a time" notice. A row of furnaces with output chests behind them primes the furnaces and leaves the chests alone; a row of chests with an inserter reaching into a furnace primes the chests and leaves the furnace alone. Mixing a machine's and a chest's numbers in one window would have meant showing either a fabricated craft count for the chest or a fabricated item table for the furnace, so the two families simply never share a group.

A chest also carries a quality, and quality changes its slot count (a legendary wooden chest holds more than a normal one), which a machine's recipe cap never depends on. So a chest additionally has to match the primary's quality to join the group; one of another quality is skipped and outlined red exactly like a chest of another kind, even though its prototype matches (ADR-0011's amendment). Machines are unaffected and keep grouping across qualities.

Clicking a chest, or hovering one with ALT + P, opens its window directly, exactly as for a machine (the tool leaving the cursor once it has picked something, ADR-0011's already-accepted trade-off, now extended).

## Recipe mode: borrowing a recipe with nothing to craft it

A chest runs no recipe, so its Recipe mode candidate list cannot come from the chest's own crafting categories, it has none; it has to come from every recipe *some* crafter in the game could run: the union of every assembling machine's and every furnace's crafting categories. That list is long, several hundred entries with Space Age, and the recipe picker (ADR-0009) already tolerates a long list fine; the trade-off is accepted rather than trimmed, since trimming it would mean guessing which crafters the player actually owns.

A chest that visibly feeds a machine should not make the player pick a recipe it can already see running. So a chest looks at its **fed machines**: every crafter, built or ghost, that an inserter (built or ghost) carries this chest's items into, found from the inserter's own `pickup_position` and `drop_position` (readable on a ghost from the moment it is placed; `pickup_target`/`drop_target` are not, and direction alone does not say which way an inserter drops). If every fed machine agrees on one recipe, at one quality, that is the chest's **fed recipe**, and a fresh chest window opens straight onto it. Two machines feeding two different recipes agree on nothing, so the window falls back to asking, exactly as it would for a machine with no recipe yet. Loaders are ignored; they are a distinct enough case, and absent without a mod, that stretching the same geometry to cover them was not worth the complexity here.

The chest's own slider cap is not a slot cap, since a chest has no slot dedicated to one ingredient; it is a **chest cap**, the largest craft count whose ingredients, each rounded up to whole stacks, still fit the chest's own inventory size at its own quality.

## Carrying and reopening

A chest's pending request lives in its own inventory rather than in a `crafter_input`, so every place that asked "which inventory holds this target's ingredients" (carried, copy, reopen, request) now asks `target.input_inventory(t)` instead of assuming `crafter_input`. With that one seam, ADR-0008's whole carrying story, copies, blueprints and Shift+click settings paste all reading the source's *whole* priming rather than only what is still in flight, applies to chests with no separate mechanism. A vanilla probe found the same gap ADR-0008 already fixed for machines: a built chest's item-request-proxy loses every position when blueprinted, so a chest needed exactly the same `on_player_setup_blueprint` fix, not a new one (see ADR-0008's amendment).

Reopening a chest is its own small decision, given a second mode to reopen into; see ADR-0013.

## Consequences

- `target.is_machine` keeps meaning "machine family"; no caller may treat a chest as a machine, and nothing that only makes sense for a crafter (recipe locking, fuel) is ever asked of one.
- The recipe picker's candidate list is now sometimes "every crafting recipe in the game", not one machine's few. Accepted; the list already scrolls, and grouping by item group keeps it navigable.
- A chest is placed like a fresh chest when it does not exist yet (a ghost, a copy, a primed blueprint) and topped up around its contents when it already exists; see ADR-0013 for what that changes about placement itself.
- Loaders feeding a chest are never read as a fed machine.
- Logistic chests of every kind are excluded outright: a click, ALT + P, or a drag that selects nothing else primable gets a spoken reason (`LOGISTIC_CHEST`) rather than silence; one caught in a wider drag alongside something primable simply stays dark and unmentioned.
- A chest group is also a one-quality group; a chest of another quality is skipped like a chest of another kind, even though machines still group across qualities freely.
