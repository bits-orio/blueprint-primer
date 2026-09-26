# Machine Primer — design contract

The vocabulary is in `CONTEXT.md`; the decisions and their reasons are in `docs/adr/`. This file is the module contract: what each file owns and the exact interface between them. Factorio 2.0 (tested against 2.0.77), Space Age optional.

## Engine facts this design stands on

Proven by the headless spike (`dev/run-spike.sh`, all six cases pass):

- `InventoryPosition.count` below a stack is honoured end to end: robots deliver exactly that count, via a ghost's `insert_plan`, via an `item-request-proxy` on a built entity (`surface.create_entity{name="item-request-proxy", target=e, position=e.position, force=e.force, modules=plans}`; the field is `modules` at creation, `insert_plan` afterwards), and via a blueprint entity's `items` placed with `build_blueprint`.
- `set_recipe(name, quality)` works on an assembling-machine ghost, and an assembler's `crafter_input` stack indices follow the recipe's item-ingredient order (0-based).
- Fuel energy for N crafts = `N × recipe.energy / crafting_speed × energy_usage_per_tick × 60 / effectivity`. A stone furnace needs exactly 4 coal for 50 iron ore; 3 coal smelts 41. A run also costs a small fixed start-up energy (~1 tick of usage), which is why the estimate adds one second of usage before rounding up (ADR-0004).

Proven by `bp-test` (`dev/run-tests.sh`):

- A crafter's input slot holds one craft's worth even when that is more than a stack: robots deliver 25 of a stack-10 item into one `crafter_input` slot, via a ghost's `insert_plan` and via a proxy (delivery.g). This is the satellite's case (100 low density structures of stack 50).
- `LuaEntity.crafting_speed` = `get_crafting_speed(quality) × (1 + speed_bonus)`; `speed_bonus` and `consumption_bonus` include modules and beacons.
- A car's (tank's) `orientation` is readable on the built entity and on its ghost, and a blueprint entity's `orientation` survives `build_blueprint`.
- `get_max_energy_usage(quality)` equals `energy_usage` at every quality for burner crafters, so quality reaches the estimate only through crafting speed.
- `consumption_bonus` reads back clamped at the engine floor: a biochamber holding four efficiency modules (-1.2) reports -0.8.
- A blueprint of a built machine with a pending item-request-proxy (`create_blueprint`, the same set-up `on_player_setup_blueprint` reports) keeps the proxy's `fuel` and `crafter_modules` positions and drops its `crafter_input` ones; a ghost keeps its whole plan; a machine whose items were delivered carries nothing. The returned mapping (blueprint entity index -> source entity) covers every blueprint entity (ADR-0008).
- Insert-plan stack indices are inventory slots, not map positions: a flipped assembler's blueprint (`mirror = true`) stamps a ghost with the same `crafter_input` stack indices.

From the 2.0.77 docs:

- Use `defines.inventory.crafter_input`, `crafter_modules` and `fuel` (the furnace_/assembling_machine_ names are deprecated aliases).
- `LuaEntityPrototype.get_crafting_speed(quality)`, `.energy_usage` (J/tick), `.burner_prototype` (`effectivity`, `fuel_inventory_size`, `burnt_inventory_size`, `fuel_categories`), `.fixed_recipe`, `LuaItemPrototype.fuel_value`, `.fuel_category`, `.burnt_result`, `.module_effects` (normal-quality figures; quality strengthens a module's bonus, never its penalty).
- Furnaces have no settable recipe (`set_recipe` is AssemblingMachine-only; furnace BlueprintEntity has no `recipe` field). A furnace's recipe is implied by what is requested into it. `get_recipe()` / `previous_recipe` read a built furnace's current or last recipe.
- Car, locomotive and wagon BlueprintEntities carry `orientation` (RealOrientation), not `direction`.
- A quality-N recipe consumes quality-N ingredients; request ingredients at the recipe's quality. Fuel is requested at normal quality, unless a built target already burns that fuel at another quality: a stack never mixes qualities, and fuel value does not depend on quality (`LuaItemPrototype` has quality bonuses only for a vehicle fuel's acceleration and top speed).
- `ItemPrototypeFilter` supports `{filter = "fuel-category", ["fuel-category"] = <name>}`; `RecipePrototypeFilter` supports `has-ingredient-item` with no `elem_filters`. `prototypes.get_*_filtered` return a LuaCustomTable (use `#` or `pairs`, not `next`).
- `LuaEntity.item_request_proxy` returns an existing proxy for a built entity; write its `insert_plan` instead of creating a second proxy.
- `on_gui_closed` is not raised when `player.opened` is cleared by the player dying, disconnecting or becoming a spectator. A spectator has no `cursor_stack`.
- `LuaItemPrototype.get_module_effects(quality)` gives a module's effects at a quality; `LuaEntity.item_request_proxy.removal_plan` lists what robots will take out (a module swap's old modules).
- `get_blueprint_entities`/`set_blueprint_entities` drop rolling-stock connections before 2.0.74 (engine changelog), so copy.lua's round trip needs `base >= 2.0.74`.
- A 1.1 save loads in 2.0 with `global` carried over as `storage`; GUI elements a mod created survive an upgrade of that mod.
- Stone and steel furnaces and the biochamber have one fuel slot; locomotives three, tanks and heating towers two.

