#!/usr/bin/env bash
# Runs a throwaway GDScript probe (extends Node) inside this project, then cleans up.
# Usage: bash .claude/skills/godot-verify/run_probe.sh <probe.gd> [--window]
#   --window  run with rendering (needed for screenshots; briefly opens a window)
set -euo pipefail

probe="${1:?usage: run_probe.sh <probe.gd> [--window]}"
mode="${2:-}"
godot="${GODOT:-/c/Program Files/Godot_v4.4-stable_mono_win64/Godot_v4.4-stable_mono_win64_console.exe}"
root="$(cd "$(dirname "$0")/../../.." && pwd)"

mkdir -p "$root/_probe"
trap 'rm -rf "$root/_probe"' EXIT
cp "$probe" "$root/_probe/probe.gd"
printf '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://_probe/probe.gd" id="1"]\n\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' \
	> "$root/_probe/probe.tscn"

flags=(--path "$root")
[[ "$mode" == "--window" ]] || flags=(--headless "${flags[@]}")

# Drop known-harmless noise, keep everything else (prints, errors).
timeout 300 "$godot" "${flags[@]}" res://_probe/probe.tscn 2>&1 \
	| grep -v -E "^\s*$|^Godot Engine|ObjectDB instances leaked|resources still in use|at: (cleanup|clear) \(core/" || true
