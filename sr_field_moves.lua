-- Field moves: the HM-user rule, contact triggers, and the SELECT menu.
--
-- THE HM RULE
--
-- Every field move in the game funnels through OverworldState:partyKnows,
-- which the engine routes through the fieldmove.eligibility hook.  Wrapping
-- that one hook covers the party menu, the SELECT menu, the collision
-- triggers below and the surfing-Pikachu sprite check all at once, with no
-- monkeypatching anywhere.
--
-- With NEED HM USERS off, the vanilla "a party member knows this move"
-- requirement is replaced by "you hold the badge AND you have obtained the
-- machine".  The move is then credited to the lead party mon, which is what
-- makes the "<STARTER> used STRENGTH" line read correctly on a solo run.
--
-- The widening is strictly additive: whenever it does not apply, the
-- vanilla answer is returned untouched, so a mon that genuinely knows the
-- move still works exactly as before.
--
-- Machines are matched by what they TEACH, not by item id.  Item defs carry
-- machine = { kind = "HM", move = "CUT" }, so scanning the bag for a def
-- whose machine.move matches covers HM01-HM05 and TM_DIG uniformly and
-- survives any item-id rename.
--
-- OBTAINED, NOT HELD.  HMs are never consumed, but TM_DIG is, and the DIG
-- machine is genuinely worth teaching.  So the first time a machine is ever
-- seen in the bag it is recorded in mod.save and counts forever after.  DIG
-- additionally accepts EVENT_BEAT_CERULEAN_ROCKET_THIEF, the engine's own
-- flag for the Cerulean thief who hands TM_DIG over, which covers a save
-- that already spent the TM before this mod was installed.
--
-- DIG is gated on CASCADEBADGE.  It has no vanilla badge because it is a TM;
-- Misty is the right gate because the thief is beaten on the way out of
-- Cerulean and Surge is occasionally skipped.
--
-- TELEPORT is deliberately NOT widened.  There is no Teleport machine to
-- own, so the rule stays "your Pokemon actually knows it" and the SELECT
-- menu is purely a shortcut past the party menu.

local feature = {}

-- Moves the pack will credit to the lead mon.  Everything absent from this
-- table keeps its vanilla answer, TELEPORT included.
local EXTRA_BADGES = { DIG = "CASCADEBADGE" }

-- Machines that survive being spent, keyed to the event flag that proves
-- the machine was once handed over.
local PERMANENT_FLAGS = { DIG = "EVENT_BEAT_CERULEAN_ROCKET_THIEF" }

local WIDENED = {
  CUT = true, SURF = true, STRENGTH = true,
  FLY = true, FLASH = true, DIG = true,
}