## Layout

```
info.json  changelog.txt  LICENSE  README.md  thumbnail.png
link-mod.sh                   -- symlink the repo into the Factorio mods folder (never shipped)
.luarc.json                   -- Lua language server settings (never shipped)
data.lua                      -- requires prototypes/*
control.lua                   -- event wiring only, no logic
prototypes/tool.lua           -- the primer tool (selection-tool)
prototypes/shortcut.lua       -- shortcut-bar button + custom input
scripts/const.lua             -- every shared name and constant
scripts/state.lua             -- storage layout, init and 0.1.x migration, per-player records
scripts/target.lua            -- resolve an entity into a Target (re-exports target_recipe)
scripts/target_recipe.lua     -- which recipes a Target takes, which it is on, whether it is locked, which are researched
scripts/pending.lua           -- read the request already waiting on a Target
scripts/effects.lua           -- a Target's module and beacon factors on draw and speed
scripts/craft.lua             -- recipe math: per-craft amounts, slot limit and cap, output unit
scripts/fuel.lua              -- fuel estimate, capacity, default-fuel ranking
scripts/fuel_tier.lua         -- how early each item becomes obtainable (default-fuel ranking)
scripts/request.lua           -- build insert plans; write them onto a target
scripts/blueprint.lua         -- put a primed blueprint in the cursor
scripts/copy.lua              -- on_player_setup_blueprint: a copy of a primed built machine is primed like it
scripts/carried.lua           -- the Priming a primed machine carries into a copy or a settings paste
scripts/paste.lua             -- on_entity_settings_pasted: settings paste carries a primed request
scripts/tool.lua              -- selection / shortcut / hotkey handlers -> open window
scripts/gui/names.lua         -- every element name in the window
scripts/gui/priming.lua       -- the Priming record's rules (pure state, no GUI access)
scripts/gui/reopen.lua        -- preset a new Priming from the target's pending request
scripts/gui/window.lua        -- build and destroy the priming window
scripts/gui/view.lua          -- fill the window's numbers from a Priming
scripts/gui/events.lua        -- GUI event handlers
scripts/gui/legacy.lua        -- remove the GUI 0.1.x left behind
locale/en/blueprint-primer.cfg
graphics/                     -- generated by tools/gen_*.py
tools/                        -- pack.sh, gen_*.py, portal_meta.json and the portal sync/lint/check scripts (never shipped)
dev/                          -- spike, headless test and GUI smoke mods and runners (never shipped)
docs/                         -- ADRs, portal.md (never shipped)
```

Files stay under ~200 lines, functions under ~25 (house Lua style). No `on_tick`. Every module returns one table.

## Shared names (`scripts/const.lua`)

`const.lua` is authoritative; this is what it holds.

