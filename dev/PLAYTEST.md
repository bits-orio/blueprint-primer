# Playtest checklist

GUI and selection behaviour the headless tests cannot reach (no players exist headless). Run it in a sandbox or editor map with a roboport, construction robots and a storage chest stocked with ore, plates and coal. Do one pass with base only and one with Space Age + Quality.

Each line is an action, then the expected result.

## Entry points

- [ ] Shortcut bar: the primer button shows its icon, and its tooltip names ALT + P.
- [ ] Click the button: the primer tool is in the cursor. Click again: it is gone.
- [ ] Click the recipe slot: the picker opens with vanilla-style group tabs; unresearched recipes (steel plate early on) sit on red slots. Pick one: the slot turns red with the "not unlocked" sign, and the note explains. On a built furnace Request is disabled; on a ghost it stays enabled; Blueprint always works.
- [ ] Drag the tool: only machines and plain chests light up while dragging. Over a row of one kind: all are outlined (copy colour), the title reads "Prime N × <machine>", a totals line appears once a recipe is set, Request primes every one (built ones topped up), Blueprint takes the whole dragged area with them primed. Over mixed kinds: the kind nearest the middle wins, the others are outlined in red, and flying text above the drag says one kind at a time. A drag over one machine shows no hint.
- [ ] With the tool, click a furnace: the window opens and the tool has left the cursor. Click bare ground: the tool stays in hand.
- [ ] Hover a furnace and press ALT + P: its priming window opens. Hover bare ground and press ALT + P: the tool is in the cursor.
- [ ] Hover a rocket silo and press ALT + P: flying text says this kind of crafting machine cannot be primed, and the cursor is unchanged. Hover a tree: the tool is toggled, with no message.
- [ ] Hold an item that cannot be put away (full inventory) and press the shortcut: "Empty your cursor first."
- [ ] Rebind the input under Settings > Controls: the shortcut tooltip shows the new key.

## Selection

- [ ] Click a stone furnace ghost, then a built furnace: each opens its window. This is the check that ghosts are selectable (`entity-ghost` flag).
- [ ] Drag across three furnaces: the one nearest the centre of the drag opens. Shift-drag does the same.
- [ ] Click a belt: flying text says it cannot be primed. Drag over empty ground: "No machine or chest here to prime."
- [ ] Base + Quality without Space Age: click a recycler: "This kind of crafting machine cannot be primed." With Space Age it opens as a furnace offering scrap recycling.
- [ ] Multiplayer, second force: the other force's machines are not selected.

## Window

- [ ] Title reads "Prime Stone furnace". The window opens centred, drags by its title bar and by the gap between the two bottom buttons, and closes with the X, with E and with Escape.
- [ ] It looks native: a shallow inner panel, slot-style icons, a green Request button. Nothing is added to the top or left GUI.

## Recipe and output

