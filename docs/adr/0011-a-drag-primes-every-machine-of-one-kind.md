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

**Amended (0.3.4):** ADR-0012 adds a second family, chests, beside machines. The rule above generalises directly: "kind" becomes "family" at the top of the decision (which family does the drag's primary belong to), and stays "prototype and per-entity kind" for what actually joins the group, so a drag still never mixes a stone furnace with a steel one, or a wooden chest with an iron one. Entities of the *other* family are not skipped and outlined red; they are ignored as if the tool could not see them at all, since a machine's and a chest's numbers have nothing in common to warn about mixing (a drag centred on a furnace row that clips its output chests primes the furnaces with no red boxes on the chests, and the other way round). `target.is_machine` keeps its old meaning, machine family only; the new `target.family` is what selection and the tool actually ask. A chest also carries a **quality**, which changes its slot count the way nothing about a machine's quality changes its recipe slots; so a chest group additionally requires the same quality as the primary, and a chest of another quality is skipped and outlined red like any other kind mismatch, even though its prototype and kind both match. Machines keep grouping across qualities, since a machine's cap depends only on its recipe.
