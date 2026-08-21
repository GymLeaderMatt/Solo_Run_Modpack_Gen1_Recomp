-- The single MOD OPTIONS screen for the whole pack.
--
-- Two constraints shape this list and both come from the engine:
--
--   * Only FOUR rows are visible at once (OptionRows.VISIBLE), so the rows
--     that change between runs sit at the top and the set-and-forget ones
--     sink to the bottom.
--   * Labels have no '%' glyph and no '+' or '='.  The font charmap is
--     letters, digits and ! ? . , - / : ; ' ( ) [ ].  A missing glyph is
--     logged and skipped, so a label with '%' silently loses characters.
--     Roughly 17 characters fit before a label runs off the box.
--
-- HIDING ROWS ON TWO DIFFERENT ENGINES
--
-- The engine grew a `visible_if` field on option rows in v0.1.95.  On 0.1.90
-- and 0.1.91 the field is simply ignored -- the row validator only looks at
-- `key` and `type` -- so a conditional row renders unconditionally and the
-- HM rows sit there with nothing left to configure.
--
-- So conditional rows are handled twice over:
--
--   1. `visible_if` is set, which does the whole job on 0.1.95 and later.
--   2. The schema is re-defined with the dead rows filtered out whenever the
--      key they depend on changes, which fixes the list for the next time
--      the options screen is opened.
--   3. The screen currently on the stack is rebuilt in place, because (2)
--      alone leaves a stale row visible until you back out and return --
--      which reads as the toggle simply not working.
--
-- The catch with (2) is that a row removed from the schema takes its default
-- with it: mod.options:get falls back to the schema, finds nothing, and
-- answers nil.  DEFAULTS below is the backstop, so a hidden row still reads
-- as its real value.  Nothing outside this file needs to know which
-- mechanism did the hiding.
--
-- visible_if also takes exactly ONE condition (a key plus equals or
-- not_equals); there is no AND.  That is why there is no PRESET row: the
-- rows that would need it already spend their one condition on hm_users.
-- The defaults below ARE the solo run ruleset, so a fresh install never
-- needs this screen at all.

local options = {}

-- Every key in one place; the feature files index this rather than
-- retyping string literals that a rename would silently orphan.
options.KEYS = {
  STARTER_SLOT    = "starter_slot",
  STARTER_SPECIES = "starter_species",
  PERFECT_DVS     = "perfect_dvs",
  HM_USERS        = "hm_users",
  HM_SPAWNS       = "hm_spawns",
  BALLS_WORK      = "balls_work",
  AUTO_FIELD      = "auto_field",
  SELECT_MENU     = "select_menu",
  NO_ITEMS        = "no_battle_items",
  BADGE_BOOST     = "badge_boost",
  NO_EARLY_WILDS  = "no_early_wilds",
  INSTANT_TEXT    = "instant_text",
  NO_SOUND_WAITS  = "no_sound_waits",
  NO_POISON       = "no_poison_flash",
  LIGHT_TUNNEL    = "light_rock_tunnel",
  AUTO_TRASH      = "auto_trash",
}

local K = options.KEYS

-- Filled in from the row list at install; read whenever the schema no
-- longer carries a row because it is currently hidden.
options.DEFAULTS = {}

