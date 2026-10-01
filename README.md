# Cat Cafe

Day: run a cozy cat cafe. Night: dive into a dream dungeon to rescue cats and gather ingredients.
Design notes live in [`docs/`](docs/) (start with `docs/- Overview.md`).

Godot **4.4**, GDScript, placeholder shapes only (no art yet). Open `project.godot` and press **F5**.
The title screen switches between the two prototype slices, and **Esc** returns to it.

- [DUNGEON_SLICE.md](DUNGEON_SLICE.md): status and next steps for the dream dungeon.
- [CAFE_SLICE.md](CAFE_SLICE.md): status and next steps for the cafe day, including its code map.

### Cafe controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick / D-pad |
| Interact / minigame | E / Space / J | A |
| Menu navigation | Arrows + Enter/Space/E, or mouse | D-pad + A |
| Back / cancel | Esc | |

## Prototype: dream dungeon vertical slice

The slice is four hand-built rooms: start → combat → spikes → sunbeam exit. Curling up in the
sunbeam "wakes you up" and starts a new run. Dying does the same.

### Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A/D or arrows | Left stick / D-pad |
| Jump (hold for higher) | Space / Z | A |
| Attack (3-hit combo) | J / X | X |
| Aim attack | Hold Up / Down while attacking (down only in the air) | Stick / D-pad |
| Dash | K / Shift / C | RB |
| Interact | E / W / Up | Y |
| Restart run | R | LB |

A down-attack that hits an enemy or spikes **pogos** you upward and refreshes your air dash.

### Tuning feel

Every movement and combat number is an exported property on the Player (`scripts/player/player.gd`),
grouped into Run / Jump / Dash / Attack / Health. While the game is running, select
**Remote → Main/Player** in the Scene dock to tweak them live. Jump is defined by *height* and
*time to peak/fall*; gravity and jump velocity are derived from those.

### Building rooms

Rooms are ordinary scenes in `scenes/rooms/` with `scripts/world/room.gd` on the root. The easiest
way to make a new room is to duplicate an existing one. Enable 16px grid snapping in the 2D editor.

| Node | Script | Notes |
|---|---|---|
| Room root | `room.gd` | `size` sets the camera bounds. Add a `Marker2D` named `PlayerStart` for the run start. |
| Solid / one-way platform | `block.gd` on a `StaticBody2D` | Position is the top-left corner. Set `size`; tick `one_way` for jump-through. |
| Door | `door.gd` on an `Area2D` | Set `target_room` and `target_door` (the `door_id` of the door you arrive at). The green dot shows `spawn_offset`. |
| Spikes | `spikes.gd` on an `Area2D` | Hurts, then returns the player to the last safe ground. Can be pogoed. |
| Sunbeam | `sunbeam.gd` on an `Area2D` | The exit. |
| Enemy | instance `scenes/enemies/crawler.tscn` | Patrols, turns at walls and ledges. |

Blocks, doors, spikes and sunbeams size their own collision shapes from `size`, so there is nothing
else to set up.

### Code map

- `scripts/main.gd`: keeps the player, camera and HUD across rooms, swaps rooms, and runs the run lifecycle.
- `scripts/autoload/game.gd` (`Game`): global signals (room change, wake up, prompt, shake) and hitstop.
- `scripts/player/player.gd`: movement, combat, health.
- `scripts/enemies/crawler.gd`, `scripts/combat/hitbox.gd`: the enemy, and anything that damages the player.

Physics layers: 1 world, 2 player, 3 enemy, 4 player_attack, 5 hurts_player, 6 interactable.
