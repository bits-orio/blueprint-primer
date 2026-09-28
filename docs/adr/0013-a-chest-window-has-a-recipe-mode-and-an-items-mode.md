# A chest window has a recipe mode and an items mode

ADR-0012 gives a chest Recipe mode for free: pick a recipe, drag one slider, and the chest asks for that recipe's ingredients exactly as a machine would. That covers "stage the inputs for this machine" well, but not the other reason players fill a chest by hand: a stockpile of one item, a train's mixed load, spare parts for a build that is not a recipe at all. Recipe mode cannot say "600 iron plate and nothing else" unless some recipe happens to want exactly that; the fix is not a smarter recipe search, it is a second, honest mode that edits items instead.

So a chest window carries a `switch`: **Recipe** on the left, **Items** on the right. Both modes keep their own state in the Priming record (`recipe`/`quality`/`crafts` for one, `items`/`next_row_id` for the other), and only the mode actually showing is ever requested; switching back and forth loses neither side's numbers. A chest with a recipe already fed, switching into Items, seeds its rows from that recipe's want list, so the player is not starting from a blank table; switching a chest with rows back into Recipe keeps whatever recipe was already there (the fed recipe, if none was set yet).

## Items mode

A row is `{ id, name, quality, count }`. `count` is the only number actually stored; everything else (whole slots, the slider position) is derived from it and the item's stack size, the same relationship a craft count has to its output count. A row's **row cap** is whatever whole stacks the chest's *other* rows leave it, in that item's stack size, so a chest is never over-committed no matter which rows are edited in which order. Half, Max, a slots slider and an exact item field are four ways to write the same one number, matching the vocabulary Recipe mode already uses for craft count (ADR-0003's amendment records the parallel).

Adding a row is a trailing, always-empty item chooser, the same shape as the row choosers themselves; picking an item there appends a new row at Half, and the chooser goes empty again, ready for the next one. Clearing a row's own chooser removes that row outright, matching how a slot-based request works. Picking an item and quality that is already listed refuses with a notice rather than merging into the existing row, since merging silently would make "how much of X have I asked for" require adding up rows in your head.

## Reopening a chest

A machine's reopen rule (ADR-0003) is simple because a machine has one shape of request: a recipe's ingredients at some craft count, so any pending request either fits that shape or it does not. A chest has two shapes now, and the reopen rule has to guess between them without ever guessing a *recipe*: a stockpile of iron plate must never reopen as "gears", just because gears happen to eat plate.

The rule: a chest with nothing pending opens on its fed recipe if it has one (Recipe mode, half the chest cap), else Items mode with nothing in it. A chest with something pending reopens in **Recipe mode**, on the fed recipe, only when every single pending item is one of that recipe's ingredients, at the recipe's quality, and the pending amount for every ingredient with anything pending matches `ceil(N * amount)` exactly for one shared craft count `N`. That last clause is doing the real work: it is the same property ADR-0003 already relies on, that reopening an untouched request and pressing Request again must rewrite the same numbers, not shrink or round them. Anything that does not clear that bar, a stockpile with no fed machine, a partial delivery that no longer divides evenly, two unrelated items, reopens in **Items mode**, one row per pending item and quality, at whatever it is holding once the request lands.

One consequence is deliberately accepted rather than fought: a chest whose Items-mode rows happen to exactly match a fed recipe's want list reopens in Recipe mode, not Items mode. That is not a bug in row-tracking, it is the reopen rule correctly recognising its own request; the player sees the same numbers either way, just through the other tab.

Row order on reopen is not "the order the request was written in"; the engine hands a chest's pending plan back in its own order, not plan-insertion order. Rows are instead ordered by the highest inventory slot each one fills, descending, which is the order a *fresh* placement would have filled them in the first place (ADR-0012's placement rule fills from the last slot down). Without this, reopening an untouched Request could rewrite different slots than the ones already holding the items, for no reason visible to the player.

## Consequences

- Recipe mode and Items mode are genuinely separate state, not one field reinterpreted two ways; a chest carries both `recipe`/`quality`/`crafts` and `items`/`next_row_id` at once, and only the active one is read when writing a request.
- No recipe is ever inferred from Items-mode rows alone, even when they happen to match one exactly on reopen; recipes are only ever offered from a fed machine or the player's own pick.
- A row whose cap would be zero cannot be added at all; there is nothing useful "half of zero" could mean.
- Carrying a chest onto a smaller one (a settings paste, or a copy) keeps earlier rows first and drops whatever no longer fits, rather than shrinking every row proportionally; the player who listed the important item first keeps it.
