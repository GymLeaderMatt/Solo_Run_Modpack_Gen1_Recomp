-- Solo Run Modpack: the whole solo-run ruleset as one installable mod.
--
-- Every feature that used to be its own zip lives in its own file here and
-- is switched from a single MOD OPTIONS screen.  The eight originals were
-- solo_run starter change, speedrun encounter tweaks, badge boost glitch,
-- remove poison visual, rock tunnel flash removal, surge trash puzzle,
-- instant text and the overworld field-move layer.
--
-- Three rules hold everywhere in this mod and breaking any of them breaks
-- a toggle:
--
--   1. Patches install unconditionally and read mod.options:get() at CALL
--      time.  Installing behind an `if` means the toggle needs a restart.
--   2. Anything patched onto an engine module table uses the marker+slot
--      pattern.  Module tables survive an F5 reload but the mod's own
--      environment does not, so a plain boolean guard stacks a second
--      wrapper on every reload and the old closure keeps running.
--   3. Engine data that gets overwritten (field.darkMaps) is stashed
--      first and restored when the toggle goes off, never destroyed.
--
-- Load order: options first (every other file reads the schema), then the
-- features in no particular order.  priority 900 in the manifest makes the
-- whole pack load AFTER species-adding mods so the STARTER row can list
-- anything they registered.

return function(mod)
  local compile = loadstring or load

  local function loadModule(path)
    local source, readError = mod:read(path)
    if not source then
      mod.log:error("cannot read %s: %s; reinstall the mod", path,
        tostring(readError))
      error("cannot read " .. path, 0)
    end
    local chunk, compileError = compile(source, "@" .. mod.path .. "/" .. path)
    if not chunk then
      mod.log:error("cannot compile %s: %s; reinstall the mod", path,
        tostring(compileError))
      error("cannot compile " .. path, 0)
    end
    return chunk()
  end

  local options = loadModule("sr_options.lua")
  options.install(mod)

  local features = {
    "sr_starter.lua",
    "sr_field_moves.lua",
    "sr_encounters.lua",
    "sr_battle_rules.lua",
    "sr_brock_skip.lua",
    "sr_text_speed.lua",
    "sr_world_tweaks.lua",
  }

  for _, path in ipairs(features) do
    local feature = loadModule(path)
    local ok, err = pcall(feature.install, mod, options)
    if not ok then
      mod.log:error("%s failed to install: %s", path, tostring(err))
    end
  end

  mod.log:info("solo_run_modpack: loaded")
end