-- Species list for the STARTER row.  Built at install time, which is safe
-- only because the manifest sets priority 900: load order is priority
-- ASCENDING, so every species-adding mod has already registered by now.
local function speciesChoices(mod)
  local list = {}
  for id, def in mod.content.pokemon:each() do
    if def and def.name and def.name ~= "" then
      list[#list + 1] = { name = def.name, id = id }
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  local choices = {}
  for _, entry in ipairs(list) do
    choices[#choices + 1] = { entry.name, entry.id }
  end
  return choices
end

local function buildRows(mod)
  local species = speciesChoices(mod)
  local defaultSpecies = species[1] and species[1][2] or "CHARMANDER"

  return {
    -- ---- changed every run, so first ----
    { key = K.STARTER_SLOT, label = "REPLACE BALL", type = "choice",
      default = "CHARMANDER",
      choices = {
        { "CHARMANDER", "CHARMANDER" },
        { "BULBASAUR", "BULBASAUR" },
        { "SQUIRTLE", "SQUIRTLE" },
      } },
    { key = K.STARTER_SPECIES, label = "NEW STARTER", type = "choice",
      default = defaultSpecies, choices = species },
    { key = K.PERFECT_DVS, label = "PERFECT DVS", type = "toggle",
      default = true },

    -- ---- the HM rule, and the two rows that only exist because of it ----
    { key = K.HM_USERS, label = "NEED HM USERS", type = "toggle",
      default = false },
    { key = K.HM_SPAWNS, label = "HM MON SPAWNS", type = "toggle",
      default = true, visible_if = { key = K.HM_USERS, equals = true } },
    { key = K.BALLS_WORK, label = "BALLS ALWAYS WORK", type = "toggle",
      default = true, visible_if = { key = K.HM_USERS, equals = true } },

    -- ---- overworld ----
    { key = K.AUTO_FIELD, label = "AUTO FIELD MOVES", type = "toggle",
      default = true },
    { key = K.SELECT_MENU, label = "SELECT FIELD MENU", type = "toggle",
      default = true },

    -- ---- battle ----
    { key = K.NO_ITEMS, label = "NO BATTLE ITEMS", type = "toggle",
      default = true },
    { key = K.BADGE_BOOST, label = "BADGE BOOST", type = "toggle",
      default = true },

    -- ---- set and forget ----
    { key = K.NO_EARLY_WILDS, label = "NO EARLY WILDS", type = "toggle",
      default = true },
    { key = K.INSTANT_TEXT, label = "INSTANT TEXT", type = "toggle",
      default = true },
    { key = K.NO_SOUND_WAITS, label = "NO SOUND WAITS", type = "toggle",
      default = true },
    { key = K.NO_POISON, label = "NO POISON FLASH", type = "toggle",
      default = true },
    { key = K.LIGHT_TUNNEL, label = "LIGHT ROCK TUNNEL", type = "toggle",
      default = true },
    { key = K.AUTO_TRASH, label = "AUTO TRASH PUZZLE", type = "toggle",
      default = true },
  }
end

-- Reads a key without consulting the schema, so it still answers correctly
-- while the row is filtered out of it.
local function rawValue(mod, key)
  local value = mod.options:get(key)
  if value == nil then value = options.DEFAULTS[key] end
  return value
end

-- The same test the engine applies from 0.1.95 on, evaluated here so the
-- behaviour is identical on the versions that do not have it.
local function rowVisible(mod, row)
  local condition = row.visible_if
  if condition == nil then return true end
  if type(condition) ~= "table" or type(condition.key) ~= "string" then
    return false
  end
  local value = rawValue(mod, condition.key)
  if condition.equals ~= nil then return value == condition.equals end
  if condition.not_equals ~= nil then return value ~= condition.not_equals end
  return false
end

function options.install(mod)
  local allRows = buildRows(mod)

  options.DEFAULTS = {}
  local watched = {}
  for _, row in ipairs(allRows) do
    options.DEFAULTS[row.key] = row.default
    if type(row.visible_if) == "table"
        and type(row.visible_if.key) == "string" then
      watched[row.visible_if.key] = true
    end
  end

  local game
  mod.events:on("game.ready", function(ev) game = (ev and ev.game) or game end)

  local function publish()
    local shown = {}
    for _, row in ipairs(allRows) do
      if rowVisible(mod, row) then shown[#shown + 1] = row end
    end
    mod.options:define(shown)
    return shown
  end

  -- Re-defining the schema is enough for the NEXT time the options screen
  -- is opened, but the screen currently on the stack has already cached its
  -- rows -- so a row toggled while looking at it does not vanish until you
  -- back out and come in again.  From 0.1.95 the engine rebuilds those rows
  -- itself when a visibility key changes; below that nothing does.
  --
  -- This performs the same rebuild the engine's own refresh() performs, on
  -- the live screen, keeping the cursor on whichever row it was on.  Every
  -- step is guarded: on any engine where the shape differs, the fallback is
  -- the old behaviour of updating on reopen rather than an error.
  local function rebuildOpenMenu(schema)
    local ok, ManagerState = pcall(require, "src.mods.ManagerState")
    if not (ok and ManagerState) then return end
    local stack = game and game.stack
    local top = stack and stack.top and stack:top()
    if not (top and getmetatable(top) == ManagerState) then return end
    if top.screen ~= "options" then return end
    if type(top.buildOptionRows) ~= "function" then return end
    local record = top.currentMod
    if not (record and record.id == mod.id) then return end

    local rows = top.optionRows or {}
    local keep = rows[top.cursor] and rows[top.cursor].id
    top.optionRows = top:buildOptionRows(record, schema)
    local n = #top.optionRows
    if keep then
      for index, row in ipairs(top.optionRows) do
        if row.id == keep then top.cursor = index break end
      end
    end
    if top.cursor > n then top.cursor = n end
    if top.cursor < 1 then top.cursor = 1 end
  end

  publish()

  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id) then return end
    if not watched[ev.key] then return end
    local schema = publish()
    pcall(rebuildOpenMenu, schema)
  end)
end

-- Shorthand the feature files use.  Reading through here rather than
-- calling mod.options:get directly keeps every read at call time and
-- routes it through the DEFAULTS backstop.
function options.get(mod, key)
  return rawValue(mod, key)
end

function options.on(mod, key)
  return rawValue(mod, key) == true
end

return options
