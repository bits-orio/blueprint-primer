# The mod is titled Machine Primer

"Blueprint Primer" promised what the 1.1 version did (prime a whole blueprint) and playtesting 0.3.0 showed the name now misleads: the tool deliberately primes one machine at a time (ADR-0001), and copies and settings paste spread that priming (ADR-0008). A player reading "Blueprint Primer" in the browse list expects it to take a complex build's blueprint and fill every machine in it.

The display title is therefore **Machine Primer - exact item requests**: the name says one machine, keeps the "primer" word the game already shows (the primer tool, "Prime Stone furnace"), and the tail carries the words people search with. The internal name stays `BlueprintPrimer`: it is immutable, and the portal URL, saves and any dependency key off it.

## Consequences

- Title, portal copy, README, glossary and thumbnail (MP) say Machine Primer. The README and portal Status say "formerly Blueprint Primer" once, so existing users recognise it.
- The ADRs keep the old name where they describe history.
- Search: "blueprints" stays in the summary and "Blueprint" in the internal name, so nothing that found the mod before is dropped. The descriptive title tail is a measured bet, per the house search rules: re-run rank.py after the portal sync and revert the tail if it costs more than it wins.
- The GitHub repository keeps its `blueprint-primer` path for now; renaming it (GitHub redirects the old URL) is a separate, optional step.
- **Amended (0.3.1):** the display title is **Blueprint Primer - exact item requests**. ADR-0011 lets a drag prime every machine of one kind and take the whole dragged area as a primed blueprint, so the old name is accurate again; the "exact item requests" tail stays for search. The thumbnail mark returns to BP.
