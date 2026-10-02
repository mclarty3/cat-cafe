---
name: godot-verify
description: Verify a change in this Godot project by running a throwaway scripted probe headlessly (PASS/FAIL checks) or windowed (screenshots). Use after changing cafe or dungeon code or scenes, before reporting a change as working, or when the user asks to test, check, screenshot, or "see" something.
---

# Godot verify

Check changes by actually running the game, rather than reading code. Three levels, cheapest first:

## 1. Import + load check (always)
After adding or changing assets, re-import. Then load the scene and look for script errors:

```bash
GODOT="/c/Program Files/Godot_v4.4-stable_mono_win64/Godot_v4.4-stable_mono_win64_console.exe"
timeout 300 "$GODOT" --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: res"
timeout 60 "$GODOT" --headless --path . res://scenes/cafe/cafe.tscn --quit-after 90 2>&1 | grep -E "SCRIPT|Parse|ERROR" | grep -v "resources still"
```
Ignore headless-import noise ("progress dialog", "Parameter \"t\" is null") and "ObjectDB instances leaked at exit".

## 2. Scripted probe (behaviour)
Write a GDScript `extends Node` probe that instantiates the scene, drives it, and prints `PASS`/`FAIL` lines.
Then run it with the helper, which wraps it in a scene under `_probe/`, runs it, and deletes `_probe/` afterwards:

```bash
bash .claude/skills/godot-verify/run_probe.sh path/to/my_probe.gd            # headless
bash .claude/skills/godot-verify/run_probe.sh path/to/my_probe.gd --window   # windowed (needed for screenshots)
```
Write the probe file in the scratchpad, not the repo. Template:

```gdscript
extends Node
var fails := 0

func _ready() -> void:
	var cafe: Cafe = load("res://scenes/cafe/cafe.tscn").instantiate()
	cafe.customers_per_day = 3                  # speed things up via exported tuning
	cafe.spawn_interval = Vector2(1.5, 1.5)
	add_child(cafe)
	await _wait(0.3)
	cafe._open_cafe()                           # skip morning prep (or drive CafeOS: cafe.open_computer())
	_check(cafe.phase == Cafe.Phase.SERVICE, "service started")
	# Real input:   _press("cafe_interact")
	# Walking:      Input.action_press("move_left"); await _wait(0.5); Input.action_release("move_left")
	# Position:     cafe.barista.global_position = Vector3(0.75, 0, 0.95)  # e.g. at the register
	print("DONE fails=%d" % fails)
	get_tree().quit()

func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(0.05)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _check(cond: bool, what: String) -> void:
	if not cond: fails += 1
	print(("PASS  " if cond else "FAIL  ") + what)
```

Tips:
- Use `Input.parse_input_event` (not `Input.action_press`) for one-shot "just pressed" input. `action_press` from a timer can miss `is_action_just_pressed`.
- The barista ignores Interact for a couple of frames after a menu closes, so wait between presses.
- Private members (`cafe._cats`, `hud.computer._content`) are fine to inspect from probes.

## 3. Screenshots (anything visual)
Run with `--window` (a Godot window briefly opens on the user's screen; say so). Inside the probe:

```gdscript
await RenderingServer.frame_post_draw
get_viewport().get_texture().get_image().save_png("<scratchpad>/shots/name.png")
```
Then view the PNG with the Read tool. To choose between options (camera angles, lighting, colours), render several
variants into one grid image with PIL and compare them side by side.

## Report honestly
State what was checked (headless checks, screenshots) and what wasn't (e.g. "not played by hand",
"couldn't listen to audio").