function feature.install(mod, options)
  local K = options.KEYS
  local FieldDefaults = require("src.world.FieldDefaults")
  local Map = require("src.world.Map")

  local game
  mod.events:on("game.ready", function(ev) game = (ev and ev.game) or game end)

  -- ---------------------------------------------------------------------
  -- eligibility: badge plus machine, in place of an HM user
  -- ---------------------------------------------------------------------

  local function badgeFor(data, moveId)
    local gates = FieldDefaults.constant(data, "hmBadges") or {}
    local gate = gates[moveId]
    return (gate and gate.badge) or EXTRA_BADGES[moveId]
  end

  local function machineInBag(save, data, moveId)
    local items = data and data.items or {}
    for id, count in pairs(save.inventory or {}) do
      if type(count) == "number" and count > 0 then
        local def = items[id]
        if def and def.machine and def.machine.move == moveId then
          return true
        end
      end
    end
    return false
  end

  -- "have you ever had it", not "is it in the bag right now"
  local function machineObtained(save, data, moveId)
    local remembered = "had_machine_" .. moveId
    if mod.save:get(remembered, false) then return true end
    if machineInBag(save, data, moveId) then
      mod.save:set(remembered, true)
      return true
    end
    local flag = PERMANENT_FLAGS[moveId]
    if flag and save.flags and save.flags[flag] then
      mod.save:set(remembered, true)
      return true
    end
    return false
  end

  mod.hooks:wrap("fieldmove.eligibility", function(nextFn, moveId, ctx)
    local vanilla = nextFn(moveId, ctx)
    if vanilla then return vanilla end
    if options.on(mod, K.HM_USERS) then return vanilla end
    if not WIDENED[moveId] then return vanilla end

    local save = ctx and ctx.save
    local data = ctx and ctx.data
    if not (save and data) then return vanilla end

    local badge = badgeFor(data, moveId)
    if badge and not (save.inventory or {})[badge] then return vanilla end
    if not machineObtained(save, data, moveId) then return vanilla end

    -- credit the lead mon: callers read .species for the cry and
    -- .nickname for the message text
    local lead = save.party and save.party[1]
    return lead or vanilla
  end)

  -- ---------------------------------------------------------------------
  -- contact triggers: walk into it and the move fires, with no textbox
  -- ---------------------------------------------------------------------

  -- The engine's own flows carry their continuation in the textbox
  -- callback, so the box is popped and its onDone run immediately: every
  -- real step (mount, animation, sound) still happens, the text never
  -- appears.  Called repeatedly because STRENGTH chains two pages.
  local function skipText(stack)
    local TextBox = mod.ui.TextBox
    for _ = 1, 3 do
      local top = stack:top()
      if not (top and getmetatable(top) == TextBox) then break end
      stack:pop()
      if top.onDone then top.onDone() end
    end
  end

  -- Surf's party-menu flow ends in a full-screen white blink, which reads
  -- as a glitch when the trigger was a footstep.  Run the transition's
  -- continuation without the flash itself.
  local function skipFlash(stack)
    local top = stack:top()
    if top and top.onDone and top.frames and top.t then
      stack:pop()
      top.onDone()
    end
  end

  mod.hooks:wrap("movement.collision", function(nextFn, allowed, ctx)
    allowed = nextFn(allowed, ctx)
    if allowed then return true end
    if not options.on(mod, K.AUTO_FIELD) then return false end

    local ow = mod.world:overworld()
    if not (ow and game and ctx.mover == ow.player) then return false end
    local stack = game.stack

    if ctx.reason == "tile" then
      if ctx.map:isWaterCell(ctx.toX, ctx.toY) and not ow.player.surfing then
        -- the collision's own direction is authoritative here: a bump can
        -- arrive before the player object's facing has been refreshed
        if ctx.dir then ow.player.facing = ctx.dir end
        if ow:useSurfFieldMove() ~= "ok" then return false end
        ow:trySurf(ctx.toX, ctx.toY)
        skipText(stack)
        skipFlash(stack)
        return false
      end
      if ow:useCutFieldMove() == "ok" and ow:tryCut(ctx.toX, ctx.toY) then
        skipText(stack)
        return false
      end
    elseif ctx.reason == "entity" and not ow.strengthActive then
      local npc = ow:npcAtCell(ctx.toX, ctx.toY)
      if npc and Map.isPushable(npc.def) and ow:partyKnows("STRENGTH") then
        if ow:useStrengthFieldMove() then
          skipText(stack)
          skipFlash(stack)
        end
        return false
      end
    end
    return false
  end)

  -- Entering a dark cave lights it, when the darkness is still there at all
  -- (LIGHT ROCK TUNNEL removes it outright and makes this moot).
  mod.events:on("map.entered", function()
    if not options.on(mod, K.AUTO_FIELD) then return end
    local ow = mod.world:overworld()
    if not (ow and game and ow.dark) then return end
    if not ow:partyKnows("FLASH") then return end
    -- setDark may rebuild the map atlas and re-emit map.entered; flashLit
    -- has to be true before that happens or the nested entry starts a
    -- second activation and recurses
    game.save.flashLit = true
    ow:setDark(false)
    game.stack:push(require("src.render.Transition").whiteFlash(game))
  end)

  -- ---------------------------------------------------------------------
  -- SELECT: the moves with no contact trigger
  -- ---------------------------------------------------------------------

  local function bottomMenu(items)
    local width = 10
    for _, item in ipairs(items) do
      width = math.max(width, #item.label + 4)
    end
    local height = #items * 2 + 2
    game.stack:push(mod.ui.Menu.new(game, items, {
      tx = 20 - width, ty = 18 - height, tw = width, th = height,
    }))
  end

  -- The SELECT menu, in a fixed order regardless of what is unlocked:
  -- BICYCLE, FLY, DIG, TELEPORT.  Availability changes across a run, so an
  -- order that depended on it would move entries under the player's thumb.
  --
  -- BICYCLE, DIG and TELEPORT all come from mod.world:availableFieldActions,
  -- which already applies every gate the party menu would: the bike needs
  -- to be in the bag and the map to allow it and the player not to be
  -- surfing, DIG needs a diggable tileset, TELEPORT needs to be outdoors.
  -- Asking for them rather than recomputing means those gates cannot drift.
  -- FLY is the exception: it is not a field action because it opens the
  -- town map, so it is built here.
  local SELECT_ORDER = { "bicycle", "fly", "dig", "teleport" }

  local function openSelectMenu(ow)
    local available = {}
    for _, action in ipairs(mod.world:availableFieldActions()) do
      available[action.id] = action
    end

    local outside = Map.isOutside(ow.map.def,
      FieldDefaults.field(game.data, "outsideTilesets"))

    local items = {}
    for _, id in ipairs(SELECT_ORDER) do
      if id == "fly" then
        if outside and ow:partyKnows("FLY") then
          items[#items + 1] = { label = "FLY", onSelect = function()
            mod.ui.push(game, "TownMap", { fly = true, onFly = function(mapId)
              ow:flyTo(mapId)
            end })
          end }
        end
      else
        local action = available[id]
        if action then
          items[#items + 1] = { label = action.label, onSelect = function()
            mod.world:useFieldAction(id)
          end }
        end
      end
    end

    if #items == 0 then return false end
    items[#items + 1] = { label = "CANCEL" }
    bottomMenu(items)
    return true
  end

  -- handleInput lives on the OverworldController module table, which
  -- survives an F5 reload while this mod's environment does not.  Marker
  -- installs the wrapper exactly once ever; slot lets the newest load claim
  -- it, so a reload replaces the handler instead of stacking a second one.
  do
    local OverworldController = require("src.world.OverworldController")
    local slot = rawget(OverworldController, "__soloRunSelect")
    if not slot then
      slot = {}
      OverworldController.__soloRunSelect = slot
      local original = OverworldController.handleInput
      OverworldController.handleInput = function(self, ...)
        if slot.onInput and slot.onInput(self) then return end
        return original(self, ...)
      end
    end
    slot.onInput = function(ow)
      if not options.on(mod, K.SELECT_MENU) then return false end
      if not (game and game.stack and game.stack:top() == ow) then
        return false
      end
      if not game.input:wasPressed("select") then return false end
      return openSelectMenu(ow)
    end
  end
end

return feature
