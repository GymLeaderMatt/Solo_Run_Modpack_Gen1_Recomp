-- Three small world tweaks: poison, Rock Tunnel, and Surge's trash cans.
--
-- ROCK TUNNEL IS THE ONE WITH A TRAP IN IT.
--
-- Darkness comes from data.field.darkMaps, which is engine data loaded
-- once.  The old standalone mod simply overwrote it with an empty table at
-- load, which works exactly once: with the original gone there is nothing
-- to put back, so the toggle could never be turned off again without a
-- restart.  The original table is stashed here on first touch and swapped
-- in and out, so LIGHT ROCK TUNNEL is a live toggle like everything else.
--
-- Note that with this on, FLASH has nothing to light and the pack's
-- automatic FLASH-on-entering-a-dark-cave never fires.  That is expected:
-- the two features do the same job by different means.
--
-- Poison keeps hurting either way.  Only the screen blink and the every-
-- few-steps poison sound are suppressed, and the sound is silenced by
-- swapping Sound.play just for the duration of the engine's own field
-- poison call, so nothing else that happens to play at that moment is lost.

local feature = {}

function feature.install(mod, options)
  local K = options.KEYS

  local function req(path)
    local ok, module = pcall(require, path)
    return ok and module or nil
  end

  local game
  mod.events:on("game.ready", function(ev) game = (ev and ev.game) or game end)

  -- ---------------------------------------------------------------------
  -- poison: no blink, no noise
  -- ---------------------------------------------------------------------

  local OverworldController = req("src.world.OverworldController")
  local Sound = req("src.core.Sound")

  if OverworldController and OverworldController.applyFieldPoison and Sound then
    local slot = rawget(OverworldController, "__soloRunPoison")
    if not slot then
      slot = {}
      OverworldController.__soloRunPoison = slot
      local original = OverworldController.applyFieldPoison
      OverworldController.applyFieldPoison = function(self, ...)
        if not (slot.enabled and slot.enabled()) then
          return original(self, ...)
        end
        local realPlay = Sound.play
        Sound.play = function(data, name)
          if name == "Poisoned" then return nil end
          return realPlay(data, name)
        end
        local ok, result = pcall(original, self, ...)
        Sound.play = realPlay
        self.poisonFlash = 0
        if not ok then error(result, 0) end
        return result
      end
    end
    slot.enabled = function() return options.on(mod, K.NO_POISON) end
  else
    mod.log:error("world tweaks: could not install the poison change")
  end

  -- ---------------------------------------------------------------------
  -- Rock Tunnel: lights on
  -- ---------------------------------------------------------------------

  local stashedDarkMaps

  local function applyDarkMaps()
    local data = game and game.data
    local field = data and data.field
    if not field then return end
    if stashedDarkMaps == nil then stashedDarkMaps = field.darkMaps or false end
    if options.on(mod, K.LIGHT_TUNNEL) then
      field.darkMaps = { maps = {} }
    else
      field.darkMaps = stashedDarkMaps or nil
    end
  end

  mod.events:on("game.ready", function(ev)
    game = (ev and ev.game) or game
    applyDarkMaps()
  end)
  mod.events:on("save.loaded", applyDarkMaps)
  mod.events:on("map.entered", applyDarkMaps)
  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == mod.id and ev.key == K.LIGHT_TUNNEL then
      applyDarkMaps()
    end
  end)

  -- ---------------------------------------------------------------------
  -- Lt. Surge's trash cans
  -- ---------------------------------------------------------------------

  mod.content.map_scripts:register("VERMILION_GYM", {
    onEnter = function(g)
      if not options.on(mod, K.AUTO_TRASH) then return end
      g.save.flags.EVENT_1ST_LOCK_OPENED = true
      g.save.flags.EVENT_2ND_LOCK_OPENED = true
    end,
  })
end

return feature
