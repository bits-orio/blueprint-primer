# A drag primes every machine of one kind

ADR-0001 made priming strictly one machine at a time: a drag over several machines primed only the one nearest the middle. Playtesting showed that is needlessly narrow for the common case (a column of identical furnaces wants the identical request), while the reason for the rule still holds for mixed selections: fuel use differs between kinds of machine (a steel furnace burns half what a stone one does per craft), so one window cannot honestly carry one set of numbers for both.

So a drag primes **every selected machine of the same prototype** as the one nearest the middle, which together form its **group**. Machines of any other kind in the drag are skipped, and the player is told.

- **Kind** means the machine's prototype (stone furnace and steel furnace are different kinds), and the same per-entity kind the window uses (a biochamber cracking oil is fuel-only, so it is not grouped with one making bioflux).
- **One window** carries the numbers per machine; its title reads "Prime 6 × Stone furnace", and a status line gives the totals robots will deliver.
- **Request** applies the window's priming to every member through the same path Shift+click paste uses (ADR-0008): each machine is topped up for what it already holds and gets its own fuel estimate unless the fuel amount was typed. Members that cannot take it (a built assembler already on another recipe, a built furnace for an unresearched recipe) are skipped and counted in the message.
- **Blueprint**, after a drag over two or more machines of the kind, takes the **whole dragged area** (belts, inserters, poles and other-kind machines as vanilla would copy them) with every group member primed. A single machine still gives the one-machine primed blueprint of ADR-0007.

## Visual hints

The engine draws the drag's highlight and offers no event while dragging, so boxes cannot change colour by kind mid-drag. Instead:

- The tool's selection modes carry an `entity_filters` list, built in `data-final-fixes.lua`, of every crafter and burner entity; a probe on 2.0.77 showed such filters also match ghosts. Only primable machines light up while dragging, and vanilla's own counter by the cursor shows how many of each kind are inside.
- On release, group members are outlined in vanilla's copy colour and skipped machines of other kinds in vanilla's red "not allowed" boxes, for this player only, briefly. If anything was skipped, flying text names what is being primed and asks for one kind at a time.

## Consequences

- Supersedes ADR-0001's "nearest the centre wins" for drags. The hover hotkey and a click still prime exactly one machine.
- The title goes back to Blueprint Primer (ADR-0010 amended): priming a whole build into a blueprint is now a real feature.
