# Dream Dungeon Structure

Part of [[- Overview|Cat Cafe Dungeon Crawler]] · status tags: see the legend in the hub · [[Decision Log]] · [[Open Questions]]

- `[DECIDED]` **2D, metroidvania-inspired roguelite** with a **Hollow Knight / Dead Cells** feel.
- `[DECIDED]` Priorities: **good movement**, **some platforming**, **satisfying combat**.
- `[DECIDED]` **Meta progression.** Leading idea: **permanent movement abilities** unlocked through cats or story progress, which make previously unreachable areas accessible.
- `[PROPOSED]` The **Dead Cells model**: a fixed, hand-designed biome map, with handcrafted rooms rearranged each run. This keeps the metroidvania "I remember that locked door" feeling alongside roguelite variety.
- `[OPEN]` Whether progression through the dream is **fixed and floor-like** (biome after biome) or something else. Starting deeper (below) assumes the floor-like version.

## Exits (waking up)
- `[DECIDED]` There's a **voluntary way to wake up** and return home with your loot. It should be **reasonably easy**, but **not available anywhere**. It exists only in **specific rooms in each area**.
- `[DECIDED]` (2026-09-30) The exit rooms are **sunbeam rooms**: a warm patch of light and a cat bed where you curl up and wake.
- `[PROPOSED]` Sunbeam rooms could double as safe rooms with a small shop or a place to swap cats. Suggested placement: one at the end of each biome, maybe a hidden one mid-biome.
- `[DECIDED]` (2026-09-30) **Exiting has no cost.** Needing to reach an exit room is already enough push-your-luck tension.

## Time pressure
- `[OPEN]` Whether there's a **time limit**. Ryan is unsure but thinks it could be good.
- `[PROPOSED]` Soft pressure instead of a hard limit: Dead Cells-style **timed doors or bonuses**, possibly framed as **dawn approaching**. Speed is rewarded, and careful play isn't punished.

## Starting deeper
- `[DECIDED]` Let players **start runs deeper** once they've unlocked it (assuming floor-like progression). Proposed name: lucid-dream anchors, unlocked by beating biome guardians or rescuing boss cats.
- `[REJECTED]` Attaching **conditions or penalties** to starting deeper (for example, less health or fewer ingredient slots).
- `[PROPOSED]` A natural trade-off without artificial penalties: if early biomes are where you pick up upgrades for the run and common ingredients, skipping them means going deeper with less (as in Dead Cells).

## Needs expansion
- The biome list, themes, and how they connect.
- Room design rules and how procedural the generation is.
- Loot and ingredient distribution by biome.
- Items or upgrades found during a run (does a run have its own build, like Dead Cells?).
- What you keep and what you lose when you die.
