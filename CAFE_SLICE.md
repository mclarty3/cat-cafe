# Cafe Vertical Slice

Status of the cafe-day prototype, and what to do next. For the design, see `docs/Cafe Gameplay.md`,
`docs/Customers & Regulars.md` and `docs/Cats.md`. The dungeon counterpart is
[DUNGEON_SLICE.md](DUNGEON_SLICE.md).

## Goal

Test whether a short cafe day (prep, then service) feels cozy but engaging: juggling orders, a quick
drink minigame, a regular worth talking to, and a cat causing trouble. Everything is placeholder shapes.

## Decisions made for the prototype

- **Flat top-down view as a stand-in**, with a walking barista. The intended view is
  **isometric / 3D-feeling** (decided 2026-09-30, see *Atmosphere, Art & Audio*). Overhead is fine
  for testing mechanics, but isn't the target look.
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
- **Minigame speed and zone sizes** are on `DrinkMinigame` (`scripts/cafe/ui/drink_minigame.gd`).
- **Menu, prep actions, the starting pantry, and Theo's dialogue** live in `scripts/cafe/cafe_data.gd`
  as plain dictionaries.

### Code map

| File | What it does |
|---|---|
| `scenes/cafe/cafe.tscn`, `scripts/cafe/cafe.gd` | Layout; runs the day (phases, arrivals, orders, pay, events) |
| `scripts/cafe/cafe_day.gd` | One day's state: prep actions, pantry, stock, money, stats |
| `scripts/cafe/cafe_data.gd` | Content tables |
| `scripts/cafe/barista.gd` | Player movement, tray, and picking the closest interactable |
| `scripts/cafe/interactable.gd` | Base class for anything you can use: `get_prompt()` / `interact()` |
| `scripts/cafe/station.gd` + `espresso_machine.gd`, `pastry_case.gd`, `trash_bin.gd` | Counter equipment |
| `scripts/cafe/customer.gd` | Customer states, patience, order bubble, the regular's chat |
| `scripts/cafe/cafe_cat.gd` | Wandering, petting, the mug event |
| `scripts/cafe/table.gd`, `seat.gd` | Furniture. Customers path door → aisle → seat, so put seats on the aisle side |
| `scripts/cafe/ui/*` | HUD, choice menu, minigame, dialogue, prep, and results panels |

### Verified

A headless scripted day passed. It covered prep (stock and pantry), making a latte through the real
menu and minigame, taking orders, serving, chatting with Theo, catching the mug, the day ending, and
the results. A second check covered walking up to the espresso machine and the counter (the right
prompt shows and Interact opens the menu) and the title screen. None of this has been played by
hand yet.

### Playtest notes

- **Round 1** (7 customers, 8–14s apart, patience 35s / 50s): stressful. Finishable with no
  walkouts, but only by rushing at the end. That felt like **mid-game pacing**, about the limit without
  staff. Now retuned to an early-game day (5 customers, 16–24s apart, patience 45s / 70s). Keep the
  round 1 numbers as a reference for a later-game difficulty.
- **Round 1:** the mug broke while a drink was being made. Losing it to a minigame felt like bad luck
  rather than a choice. Cat events now wait until your hands are free.

## Known shortcuts

- The layout is fixed, with no furniture editing. The prep phase is actions only.
- Customers walk through the barista, the cat, and each other. There's no pathfinding beyond
  door → aisle → seat.
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
8. **A cozy pass:** warm lighting, calm open and close periods, and placeholder cafe jazz, to check the
   Coffee Talk mood target.

## Open design questions this slice could answer

- Should the world pause during the minigame or chats, or keep running as it does now? (Cat events
  already wait for free hands. Should customers' patience too?)
- How much should drink quality matter compared with speed?
- Is a 3-item tray the right juggling limit?
- Do prep actions create interesting choices, or is the best choice always obvious?