```lua
const.MOD            = "BlueprintPrimer"
const.TOOL           = "bp-primer-tool"          -- selection-tool item
const.SHORTCUT       = "bp-primer-shortcut"      -- shortcut, action = "lua"
const.INPUT_PRIME    = "bp-primer-prime"         -- custom input, ALT + P
const.GUI_PREFIX     = "bp_primer_"              -- every GUI element name starts with this
const.WINDOW         = "bp_primer_window"
const.CRAFTER_TYPES  = { ["assembling-machine"] = true, ["furnace"] = true }
const.NEVER_DEFAULT_FUEL = { ["wood"] = true }
const.FUEL_MARGIN_SECONDS = 1
const.KIND_ASSEMBLER = "assembler"
const.KIND_FURNACE   = "furnace"
const.KIND_FUEL_ONLY = "fuel-only"
const.CRAFTING_MACHINE_TYPES = { ["assembling-machine"], ["furnace"], ["rocket-silo"] }  -- = true each
const.ORIENTED_TYPES = { car, locomotive, cargo-wagon, fluid-wagon, artillery-wagon }    -- = true each
const.NORMAL_QUALITY   = "normal"
const.GHOST_TYPE       = "entity-ghost"
const.PROXY_NAME       = "item-request-proxy"
const.TICKS_PER_SECOND = 60
const.FLOAT_EPSILON    = 1e-9        -- slack when rounding an energy ratio up
const.UNREACHABLE_TIER = math.huge   -- fuel_tier of an item nothing produces
const.MIN_CONSUMPTION_FACTOR = 0.2   -- engine floor on modules' and beacons' draw effect
const.MIN_SPEED_FACTOR       = 0.2   -- engine floor on their speed effect
const.REASON = {                     -- `false, reason` and priming.blocker; locale keys
  INVALID, OTHER_FORCE, NOT_PRIMABLE, UNSUPPORTED, TARGET_GONE, RECIPE_MISMATCH,
  RECIPE_NOT_ALLOWED, CURSOR_BLOCKED, FUEL_SLOT_TAKEN,
  NO_FUEL, PICK_RECIPE, RECIPE_NOT_PRIMABLE, CAP_ZERO, SPECTATOR,
}
const.NOTICE = { REQUESTED, ALREADY_STOCKED, RECIPE_CHANGED }  -- `true, notice`; locale keys
```

## Data types

**Target** (built by `target.from_entity`, never stored across saves except inside `storage.players[i].priming`):

```lua
{
  entity      = LuaEntity,           -- the ghost or the built entity
  is_ghost    = boolean,
  name        = string,              -- inner prototype name (ghost_name for ghosts)
  prototype   = LuaEntityPrototype,  -- inner prototype
  quality     = string,              -- entity quality name
  kind        = const.KIND_ASSEMBLER | const.KIND_FURNACE | const.KIND_FUEL_ONLY,  -- per entity, see from_entity
  burner      = LuaBurnerPrototype | nil,
  surface     = LuaSurface, position = MapPosition,
  direction   = defines.direction | nil,   -- everything but ORIENTED_TYPES
  orientation = RealOrientation | nil,     -- ORIENTED_TYPES only
  force       = LuaForce,
}
```

