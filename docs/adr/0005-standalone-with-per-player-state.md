# Standalone, with per-player and per-force state

Blueprint Primer knows nothing about Multi-Team Support or any other mod. It has no dependency in either direction and no remote interface. It sits beside MTS without trouble because all of its state is scoped correctly, not because of special-casing.

The 1.1 version kept the preferred fuel in one global shared by every player on the server. On any multiplayer map, let alone a multi-team one, that is a bug.

## Consequences

- Remembered choices (last fuel per fuel category) live in `storage.players[player_index]`.
- Recipe availability is read from the acting player's force; fuel choice depends only on the burner and prototypes. If the target's force stops matching the player's (a team switch mid-window), the window closes.
- Old 0.1.x records in `storage.players` are migrated on load, so a 1.1 save that had the old mod keeps working, and the old top-bar button is removed.
- The mod adds nothing to the top bar or the left GUI flow. Its only persistent UI is a shortcut-bar button, which players can hide in vanilla.
