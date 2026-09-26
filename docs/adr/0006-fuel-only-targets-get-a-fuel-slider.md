# Fuel-only targets get a fuel slider, not a steam or mining calculator

Boilers, burner mining drills, burner inserters and locomotives burn fuel but run no recipe. A burner crafter with nothing to deliver is treated the same way. Space Age's captive biter spawner has a fixed recipe with no item ingredients, so fuel (food) is the only thing to prime. The same holds per machine, not just per prototype: a burner crafter whose current recipe has no item ingredients (a Space Age biochamber cracking oil) is primed for fuel only, and its recipe is left alone (a primed blueprint of it keeps the recipe). Their "output" is steam, ore or motion, whose demand depends on the rest of the factory, so there is no honest craft count to derive fuel from.

They still get priming: the same window shows only the fuel row, and the slider counts fuel items directly, from one up to what the fuel inventory holds.

## Consequences

- No steam, mining or distance math. Adding it later would be its own ADR.
- The fuel-only path shares the fuel chooser, default-fuel rule and request writing with crafting machines; it only skips the craft count.
