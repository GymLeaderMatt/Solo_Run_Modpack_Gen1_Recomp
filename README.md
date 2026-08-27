# Solo Run Modpack

Every rule a solo run needs, in one mod. Install it and it is already set up
correctly — the defaults *are* the ruleset. Everything below is a toggle in
**MOD OPTIONS** if you want something different.

Only four option rows fit on screen at once, so the rows you change between
runs are at the top.

## The options, in the order they appear

| Row | Default | What it does |
|---|---|---|
| **REPLACE BALL** | CHARMANDER | Which of Oak's three Pokéballs gets swapped out. |
| **NEW STARTER** | *first alphabetically* | What you get instead. Lists every species in the game, including any added by other mods. The pick itself is swapped too: the Pokédex page Oak shows you, its cry, and the lines either side of it all name what you are actually getting. |
| **PERFECT DVS** | ON | Your starter gets 15 in every stat. **Nothing else is affected** — wild Pokémon roll normally, and trainers were always on the fixed 9/8/8/8/8 spread. |
| **NEED HM USERS** | OFF | ON is vanilla: a party member has to actually know the move. OFF replaces that with **badge + machine obtained** (see below). |
| **HM MON SPAWNS** | ON | *Only shown when NEED HM USERS is ON.* Guarantees the Paras in Mt. Moon and the Doduo on Route 16, then silences that map once you have it. |
| **BALLS ALWAYS WORK** | ON | *Only shown when NEED HM USERS is ON.* A regular Pokéball catches on the first throw. |
| **AUTO FIELD MOVES** | ON | Walk into water to surf, into a tree to cut it, into a boulder for Strength. No menu, no textbox. Also lights a dark cave on entry if it is still dark. |
| **SELECT FIELD MENU** | ON | SELECT opens a small menu with the things that have no walk-into trigger. Always in the same order: **BICYCLE, FLY, DIG, TELEPORT** — entries appear as you unlock them but never reorder. The bike shows once it's in your bag, and reads BIKE OFF while you're riding. |
| **NO BATTLE ITEMS** | ON | The in-battle bag is filtered to Pokéballs only. You can still catch the HM users; you cannot use a Potion or an X Attack. |
| **BADGE BOOST** | ON | Restores the Gen 1 badge boost glitch. |
| **NO EARLY WILDS** | ON | No wild encounters before repels are affordable: Routes 1, 22, 3 and 6, Viridian Forest, Mt. Moon B1F and B2F. |
| **INSTANT TEXT** | ON | All text prints at once, **including in battle**. |
| **NO SOUND WAITS** | ON | Removes the pauses where the game stands still waiting for a jingle or a cry to finish — receiving an item, levelling up, learning a move, a Pokémon being sent out. The sound still plays, the game just stops waiting for it. |
| **NO POISON FLASH** | ON | Poison still hurts in the overworld, it just stops blinking the screen and making the noise. |
| **LIGHT ROCK TUNNEL** | ON | Removes the darkness from Rock Tunnel. |
| **AUTO TRASH PUZZLE** | ON | Lt. Surge's trash cans are already unlocked. |

The engine adds its own **RESET DEFAULTS** row at the bottom.

## The HM rule, in detail

With **NEED HM USERS** off, a field move works when you hold the badge *and*
you have obtained the machine that teaches it. Nothing needs to know the move.

| Move | Badge | Machine |
|---|---|---|
| CUT | Cascade | HM01 |
| FLY | Thunder | HM02 |
| SURF | Soul | HM03 |
| STRENGTH | Rainbow | HM04 |
| FLASH | Boulder | HM05 |
| DIG | Cascade | TM28 |

Three things worth knowing:

- **Obtained, not held.** HMs are never consumed, but TM28 is, and Dig is
  worth teaching. Once a machine has been in your bag it counts for the rest
  of the run. Saves that already spent TM28 are covered too — beating the
  Cerulean thief is enough on its own.
- **Dig is gated on Misty** rather than Surge, because the thief is beaten on
  the way out of Cerulean and Surge is occasionally skipped.
- **Teleport is not part of this.** There is no Teleport machine to own, so it
  works the normal way: your Pokémon has to know it. The SELECT menu is just a
  shortcut past the party menu.

This changes the route. You no longer need to *teach* anything, so Cut works
the moment you beat Misty, before the S.S. Anne.

## Notes

- **Oak's question is reworded on the ball you replace.** The original line
  has the type built into the sentence — "the fire POKéMON, CHARMANDER" —
  which is wrong for most replacements and has nowhere to put a new name. On
  the replaced ball it becomes "So! You want to pick *name*?" The other two
  balls keep their original wording.
- Turning **NEED HM USERS** off also silences Mt. Moon and Route 16, since
  there is nothing left to catch there.
- **LIGHT ROCK TUNNEL** and the automatic Flash do the same job by different
  means. With the tunnel lit, Flash has nothing to light.
- **NO SOUND WAITS** is worth turning off if you play with sound on: cries
  and jingles will overlap the text that follows them.
- The HM rows disappear the moment you flip NEED HM USERS off, even while
  you're looking at the options screen, on every engine version.
- Options are stored per mod, so settings from the standalone versions of
  these mods do not carry over. The defaults are the same ruleset.

## Replaces

This pack contains the same features as, and should not be run alongside,
the standalone Starter Change, Encounter Tweaks, Badge Boost Glitch, Remove
Poison Visual, Rock Tunnel Flash, Trash Can Puzzle Solve and Instant Text
mods. The overworld field-move layer covers the same ground as Quality of
Life's easy interactions and Auto Field Moves.
