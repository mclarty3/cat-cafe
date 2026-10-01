# Cafe Vertical Slice

Status of the cafe-day prototype, and what to do next. For the design, see `docs/Cafe Gameplay.md`,
`docs/Customers & Regulars.md` and `docs/Cats.md`. The dungeon counterpart is
[DUNGEON_SLICE.md](DUNGEON_SLICE.md).

## Goal

Test whether a short cafe day (prep, then service) feels cozy but engaging: juggling orders, a quick
drink minigame, a regular worth talking to, and a cat causing trouble. The art is free placeholder
models (see [Placeholder art](#placeholder-art)).

## Decisions made for the prototype

- **3D with a fixed isometric camera** (orthographic, about 32° down and 45° around), matching the
  decided cafe view (*Atmosphere, Art & Audio*, 2026-09-30). The first version used a flat top-down
  stand-in; the gameplay code didn't change when the view did.
- **Movement follows the screen:** Up walks up the screen (diagonally in the world), the usual feel
  for isometric games.
- **Bubbles, patience bars and floating text are 2D**, drawn on an overlay pinned above each 3D
  actor so they stay crisp and readable.
- **Runs separately from the dungeon.** A title screen switches between slices, and the pantry
  starts with a fake haul "from last night's dream".
- **The world keeps running during menus, the minigame and chats.** Customers stay impatient while
  you're busy, so chatting during a rush has a cost (the *Customers & Regulars* proposal).

## What's built

Open the project and press F5, then choose **Cafe day**. Esc returns to the title.

### Day flow

1. **Morning prep.** 3 actions: bake croissants (+4), bake moonflour muffins (+3, uses 1 moonflour)
   or make dream-honey syrup (+3 honey lattes, uses 1 dream honey). The pantry starts with 2
   moonflour and 1 dream honey, so you can't do everything.
2. **Service.** 5 customers arrive about 20 seconds apart. Each one sits, shows **!**, and
   waits to order. Walk up and press Interact to take the order, which appears in their bubble and
   on the Orders list. Make drinks and grab pastries, carry up to 3 items, and deliver them. They eat,
   pay, and tip, or walk out if their patience bar runs out.
3. **Closing.** A results screen shows customers served, walkouts, sales, tips, the mug, and chats.
   From there you can start another day or go back to the title.

### Pieces

- **Espresso machine:** choose a drink, then play the minigame.
  - *Pull:* stop a sweeping marker inside the zone.
  - *Steam* (lattes): hold to heat, release inside the zone, and don't hit the end (scalded).
  - The drink's quality is its worst step (Poor / Good / Perfect), which sets the tip.
- **Pastry case:** take a baked pastry. Stock only comes from morning prep.
- **Bin:** toss your tray if you made the wrong thing.
- **Orders only use what you can make.** Customers don't order sold-out items. Stock on your tray and
  items already owed to waiting customers are both counted.
- **Theo (a regular):** orders his favourite (a honey latte if there's syrup, otherwise a latte),
  then shows a speech bubble while he eats. Chat for a short 2-choice conversation; his timer pauses
  while you talk. If you skip it, the results say he'll bring it up next visit ("optional but never
  missable").
- **Mochi (a cat):** wanders the floor and can be petted. About 45 seconds in, she jumps on the
  counter and starts nudging a mug, and you have 6 seconds to catch it. Otherwise it breaks and costs $2.
  She waits until you're not in a menu, minigame or chat, and a toast warns you when she starts
  (`cat_events_wait_for_free_hands`).

### Tuning

- **Day, customer and money numbers** are exported on the `Cafe` root node (`scripts/cafe/cafe.gd`):
  customers per day, arrival gaps, patience, eat time, tip amounts, and when the mug event happens.
  Character scale, sitting height and the aisle position are there too.
- **Camera:** the `Camera` node (`IsoCamera`) has pitch, yaw, zoom (`view_height`) and target, and it
  updates live in the editor.
- **Lighting:** the `Sun` (DirectionalLight3D) and `WorldEnvironment` ambient settings. The current values
  are a quick pass that avoids blowing out the light Kenney woods.
- **Minigame speed and zone sizes** are on `DrinkMinigame` (`scripts/cafe/ui/drink_minigame.gd`).
- **Menu, prep actions, the starting pantry, and Theo's dialogue** live in `scripts/cafe/cafe_data.gd`
  as plain dictionaries.

### Code map

| File | What it does |
|---|---|
| `scenes/cafe/cafe.tscn`, `scripts/cafe/cafe.gd` | 3D layout; runs the day (phases, arrivals, walking paths, orders, pay, events) |
| `scripts/cafe/cafe_day.gd` | One day's state: prep actions, pantry, stock, money, stats |
| `scripts/cafe/cafe_data.gd` | Content tables |
| `scripts/cafe/barista.gd` | Screen-relative movement, tray, and picking the closest interactable |
| `scripts/cafe/interactable.gd` | Base class for anything you can use: `get_prompt()` / `interact()` |
| `scripts/cafe/station.gd` + `espresso_machine.gd`, `pastry_case.gd`, `trash_bin.gd` | Counter equipment |
| `scripts/cafe/customer.gd` | Customer states, patience, order bubble, the regular's chat |
| `scripts/cafe/cafe_cat.gd` | Wandering, petting, the mug event |
| `scripts/cafe/seat.gd` | Where customers sit. Point its +Z at the table. Customers path door → aisle → seat, so put seats on the aisle side |
| `scripts/cafe/prop_3d.gd` | Places any model, centres its footprint, and adds an optional auto-sized box or cylinder collider. Use it for all furniture |
| `scripts/cafe/animated_model.gd` | Plays a Kenney character or pet animation by name and turns it to face a direction |
| `scripts/cafe/overlay_anchor.gd` | 2D drawing pinned above a 3D node (bubbles, bars, names) |
| `scripts/cafe/iso_camera.gd` | The fixed isometric camera |
| `scripts/cafe/ui/*` | HUD, choice menu, minigame, dialogue, prep, and results panels |

### Verified

After the 3D conversion, a headless scripted day passed. It covered prep, screen-relative walking,
walking up to the espresso machine (the right prompt shows and Interact opens the menu), making a
drink through the minigame, serving every customer, chatting with Theo, catching the mug, and the
results. The look was checked with rendered screenshots: seating direction, sitting height, lighting,
and overlay alignment. The 2D version had been played by hand; the 3D version hasn't been yet.

### Playtest notes

- **Round 1** (7 customers, 8–14s apart, patience 35s / 50s): stressful. Finishable with no
  walkouts, but only by rushing at the end. That felt like **mid-game pacing**, about the limit without
  staff. Now retuned to an early-game day (5 customers, 16–24s apart, patience 45s / 70s). Keep the
  round 1 numbers as a reference for a later-game difficulty.
- **Round 1:** the mug broke while a drink was being made. Losing it to a minigame felt like bad luck
  rather than a choice. Cat events now wait until your hands are free.

## Placeholder art

All from [Kenney](https://kenney.nl), CC0 (free for any use, and no credit required, though it's
appreciated). Only the models in use are in `assets/kenney/`, each folder with its `License.txt`.

| Folder | Pack | Used for |
|---|---|---|
| `furniture/` | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Walls, counter cabinets, coffee machine, round tables, chairs, rugs, plants, lamp, bookcase, bin |
| `food/` | [Food Kit](https://kenney.nl/assets/food-kit) | Croissant, muffin, cups, mug, honey, plates |
| `characters/` | [Mini Characters](https://kenney.nl/assets/mini-characters) | Barista and customers, animated (idle, walk, sit, holding-both, and more) |
| `pets/` | [Cube Pets](https://kenney.nl/assets/cube-pets) | Mochi (idle, walk, run, gestures) |

To add more, download the pack, copy the `.glb` (plus its `Textures/colormap.png` if the model uses
one) into the matching folder, and drop it onto a `Prop3D`.

## Known shortcuts

- The layout is fixed, with no furniture editing. The prep phase is actions only.
- Customers walk through the barista, the cat, and each other. There's no pathfinding beyond
  door → aisle → seat.
- The art styles don't match. The furniture and food are smooth low-poly, while the characters and
  cat are blocky. That's fine for a prototype, but not a look to keep.
- The sit pose and chair positions are eyeballed. Mochi glides onto the counter rather than jumping,
  and the barista doesn't visibly carry the items on the tray.
- One regular, one conversation, and no memory between days. "Another day" starts completely fresh.
- One cat event, always at the same time.
- No staff, no cafe upgrades, no customer–cat matchmaking.
- No audio, and no clock or time of day.

## Next steps

1. **Keep tuning the pace, and add a difficulty curve.** Check that the retuned day feels calm.
   Then ramp the customer count and arrival rate over days, toward the round 1 "mid-game" numbers,
   with staff arriving as the relief valve (*Cafe Gameplay: Staff*). The target from *Core Loop &
   Pacing* is an 8–12 minute day with fewer than 12 customers.
2. **Make the minigame feel good:** sound, a visual cup filling, and a little ceremony on a Perfect.
   It's the most repeated action.
3. **Persistence between days:** carry money and Theo's story progress forward, and have
   his next visit pick up the skipped chat. That tests "never missable" for real.
4. **Cats with personalities** (the Lazy / Playful / Curious roster). Each resident cat changes the day,
   for example Lazy calms impatient customers nearby. This also tests the matchmaking idea.
5. **More cat events**, at random times: a cat fight, a kitten on the curtains, the croissant thief.
6. **Upgrades and money sinks** for spending earnings (a second espresso group head, a bigger pastry
   case, more seats), so earning feels like it matters.
7. **Connect to the dungeon.** Once the dungeon collects ingredients, feed the real haul into the pantry,
   and let the night's outcome change prep (the "fewer prep actions" option in *Day-Night Connection*).
8. **A cozy pass:** better lighting (lamps that glow, window light, maybe light baking), calm open and
   close periods, and placeholder cafe jazz, to check the Coffee Talk mood target.
9. **Show the tray in 3D:** put the actual cup and pastry models in the barista's hands.

## Open design questions this slice could answer

- Should the world pause during the minigame or chats, or keep running as it does now? (Cat events
  already wait for free hands. Should customers' patience too?)
- How much should drink quality matter compared with speed?
- Is a 3-item tray the right juggling limit?
- Do prep actions create interesting choices, or is the best choice always obvious?
