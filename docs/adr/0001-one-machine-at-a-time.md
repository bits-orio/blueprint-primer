# Priming works on one machine at a time

The 1.1 version of Blueprint Primer primed a whole blueprint in one go: every assembler got a recipe, every burner got fuel, and a single picker chose the recipe for all of them. That was the wrong unit. A blueprint of several machines rarely wants one quantity for all of them, the picker only knew the first entity's recipes, and the result was a large GUI for a small job.

The real, recurring problem is narrower: vanilla 2.0 can request items into a machine, but only in whole stacks. Smelting 10 ore should need 10 ore and a couple of coal, not a stack of each. So the unit of work is one **target**, and the product is an exact **primed request** on it.

## Consequences

- The primer tool resolves a click or drag to exactly one target. If a drag covers several eligible machines, the one nearest the centre of the dragged area wins.
- Multi-machine blueprints are out of scope. A **primed blueprint** holds exactly one machine; stamping it many times is how a player primes a row.
- The internal name stays `BlueprintPrimer` (immutable, and it keeps the existing portal page and install base) even though the mod now primes machines as much as blueprints.
