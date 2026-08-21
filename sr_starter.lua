-- Starter: which of Oak's balls gets swapped, what it becomes, and DVs.
--
-- PERFECT DVS IS STARTER-ONLY, WHICH IS A CHANGE FROM THE OLD MOD.
--
-- The original replaced Stats.randomDVs outright, so every wild Pokemon in
-- the game also came out with 15s.  Trainers were never affected -- battle
-- setup builds each enemy with Pokemon.new and then overwrites its DVs with
-- the fixed 9/8/8/8/8 trainer spread -- so gym leaders and rivals were
-- always vanilla.  But wild mons were not, which quietly made every wild
-- battle harder than the real thing.
--
-- pokemon.before_give cannot set DVs: it carries species, level and
-- nickname, and the Pokemon object is built afterward.  What it CAN do is
-- arm a one-shot.  Pokemon.new calls Stats.randomDVs exactly once and the
-- call happens immediately after the event, synchronously, so the very next
-- roll is the starter's and nothing else can slip between them.
--
-- The patch stays installed either way and the one-shot is armed only when
-- the toggle is on at gift time, so PERFECT DVS takes effect without a
-- restart.
--
-- WHY THE PRESENTATION NEEDS ITS OWN SEAM
--
-- pokemon.before_give fires from Commands.give_pokemon, which in Oak's lab
-- is row 11 of the ball script (data/scripts/oaks_lab.lua, starterBall).
-- Three earlier rows name the species the ball was authored with, so
-- swapping the gift alone left the pick showing CHARMANDER and then handing
-- over something else:
--
--   row  5  push_screen DexEntryMenu { species = <ball> }  the preview page
--   row  6  ask         _OaksLabYouWant<Ball>Text          "So! You want..."
--   row 10  show_text   _OaksLabReceivedMonText { RAM = <ball> }
--
-- Row 5 is the visible one: the dex page owns the front sprite, the height
-- and weight, the description and -- via DexEntryMenu.new -- the cry.  All
-- four follow the species argument, so rewriting that one value fixes the
-- whole page at once.
--
-- The engine already has a mechanism for row 10's problem: give_pokemon
-- sets ctx.pendingPokemonName to the post-swap species and show_text
-- prefers it over any RAM substitution it was handed.  It does not help
-- here only because this script prints the line BEFORE it gives the mon.
-- (It does reach the nickname prompt, which runs inside give_pokemon --
-- which is why the unpatched game offers to nickname the right Pokemon
-- immediately after announcing the wrong one.)
--
-- Row 6 is a ROM string with the type baked into the sentence ("the fire
-- POKeMON, CHARMANDER").  There is no substitution slot to aim at and the
-- clause is wrong for any replacement that is not that type, so the line is
-- replaced wholesale with a neutral one.  show_text falls back to treating
-- an unrecognised text id as a literal string, so a plain sentence is a
-- legal thing to hand it.  ASK_LINE is deliberately punctuation the font
-- actually has -- no percent, plus or equals sign (see sr_options.lua).
--
-- All three ride ONE hook.  ScriptRunner:exec resolves every row through
-- "script.command" with the row's arguments in a table it built fresh for
-- that dispatch, so a wrapper can rewrite an argument before the command
-- runs.  That is a lighter touch than overriding the verbs themselves --
-- show_text is most of the dialogue in the game -- and Hooks:call pcalls
-- each link, so a throw here is logged and skipped rather than taking the
-- textbox with it.
--
-- ONE TABLE IN THIS PATH IS SHARED AND MUST NOT BE WRITTEN TO.  The args
-- array is rebuilt per dispatch and is safe to edit.  The tables INSIDE it
-- are not: starterBall() builds its rows once at load and map_scripts holds
-- them for the session, so writing args[2].species would rewrite the script
-- permanently and the second run of the game would preview the replacement
-- even with the mod off.  Nested tables are copied before they are changed.

local feature = {}

local PERFECT = { attack = 15, defense = 15, speed = 15, special = 15 }

local STARTER_MAP  = "OAKS_LAB"
local BALL_SCREEN  = "DexEntryMenu"
local RECEIVED_ROW = "_OaksLabReceivedMonText"

-- data/scripts/oaks_lab.lua:187-195 -- the ask text each ball was authored
-- with, which is the only thing identifying the ball on that row.
local ASK_ROWS = {
  ["_OaksLabYouWantCharmanderText"] = "CHARMANDER",
  ["_OaksLabYouWantSquirtleText"]   = "SQUIRTLE",
  ["_OaksLabYouWantBulbasaurText"]  = "BULBASAUR",
}

-- No explicit line break: TextBox.paginate soft-wraps on word boundaries at
-- 18 columns, so a long name from a species-adding mod wraps or paginates
-- instead of overrunning the box.
local ASK_LINE = "So! You want to pick %s?"

-- Gen 1 HP DV is derived from the low bit of the other four
local function withHp(dvs)
  local out = {}
  for k, v in pairs(dvs) do out[k] = v end
  out.hp = (out.attack % 2) * 8 + (out.defense % 2) * 4
    + (out.speed % 2) * 2 + (out.special % 2)
  return out
end

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

function feature.install(mod, options)
  local K = options.KEYS

  local function pokedex(ctx)
    local data = ctx and ctx.game and ctx.game.data
    return data and data.pokemon or nil
  end

  -- The one test all four sites share: this is the ball the player elected
  -- to replace, we are standing in Oak's lab, the starter has not been
  -- taken yet, and the replacement is a species that actually exists.
  -- Returns the replacement id, or nil to leave the row alone.
  --
  -- The flag check is what keeps the rival's own received-mon line (row 20)
  -- out of this: EVENT_GOT_STARTER is set at row 12, before he picks.
  local function replacementFor(ctx, ballSpecies)
    if type(ballSpecies) ~= "string" then return nil end
    if ballSpecies ~= options.get(mod, K.STARTER_SLOT) then return nil end

    local map = ctx and ctx.overworld and ctx.overworld.map
    if not (map and map.id == STARTER_MAP) then return nil end

    local save = ctx and ctx.save
    if not (save and save.flags and not save.flags.EVENT_GOT_STARTER) then
      return nil
    end

    local replacement = options.get(mod, K.STARTER_SPECIES)
    if type(replacement) ~= "string" or replacement == ballSpecies then
      return nil
    end

    local species = pokedex(ctx)
    if not (species and species[replacement]) then
      mod.log:error("starter: NEW STARTER is %s, which no longer exists; "
        .. "leaving the ball alone", tostring(replacement))
      return nil
    end
    return replacement
  end

  local function displayName(ctx, id)
    local species = pokedex(ctx)
    local def = species and species[id]
    return (def and def.name) or id
  end

  -- ---------------------------------------------------------------------
  -- the gift itself
  -- ---------------------------------------------------------------------

  mod.events:on("pokemon.before_give", function(gift)
    local replacement = replacementFor(gift.ctx, gift.species)
    if not replacement then return end

    gift.species = replacement
    gift.level = 5

    -- consumed by the very next randomDVs call, which is this gift's
    if options.on(mod, K.PERFECT_DVS) then
      feature.armed = true
    end
  end)

  -- ---------------------------------------------------------------------
  -- the three rows that still name the ball's original species
  -- ---------------------------------------------------------------------

  mod.hooks:wrap("script.command", function(nextFn, ctx, name, args)
    -- Every script row in the game comes through here, so the miss path is
    -- three string compares and out.
    if type(args) == "table" then
      if name == "push_screen" and args[1] == BALL_SCREEN
          and type(args[2]) == "table" then
        local page = args[2]
        local replacement = replacementFor(ctx, page.species or page[1])
        if replacement then
          local swapped = copy(page)
          if swapped.species ~= nil then
            swapped.species = replacement
          else
            swapped[1] = replacement
          end
          args[2] = swapped
        end

      elseif name == "ask" and ASK_ROWS[args[1]] then
        local replacement = replacementFor(ctx, ASK_ROWS[args[1]])
        if replacement then
          args[1] = ASK_LINE:format(displayName(ctx, replacement))
          -- the ROM line took no substitutions; make sure none ride along
          args[2] = nil
        end

      elseif name == "show_text" and args[1] == RECEIVED_ROW
          and type(args[2]) == "table" then
        local replacement = replacementFor(ctx, args[2].RAM)
        if replacement then
          local subs = copy(args[2])
          subs.RAM = displayName(ctx, replacement)
          args[2] = subs
        end
      end
    end
    return nextFn(ctx, name, args)
  end)

  -- ---------------------------------------------------------------------
  -- perfect DVs, armed one gift at a time
  -- ---------------------------------------------------------------------

  local Stats
  pcall(function() Stats = require("src.pokemon.Stats") end)

  if not (Stats and Stats.randomDVs) then
    mod.log:error("starter: could not find Stats.randomDVs")
    return
  end

  -- Stats is a required singleton and survives an F5 reload, so the patch
  -- gets the marker+slot treatment rather than a boolean guard.
  local slot = rawget(Stats, "__soloRunDVs")
  if not slot then
    slot = {}
    Stats.__soloRunDVs = slot
    local original = Stats.randomDVs
    Stats.randomDVs = function(rng)
      if slot.takeArmed and slot.takeArmed() then
        return withHp(PERFECT)
      end
      return original(rng)
    end
  end
  slot.takeArmed = function()
    if not feature.armed then return false end
    feature.armed = false
    return true
  end
end

return feature
