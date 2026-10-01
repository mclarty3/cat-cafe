# Dungeon Vertical Slice

Status of the dream-dungeon prototype, and what to do next. For how to build rooms and the code map,
see the [README](README.md). For the design itself, see `docs/Dream Dungeon Structure.md` and
`docs/Combat, Movement & Bosses.md`.

## Goal

Get a playable, hands-on prototype to test **movement and combat feel** (the Hollow Knight /
Dead Cells target), before art or content. Everything is placeholder shapes drawn in code.

## What's built

Godot 4.4, GDScript, Compatibility renderer, 640×360 viewport scaled to 1280×720.

### Player (`scripts/player/player.gd`)

- **Run:** separate acceleration and deceleration for ground and air.
- **Jump:** defined by height (72px) and time to peak / time to fall, with gravity derived from
  those. Falling is faster than rising. Releasing jump early cuts the jump short.
- **Coyote time** (0.1s) and **jump buffering** (0.12s).
- **Dash:** 0.15s, with one air dash that resets on landing or a pogo. It exits at run speed.
  Dash invulnerability is available as a toggle but off by default (Hollow Knight doesn't have it early).
- **Brooch-sword:** a 3-hit side combo (the third hit is bigger and does double damage), an up-slash,
  and an air down-slash. Presses are buffered so combos chain reliably.
- **Pogo:** a down-slash that hits an enemy or spikes bounces you up and refreshes the air dash.
- **Hit feedback:** hitstop, screen shake, recoil on side hits, and a ring effect on impact.
- **Health:** 5 points, 1s of blinking invulnerability, knockback, and a short stun.
- **Hazard respawn:** spikes put you back on the last ground you stood on for 0.15s or more.

Every number is exported, so it can be tuned live from the Remote scene tree.

### World

- **Rooms** are scenes with a `size` that sets the camera limits. `main.gd` keeps the player,
  camera and HUD across rooms and swaps rooms behind a fade.
- **Self-sizing placeholder pieces** (`@tool` scripts): Block (solid or one-way), Door, Spikes,
  Sunbeam. Set `size` and the collision follows.
- **Doors** link rooms by `door_id` / `target_door`, with a spawn offset shown in the editor.
- **Crawler enemy:** patrols, turns at walls and ledges, deals contact damage, takes knockback,
  and has 3 health.
- **Sunbeam exit:** press Interact to "wake up", which ends the run.

### Run loop

Start room → combat room (wide, scrolling) → spikes room (gaps that need a dash or pogo) →
sunbeam room. Waking up, dying or pressing R restarts the run at full health.

### Verified

A headless scripted playthrough passed: landing, jumping, a door transition, attacking an enemy,
contact damage, spikes and respawn, and waking up in the sunbeam. Dash and pogo were only checked
by hand.

## Known shortcuts

- Rooms reload fresh on every entry, so enemies respawn when you walk back in.
- Room order is fixed.
- No drop-through for one-way platforms.
- Doors are side-only. Vertical doors would need an entry velocity so you don't fall straight back out.
- Nothing is collected, so waking up has nothing to "keep".
- No pause menu, settings, or rebinding.
- No audio.

## Next steps

Roughly in priority order. The first two matter most, because feel is the core risk.

1. **Tune feel through play.** Play in short sessions, note what feels off (floaty jump,
   sluggish attack, dash distance), and adjust the exported values. Consider saving good sets as
   presets (`.tres` resources) so they can be A/B tested.
2. **Juice pass (still placeholder).** Squash-and-stretch, a sword-arc sprite instead of a
   rectangle, landing dust, an enemy hit flash plus a small freeze, and simple sound effects. It's much
   easier to judge feel with feedback than with bare rectangles.
3. **Run state within a run.** Rooms remember cleared enemies until the run ends.
4. **More enemy variety** to test combat against: a flier, a charger with a readable wind-up,
   a ranged enemy with a projectile to parry or pogo, and a stationary pogo target.
5. **Room shuffling (the Dead Cells model).** A fixed biome layout with handcrafted rooms tagged
   by exit shape, shuffled per run. Needs vertical doors.
6. **Ingredients and a results screen.** Enemy and room pickups, lost on death or partly kept
   (still an open design question), shown when you wake up. This is the handoff to the cafe.
7. **Cat loadout hook.** One equippable personality (for example, Lazy: standing still heals)
   to test how cat traits feel in combat.
8. **A movement-ability gate.** One boss-cat ability (for example, Pounce double jump) and a room
   that needs it, to test the metroidvania "come back later" loop.
9. **A small guardian or possessed-cat boss** to test boss pacing and the "knocking the shadow off"
   idea.

## Open design questions this slice could answer

- Is the brooch-sword's 3-hit combo right, or does a single repeatable slash (Hollow Knight) feel better?
- Should the dash have invulnerability by default?
- How punishing should spikes be (damage plus respawn, or respawn only)?
- What do you keep when you die? (Needs step 6.)