- [ ] Stone furnace ghost, pick iron plate: 25 iron ore, output 25, fuel 2 coal, "Minimum: 2".
- [ ] Pick a recipe that is not researched yet: flying text, and the chooser snaps back. Right-click to clear it: it snaps back too.
- [ ] Built assembler with a recipe: the chooser is locked, and its tooltip says why (change it in the machine's own window). A built furnace that has smelted iron opens preset to iron plate, and its chooser is locked while it is still smelting and free once it is idle.
- [ ] Space Age: a stone furnace smelting normal iron ore, window open; feed it uncommon ore until it switches, then press Max: "This machine's recipe changed", and the ingredient icon now carries the uncommon badge like the output icon.
- [ ] Space Age: an idle furnace whose last ore was uncommon opens on that recipe at normal quality (no badge), and picking copper plate requests normal copper ore.
- [ ] Drag the slider: the output field, ingredient counts and fuel follow live and stop at the cap (50 for iron plate in a stone furnace).
- [ ] Electronic circuit in an assembler: the cap is set by the tighter slot (66 crafts, 198 cables).
- [ ] Copper cable: type 5 and press Enter, and it becomes 6 (whole crafts). Type 999 and press Enter: it clamps to the cap. Clear the field and press Enter: the last value returns.
- [ ] Half and Max set half the cap and the cap.
- [ ] Assembler ghost with no recipe: the slider, Half and Max are greyed out, and the status line says "Pick a recipe to prime."
- [ ] Artillery turret recipe (cap of 1): the slider is disabled at 1. Satellite (base only; 100 low density structures of stack 50): the cap is 1 craft, and after Request robots deliver all 100 into one slot.
- [ ] Chemical plant: lubricant and the cracking recipes are not in the chooser (nothing a robot could deliver).

## Fuel

- [ ] Type 9 into the fuel field: it stays 9 and the minimum note is unchanged. Move the slider: fuel returns to the estimate.
- [ ] Switch to solid fuel: the count drops. The next furnace opens with solid fuel. A second player still gets coal.
- [ ] Electric furnace: no fuel row.
- [ ] Boiler, burner mining drill, locomotive: only the fuel row, with a slider up to what the fuel slots hold (a boiler holds 50 coal, a locomotive 150).
- [ ] Space Age: a biochamber defaults to a nutrient fuel, not coal. A biochamber ghost carrying four speed-module requests shows a higher "Minimum" than a bare one.
- [ ] Space Age: a captive biter spawner opens a fuel-only window (food fuel, no recipe row).
- [ ] Space Age: a biochamber (ghost and built) set to light oil cracking opens a fuel-only window with nutrients. Request leaves it on cracking; Blueprint stamps copies still on cracking, with nutrients requested.
- [ ] Space Age: a built stone furnace holding uncommon coal preselects coal and tops it up with uncommon coal. Switch to solid fuel and back to coal: still uncommon, and Request succeeds.
- [ ] Built stone furnace burning wood: the window preselects wood. Switch to coal and press Request: "The fuel slots hold a different fuel..." and the window stays open.

## Request and Blueprint

- [ ] Request on a ghost: the window closes and "Requested" appears. After robots build it, the furnace holds exactly the requested ore and coal.
- [ ] Built furnace already holding 10 ore, 25 requested: robots bring 15. A pending module request on an assembler survives priming.
- [ ] Built furnace already holding everything the window asks for: Request says "Already holds that much. Nothing requested."
- [ ] Prime a ghost furnace with Max and solid fuel, then reopen it: the window shows the same count and solid fuel, and Request changes nothing. A built furnace that has never smelted reopens on the recipe just requested.
- [ ] Built assembler with no recipe: pick one, then have a second player (or `/c`) set a different recipe on it while the window is open, then press Request: "This machine's recipe changed" appears, the window stays open showing the new recipe locked, and nothing is requested until Request is pressed again.
- [ ] Blueprint: the cursor holds a one-machine blueprint labelled with the output and count. Stamp it three times: each copy carries the same request.
- [ ] Prime a locomotive standing on an east-west rail and press Blueprint: the stamped locomotive lines up with the rail, not north.

## Chests

- [ ] Hover a wooden chest that feeds nothing and press ALT + P: the window opens in Items mode with no rows, and `NO_ITEMS` shows with both buttons disabled.
- [ ] Build an inserter feeding ore from a chest into a furnace set to a recipe, then ALT + P the chest: it opens in Recipe mode already on that recipe, at half the chest cap. Feed two furnaces on different recipes from one chest: it opens in Items mode instead.
- [ ] Drag the tool over a row of chests: all light up, are outlined, and the title reads "Prime N × <chest>". Drag a row that clips both chests and furnaces, centred on the chests: the furnaces are not skipped or outlined at all; centred on the furnaces, the chests are not either.
- [ ] Click a storage or requester chest, or hover one with ALT + P: "Only plain chests can be primed" (`LOGISTIC_CHEST`), not "nothing to prime".
- [ ] Recipe mode: pick a recipe with 2+ ingredients; the slider's cap matches a hand-count of what a fresh chest of that size can hold in whole stacks. Half and Max set half and all of it.
- [ ] Switch a chest with a recipe chosen from Recipe to Items: rows appear, one per ingredient, at the recipe's amounts. Switch back to Recipe: the recipe and craft count are unchanged.
- [ ] Items mode: pick an item in the trailing chooser: a new row appears at Half. Pick the same item and quality again in another row: `ITEM_LISTED`, no second row. Fill the chest, then pick one more item: `CHEST_NO_ROOM`, no row added.
- [ ] On a row: Half, Max, drag the slots slider, and type an exact count into the items field; each updates the other two, and none can push the row past what the other rows leave.
- [ ] Built chest already holding 20 stacks of stone: prime 16 slots of plate. `CHEST_FULL` shows, Request is disabled, Blueprint stays enabled. Lower it to 12 slots: the full note is replaced by the top-up reminder and Request re-enables; pressing it tops up exactly the empty slots.
- [ ] Prime a ghost chest in Items mode with three rows, Request, then reopen it: the same three rows and counts come back. Do the same in Recipe mode on a chest that feeds a machine on that recipe: the same recipe and craft count come back, and Request again rewrites the same plan ("Requested"; compare the item-request markers before and after). An unfed chest reopens in Items mode with the recipe's amounts as rows.
- [ ] Pick an unresearched recipe on a chest: the note reads the chest wording (`CHEST_NOT_RESEARCHED`), Request still works (robots wait for the research; a chest is never a "built furnace" refusal).
- [ ] Copy-paste a built, primed chest: the copy carries the same rows or recipe. Shift+click paste chest settings onto another chest of the same kind: it takes the source's mode and rows, fitted to its own size.
- [ ] Drag-prime three chests, set items-mode rows, Request: the group window shows a totals line with quality tags where relevant, and all three chests get the same plan. Blueprint the dragged area: any other already-primed machine or chest caught in it keeps its own request too.
- [ ] Blueprint a chest with a bar set partway: the stamped copy keeps the bar.
- [ ] Put foreign items in the middle chest of a row, then drag-prime the row with a row of plates too big for that chest: the status line says the middle chest will be skipped, Request stays enabled, and pressing it reports how many chests took it, naming the full chest. The same drag over a row of chests of mixed quality outlines the other-quality chests in red and says one kind and quality at a time.

## Robustness

- [ ] Mine the machine with its window open (a second player or `/c` may be needed), then press Max or Request: the window closes with "That machine or chest is gone."
- [ ] With the window open, die (`/c game.player.character.die()`), or change force (`/c game.player.force = game.create_force("x")`): the window is gone afterwards, not stranded on screen.
- [ ] With the window open, become a spectator without changing force (`/c game.player.set_controller{type = defines.controllers.spectator}`): the window is gone. As a spectator, ALT + P over a furnace does nothing. Open Space Age remote view with the window open: if the window stays on screen, E and Escape still close it.
- [ ] Let robots build the ghost while its window is open, then press Request: it tops up the built machine.
- [ ] Save and reload with a window open: it still works.
- [ ] Enable or disable another mod on that save: open windows are gone after loading, with no error.
- [ ] If a Factorio 1.1 save that had BlueprintPrimer 0.1.1 is available, load it in 2.0: no script error, the old "Prime Blueprint" top-bar button and its left frame are gone, and priming a stone furnace works.
- [ ] Two players prime different machines at the same time: no cross-talk and no desync.
