# Blueprint Primer: design contract

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
- A selection tool's `entity_type_filters` / `entity_filters` also match entity ghosts by their inner prototype (probed on 2.0.77 with a furnace-only filter: ghost and built furnaces lit up, an assembler ghost and a boiler did not), and vanilla then shows a per-kind count by the cursor while dragging. `LuaItemPrototype.get_entity_filters` returns an array of prototypes.
- `get_blueprint_entities`/`set_blueprint_entities` drop rolling-stock connections before 2.0.74 (engine changelog), so copy.lua's round trip needs `base >= 2.0.74`.
- A 1.1 save loads in 2.0 with `global` carried over as `storage`; GUI elements a mod created survive an upgrade of that mod.
- Stone and steel furnaces and the biochamber have one fuel slot; locomotives three, tanks and heating towers two.

Proven by the chest spike (headless probes, 2.0.77 and 2.1.17 identical unless noted):

- A chest ghost's `insert_plan`, a built chest's `item-request-proxy`, and a blueprint entity's `items` stamped by `build_blueprint` all deliver exactly per requested stack index into `defines.inventory.chest`, the same as a crafter's slots.
- `create_blueprint` over a chest ghost keeps its `insert_plan`; over a **built** chest with a pending proxy, `items` comes back nil. The same loss ADR-0008 found for a crafter's `crafter_input`, so the same fix applies (ADR-0008's amendment, ADR-0012).
- A passive provider chest's contents are drained by logistic robots even mid-delivery, and a requester chest with "trash unrequested" (or any request slot with a maximum) trashes primed items. Both measured directly; neither is a chest here (ADR-0012).
- An inserter's `pickup_position` and `drop_position` are readable on a built inserter and on a ghost from the moment it is placed; `pickup_target`/`drop_target` stay nil on a ghost forever, and nil on a built one until it first ticks. Direction does not say which way an inserter drops (a chest-west, machine-east inserter still reports `west`), so `feed.lua` always reads the positions, never direction. `find_entities_filtered{position = drop_position}` returns the machine or the entity-ghost standing there.
- `LuaEntityPrototype.get_inventory_size(defines.inventory.chest, quality)` scales with quality: wooden 16/20/25/30/40, iron 32/41/51/60/80, steel 48/62/76/91/120 (normal through legendary), equal to a built chest's own `#get_inventory(...)`.
- The bar does not stop a slot-targeted delivery. A position into a slot already holding another item is silently dropped (its proxy destroyed); a position over a stack is truncated to one stack; a partial stack of the same item and quality tops up. Filtered, custom-stack and weight-limited container inventories drop or truncate positions the same way (modded only), which is why they are excluded from `is_chest` entirely.
- A blueprint stamped over an existing built chest: vanilla adds a proxy with the blueprint's positions verbatim, the same collision `placement.lua`'s fresh-fill-from-the-top rule is chosen to avoid.
- `defines.inventory.chest == defines.inventory.fuel == 1`; `crafter_input == 2`. A single Target is never both a chest and a burner, so `request.owned`'s per-kind map never confuses the two.
- The `switch` element, `on_gui_switch_state_changed`, the `item-with-quality` elem type, `get_inventory_size`, `find_entities_filtered`, `LuaInventory.get_filter` and `get_inventory_filter` all exist with the same shape in both 2.0.77 and 2.1.17.
- `LuaEntityPrototype.fixed_recipe` reads back a `LuaRecipePrototype` on 2.1.17, where 2.0.77 gives a plain string; `target_recipe.lua`'s `name_of` reads either. 2.1 also refuses `category` on a `RecipePrototype` at the data stage ("got merged into `categories`"), so `bp-test`'s data.lua picks the field to set from `mods.base`'s major.minor.

## Layout

