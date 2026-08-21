-- Instant text, in battle as well as out of it.
--
-- THERE ARE TWO TYPEWRITERS, WHICH IS WHY THIS USED TO HALF-WORK.
--
-- Menus, signs and NPC dialogue type through TextBox.update.  Battle text
-- does not: BattleState:updateQueue has its own character loop.  Patching
-- only TextBox therefore leaves every battle running at the OPTION menu's
-- speed, which is the bug the old standalone mod had.
--
-- Worth knowing if a viewer also runs a text-speed mod that adds values to
-- the TEXT SPEED row: both loops sanitise the setting with
--
--   if delay ~= 1 and delay ~= 3 and delay ~= 5 then delay = 3 end
--
-- so a non-numeric speed silently becomes MEDIUM in battle -- slower than
-- FAST, not faster.  This mod stays off save.options.textSpeed entirely and
-- keeps its own toggle, so the OPTION menu still means what it says and
-- nothing leaks into the save converters or the launcher settings, which
-- both read that field expecting 1, 3 or 5.
--
-- Both patches drive the ORIGINAL update repeatedly within a single frame
-- rather than reimplementing the cadence, so every page break, scroll pause
-- and prompt still happens exactly where it did -- the characters just all
-- arrive at once.  The guard is a runaway stop, not a tuning knob.
--
-- NO SOUND WAITS: THE OTHER HALF OF THE DELAY
--
-- Instant text does nothing about the pauses that are not text at all.  The
-- original blocks on WaitForSoundToFinish, and this port is faithful to it
-- in two places, both gated on a LOVE audio source still reporting that it
-- is playing:
--
--   * the overworld/menu box, when a script hands it auto.sound -- the item
--     and key-item jingles ride on that, which is the pause on receiving
--     the POKEDEX
--   * the battle queue's waitingSound, which is a level-up jingle, a
--     move-learn jingle, or a cry as a Pokemon is sent out
--
-- The wait is dropped by clearing the reference to the source, NOT by
-- stopping it.  The sound still plays; the game simply stops standing
-- still while it does.  With sound on, that means a cry can overlap the
-- text after it, which is why this is its own toggle rather than part of
-- instant text.

local feature = {}

local GUARD_LIMIT = 4000

function feature.install(mod, options)
  local K = options.KEYS

  local function req(path)
    local ok, module = pcall(require, path)
    return ok and module or nil
  end

  local function enabled() return options.on(mod, K.INSTANT_TEXT) end
  local function skipSound() return options.on(mod, K.NO_SOUND_WAITS) end

  -- ---------------------------------------------------------------------
  -- overworld, menus, signs
  -- ---------------------------------------------------------------------

  local TextBox = req("src.render.TextBox")
  if TextBox and TextBox.update then
    local slot = rawget(TextBox, "__soloRunInstant")
    if not slot then
      slot = {}
      TextBox.__soloRunInstant = slot
      local original = TextBox.update
      TextBox.update = function(self, dt)
        original(self, dt)
        -- the jingle has been started by now; drop the handle so the box
        -- stops waiting on it, then let the box advance on the same frame
        if self.autoSrc and slot.skipSound and slot.skipSound() then
          self.autoSrc = nil
          original(self, dt)
        end
        if not (slot.enabled and slot.enabled()) then return end
        local guard = 0
        while not self.done and not self.waiting and not self.stay
              and not self.auto and not self.choice
              and (self.holdFrames or 0) <= 0
              and guard < GUARD_LIMIT do
          original(self, dt)
          guard = guard + 1
        end
      end
    end
    slot.enabled = enabled
    slot.skipSound = skipSound
  else
    mod.log:error("instant text: could not find TextBox.update")
  end

  -- ---------------------------------------------------------------------
  -- battle
  -- ---------------------------------------------------------------------

  -- updateQueue returns true while the queue is still busy.  Re-running it
  -- drains the current message's characters; the loop stops the moment the
  -- queue reports it is waiting on the player, holding frames, waiting on a
  -- sound, or finished, so prompts and animations are untouched.
  local BattleState = req("src.battle.BattleState")
  if BattleState and BattleState.updateQueue then
    local slot = rawget(BattleState, "__soloRunInstantBattle")
    if not slot then
      slot = {}
      BattleState.__soloRunInstantBattle = slot
      local original = BattleState.updateQueue
      BattleState.updateQueue = function(self, ...)
        local dropSound = slot.skipSound and slot.skipSound()
        -- the queue item that set this has already been removed, so
        -- clearing it cannot make the same row fire twice
        if dropSound then self.waitingSound = nil end
        local busy = original(self, ...)
        if dropSound then self.waitingSound = nil end
        if not (slot.enabled and slot.enabled()) then return busy end
        local guard = 0
        while busy and guard < GUARD_LIMIT do
          if dropSound then self.waitingSound = nil end
          if self.waitingUI or self.msgWaiting or self.waitingSound
              or self.draining or (self.waitFrames or 0) > 0 then
            break
          end
          local current = self.current
          if not current then break end
          -- stop once this message has finished typing; the queue itself
          -- decides what happens next
          local shown = self.shown and self.shown[#self.shown]
          if shown and self.codes and #shown >= #self.codes then break end
          busy = original(self, ...)
          guard = guard + 1
        end
        return busy
      end
    end
    slot.enabled = enabled
    slot.skipSound = skipSound
  else
    mod.log:error("instant text: could not find BattleState.updateQueue")
  end
end

return feature