**Priming** (the window's state; lives in `storage.players[i].priming` so it survives save/load):

```lua
{
  target      = Target,
  recipe      = string | nil,       -- nil for fuel-only, or a crafter with nothing chosen yet
  quality     = string,             -- recipe quality: target_recipe.current's quality, else "normal"; never changed by the window
  crafts      = integer,            -- craft count (crafters); >= 1 once a recipe is chosen and cap >= 1, else 0
  fuel        = string | nil,       -- fuel item (burner targets only)
  fuel_quality = string,            -- "normal", or the quality a built target already burns this fuel at
  fuel_count  = integer,            -- fuel items to request
  fuel_edited = boolean,            -- true once the player typed a fuel amount; cleared when crafts change
}
```

## Module interfaces

### state.lua
- `state.init()` — ensures `storage.players`; migrates 0.1.x storage (drops each record's `max_stack` and the global `storage.preferred_fuel`, backfills `fuel_by_category`). Called from on_init and on_configuration_changed.
- `state.player(player_index)` → the record `{ fuel_by_category = {}, priming = nil }`, created on demand; a 0.1.x record is backfilled on every read.
- `state.remove(player_index)` — on_player_removed.

### target.lua
- `target.from_entity(entity, force)` → `Target` or `nil, reason_locale_key`. Rejects: invalid, other force, not a crafter and has no burner (`NOT_PRIMABLE`), crafter of a type outside `CRAFTER_TYPES` (`UNSUPPORTED`). A crafter with no primable recipe at all (`target_recipe.any_primable`) is fuel-only if it has a burner (the captive biter spawner) and `UNSUPPORTED` otherwise (the recycler without Space Age). A burner crafter whose own recipe has no item ingredient (`target_recipe.on_fluid_only`: a Space Age biochamber cracking oil) is fuel-only too, so its fuel can be primed and its recipe is never overwritten; the kind is therefore per entity, fixed when the Target is built. Ghost handling uses `entity.ghost_name`, `entity.ghost_prototype`, `entity.quality`. Records `orientation` for `ORIENTED_TYPES`, `direction` for everything else.
- `target.revalidate(t)` → `true` if `t.entity` is still valid. If a ghost was revived meanwhile, finds the built entity (same name, position, force) and rewrites `t.entity` / `t.is_ghost`; returns false if neither exists.
- `target.inventory_count(t, inventory_define, item, quality)` → items already inside a built target (0 for ghosts).
- `target.current_recipe`, `target.allows_recipe`, `target.recipe_filters`, `target.recipe_locked`, `target.recipe_unlocked`, `target.recipe_deliverable`, `target.recipe_candidates` — re-exported from target_recipe.lua (below).

### target_recipe.lua (never requires target.lua)
- `current(t)` → `name, quality` or `nil`. Assembler (ghost or built): `get_recipe()`, else the prototype's `fixed_recipe`. Built furnace: `get_recipe()`, else the recipe implied by its proxy's pending crafter_input request, else `previous_recipe`'s name at normal quality (the window has no quality control, so one stray uncommon ore must not set the quality of every later pick). Ghost furnace: the recipe implied by its own crafter_input insert plan (`pending.plans`), else nil. The implied recipe is the first allowed recipe, in inventory order, that takes the requested item.
- `allows(t, recipe_name)` → boolean: recipe exists for the force, `enabled`, not hidden, not a parameter, in one of the prototype's crafting categories (`has_category`), and with at least one item ingredient (exactly one for a furnace).
- `filters(t)` / `filters_for(prototype)` → recipe prototype filters: (category c1 AND NOT hidden AND has-ingredient-item) OR (c2 …).
- `candidates(prototype)` → the recipe names the picker offers, in inventory order: `filters_for` minus blueprint-parameter recipes, and for a furnace only single-item-ingredient ones. Memoised per prototype name. Researched or not (ADR-0009).
- `unlocked(t, name)` → the force has researched it. `deliverable(t, name)` → false only for a built furnace and an unresearched recipe: a furnace accepts only items for unlocked recipes, so the engine would drop that request. `allows` no longer checks research.
- `on_fluid_only(t)` → whether the recipe the machine is set to (`get_recipe()` on an assembler, ghost or built, or on a built furnace) has no item ingredient.
- `any_primable(prototype)` → whether `filters_for(prototype)` matches any recipe; memoised per prototype name (a pure function of prototypes, so multiplayer-safe).
- `locked(t)` → whether the window may not choose a recipe (ADR-0007): true for an assembler with a `fixed_recipe`; false for ghosts and fuel-only targets; for a built assembler or furnace, `entity.get_recipe() ~= nil`. Request refuses exactly what this locks.

### pending.lua
- `pending.plans(t)` → the request waiting on a target: a ghost's `insert_plan`, or a built entity's `item_request_proxy.insert_plan`, or `{}`.
- `pending.count(plans, inventory, name, quality)` → items of that id requested into that inventory, all stacks.
- `pending.removals(t)` → what a built entity's proxy will take out (`item_request_proxy.removal_plan`), or `{}` (always for a ghost).
- `pending.items_in(plans, inventory)` → `{ name, quality, count }` per plan with a position in that inventory, in plan order.
- `pending.within(plans, inventory)` → the plans cut down to their positions in that inventory, plans left empty dropped.

### effects.lua
- `effects.consumption_factor(t)` → `max(MIN_CONSUMPTION_FACTOR, 1 + live consumption_bonus + pending)`; `effects.speed_factor(t)` the same with `speed_bonus` and `MIN_SPEED_FACTOR`. Live bonuses (modules and beacons) are a built machine's; a ghost has none. Pending, crafters only: plus the normal-quality effects of modules requested into `crafter_modules` (`pending.plans`), minus the effects at their own quality of modules a proxy will remove (`pending.removals`). The live bonus reads back clamped, so a removal from a clamped bonus over-estimates, the safe direction.

### craft.lua (pure prototype math, no LuaEntity access)
- `craft.ingredients(recipe_name)` → array in recipe order of `{ name, type = "item"|"fluid", amount, stack_size (items only), slot (0-based among item ingredients) }`.
- `craft.slot_limit(ingredient)` → `max(stack_size, amount)`: the most one input slot is asked to hold (one craft's worth when a craft needs more than a stack).
- `craft.slot_cap(recipe_name)` → the largest crafts with every item ingredient within its slot limit: `min(floor(slot_limit / amount))`, so at least 1 for any recipe with item ingredients; `0` if it has none.
- `craft.output(recipe_name)` → `{ name, type, amount_per_craft }` for the main product (`main_product` or the only product) when its amount is deterministic; `nil` otherwise (the slider then counts crafts).

### fuel.lua
- `fuel.joules_per_craft(t, recipe_name)` → fuel joules one craft consumes in this target (quality-aware, effectivity-aware). The draw per recipe second is `max(1 / speed, effects.consumption_factor(t) / (speed × effects.speed_factor(t)))`, where `speed = get_crafting_speed(quality)`: live bonuses, plus pending module requests, minus pending module removals (effects.lua). Beacons around a ghost are not counted. The bare figure is the floor because a primed blueprint carries no modules.
- `fuel.estimate(t, recipe_name, crafts, fuel_item)` → integer ≥ 1: `ceil((crafts × J + margin) / fuel_value − FLOAT_EPSILON)`, `margin = energy_usage × max(1, effects.consumption_factor) × 60 × FUEL_MARGIN_SECONDS / effectivity`.
- `fuel.capacity(t, fuel_item)` → `fuel_inventory_size × stack_size`.
- `fuel.max_crafts(t, recipe_name, fuel_item)` → largest crafts whose estimate fits the capacity (`math.huge` when a craft costs no fuel).
- `fuel.accepts(t, item)` → item is not a parameter, has fuel_value > 0, its fuel_category is in the burner's categories, and it has no burnt result unless the burner has a burnt-result slot.
- `fuel.filters(t)` → `elem_filters` for `choose-elem-button{elem_type="item"}`: per burner category, (fuel-category c AND NOT hidden AND NOT is-parameter), OR-combined.
- `fuel.default(t, player_index)` → `item, quality`: for a built target, the first fuel already in its fuel inventory that `accepts`, at that stack's quality; else the remembered fuel for any of the burner's categories that `accepts`; else `fuel.earliest(t)`; both of those at normal quality.
- `fuel.quality_for(t, item)` → the quality of the first `item` stack in a built target's fuel inventory, else `"normal"`.
- `fuel.earliest(t)` → among accepted fuels, `NEVER_DEFAULT_FUEL` ranks after every other one (so wood is chosen only when nothing else is accepted): lowest tier first, where tier 0 = mined from a resource entity or produced by a recipe prototype that is enabled from the start, tier n = 1 + depth of the shallowest technology unlocking a recipe that produces it (depth = longest prerequisite chain); unreachable = `UNREACHABLE_TIER`. Ties broken by item `order`, then name. Prototype-only, not the force's research. Deterministic; the memo in fuel_tier.lua is derived from prototypes only.
- `fuel.remember(player_index, t, item)` — stores the choice under the item's fuel category, if `accepts`.

### request.lua
- `request.plans(t, priming, opts)` → `array[BlueprintInsertPlan], shortfall`. Plans for the ingredient and fuel inventories. `opts.top_up = true` subtracts what a built target already holds (never below 0; plans with count 0 are dropped). Ingredients go to `crafter_input` at their `slot`, at the recipe quality, each clamped to `craft.slot_limit`; fuel fills `fuel` stacks 0..n-1 one stack at a time, at `priming.fuel_quality`, skipping a built target's stack that holds another fuel (or this fuel at another quality); a top-up subtracts only what is held at that quality. `shortfall` is the fuel that found no room (0 unless such stacks leave too little).
- `request.apply(t, priming)` → `true, notice` or `false, reason_locale_key`. Revalidates the target. A fuel `shortfall` refuses everything (`FUEL_SLOT_TAKEN`), so a machine is never primed to run dry part-way. Recipe (never for a fuel-only target, whose recipe is left as it is): refused (`RECIPE_NOT_ALLOWED`) unless `target.allows_recipe`; nothing to do if the target is already on it at that quality; refused (`RECIPE_MISMATCH`, ADR-0007) if `target.recipe_locked`; otherwise an assembler (ghost, or built with no recipe) gets `set_recipe`, and a furnace needs nothing. Merge = keep every existing InventoryPosition (and `grid_count`) for any inventory we do not own (`fuel` always; `crafter_input` only on a target that is not fuel-only, since inventory ids are per entity type), replace ours, drop empty plans. Ghost: write `insert_plan`. Built target: write into `entity.item_request_proxy.insert_plan` if one exists (destroying it if the merged plan and its removal plan are both empty), else create a proxy; if the merged plan is empty, create nothing. `notice` is `REQUESTED`, or `ALREADY_STOCKED` when the top-up left nothing to request.
- `request.merge(existing, ours, owned)` → the merge above as plans: every position of `existing` outside the `owned` inventory set (and its `grid_count`) kept, every position of `ours` added, one plan per item and quality.
- Messages are locale keys; the caller prints them.

### blueprint.lua
- `blueprint.entity(t, priming)` → one BlueprintEntity at `{0,0}`: name, quality, `direction` or (vehicles) `orientation`, `mirror` if the source is mirrored, `recipe`/`recipe_quality` (the window's for an assembler; for a fuel-only assembler without a `fixed_recipe`, the source's live `get_recipe()`, so a cracking biochamber's copy keeps cracking; none for furnaces), `items = request.plans(t, priming, {top_up=false})`.
- `blueprint.write(stack, t, priming)` → turns any writable stack into the primed blueprint: that entity, a label naming the output and count in rich text, icons = machine + output.
- `blueprint.to_cursor(player, t, priming)` → `true` or `false, reason`. Refuses a player with no `cursor_stack` (`SPECTATOR`) before touching anything; otherwise clears the cursor (`CURSOR_BLOCKED` if it cannot), writes the blueprint there, and marks it `cursor_stack_temporary`, like a vanilla copy.

### copy.lua (ADR-0008)
- `copy.carry(entities, mapping, force, player_index)` → whether any BlueprintEntity changed. `mapping` is blueprint entity index -> source LuaEntity. Does nothing when `table_size(mapping) ~= #entities` (another mod reshaped the blueprint first). Per entity: skipped unless the source is valid, has the entity's name, is a built `CRAFTER_TYPES` machine with an `item_request_proxy` (checked first, since almost no copied machine has one; ghosts have type `entity-ghost` and vanilla already carries their plan), and `carried.priming` returns a Priming for it. Then `request.plans(p.target, p)` (full amounts, no top-up) is merged into `items` with `request.merge`, owning `crafter_input` and `fuel`, so modules stay as vanilla wrote them. No transform for mirrored or rotated sources: stack indices are slots.

### carried.lua (ADR-0008)
- `carried.priming(entity, force, player_index)` → the Priming a machine carries, or nil: a non-fuel-only Target with pending `crafter_input` positions, run through `priming.new` (so crafts come from pending plus contents, and fuel from what is pending or held, as a reopened window shows them), and no blocker. Shared by copy.lua and paste.lua.
- `copy.on_setup(event)` — `on_player_setup_blueprint`. The blueprint is the first set-up one of `player.blueprint_to_setup`, `event.stack` (on "select new contents" it can still hold the old contents), `player.cursor_stack` (a book gives its active blueprint, via `item_main` and `active_index`) and `event.record`; the mapping is `event.mapping.get()`. Writes back with `set_blueprint_entities` only if `carry` changed something, inside `pcall`; any missing piece leaves vanilla's blueprint as it is.

### paste.lua (ADR-0008)
- `paste.apply(source, destination, force, player_index)` → the destination Target once its request is written, else nil. The source must resolve (`target.from_entity` with `force`) to a crafter that is not fuel-only, with a pending `crafter_input` position (vanilla asks a built crafter only for fuel and modules), and whose `priming.new` has no `blocker`. The destination must be the same kind of Target and, if it burns fuel, take the source's fuel (`fuel.accepts`) if it has one; an electric destination takes the ingredients alone. Its Priming is `priming.new(to, player_index, from)`; it must have no `blocker`, and is written with `request.apply`, which also refuses a recipe the destination does not allow or has locked. Anything refused is left silently to vanilla's paste.
- `paste.on_pasted(event)` — `on_entity_settings_pasted` (after vanilla's paste, so an assembler already has the source's recipe). Applies with the player's force; if the player's window is open on the destination, it is reopened from the new request.

### tool.lua
- `target.is_machine(entity)` → whether the window could open for it, by prototype alone (the same kind rule `from_entity` uses); cheap enough for every entity in a drag.
- `tool.on_selected(event)` — resolve `event.entities` to the one Target nearest the centre of `event.area`, via `target.from_entity`; open the window, or show the nearest entity's refusal as flying text (`window.notify`). When the drag covered more than one machine (`target.is_machine`), the picked one gets a short-lived `highlight-box` (box type `copy`, this player only, `HINT_TICKS`) and the `ONE_MACHINE` notice, so the player sees that priming is one machine at a time.
- `tool.on_shortcut(event)` — toggles the primer tool: puts it in the cursor, or clears the cursor if the tool is already there. A player with no cursor (a spectator) gets nothing; a cursor that cannot be cleared shows `CURSOR_BLOCKED`.
- `tool.on_hotkey(event)` — does nothing for a spectator. If `player.selected` resolves to a Target, open the window for it. If it is refused as `UNSUPPORTED`, or as `OTHER_FORCE` while it would be primable on its own force, show that reason. Otherwise (nothing hovered, or nothing primable such as a chest or a tree) toggle the tool as the shortcut does.

### gui/priming.lua and gui/reopen.lua (pure state, no GUI access)
- `priming.new(t, player_index, carried)` → a Priming: the target's current recipe if allowed, with its quality; `fuel.default` (item and quality); a fuel-only target's fuel count at half `fuel.capacity`; then `reopen.preset` (or `reopen.carry` when `carried` is given), then settled (crafts clamped to `1 .. cap`, or half the cap when unset, or 0 when `cap < 1`; fuel follows the estimate unless typed).
- `priming.cap(p)` → `min(craft.slot_cap, fuel.max_crafts)`; 0 without a recipe. `priming.fuel_cap(p)` → `fuel.capacity`.
- `priming.per_craft(p)` → output units per craft (1 when the output is not deterministic); `priming.outputs(p)` → `crafts × per_craft`; `priming.estimate(p)` → `fuel.estimate` for the record, or nil for a fuel-only target, without a recipe or fuel, or below one craft.
- `priming.set_crafts`, `set_outputs` (rounds up to whole crafts), `set_fuel_count`, `set_recipe` (keeps `quality`), `set_fuel` (remembers the pick; `fuel_quality = fuel.quality_for`, so picking the fuel a built machine burns matches its quality), `preset_crafts(p, full)` / `preset_fuel(p, full)` (Half when `full` is false, Max when true).
- `priming.recipe_locked(p)` = `target.recipe_locked(p.target)`.
- `priming.sync_locked(p)` → true if the chooser is locked and the machine's recipe (or its quality) no longer matches the record; re-derives the recipe as `new` does and re-settles.
- `priming.blocker(p)` → why Request and Blueprint are disabled (`const.REASON.NO_FUEL`, `PICK_RECIPE`, `RECIPE_NOT_PRIMABLE`, `CAP_ZERO`), or nil.
- `reopen.preset(p)` — if the target already carries a pending request: crafts = whole crafts the planned item ingredients cover (requested + already inside, for a built target), taken whenever an ingredient or an accepted fuel is pending (a built machine whose ingredients arrived before its fuel reopens at the crafts inside, not half the cap); fuel = the first requested fuel the burner accepts, at its requested quality, with count = planned; `fuel_edited` set on a crafter when crafts < 1 or that count differs from the estimate. With nothing pending, the record is left as `new` made it.
- `reopen.carry(p, from)` — a settings paste: takes `from`'s recipe, quality, crafts, fuel item (at `fuel.quality_for` this target), fuel count and `fuel_edited`. Settling then clamps the crafts to this target's cap and re-estimates the fuel for this target unless it was typed.

### gui/window.lua, gui/view.lua, gui/events.lua, gui/legacy.lua
- One `screen` frame named `const.WINDOW`, auto-centred, draggable title bar with a close button; `player.opened = frame` so E / Escape close it (`on_gui_closed` destroys it and clears `priming`).
- Rows, top to bottom: title "Prime <machine>"; recipe slot (a `slot_button` sprite-button, `red_slot_button` with vanilla's `utility/crafting_machine_recipe_not_unlocked` sign laid over it when unresearched; disabled per `priming.recipe_locked`), which toggles the recipe picker (`gui/picker.lua`: an `inside_deep_frame` under the rows, built only while open — `target.recipe_candidates` grouped by item group into vanilla-style tabs, each an unnamed slot button tagged `{handler = names.pick, recipe}`, red when unresearched); ingredient icons with counts (`slot_button`-style sprite-buttons with `number`; fluids shown with a tooltip saying pipes deliver them); the output row — a slider in crafts (`1 .. cap`) plus a numeric textfield showing and accepting the output count, the output icon, and Half / Max buttons (disabled when `cap < 2`); the fuel row for burners (`choose-elem-button{elem_type="item"}` with `fuel.filters(t)`, a numeric textfield for the count, a caption with the estimate); a status line (the blocker; else a not-researched note — for a built furnace it explains why Request is disabled; else a top-up reminder on a built target); then a button row: Blueprint (left), Request (right, `confirm_button`).
- Fuel-only targets show only the fuel row, whose slider counts fuel items `1 .. fuel.capacity`, with Half / Max.
- `view.refresh(player, skip)` recomputes every number from `priming` and never rebuilds the frame; it rebuilds only the ingredient icons, when the recipe or its quality changes. `skip` names a text field the player is typing into, which keeps its text. A locked recipe chooser's tooltip says why it is locked. All handlers mutate `priming`, then call `view.refresh`.
- Before any handler runs, events revalidate the target and close the window if the player is now a spectator (`SPECTATOR`), it is gone (`TARGET_GONE`) or its entity is no longer on the player's force (`OTHER_FORCE`). If `priming.sync_locked` changed the record, the view refreshes with a `RECIPE_CHANGED` notice and the click is dropped, so Request never goes out for a recipe the player has not seen.
- Request and Blueprint close the window only on success, then show the returned notice; a refusal shows its reason and leaves the window open.
- `window.close_all()` runs on configuration change: stored prototypes may be stale, so every open window is dropped rather than migrated. `legacy.remove_gui()` runs there too and destroys 0.1.x's `blueprint_primer_button` (under `gui.top.mod_gui_button_flow` or `mod_gui_top_frame.mod_gui_inner_frame`) and `blueprint_primer_frame` (under `gui.left.mod_gui_frame_flow`), plus any of those containers left empty that this mod owns.
- `on_player_died`, `on_player_left_game` and `on_player_changed_force` close the window, because `on_gui_closed` is not raised when those clear `player.opened`. `on_player_controller_changed` closes it only when it is no longer `player.opened` (becoming a spectator by script, without a force change), so a switch that keeps it opened leaves it.
- The window is the only persistent GUI besides the shortcut. Nothing is added to `gui.top` or `gui.left`.

## Tests

`dev/run-tests.sh` runs headless (`--create` then `--benchmark`) in two mod sets — base only, and base + quality + space-age — with a `bp-test` mod that `require`s `__BlueprintPrimer__/scripts/*` and checks the module contracts, the Priming rules in `gui/priming.lua`, and robot delivery end to end. The test mod logs `BP_TEST PASS|FAIL <case>`; the runner exits non-zero on any FAIL or on a Lua error. `on_player_setup_blueprint` and `on_entity_settings_pasted` cannot be raised headless, so the tests call `copy.carry` (with the mapping `create_blueprint` returns) and `paste.apply`. Code that needs a player (the window, view and events, the cursor, `on_player_*` handlers, and those two handlers) cannot run headless: `dev/run-gui.sh` starts a graphical client on the `bp-gui-smoke` world and `dev/gui-drive.sh` drives it, and `dev/PLAYTEST.md` is the checklist.
