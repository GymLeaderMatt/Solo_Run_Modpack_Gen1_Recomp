-- Battle rules: the item lock, and the badge boost glitch.
--
-- THE ITEM LOCK ALLOWS BALLS, DELIBERATELY
--
-- Throwing a ball goes through the same bag the potions do, so blocking the
-- ITEM menu outright would make the guaranteed Paras and Doduo impossible to
-- catch and break the HM-user rule.  Instead the in-battle bag is filtered
-- to balls only: press ITEM and the bag opens with nothing in it but what
-- you can legally throw.  Nothing has to know about the HM toggle, and with
-- HM users off the list is simply never useful.
--
-- Item reordering is switched off while the list is filtered, because the
-- SELECT-key handler rebuilds the list from the real inventory and would
-- put the potions straight back.
--
-- THE BADGE BOOST GLITCH
--
-- In Gen 1 the 1st, 3rd, 5th and 7th badges each give a 12.5% in-battle
-- boost to one stat, and any successful stat change re-applies those boosts
-- to every OTHER badge-boosted stat.  So Growl, Leer, Tail Whip, Defense
-- Curl, Agility and Swords Dance all quietly stack extra boosts, up to the
-- stat cap.  A stat drops its stacked boosts when it is itself recalculated:
-- a stage change, a level-up, a switch, or the end of the battle.
--
-- This runs on the core.update hook rather than a Game.update patch.  The
-- old standalone mod guarded its patch with a flag in _G, which the sandbox
-- discards on an F5 reload while the patched Game table survives -- so every
-- reload stacked another wrapper and the boosts were applied twice.  Hook
-- subscriptions are torn down with the loader, so this cannot happen here.
--
-- More detail: https://www.dragonflycave.com/mechanics/gen-i-stat-modification/

local feature = {}

local GLITCH_STATS = { "attack", "defense", "speed", "special" }

local function clamp(v) return math.max(1, math.min(999, v)) end

function feature.install(mod, options)
  local K = options.KEYS
  local function req(path)
    local ok, module = pcall(require, path)
    return ok and module or nil
  end

  local BattleState = req("src.battle.BattleState")
  local Stats = req("src.pokemon.Stats")
  local Damage = req("src.battle.Damage")
  local ItemEffects = req("src.inventory.ItemEffects")
  local BagMenu = req("src.ui.BagMenu")

  local game
  mod.events:on("game.ready", function(ev) game = (ev and ev.game) or game end)

  -- ---------------------------------------------------------------------
  -- item lock
  -- ---------------------------------------------------------------------

  if BagMenu and BagMenu.new and ItemEffects and ItemEffects.isBall then
    local slot = rawget(BagMenu, "__soloRunItemLock")
    if not slot then
      slot = {}
      BagMenu.__soloRunItemLock = slot
      local original = BagMenu.new
      BagMenu.new = function(g, opts)
        local list = original(g, opts)
        if opts and opts.battle and list and slot.shouldFilter
            and slot.shouldFilter() then
          local kept = {}
          for _, item in ipairs(list.items or {}) do
            if ItemEffects.isBall(item.value) then kept[#kept + 1] = item end
          end
          list.items = kept
          list.index = math.min(list.index or 1, math.max(1, #kept))
          list.onSelectKey = nil
        end
        return list
      end
    end
    slot.shouldFilter = function() return options.on(mod, K.NO_ITEMS) end
  else
    mod.log:error("battle rules: could not install the item lock")
  end

  -- ---------------------------------------------------------------------
  -- badge boost glitch
  -- ---------------------------------------------------------------------

  if not (BattleState and Stats and Stats.applyStage) then
    mod.log:error("battle rules: could not install the badge boost glitch")
    return
  end

  local function currentBattle()
    local stack = game and game.stack
    if not (stack and stack.states) then return nil end
    for i = #stack.states, 1, -1 do
      if getmetatable(stack.states[i]) == BattleState then
        return stack.states[i]
      end
    end
    return nil
  end

  local function badgeBoostRow(battler, stat)
    local badges = battler.badges
    if not badges then return nil end
    local rows = battler.badgeBoosts or (Damage and Damage.BADGE_BOOSTS) or {}
    for _, row in ipairs(rows) do
      if row.stat == stat and badges[row.badge] then return row end
    end
    return nil
  end

  local function freshValue(battler, stat, baseValue)
    local stage = battler.stages and battler.stages[stat] or 0
    local value = Stats.applyStage(baseValue, stage)
    local row = badgeBoostRow(battler, stat)
    if row then value = math.floor(value * (row.num or 9) / (row.den or 8)) end
    return clamp(value)
  end

  -- weak keys: a battler that goes away takes its tracking with it
  local tracked = setmetatable({}, { __mode = "k" })
  local lastLevel = setmetatable({}, { __mode = "k" })

  local function ensureTracked(battler)
    local state = tracked[battler]
    -- a switch, a Haze, or any engine reset starts the count over
    if state and state.mon == battler.mon and battler.curStats == state.copy then
      return state
    end
    local base = {}
    for _, stat in ipairs(GLITCH_STATS) do base[stat] = battler.mon.stats[stat] end
    local copy = {}
    for k, v in pairs(battler.mon.stats) do copy[k] = v end
    if battler.curStats then
      for k, v in pairs(battler.curStats) do copy[k] = v end
    end
    -- the ordinary badge boost applied on entry
    for _, stat in ipairs(GLITCH_STATS) do
      copy[stat] = freshValue(battler, stat, base[stat])
    end
    battler.curStats = copy
    local lastStages = {}
    for _, stat in ipairs(GLITCH_STATS) do
      lastStages[stat] = battler.stages and battler.stages[stat] or 0
    end
    state = { mon = battler.mon, base = base, copy = copy, lastStages = lastStages }
    tracked[battler] = state
    return state
  end

  local function pollBattler(battler)
    if not (battler and battler.mon and battler.mon.stats) then return end
    if lastLevel[battler.mon] ~= battler.mon.level then
      lastLevel[battler.mon] = battler.mon.level
      tracked[battler] = nil -- a level-up clears the stacked boosts
    end
    local state = ensureTracked(battler)
    local stages = battler.stages or {}
    local changed, anyChanged = {}, false
    for _, stat in ipairs(GLITCH_STATS) do
      local current = stages[stat] or 0
      if current ~= state.lastStages[stat] then
        changed[stat] = true
        anyChanged = true
        state.lastStages[stat] = current
      end
    end
    if not anyChanged then return end
    for _, stat in ipairs(GLITCH_STATS) do
      if changed[stat] then
        -- the stat that actually moved recalculates normally
        battler.curStats[stat] = freshValue(battler, stat, state.base[stat])
      else
        -- every other badge-boosted stat gets another 12.5%
        local row = badgeBoostRow(battler, stat)
        if row then
          battler.curStats[stat] = clamp(math.floor(
            battler.curStats[stat] * (row.num or 9) / (row.den or 8)))
        end
      end
    end
  end

  mod.hooks:wrap("core.update", function(nextFn, g, dt)
    nextFn(g, dt)
    if not options.on(mod, K.BADGE_BOOST) then return end
    local battle = currentBattle()
    if not battle then return end
    if battle.player then pollBattler(battle.player) end
    if battle.enemy then pollBattler(battle.enemy) end
  end)
end

return feature
