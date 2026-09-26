# The mod writes requests; robots deliver

Priming never moves an item. It writes insert plans onto a ghost, or onto an item-request-proxy for a built machine, and construction robots do the rest — from a roboport network or from the player's inventory via a personal roboport. There is no "insert now from my inventory" button.

Manual insertion is already easy in vanilla (right-click takes half a stack), so an inventory-transfer path would double the mod's surface for the case it helps least. Requests are also the only path that works for ghosts and for primed blueprints, which have nothing to insert into yet.

## Consequences

- Without construction robots in range, a primed request just waits, exactly like a vanilla module request.
- Priming a built machine replaces only the primed request: pending requests for other inventories (modules in particular) are carried over untouched.
- If the chosen fuel cannot fit next to a different fuel (or quality) already in the machine's fuel slots, the whole request is refused with a message rather than silently shortened.
- For a built machine the request tops the slot up to the chosen amount (minus what is already in it), rather than adding the whole amount on top.
