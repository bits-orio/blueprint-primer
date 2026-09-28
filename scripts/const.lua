-- Every shared name and constant. Nothing else in the mod may hold a magic
-- string or number that another file also needs.

local const = {}

const.MOD            = "BlueprintPrimer"
const.TOOL           = "bp-primer-tool"          -- selection-tool item
const.SHORTCUT       = "bp-primer-shortcut"      -- shortcut, action = "lua"
const.INPUT_PRIME    = "bp-primer-prime"         -- custom input, ALT + P
const.GUI_PREFIX     = "bp_primer_"              -- every GUI element name starts with this
const.WINDOW         = "bp_primer_window"
const.CRAFTER_TYPES  = { ["assembling-machine"] = true, ["furnace"] = true }
const.NEVER_DEFAULT_FUEL = { ["wood"] = true }
const.FUEL_MARGIN_SECONDS = 1

-- Target kinds (DESIGN.md "Target").
const.KIND_ASSEMBLER = "assembler"
const.KIND_FURNACE   = "furnace"
const.KIND_FUEL_ONLY = "fuel-only"
const.KIND_CHEST     = "chest"

-- Families (ADR-0011): a drag primes one kind and skips the other kinds of
-- its family; the other family is ignored silently.
const.FAMILY_MACHINE = "machine"
const.FAMILY_CHEST   = "chest"

-- A chest is a plain container: a filtered, custom-stack or weight-limited
-- inventory drops or truncates slot-targeted requests. Shared with the data
-- stage (prototypes/tool_filters.lua), so what lights up is what primes.
const.CHEST_TYPE           = "container"
const.LOGISTIC_CHEST_TYPE  = "logistic-container"
const.CHEST_INVENTORY_TYPES = { ["normal"] = true, ["with_bar"] = true }

-- A chest window's two modes (ADR-0013).
const.MODE_RECIPE = "recipe"
const.MODE_ITEMS  = "items"

-- Every prototype type that runs recipes. Only CRAFTER_TYPES among them can
-- be primed; the rest (rocket silos) are refused rather than treated as fuel-only.
const.CRAFTING_MACHINE_TYPES = {
  ["assembling-machine"] = true, ["furnace"] = true, ["rocket-silo"] = true,
}

-- Entity types whose blueprint entity carries a smooth `orientation`
-- instead of a `direction` (vehicles and rolling stock).
const.ORIENTED_TYPES = {
  ["car"] = true, ["locomotive"] = true, ["cargo-wagon"] = true,
  ["fluid-wagon"] = true, ["artillery-wagon"] = true,
}

const.NORMAL_QUALITY   = "normal"
const.GHOST_TYPE       = "entity-ghost"
const.PROXY_NAME       = "item-request-proxy"
const.TICKS_PER_SECOND = 60

-- Float slack when rounding an energy ratio up: a ratio that is exactly 9
-- must not become 10 because the division landed on 9.000000000000002.
const.FLOAT_EPSILON = 1e-9

-- Tier of a fuel that no recipe or resource can produce (fuel.earliest).
const.UNREACHABLE_TIER = math.huge

-- Module and beacon effects can never take a machine's energy draw, or its
-- crafting speed, below this share of the base figure (engine clamps).
const.MIN_CONSUMPTION_FACTOR = 0.2
const.MIN_SPEED_FACTOR       = 0.2

-- How long the picked machine stays outlined after a drag over several.
const.HINT_TICKS = 90
const.HINT_BLINK_TICKS = 15

-- Reasons returned as `false, reason`, or by priming.blocker; each is a
-- locale key in [bp-primer].
const.REASON = {
  INVALID             = "bp-primer.invalid-target",
  OTHER_FORCE         = "bp-primer.other-force",
  NOT_PRIMABLE        = "bp-primer.not-primable",
  UNSUPPORTED         = "bp-primer.unsupported-crafter",
  TARGET_GONE         = "bp-primer.target-gone",
  RECIPE_MISMATCH     = "bp-primer.recipe-mismatch",
  RECIPE_NOT_ALLOWED  = "bp-primer.recipe-not-allowed",
  FURNACE_NOT_RESEARCHED = "bp-primer.furnace-not-researched",
  CURSOR_BLOCKED      = "bp-primer.cursor-blocked",
  FUEL_SLOT_TAKEN     = "bp-primer.fuel-slot-taken",
  NO_FUEL             = "bp-primer.no-fuel",
  PICK_RECIPE         = "bp-primer.pick-recipe",
  RECIPE_NOT_PRIMABLE = "bp-primer.recipe-not-primable",
  CAP_ZERO            = "bp-primer.cap-zero",
  CHEST_CAP_ZERO      = "bp-primer.chest-cap-zero",
  SPECTATOR           = "bp-primer.spectator",
  LOGISTIC_CHEST      = "bp-primer.logistic-chest",
  CHEST_FULL          = "bp-primer.chest-full",
  NO_ITEMS            = "bp-primer.no-items",
}

-- Notices returned alongside success (`true, notice`), also locale keys.
const.NOTICE = {
  REQUESTED       = "bp-primer.requested",
  ALREADY_STOCKED = "bp-primer.already-stocked",
  RECIPE_CHANGED  = "bp-primer.recipe-changed",
  NOT_RESEARCHED  = "bp-primer.not-researched",
  FURNACE_NOT_RESEARCHED_YET = "bp-primer.furnace-not-researched-yet",
  ONE_KIND        = "bp-primer.one-kind",
  ONE_KIND_QUALITY = "bp-primer.one-kind-quality",
  ITEM_LISTED     = "bp-primer.item-listed",
  CHEST_NO_ROOM   = "bp-primer.chest-no-room",
  CHEST_NOT_RESEARCHED = "bp-primer.chest-not-researched",
  CHEST_FULL_GROUP = "bp-primer.chest-full-group",
}

return const
