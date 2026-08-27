-- Brock Skip: removes the youngster who blocks the east exit of Pewter
-- City and escorts you to the gym (scripts/PewterCity.asm
-- PewterCityCheckPlayerLeavingEastScript / PewterCityYoungsterShowsPlayer-
-- GymScript, ported in data/scripts/story5.lua as M.PEWTER_CITY). With this
-- on you can just walk out of Pewter without ever fighting Brock.
--
-- Two pieces, both live-toggleable like everything else in the pack:
--
--   1. onEnter hides or shows PEWTERCITY_YOUNGSTER with the exact same
--      Commands.hide_object / show_object toggle the real Brock victory
--      uses (data/scripts/victories.lua OPP_BROCK#1.hide), so "skipped" is
--      indistinguishable from the vanilla "already beaten" state. Once
--      EVENT_BEAT_BROCK is actually set the real victory owns him forever
--      and this leaves him alone.
--
--   2. onStep on PEWTER_CITY returns true on the four trigger tiles
--      (PewterGymGuyCoords in engine/events/pewter_guys.asm) to consume the
--      step before the escort ever arms. map_scripts composes onStep with
--      a "first truthy wins" rule and runs every mod contribution at
--      priority >= 0 before the engine's own base contribution, so this
--      always gets first refusal and the base handler's own
--      EVENT_BEAT_BROCK check never runs while the toggle is on.
--
-- Hiding the NPC already removes him from ow.npcs/ow.entities (so talking
-- to him is moot, there is nothing left to talk to), which is why this
-- file never touches the TEXT_PEWTERCITY_YOUNGSTER talk handler at all.

local feature = {}

local MAP = "PEWTER_CITY"
local NPC = "PEWTERCITY_YOUNGSTER"

-- PewterGymGuyCoords (engine/events/pewter_guys.asm): the four tiles that
-- arm PewterCityYoungsterShowsPlayerGymScript.
local TRIGGER_TILES = {
  { 35, 17 }, { 36, 17 }, { 37, 18 }, { 37, 19 },
}

local function onTrigger(x, y)
  for _, c in ipairs(TRIGGER_TILES) do
    if x == c[1] and y == c[2] then return true end
  end
  return false
end

function feature.install(mod, options)
  local K = options.KEYS
  local Commands = require("src.script.Commands")

  local function apply(game, ow)
    if not (game and game.save) then return end
    -- the real gym victory already hid him for good; do not fight that
    if game.save.flags.EVENT_BEAT_BROCK then return end
    local ctx = { game = game, save = game.save, overworld = ow }
    if options.on(mod, K.BROCK_SKIP) then
      Commands.hide_object(ctx, MAP, NPC)
    else
      Commands.show_object(ctx, MAP, NPC)
    end
  end

  local game
  mod.events:on("game.ready", function(ev) game = (ev and ev.game) or game end)

  -- flipping the toggle while already standing in Pewter applies at once,
  -- same as LIGHT ROCK TUNNEL in sr_world_tweaks.lua
  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id and ev.key == K.BROCK_SKIP) then return end
    local ow = game and game.overworld
    if ow and ow.map and ow.map.id == MAP then apply(game, ow) end
  end)

  mod.content.map_scripts:register(MAP, {
    onEnter = function(g, ow) apply(g, ow) end,

    onStep = function(g, ow, x, y)
      if not options.on(mod, K.BROCK_SKIP) then return false end
      if g.save.flags.EVENT_BEAT_BROCK then return false end
      return onTrigger(x, y)
    end,
  })
end

return feature
