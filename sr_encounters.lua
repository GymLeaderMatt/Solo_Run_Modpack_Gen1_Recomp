-- Encounters: no early wilds, guaranteed HM-user spawns, reliable balls.
--
-- CONTINUITY WITH THE HM RULE
--
-- Mt. Moon and Route 16 only have encounters turned on at all so that the
-- Paras and the Doduo can be caught.  With NEED HM USERS off there is
-- nothing to catch there, so both maps join the zero-encounter list and the
-- two rows that configure them disappear from the options screen.  That is
-- handled here rather than with a row, because with no HM users there is
-- nothing left to decide.
--
-- BALLS ALWAYS WORK swaps in a ball definition with randMax 0 and autoCatch,
-- which is the master ball's behaviour on a regular POKE_BALL.  It only
-- applies while HM users are on, for the same reason.

local feature = {}

-- The two required HM users and where they are taken
local GUARANTEE_BY_MAP = {
  MT_MOON_1F = { species = "PARAS", level = 8 },
  ROUTE_16   = { species = "DODUO", level = 18 },
}

-- Everything reachable before repels are affordable
local ZERO_MAPS = {
  ROUTE_1 = true, ROUTE_22 = true, VIRIDIAN_FOREST = true, ROUTE_3 = true,
  MT_MOON_B1F = true, MT_MOON_B2F = true, ROUTE_6 = true,
}

local ALWAYS_CATCH = {
  randMax = 0, autoCatch = true, tossAnim = "ULTRATOSS_ANIM", flicker = true,
}

local function ownedKey(species) return "owned_" .. species end

function feature.install(mod, options)
  local K = options.KEYS

  mod.events:on("pokemon.caught", function(ev)
    for _, guarantee in pairs(GUARANTEE_BY_MAP) do
      if ev.species == guarantee.species then
        mod.save:set(ownedKey(guarantee.species), true)
      end
    end
  end)

  mod.hooks:wrap("encounter.roll", function(nextFn, encDef, ctx)
    if ctx.terrain ~= "grass" and ctx.terrain ~= "indoor" then
      return nextFn(encDef, ctx)
    end

    local usingHmUsers = options.on(mod, K.HM_USERS)
    local guarantee = GUARANTEE_BY_MAP[ctx.mapId]

    if guarantee then
      -- no HM users wanted: nothing to catch here, so nothing spawns
      if not usingHmUsers then return nil end
      if options.on(mod, K.HM_SPAWNS) then
        -- caught already: the map goes quiet for the rest of the run
        if mod.save:get(ownedKey(guarantee.species), false) then return nil end
        local rolled = nextFn(encDef, ctx)
        if rolled then
          return { species = guarantee.species, level = guarantee.level }
        end
        return nil
      end
    end

    if ZERO_MAPS[ctx.mapId] and options.on(mod, K.NO_EARLY_WILDS) then
      return nil
    end
    return nextFn(encDef, ctx)
  end)

  -- Catching.attempt is a module-table function on a required singleton, so
  -- marker+slot rather than a boolean guard: a plain guard lives in this
  -- mod's environment, which an F5 reload discards while the patch stays.
  local Catching
  pcall(function() Catching = require("src.battle.Catching") end)
  if not (Catching and Catching.attempt) then
    mod.log:error("encounters: could not find Catching.attempt")
    return
  end

  local slot = rawget(Catching, "__soloRunCatch")
  if not slot then
    slot = {}
    Catching.__soloRunCatch = slot
    local original = Catching.attempt
    Catching.attempt = function(ball, targetMon, targetDef, rng, rateOverride, opts)
      if slot.override and slot.override(ball) then
        opts = opts or {}
        opts.ballDef = ALWAYS_CATCH
      end
      return original(ball, targetMon, targetDef, rng, rateOverride, opts)
    end
  end
  slot.override = function(ball)
    return ball == "POKE_BALL"
      and options.on(mod, K.HM_USERS)
      and options.on(mod, K.BALLS_WORK)
  end
end

return feature