```
info.json  changelog.txt  LICENSE  README.md  thumbnail.png
link-mod.sh                   -- symlink the repo into the Factorio mods folder (never shipped)
.luarc.json                   -- Lua language server settings (never shipped)
data.lua                      -- requires prototypes/*
data-final-fixes.lua          -- requires prototypes/tool_filters (the drag lights up only machines and chests)
control.lua                   -- event wiring only, no logic
prototypes/tool.lua           -- the primer tool (selection-tool)
prototypes/shortcut.lua       -- shortcut-bar button + custom input
prototypes/tool_filters.lua   -- data-final-fixes: the tool's entity_filters (crafters, burners, chests)
scripts/const.lua             -- every shared name and constant
scripts/state.lua             -- storage layout, init and 0.1.x migration, per-player records
scripts/target.lua            -- resolve an entity into a Target, machine or chest (re-exports target_recipe)
scripts/target_recipe.lua     -- which recipes a Target takes, which it is on, whether it is locked, which are researched
scripts/recipes.lua           -- recipe prototype filters and inventory-order sort, shared by machines and chests
scripts/chest_recipe.lua      -- a chest's recipe candidates and allows (ADR-0012): every crafter's categories, union
scripts/feed.lua              -- the crafters an inserter takes a chest's items into (ADR-0012)
scripts/pending.lua           -- read the request already waiting on a Target
scripts/effects.lua           -- a Target's module and beacon factors on draw and speed
scripts/craft.lua             -- recipe math: per-craft amounts, slot limit and cap, output unit
scripts/fuel.lua              -- fuel estimate, capacity, default-fuel ranking
scripts/fuel_tier.lua         -- how early each item becomes obtainable (default-fuel ranking)
scripts/placement.lua         -- a chest's want list into inventory positions, and the chest cap (ADR-0012)
scripts/request.lua           -- build insert plans; write them onto a target
scripts/blueprint.lua         -- put a primed blueprint in the cursor
scripts/copy.lua              -- on_player_setup_blueprint: a copy of a primed built machine or chest is primed like it
scripts/carried.lua           -- the Priming a primed machine or chest carries into a copy or a settings paste
scripts/paste.lua             -- on_entity_settings_pasted: settings paste carries a primed request
scripts/tool.lua              -- selection / shortcut / hotkey handlers -> open window, drag hints
scripts/selection.lua         -- resolve a drag into a group of one family and kind (ADR-0011, ADR-0012)
scripts/group.lua             -- a group's Request, totals and whole-area primed blueprint
scripts/gui/names.lua         -- every element name in the window
scripts/gui/priming.lua       -- the Priming record's rules (pure state, no GUI access)
scripts/gui/caps.lua          -- the slot/chest/fuel caps and settling, split out of priming.lua
scripts/gui/items.lua         -- a chest's items-mode rows: the four ways to set one, and the row cap (ADR-0013)
scripts/gui/reopen.lua        -- preset a new Priming from the target's pending request
scripts/gui/picker.lua        -- the mod's own recipe picker (ADR-0009), grouped by item group
scripts/gui/widgets.lua       -- shared button / number-field / slider builders and setters
scripts/gui/recipe_rows.lua   -- the recipe slot, ingredients, output and fuel rows
scripts/gui/item_table.lua    -- items mode's table: header, rows, trailing chooser (ADR-0013)
scripts/gui/window.lua        -- build and destroy the priming window
scripts/gui/view.lua          -- fill the window's numbers from a Priming
scripts/gui/events.lua        -- GUI event handlers
scripts/gui/chest_events.lua  -- handlers for the mode switch and items-mode lines (ADR-0013)
scripts/gui/actions.lua       -- Request and Blueprint, for one target or a group
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

-- Target kinds: per entity, fixed when the Target is built.
const.KIND_ASSEMBLER = "assembler"
const.KIND_FURNACE   = "furnace"
const.KIND_FUEL_ONLY = "fuel-only"
const.KIND_CHEST     = "chest"           -- ADR-0012

-- Families (ADR-0012): a drag primes one kind and skips other kinds of its
-- family; the other family is ignored silently (selection.lua).
const.FAMILY_MACHINE = "machine"
const.FAMILY_CHEST   = "chest"

-- A chest is a plain container: a filtered, custom-stack or weight-limited
-- inventory drops or truncates slot-targeted requests. Shared with the data
-- stage (prototypes/tool_filters.lua), so what lights up is what primes.
const.CHEST_TYPE            = "container"
const.LOGISTIC_CHEST_TYPE   = "logistic-container"
const.CHEST_INVENTORY_TYPES = { ["normal"] = true, ["with_bar"] = true }

-- A chest window's two modes (ADR-0013).
const.MODE_RECIPE = "recipe"
const.MODE_ITEMS  = "items"

-- Every prototype type that runs recipes. Only CRAFTER_TYPES among them can
-- be primed; the rest (rocket silos) are refused rather than treated as fuel-only.
const.CRAFTING_MACHINE_TYPES = { ["assembling-machine"] = true, ["furnace"] = true, ["rocket-silo"] = true }
const.ORIENTED_TYPES = { car, locomotive, cargo-wagon, fluid-wagon, artillery-wagon }    -- = true each
const.NORMAL_QUALITY   = "normal"
const.GHOST_TYPE       = "entity-ghost"
const.PROXY_NAME       = "item-request-proxy"
const.TICKS_PER_SECOND = 60
const.FLOAT_EPSILON    = 1e-9        -- slack when rounding an energy ratio up
const.UNREACHABLE_TIER = math.huge   -- fuel_tier of an item nothing produces
const.MIN_CONSUMPTION_FACTOR = 0.2   -- engine floor on modules' and beacons' draw effect
const.MIN_SPEED_FACTOR       = 0.2   -- engine floor on their speed effect
const.HINT_TICKS       = 90          -- how long a drag's outline hints last (tool.lua)
const.HINT_BLINK_TICKS = 15
const.REASON = {                     -- `false, reason` and priming.blocker; locale keys
  INVALID, OTHER_FORCE, NOT_PRIMABLE, UNSUPPORTED, TARGET_GONE, RECIPE_MISMATCH,
  RECIPE_NOT_ALLOWED, FURNACE_NOT_RESEARCHED, CURSOR_BLOCKED, FUEL_SLOT_TAKEN,
  NO_FUEL, PICK_RECIPE, RECIPE_NOT_PRIMABLE, CAP_ZERO, SPECTATOR,
  LOGISTIC_CHEST, CHEST_FULL, NO_ITEMS, CHEST_CAP_ZERO,    -- ADR-0012 / ADR-0013
}
const.NOTICE = {                     -- `true, notice`; locale keys
  REQUESTED, ALREADY_STOCKED, RECIPE_CHANGED, NOT_RESEARCHED, FURNACE_NOT_RESEARCHED_YET, ONE_KIND,
  ITEM_LISTED, CHEST_NO_ROOM, CHEST_NOT_RESEARCHED, ONE_KIND_QUALITY, CHEST_FULL_GROUP,   -- ADR-0012 / ADR-0013
}
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
  kind        = const.KIND_ASSEMBLER | const.KIND_FURNACE | const.KIND_FUEL_ONLY | const.KIND_CHEST,  -- per entity, see from_entity
  burner      = LuaBurnerPrototype | nil,     -- nil for a chest
  surface     = LuaSurface, position = MapPosition,
  direction   = defines.direction | nil,   -- everything but ORIENTED_TYPES (chests included)
  orientation = RealOrientation | nil,     -- ORIENTED_TYPES only
  force       = LuaForce,
}
```

`target.family(t.entity)` answers `const.FAMILY_MACHINE` or `const.FAMILY_CHEST` from the prototype alone, cheaply enough for every entity in a drag (ADR-0012); it is not stored on the Target itself.

**Priming** (the window's state; lives in `storage.players[i].priming` so it survives save/load):

```lua
{
  target      = Target,
  recipe      = string | nil,       -- nil for fuel-only or a chest with nothing chosen, or a crafter with nothing chosen yet
  quality     = string,             -- recipe quality: target_recipe.current's quality, else "normal"; never changed by the window
  crafts      = integer,            -- craft count (crafters and chests); >= 1 once a recipe is chosen and cap >= 1, else 0
  fuel        = string | nil,       -- fuel item (burner targets only; always nil for a chest)
  fuel_quality = string,            -- "normal", or the quality a built target already burns this fuel at
  fuel_count  = integer,            -- fuel items to request (always 0 for a chest)
  fuel_edited = boolean,            -- true once the player typed a fuel amount; cleared when crafts change
  -- Chests only (nil for machines, ADR-0013):
  mode        = const.MODE_RECIPE | const.MODE_ITEMS | nil,
  items       = { { id = integer, name = string, quality = string, count = integer }, ... } | nil,
  next_row_id = integer | nil,      -- the next row's id; increases, never reused
}
```

Recipe mode keeps using `recipe`, `quality` and `crafts` exactly as a machine does, and they stay set while the chest is showing Items mode; only the active mode is ever requested (`placement.wants`).

## Module interfaces

### state.lua
- `state.init()`: ensures `storage.players`; migrates 0.1.x storage (drops each record's `max_stack` and the global `storage.preferred_fuel`, backfills `fuel_by_category`). Called from on_init and on_configuration_changed.
- `state.player(player_index)` → the record `{ fuel_by_category = {}, priming = nil }`, created on demand; a 0.1.x record is backfilled on every read.
- `state.remove(player_index)`: on_player_removed.

### target.lua
- `target.from_entity(entity, force)` → `Target` or `nil, reason_locale_key`. Rejects: invalid, other force, not a crafter and has no burner (`NOT_PRIMABLE`), crafter of a type outside `CRAFTER_TYPES` (`UNSUPPORTED`), a `logistic-container` (`LOGISTIC_CHEST`, ADR-0012: robots would move its contents, or a requester's trash setting would throw them out). A crafter with no primable recipe at all (`target_recipe.any_primable`) is fuel-only if it has a burner (the captive biter spawner) and `UNSUPPORTED` otherwise (the recycler without Space Age). A burner crafter whose own recipe has no item ingredient (`target_recipe.on_fluid_only`: a Space Age biochamber cracking oil) is fuel-only too, so its fuel can be primed and its recipe is never overwritten; the kind is therefore per entity, fixed when the Target is built. A plain container (`type == "container"`, not hidden, `inventory_type` "normal" or "with_bar", chest inventory size >= 1) is `const.KIND_CHEST`, with `burner = nil`. Ghost handling uses `entity.ghost_name`, `entity.ghost_prototype`, `entity.quality`. Records `orientation` for `ORIENTED_TYPES`, `direction` for everything else, chests included.
- `target.family(entity)` → `const.FAMILY_MACHINE`, `const.FAMILY_CHEST`, or nil when the entity cannot be primed at all: the kind check alone, by prototype, cheap enough for every entity in a drag (ADR-0011, amended by ADR-0012). `target.is_machine(entity)` → `family(entity) == FAMILY_MACHINE`; a chest is never a machine.
- `target.revalidate(t)` → `true` if `t.entity` is still valid. If a ghost was revived meanwhile, finds the built entity (same name, position, force) and rewrites `t.entity` / `t.is_ghost`; returns false if neither exists.
- `target.input_inventory(t)` → the inventory a Target's items go into: `defines.inventory.chest` for a chest, else `defines.inventory.crafter_input`. The one answer request.lua, reopen.lua, carried.lua and copy.lua all share, instead of each assuming `crafter_input`.
- `target.fed_recipe(t)` → `name, quality` or nil (ADR-0012): the recipe every one of a chest's fed machines (`scripts/feed.lua`) agrees on, counting only a fed machine whose own current recipe the chest allows; none, or a disagreement between fed machines, gives nil. Calls `target.from_entity` on each fed machine, which is why this lives here rather than in feed.lua (which must stay free of both target.lua and target_recipe.lua).
- `target.inventory_count(t, inventory_define, item, quality)` → items already inside a built target (0 for ghosts).
- `target.current_recipe`, `target.allows_recipe`, `target.recipe_filters`, `target.recipe_locked`, `target.recipe_unlocked`, `target.recipe_deliverable`, `target.recipe_candidates`: re-exported from target_recipe.lua (below). `target.recipe_candidates(t)` now takes the Target, not a prototype, so it can delegate to chest_recipe.lua; the picker always calls it this way.

### recipes.lua (pure prototype reads; no LuaEntity access, shared by target_recipe.lua and chest_recipe.lua)
- `recipes.item_ingredient_count(recipe)` → how many of a recipe's ingredients are items; fluids never count, since robots have nothing to deliver for them.
- `recipes.filters_for(categories)` → RecipePrototypeFilters: `(category c1 AND NOT hidden AND has-ingredient-item) OR (c2 AND ...)`, one clause per category in the set ("and" binds tighter than "or" in prototype filters, so the exclusions repeat after every category).
- `recipes.inventory_order(recipe)` → a sortable key, the recipe's group/subgroup/recipe order joined on `"\0"` (which sorts below every other byte): the engine's own furnace-recipe rule, and the picker's display order.
- `recipes.sorted(filters, keep)` → the names `prototypes.get_recipe_filtered(filters)` matches and `keep(recipe)` accepts, in inventory order. Shared by `target_recipe.candidates` (one machine's own categories) and `chest_recipe.candidates` (every crafter's).

### chest_recipe.lua (ADR-0012; never requires target.lua, never calls `get_recipe` or `crafting_categories` on a chest prototype)
A chest crafts nothing, so its recipe mode offers every recipe some crafter could run, not its own prototype's categories, since it has none.
- `chest_recipe.categories()` → the union of `crafting_categories` over every `CRAFTER_TYPES` prototype. Memoised in a file-level local, like `target_recipe`'s per-prototype memos: a pure function of the prototypes, so every peer computes the same answer.
- `chest_recipe.filters()` → `recipes.filters_for(chest_recipe.categories())`.
- `chest_recipe.candidates()` → every recipe those filters match with at least one item ingredient and not a parameter, in inventory order. Long with Space Age (hundreds of recipes); accepted, and the picker still opens on the current recipe's group tab.
- `chest_recipe.allows(t, recipe_name)` → recipe exists for the force, not hidden, not a parameter, in one of those categories, with at least one item ingredient. Unresearched recipes are allowed (ADR-0009). `target_recipe.allows` delegates here for a chest Target; `locked` is always false and `deliverable` always true for one.

### feed.lua (ADR-0012; requires neither target.lua nor target_recipe.lua)
The geometry of a chest's fed machines: which crafters an inserter takes its items into. Which recipe they agree on is target.lua's question (it needs `target.from_entity`); this file only ever returns entities.
- `feed.machines(chest_entity)` → every crafter (built, or a ghost whose `ghost_type` is in `CRAFTER_TYPES`) of the chest's force that an inserter (built, or an inserter ghost) of the same force takes from the chest into, each entity once. Positions come from the inserter itself: `pickup_position` and `drop_position` are readable on a built inserter and on a ghost from creation, while `pickup_target`/`drop_target` stay nil on a ghost forever (and nil on a built one until it first ticks); direction is never used to derive them (direction does not say which way an inserter drops). The search area is the chest's bounding box grown by the longest pickup or drop vector of any inserter prototype, plus a tile, memoised from prototypes. Loaders are ignored.

### target_recipe.lua (never requires target.lua; a chest's answers come from chest_recipe.lua, which has no categories of its own)
- `current(t)` → `name, quality` or `nil`. A chest has none: its recipe mode starts from the fed recipe, which target.lua resolves. Assembler (ghost or built): `get_recipe()`, else the prototype's `fixed_recipe` read through `name_of` (a plain string on 2.0, a `LuaRecipePrototype` on 2.1). Built furnace: `get_recipe()`, else the recipe implied by its proxy's pending crafter_input request, else `previous_recipe`'s name at normal quality (the window has no quality control, so one stray uncommon ore must not set the quality of every later pick). Ghost furnace: the recipe implied by its own crafter_input insert plan (`pending.plans`), else nil. The implied recipe is the first allowed recipe, in inventory order, that takes the requested item. The `fixed_recipe` fallback is untested: `get_recipe()` already returns the fixed recipe on both a ghost and a built entity, on 2.0.77 and 2.1.17, so no test scenario reaches `name_of(t.prototype.fixed_recipe)`.
- `allows(t, recipe_name)` → for a chest, `chest_recipe.allows(t, recipe_name)`. Otherwise: recipe exists for the force, not hidden, not a parameter, in one of the prototype's crafting categories (`has_category`), and with at least one item ingredient (exactly one for a furnace). Unresearched recipes are allowed (ADR-0009): `unlocked(t, name)` is the one that checks `enabled`.
- `filters(t)` → `{}` for fuel-only, `chest_recipe.filters()` for a chest, else `filters_for(t.prototype)`. `filters_for(prototype)` → `recipes.filters_for(prototype.crafting_categories)`.
- `candidates(t)` → the recipe names the picker offers, in inventory order, keyed on the **Target**, not a prototype: a chest delegates to `chest_recipe.candidates()`; a machine memoises per prototype name as before, via `recipes.sorted`. Researched or not either way (ADR-0009).
- `unlocked(t, name)` → the force has researched it. `deliverable(t, name)` → false only for a built furnace and an unresearched recipe (always true for a chest, since `t.kind ~= KIND_FURNACE`): a furnace accepts only items for unlocked recipes, so the engine would drop that request. `allows` no longer checks research.
- `on_fluid_only(t)` → whether the recipe the machine is set to (`get_recipe()` on an assembler, ghost or built, or on a built furnace) has no item ingredient. Never asked of a chest (`recipe_set_on` returns nil for one, so this is always false).
- `any_primable(prototype)` → whether `filters_for(prototype)` matches any recipe; memoised per prototype name (a pure function of prototypes, so multiplayer-safe).
- `locked(t)` → whether the window may not choose a recipe (ADR-0007, amended): always false for a chest and for fuel-only targets and ghosts; true for an assembler with a `fixed_recipe`; for a built assembler or furnace, `entity.get_recipe() ~= nil`. Request refuses exactly what this locks.

### pending.lua
- `pending.plans(t)` → the request waiting on a target: a ghost's `insert_plan`, or a built entity's `item_request_proxy.insert_plan`, or `{}`.
- `pending.count(plans, inventory, name, quality)` → items of that id requested into that inventory, all stacks.
- `pending.removals(t)` → what a built entity's proxy will take out (`item_request_proxy.removal_plan`), or `{}` (always for a ghost).
- `pending.items_in(plans, inventory)` → `{ name, quality, count, top }` per plan with a position in that inventory, in plan order (the engine's own order, not the order the plans were written in); `top` is the highest stack index that plan sends there. `reopen.lua` sorts a chest's reopened rows by it, since the engine does not hand plans back in writing order.
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
- `fuel.remember(player_index, t, item)`: stores the choice under the item's fuel category, if `accepts`.

### placement.lua (ADR-0012)
How a chest's want list becomes insert-plan positions in its own inventory, and the chest cap Recipe mode is limited by: one core for Request, the primed blueprint, copies and group totals, so what the window promises is what gets requested.
- `placement.wants(p)` → `{ name, quality, count }` totals: one entry per item ingredient in Recipe mode (`ceil(crafts * amount)` at the recipe's quality), or every Items-mode row with `count >= 1`. Only the active mode counts.
- `placement.slots(t)` → a fresh chest's slot count at this target's prototype and quality (`get_inventory_size(defines.inventory.chest, quality)`). `placement.stack(name)` → that item's stack size.
- `placement.slots_needed(wants)` → whole stacks the wants fill in a fresh chest.
- `placement.cap(t, recipe)` → the chest cap: the largest craft count whose item ingredients, each packed into whole stacks, still fit (`sum ceil(ceil(N*amount)/stack) <= slots`); found by binary search, since every term grows with N; 0 when the recipe has no item ingredient.
- `placement.place(t, wants, is_top_up)` → `{ name, quality, position }` entries, plus the shortfall (items that found no room). A **fresh** placement (`is_top_up` false, or no built entity yet) fills from the chest's **last** slot downward, each item's stacks contiguous, in want-list order: the engine and players fill from slot 0 up, so this collides far less with what a blueprint stamp or a copy's own request adds later. A **top-up** (`is_top_up` true, on a built chest) computes each want's need as `count - held` at that quality, tops up partial stacks of the same item and quality first (any slot, room = stack - count), then takes empty slots from the highest index down; slots holding anything else are unavailable. One occupancy map runs across the whole want list either way, so two items are never sent to the same slot, and no position ever asks for more than one stack (the engine truncates or drops the rest otherwise).

### request.lua
- `request.plans(t, priming, opts)` → `array[BlueprintInsertPlan], shortfall`. For a chest, the want list (`placement.wants(priming)`) run through `placement.place`, `shortfall` its item shortfall. For a machine, plans for the ingredient and fuel inventories: `opts.top_up = true` subtracts what a built target already holds (never below 0; plans with count 0 are dropped); ingredients go to `crafter_input` at their `slot`, at the recipe quality, each clamped to `craft.slot_limit`; fuel fills `fuel` stacks 0..n-1 one stack at a time, at `priming.fuel_quality`, skipping a built target's stack that holds another fuel (or this fuel at another quality); a top-up subtracts only what is held at that quality. `shortfall` there is the fuel that found no room (0 unless such stacks leave too little).
- `request.owned(t)` → the inventories this target's plans may replace: `{ [target.input_inventory(t)] = true }` for a chest (its own inventory only), else `{ [defines.inventory.fuel] = true, and target.input_inventory(t) unless fuel-only }`. Inventory ids are per entity type (`defines.inventory.chest == defines.inventory.fuel == 1`), so what is owned depends on the target's kind; a single Target is never both, so there is no collision.
- `request.apply(t, priming)` → `true, notice` or `false, reason_locale_key`. Revalidates the target. A shortfall refuses everything (`FUEL_SLOT_TAKEN` for a machine, `CHEST_FULL` for a chest), so a target is never primed to run, or sit, dry part-way. Recipe (never for a fuel-only target, whose recipe is left as it is; never for a chest in Items mode, which asks for no recipe): refused (`RECIPE_NOT_ALLOWED`) unless `target.allows_recipe`; refused (`FURNACE_NOT_RESEARCHED`) unless `target.recipe_deliverable`; nothing to do if the target is already on it at that quality; refused (`RECIPE_MISMATCH`, ADR-0007) if `target.recipe_locked` (never true for a chest); otherwise an assembler (ghost, or built with no recipe) gets `set_recipe`, and a furnace or a chest needs nothing. Merge = keep every existing InventoryPosition (and `grid_count`) for any inventory we do not own (`request.owned`), replace ours, drop empty plans. Ghost: write `insert_plan`. Built target: write into `entity.item_request_proxy.insert_plan` if one exists (destroying it if the merged plan and its removal plan are both empty), else create a proxy; if the merged plan is empty, create nothing. `notice` is `REQUESTED`, or `ALREADY_STOCKED` when the top-up left nothing to request.
- `request.merge(existing, ours, owned)` → the merge above as plans: every position of `existing` outside the `owned` inventory set (and its `grid_count`) kept, every position of `ours` added, one plan per item and quality.
- Messages are locale keys; the caller prints them.

### blueprint.lua
- `blueprint.entity(t, priming)` → one BlueprintEntity at `{0,0}`: name, quality, `direction` or (vehicles) `orientation`, `mirror` if the source is mirrored, `recipe`/`recipe_quality` (the window's for an assembler; for a fuel-only assembler without a `fixed_recipe`, the source's live `get_recipe()`, so a cracking biochamber's copy keeps cracking; none for furnaces or chests), `items = request.plans(t, priming, {top_up=false})`, `bar` (a built chest's bar as the blueprint writes it, `get_bar() - 1`, or nil; placement ignores the bar itself, since it does not stop slot-targeted delivery).
- `blueprint.item_tag(name, quality)` → `[item=name]`, or `[item=name,quality=q]` when the quality is not normal. Shared by the blueprint label and `group.totals`.
- `blueprint.write(stack, t, priming)` → turns any writable stack into the primed blueprint: that entity, a label, icons. The label and icons branch on mode for a chest: Items mode names the first row (`item_tag` + count) and " +N" for further rows, with icons the chest item then up to three row items; Recipe mode is unchanged for a chest (`[entity] [output] xN`, machine icon then output).
- `blueprint.to_cursor(player, t, priming)` → `true` or `false, reason`. Refuses a player with no `cursor_stack` (`SPECTATOR`) before touching anything; otherwise clears the cursor (`CURSOR_BLOCKED` if it cannot), writes the blueprint there, and marks it `cursor_stack_temporary`, like a vanilla copy.

### copy.lua (ADR-0008, amended for chests in ADR-0012)
- `copy.carry_one(entity, source, force, player_index)` → one blueprint entity copied from `source`; true if it changed. Exported (was a local of `copy.carry`) so `group.write_area` can call it too. Skipped unless the source is valid, has the entity's name, is a built `CRAFTER_TYPES` machine **or a built chest** with an `item_request_proxy` (checked first, since almost no copied entity has one; a ghost's type is `entity-ghost` and vanilla already carries its whole plan), and `carried.priming` returns a Priming for it. Then `request.plans(p.target, p)` (full amounts, no top-up) is merged into `items` with `request.merge`, owning `request.owned(p.target)` (a machine's `crafter_input` and `fuel`, or a chest's own inventory), so modules and everything else vanilla wrote stay. No transform for mirrored or rotated sources: stack indices are slots.
- `copy.carry(entities, mapping, force, player_index)` → whether any BlueprintEntity changed. `mapping` is blueprint entity index -> source LuaEntity. Does nothing when `table_size(mapping) ~= #entities` (another mod reshaped the blueprint first).
- `copy.on_setup(event)`: `on_player_setup_blueprint`. The blueprint is the first set-up one of `player.blueprint_to_setup`, `event.stack` (on "select new contents" it can still hold the old contents), `player.cursor_stack` (a book gives its active blueprint, via `item_main` and `active_index`) and `event.record`; the mapping is `event.mapping.get()`. Writes back with `set_blueprint_entities` only if `carry` changed something, inside `pcall`; any missing piece leaves vanilla's blueprint as it is.

### carried.lua (ADR-0008, amended for chests in ADR-0012)
- `carried.priming(entity, force, player_index)` → the Priming a machine or chest carries, or nil: a non-fuel-only Target with pending positions in `target.input_inventory(t)` (a crafter's `crafter_input`, or a chest's own inventory), run through `priming.new` (so crafts, or a chest's rows, come from pending plus contents, as a reopened window shows them), and no blocker. Shared by copy.lua and paste.lua.
- `carried.apply(to, from, player_index)` → `ok, reason`: primes Target `to` like Priming `from` (`priming.new(to, player_index, from)`, then `request.apply`), so `to` gets its own cap or chest cap, top-up and fuel estimate unless the fuel amount was typed. Used by paste.lua and by a group Request.

### paste.lua (ADR-0008, amended for chests in ADR-0012)
- `paste.apply(source, destination, force, player_index)` → the destination Target once its request is written, else nil. The source must resolve (`target.from_entity` with `force`) to a non-fuel-only Target with a pending position in its own input inventory, and whose `priming.new` has no `blocker`. The destination must be the **same kind** of Target (machine to machine, or chest to chest, since the engine raises this event between two containers too; a machine-to-chest paste stays out of scope) and, if it burns fuel, take the source's fuel (`fuel.accepts`) if it has one; an electric destination takes the ingredients alone, and a chest has no burner so this check never applies to one. Its Priming is `priming.new(to, player_index, from)`; it must have no `blocker`, and is written with `request.apply`, which also refuses a recipe the destination does not allow or has locked (never for a chest), and, for a chest, fits the source's rows to the destination's row caps (`reopen.carry`, ADR-0013). Anything refused is left silently to vanilla's paste.
- `paste.on_pasted(event)`: `on_entity_settings_pasted` (after vanilla's paste, so an assembler already has the source's recipe). Applies with the player's force; if the player's window is open on the destination, it is reopened from the new request.

### selection.lua (ADR-0011, amended for families in ADR-0012)
- `selection.resolve(entities, area, force)` → `{ primary, group, skipped }` or `nil, reason`. The primary is the Target of **either family** nearest the centre of `area` (`target.from_entity` only runs on entities closer than the best so far). The group is the primary plus every other entity with the same inner prototype name whose Target has the same kind (a cracking biochamber is fuel-only, so it is not grouped with one making bioflux) and, for a chest, the same **quality** (quality changes the chest's slot count, so a chest of another quality is not a member even though its kind and name match; machines keep grouping across qualities). `skipped` is every other entity of the primary's **family** (`target.family`), a mismatched-quality chest included; an entity of the *other* family is ignored outright, not counted as skipped at all. The caller adds `area`.

### group.lua (ADR-0011, amended in ADR-0012)
A Priming may carry `group` (Targets, primary first) and `area` (the drag's BoundingBox) when a drag selected two or more targets of one kind, machines or chests alike.
- `group.size(p)`; `group.request(p, player_index)` → `done, total, first_reason`: `carried.apply` for every member still there (`target.revalidate`). Members are not pre-checked for `CHEST_FULL`; a refusal there counts like any other.
- `group.totals(p, player_index)` → rich text, now keyed by **item and quality** (`blueprint.item_tag`, so two qualities of one item show as two entries): the full per-member plans (no top-up) summed over the group, computed once per member quality. Quality shows on the tag only when it is not normal, so a plain machine group's text is unchanged.
- `group.write_area(stack, p, force, player_index)`: `create_blueprint` over `p.area`, then every blueprint entity mapped to a member gets `request.plans` for that member merged in (owning `request.owned(t)`, so modules stay) and, for an assembler, the recipe. Every **other** built entity in the area with a pending primed request, machine or chest, is also carried through `copy.carry_one`, because `create_blueprint` raises no `on_player_setup_blueprint` and vanilla drops a built proxy's positions on its own; this closes a gap that existed for machines too before 0.3.4 (ADR-0008's amendment). Everything else stays as vanilla wrote it. `group.to_cursor(player, p)` runs it through `blueprint.into_cursor`.

### tool.lua
- `target.is_machine(entity)` → whether the window could open for it *as a machine*, by prototype alone (`target.family(entity) == FAMILY_MACHINE`); cheap enough for every entity in a drag.
- `tool.on_selected(event)`: `selection.resolve` the drag, then open the window with the resolved group (`window.open(player, primary, picked)`), or show the nearest entity's refusal as flying text. A click that finds nothing, with a logistic chest under it, searches the area for one (built or ghost) and reports `LOGISTIC_CHEST` instead of the generic "nothing to prime", since the tool's own `entity_filters` leave logistic chests out and so never select them. After a drag over two or more of one kind, or any skipped entity, every member gets a short-lived `highlight-box` in the `copy` box type and every skipped one in `not-allowed` (this player only, `HINT_TICKS`, blinking); if anything was skipped, the `ONE_KIND` notice appears just above the middle of the dragged area.
- `tool.on_shortcut(event)`: toggles the primer tool: puts it in the cursor, or clears the cursor if the tool is already there. A player with no cursor (a spectator) gets nothing; a cursor that cannot be cleared shows `CURSOR_BLOCKED`.
- `tool.on_hotkey(event)`: does nothing for a spectator. If `player.selected` resolves to a Target, open the window for it (machine or chest alike). If it is refused as `UNSUPPORTED` or `LOGISTIC_CHEST`, or as `OTHER_FORCE` while it would be primable on its own force, show that reason. Otherwise (nothing hovered, or nothing primable such as a tree) toggle the tool as the shortcut does.

### gui/priming.lua (pure state, no GUI access; caps and settling in gui/caps.lua, a chest's rows in gui/items.lua)
- `priming.new(t, player_index, carried)` → a Priming: the target's current recipe if allowed (nil for a chest), with its quality; `fuel.default` (item and quality); for a chest, `mode = MODE_ITEMS`, `items = {}`, `next_row_id = 1` before either preset can override them; a fuel-only target's fuel count at half `fuel.capacity`; then `reopen.preset` (or `reopen.carry` when `carried` is given, a settings paste or a group Request), then settled (crafts clamped to `1 .. cap`, or half the cap when unset, or 0 when `cap < 1`; fuel follows the estimate unless typed; a chest's rows fitted to it).
- `priming.cap`, `priming.fuel_cap`, `priming.estimate`: re-exported from `gui/caps.lua`, same names as before the split.
- `priming.per_craft(p)` → output units per craft (1 when the output is not deterministic); `priming.outputs(p)` → `crafts × per_craft`.
- `priming.set_crafts`, `set_outputs` (rounds up to whole crafts), `set_fuel_count`, `set_recipe` (keeps `quality`, and never touches `mode`: picking a recipe in Items mode only updates the Recipe-mode fields underneath), `set_fuel` (remembers the pick; `fuel_quality = fuel.quality_for`, so picking the fuel a built machine burns matches its quality), `preset_crafts(p, full)` / `preset_fuel(p, full)` (Half when `full` is false, Max when true). All work identically for a chest in Recipe mode, since `caps.crafts` asks `placement.cap` for one.
- `priming.set_mode(p, mode)` (ADR-0013): the **switch mode** call. Does nothing for a machine, for the current mode, or for an unknown mode. Switching into Items seeds the rows from `placement.wants(p)` when they are empty, otherwise keeps them; switching into Recipe with no recipe yet takes the fed recipe if there is one.
- `priming.slots(p)` → `used, total` whole stacks (`placement.slots_needed(placement.wants(p))`, `placement.slots(p.target)`): "Uses N of M slots", shown in both chest modes.
- `priming.chest_full(p)` → the Request pre-check on a built chest: true only when a top-up placement would fall short (`placement.place(t, wants, true)`'s shortfall > 0). Always false for a ghost, a machine, or a fresh chest with nothing yet asked for; never blocks Blueprint, which is for a fresh chest. It only ever looks at `p.target`, the primary, so `view.refresh_footer` disables Request on it only for a single-chest window (`group.size(p) == 1`); for a group it is shown as a non-blocking `CHEST_FULL_GROUP` note instead, and `group.request` counts the primary's own refusal.
- `priming.recipe_locked(p)` = `target.recipe_locked(p.target)`; always false for a chest.
- `priming.sync_locked(p)` → true if the chooser is locked and the machine's recipe (or its quality) no longer matches the record; re-derives the recipe as `new` does and re-settles. Never true for a chest.
- `priming.blocker(p)` → why Request and Blueprint are disabled: `const.REASON.NO_FUEL`, `PICK_RECIPE`, `RECIPE_NOT_PRIMABLE`, `CAP_ZERO` for a machine; `items.blocker(p)` (`NO_ITEMS`, when no row has `count >= 1`) for a chest in Items mode; nil when ready.

### gui/caps.lua (split out of priming.lua; priming.lua re-exports `cap`, `fuel_cap` and `estimate`, so its own API is unchanged)
The limits a Priming's numbers stay within, and settling: re-fitting every derived number after the recipe, the fuel or the target changed.
- `caps.clamp(n, low, high)`; `caps.share(cap, full)` → Half (`floor(cap/2)`, at least 1) or Max (`cap`).
- `caps.crafts(p)` → the slider maximum: `craft.slot_cap` and, for a burner, `fuel.max_crafts`, for a machine; `placement.cap(p.target, p.recipe)` for a chest. 0 without a recipe.
- `caps.fuel(p)` → `fuel.capacity`. `caps.estimate(p)` → `fuel.estimate` for the record, or nil for a fuel-only target, without a recipe or fuel, or below one craft.
- `caps.refuel(p)`: a typed fuel amount survives until the craft count changes (or, for a fuel-only target, always survives until re-typed); otherwise the fuel follows the crafts.
- `caps.settle(p)`: re-fits crafts to `1 .. caps.crafts(p)` (or half of it when unset, 0 when the cap is under 1), then `items.fit(p)` when `p.items` is present (a chest, so its rows always fit the target's current chest size), then `caps.refuel(p)`.

### gui/items.lua (ADR-0013)
Items mode's rows: a chest Priming's list of `{ id, name, quality, count }`, where `count` is the only stored amount, an exact item count for a fresh chest. Rows are addressed by `id`, a per-Priming increasing integer, never by position.
- `items.row_slots(row)` → `ceil(count / stack_size)`: also where the row's slots slider sits. `items.row(p, id)` → `row, index`.
- `items.slots_used(p, except)` → slots the rows fill, `except` (an id) left out when given. `items.slot_cap(p, id)` → whole slots left for row `id` (or a new row when `id` is nil) beside the others; the slider maximum. `items.row_cap(p, id)` → the most that row may hold in items: `slot_cap * stack_size`.
- `items.add(p, name, quality)` → the trailing chooser's pick: a new row at Half. `true`, or `false, NOTICE.ITEM_LISTED` (already listed at that quality), or `false, NOTICE.CHEST_NO_ROOM` (its row cap would be 0), or plain `false` for an unknown item.
- `items.remove(p, id)`.
- `items.set_item(p, id, name, quality)` → `true`, or `false, NOTICE.ITEM_LISTED`. `name = nil` removes the row and returns `true`. Keeps the row's slots (recomputed at the new item's stack size), clamped to the new row cap.
- `items.set_count(p, id, count)` → clamps to `1 .. row cap`. `items.set_slots(p, id, slots)` → `slots * stack_size`, same clamp. `items.half(p, id)` → `min(row cap, floor(chest slots / 2) * stack_size)`, never below 1. `items.max(p, id)` → the row cap.
- `items.fit(p)` → fits every row to the target's current chest, in row order, earlier rows first; a row left with nothing (typically after a carry onto a smaller chest) is dropped. Named distinctly from `caps.settle`, which calls it.
- `items.fill(p, list)` → replaces the rows with `list` (a want list, or another Priming's rows), copied under fresh ids starting at 1.
- `items.blocker(p)` → `const.REASON.NO_ITEMS` when no row has `count >= 1`, else nil.
- `items.filters()` → `elem_filters` for the rows' `item-with-quality` choosers: not hidden, not a parameter, not `only-in-cursor` or `spawnable`, and not a type a robot cannot deliver exactly (blueprints, deconstruction/upgrade planners, selection and copy-paste tools, items with an inventory, a label or tags, and the spidertron remote). `elem_value` of an `item-with-quality` chooser is a table `{ name, quality }`, not a string.

### gui/reopen.lua
- `reopen.preset(p)`: for a machine, unchanged: if the target already carries a pending request, crafts = whole crafts the planned item ingredients cover (requested + already inside, for a built target), taken whenever an ingredient or an accepted fuel is pending (a built machine whose ingredients arrived before its fuel reopens at the crafts inside, not half the cap); fuel = the first requested fuel the burner accepts, at its requested quality, with count = planned; `fuel_edited` set on a crafter when crafts < 1 or that count differs from the estimate. With nothing pending, the record is left as `new` made it. For a chest (ADR-0013), `chest_preset` always runs: with nothing pending, a chest with a fed recipe switches to **Recipe mode** on it, crafts 0 so settling picks half the chest cap; without a fed recipe it stays in the Items mode `priming.new` set, with no rows. A pending request reopens in **Recipe mode**, at the fed recipe and quality and the crafts its pending amounts exactly cover, only when every pending item is an ingredient of that recipe at that quality *and* the pending amount for every ingredient with anything pending matches `ceil(N * amount)` exactly for one shared `N` (so an untouched Request rewrites the same request, ADR-0003); otherwise it reopens in **Items mode**, one row per pending item and quality, at what the chest holds once the request lands. No recipe is ever guessed from the items alone. Rows are ordered by the highest pending slot each one fills, descending (the order a fresh placement filled them; the engine hands plans back in its own order, not the order they were written), ties broken by name then quality.
- `reopen.carry(p, from)`: a settings paste, or a group Request's per-member priming: takes `from`'s recipe, quality, crafts, fuel item (at `fuel.quality_for` this target), fuel count and `fuel_edited`; for a chest, also `from.mode` and refills `p.items` from `from.items` (fresh ids). Settling (`caps.settle`, called by `priming.new`) then clamps crafts to this target's cap, re-estimates the fuel unless it was typed, and fits a chest's rows to this chest's row caps in row order, earlier rows first (`items.fit`).

### gui/window.lua, gui/view.lua, gui/events.lua, gui/legacy.lua, gui/picker.lua
- One `screen` frame named `const.WINDOW`, auto-centred, draggable title bar with a close button; `player.opened = frame` so E / Escape close it (`on_gui_closed` destroys it and clears `priming`).
- Rows, top to bottom: for a chest, a `switch` (ADR-0013: left "Recipe", right "Items", `on_gui_switch_state_changed`, wired in control.lua) sits above everything else; title "Prime <machine or chest>" (or "Prime N × <...>" for a group); recipe slot (a `slot_button` sprite-button, `red_slot_button` with vanilla's `utility/crafting_machine_recipe_not_unlocked` sign laid over it when unresearched; disabled per `priming.recipe_locked`, never for a chest), which toggles the recipe picker (`gui/picker.lua`: an `inside_deep_frame` under the rows, built only while open, `target.recipe_candidates(t)` grouped by item group into vanilla-style tabs, each an unnamed slot button tagged `{handler = names.pick, recipe}`, red when unresearched; the candidate list can run to several hundred entries for a chest with Space Age, accepted per ADR-0012); ingredient icons with counts (`slot_button`-style sprite-buttons with `number`; fluids shown with a tooltip saying pipes deliver them); the output row, a slider in crafts (`1 .. cap`, a chest's own chest cap) plus a numeric textfield showing and accepting the output count, the output icon, and Half / Max buttons (disabled when `cap < 2`; a chest's slider tooltip says it stops where the chest is full, not at one stack); the fuel row for burners only, never for a chest (`choose-elem-button{elem_type="item"}` with `fuel.filters(t)`, a numeric textfield for the count, a caption with the estimate). A chest additionally gets Items mode's table (`gui/item_table.lua`, below) and a slots caption ("Uses N of M slots", `priming.slots`) above the status line. Both of a chest's mode blocks are built once at open and toggled `visible` by the view (the picker's build-once precedent); for a group, a totals line (`group.totals`, hidden while blocked); a status line (the blocker; else, on a built chest, `CHEST_FULL` for a single-chest window, which also disables Request, or the non-blocking `CHEST_FULL_GROUP` note for a group, whose Request stays enabled and whose `group.request` counts the primary's own refusal, as machines do with `FUEL_SLOT_TAKEN` (`priming.chest_full` only ever looks at the primary; a group's other members are never pre-checked); else, in Recipe mode, an unresearched-recipe note, `CHEST_NOT_RESEARCHED` for a chest; else a top-up reminder on a built target); then a button row: Blueprint (left), Request (right, `confirm_button`; a chest's tooltips say "chest" instead of "machine").
- Fuel-only targets show only the fuel row, whose slider counts fuel items `1 .. fuel.capacity`, with Half / Max.
- `gui/widgets.lua`: the button, number-field and slider builders shared by the recipe row and items mode's table, plus the two setters that write a value in without fighting the player: `set_text(field, value, skip)` leaves the field named `skip` alone, and `set_slider(slider, value, max)` moves the slider's value to the *other* end of its new range before writing the real one, since the engine only redraws the knob when the value changes and would otherwise leave it at the old position when a range changes but the value does not (a chest's items rows, whose caps move as sibling rows change). This assumes script writes never raise `on_gui_value_changed` themselves, which held in every observed run.
- `gui/recipe_rows.lua`: the recipe slot, ingredient icons, the output row and the fuel row, moved out of `window.lua` unchanged in behaviour (`recipe_rows.add_recipe(rows, t)`, `add_fuel(rows, t)`).
- `gui/item_table.lua` (ADR-0013): Items mode's table: a header (Item | Slots | Items), one line per row, and a trailing empty chooser, inside a scroll pane capped at 8 lines. Every line's elements are named from the row's id (`row_item_<id>` and so on) and tagged with a shared handler name plus the row id, the picker's own dispatch pattern. `item_table.build(parent)` builds the (initially hidden) block; `item_table.refresh(found, p, skip)` prunes lines whose row is gone, holds another item, or is out of order, adds the missing ones at their place, then rewrites every line's numbers in place (the field the player is typing into, `skip`, is left alone); a line is never rebuilt just to renumber it.
- `gui/chest_events.lua` (ADR-0013): handlers for the mode switch (going to Items also closes the recipe picker) and the items lines: the trailing chooser (adds a row), a row's own chooser (changes or clears it), its slots slider and field, its items field, and Half/Max. Returned as tables by event kind (`click`, `slider`, `text`, `elem`, `switch`); `gui/events.lua` merges them into its own dispatch tables, so a chest's controls are found by the same `dispatch` as every other control.
- `gui/actions.lua`: Request and Blueprint, moved out of `events.lua` unchanged (`actions.request`, `actions.blueprint`); a group's Request/Blueprint still go through `group.request`/`group.to_cursor`.
- `view.refresh(player, skip)` recomputes every number from `priming` and never rebuilds the frame; it rebuilds only the ingredient icons, when the recipe or its quality changes, and (via `item_table.refresh`) a chest's items lines, when a row is added, removed, or changes item. `skip` names a text field the player is typing into, which keeps its text. `refresh_mode` sets the switch's state, shows the active mode's block, and writes the slots caption. A locked recipe chooser's tooltip says why it is locked. All handlers mutate `priming`, then call `view.refresh`.
- Before any handler runs, events revalidate the target and close the window if the player is now a spectator (`SPECTATOR`), it is gone (`TARGET_GONE`) or its entity is no longer on the player's force (`OTHER_FORCE`). If `priming.sync_locked` changed the record, the view refreshes with a `RECIPE_CHANGED` notice and the click is dropped, so Request never goes out for a recipe the player has not seen.
- Request and Blueprint close the window only on success, then show the returned notice; a refusal shows its reason and leaves the window open. For a group, Request goes through `group.request` (the notice counts how many took it, and names the first refusal if some did not) and Blueprint through `group.to_cursor` (the whole dragged area).
- `window.close_all()` runs on configuration change: stored prototypes may be stale, so every open window is dropped rather than migrated. `legacy.remove_gui()` runs there too and destroys 0.1.x's `blueprint_primer_button` (under `gui.top.mod_gui_button_flow` or `mod_gui_top_frame.mod_gui_inner_frame`) and `blueprint_primer_frame` (under `gui.left.mod_gui_frame_flow`), plus any of those containers left empty that this mod owns.
- `on_player_died`, `on_player_left_game` and `on_player_changed_force` close the window, because `on_gui_closed` is not raised when those clear `player.opened`. `on_player_controller_changed` closes it only when it is no longer `player.opened` (becoming a spectator by script, without a force change), so a switch that keeps it opened leaves it.
- The window is the only persistent GUI besides the shortcut. Nothing is added to `gui.top` or `gui.left`.

## Tests

`dev/run-tests.sh` runs headless (`--create` then `--benchmark`) in two mod sets (base only, and base + quality + space-age) with a `bp-test` mod that `require`s `__BlueprintPrimer__/scripts/*` and checks the module contracts, the Priming rules in `gui/priming.lua`, and robot delivery end to end. The test mod logs `BP_TEST PASS|FAIL <case>`; the runner exits non-zero on any FAIL or on a Lua error. `on_player_setup_blueprint` and `on_entity_settings_pasted` cannot be raised headless, so the tests call `copy.carry` (with the mapping `create_blueprint` returns) and `paste.apply`. Code that needs a player (the window, view and events, the cursor, `on_player_*` handlers, and those two handlers) cannot run headless: `dev/run-gui.sh` starts a graphical client on the `bp-gui-smoke` world and `dev/gui-drive.sh` drives it, and `dev/PLAYTEST.md` is the checklist.

`FACTORIO=<path> dev/run-tests.sh` runs the same suite against a different Factorio binary; when its major.minor differs from the mod's `info.json`, the run stages patched copies of the mod and `bp-test` (factorio_version rewritten to match) instead of symlinks, so the repo's own `info.json` is never touched. The suite passes identically on 2.0.77 (`/home/shobhitg/factorio-2.0/bin/x64/factorio`, the default) and 2.1.17 (`/home/shobhitg/factorio-2.1/bin/x64/factorio`), both mod sets: 323 pass / 0 fail on base, 388 pass / 0 fail on space-age (up from 222 and 282 before chest priming).

Chest cases, all under `dev/mods/bp-test/cases/`: `chest.lua` (resolving a chest, families and drag skipping, recipe candidates and `allows`, fed-machine geometry, the chest cap), `chest_families.lua` (a non-hidden `with_filters` container refused as a chest and left out of the tool's `entity_filters`; a chest of another quality skipped out of a group), `chest_place.lua` (fresh and top-up placement, shortfalls), `chest_items.lua` (the four ways to set a row, duplicates, a zero row cap, `NO_ITEMS`), `chest_reopen.lua` (the Recipe/Items reopen rule and its untouched-Request property), `chest_carry.lua` (copy, settings paste, group Request and totals keyed by quality, checked in full including the uncommon-quality row, `group.write_area` carrying non-members), `chest_delivery.lua` (real robots filling a ghost chest in each mode, and topping up a built one around a foreign item), and `compat.lua` (the fixed-recipe assembler that only 2.1 reads as a `LuaRecipePrototype`, `bp-test-fixed` in `dev/mods/bp-test/data.lua`). `dev/mods/bp-test/lib/rig.lua` adds a chest-only floor (`rig.CHEST_ORIGIN`, `rig.chest_at`) beside the machine floor, and `rig.rows`/`rig.items_priming` build Items-mode fixtures.
