# Cafe Vertical Slice

Status of the cafe-day prototype, and what to do next. For the design, see `docs/Cafe Gameplay.md`,
`docs/Customers & Regulars.md` and `docs/Cats.md`. The dungeon counterpart is
[DUNGEON_SLICE.md](DUNGEON_SLICE.md).

## Goal

Test whether a short cafe day feels cozy but engaging: working the counter, a quick drink minigame,
a regular worth stepping out to talk to, and a cat causing trouble. The art is free placeholder models
(see [Placeholder art](#placeholder-art)).

## Decisions made for the prototype

- **Counter service, not table service** (2026-10-01). You work behind the counter. Customers queue,
  order at the register, wait at pickup, collect from the pass, then sit for a while. This replaced
  a first version in the style of Diner Dash, where you took orders and delivered to tables.
- **Hybrid movement.** You walk a short strip behind the counter between stations, and stepping out
  through the gate is a deliberate choice: chatting with regulars at their tables, or dealing with a
  cat. While you're out, nobody takes orders, so the queue builds. That's the trade-off the design notes
  describe. The layout keeps walking short, so it shouldn't turn into back-and-forth busywork.
- **Price at the register, tip at pickup.** The tip comes from drink quality and how long they waited at pickup.
- **You carry items to the pass, and no further.** Drinks and pastries go from the station to the pass by
  hand (2 at a time). Placing them is one press, and each item goes to the oldest ticket that needs it.
  Customers take their own order from the pass.
- **Taking an order is a single press** at the register.
- **To-go cups, no bussing.** Seated customers just leave when they're done.
- **Full 3D with a perspective follow camera** (2026-10-01). The camera looks at the counter from the
  front of house, about 48° down. It's pulled well back with a narrow 30° lens, which keeps the counter
  large while fitting the whole floor. It follows the barista side to side (40%) but only slightly front to
  back (15%), so working the counter never pushes the tables off screen. It also looks a little ahead
  and eases in while you're at a station or chatting. This replaced a fixed isometric camera, which felt limiting
  and flat. The design docs' "isometric" decision needs updating to match.
- **Movement should feel good.** Quick acceleration and quicker braking (full speed in about 0.15s, a
  stop in about 0.1s, no sliding), turning toward where you're steering, and the walk animation speed
  matched to how fast you're moving. A bobbing arrow marks whatever Interact will use. Up always walks
  toward the counter.
- **Runs separately from the dungeon.** A title screen switches between slices, and the pantry
  starts with a fake haul "from last night's dream".

## What's built

Open the project and press F5, then choose **Cafe day**. Esc returns to the title. While testing,
**F9** during service skips straight to closing time (debug builds only).

### Day flow

1. **Morning prep.** The cafe is closed and you can walk around freely. The light is cooler and
   dimmer, there are no customers, and Mochi is about. The counter stations are off until you open.
   Everything happens at the **register's computer**, the same till you take orders on later, which
   runs **CafeOS** before opening. The header always shows the time and prep actions left, and a green **Open the
   cafe** button sits in the sidebar, so you can open up from any page. The pages are:
   - **Kitchen** (the page it opens on): 3 prep actions: bake croissants (+4), bake moonflour muffins (+3, uses 1 moonflour)
     or make dream-honey syrup (+3 honey lattes, uses 1 dream honey). The pantry starts with 2
     moonflour and 1 dream honey, so you can't do everything.
   - **Cats:** a roster of compact cards, two per row. Each card shows the cat's colour, **name** and
     **personality**, plus a row of icons grouped under **Cafe** and **Dream** (for example, Curious has a
     coin and a wall). Cafe icons are **green** for benefits and **red** for drawbacks (Playful's
     "knocks things over"); Dream icons are always **lilac**. Hovering or selecting an icon shows its description on the info
     line pinned under the list. The list scrolls. Hovering a card shows the cat's description. The effects
     come from the design notes and aren't active yet. The roster is view-only for now; managing cats
     arrives with the cat systems, which matters once you have lots of them.
   - **Furniture** and **Upgrades:** placeholders showing what's planned, greyed out until money
     and the layout carry over between days.

   Opening warms the light into daytime, rings the door bell, and starts service. From then on, the
   register takes orders instead.
2. **Service.** 5 customers arrive about 20 seconds apart and queue along the left wall.
   - At the register, press Interact to take the front customer's order. They pay, a ticket goes on
     the rail (left side of the screen), and they walk over to a free pickup spot (if all are taken,
     they wait behind and move up when one frees).
   - Make the drinks at the espresso machine and grab pastries from the case, then carry them to the
     **pass** (they show in the barista's hands: first item right, second left). Once a ticket is complete, its customer collects it, tips, and goes to sit (or leaves with
     it to go if every table is taken).
   - Customers walk out if they wait too long, either in line or at pickup. They don't get a refund,
     but there's no tip either.
3. **Closing.** A results screen shows customers served, walkouts, sales, tips, the mug, and chats.
   From there you can start another day or go back to the title.

### Pieces

- **Register:** takes the order of whoever is at the front of the line.
- **Espresso machine:** choose a drink, then play the minigame.
  - *Pull:* stop a sweeping marker inside the zone.
  - *Steam* (lattes): hold to heat, release inside the zone, and don't hit the end (scalded).
  - The drink's quality is its worst step (Poor / Good / Perfect), which sets the tip.
- **Pastry case:** take a baked pastry. Stock only comes from morning prep.
- **Pass:** put down what you're carrying. Items waiting for pickup show on the counter as little models.
- **Bin:** throw away what you're holding if you made the wrong thing.
- **Orders only use what you can make.** Customers don't order sold-out items. Stock in your hands or on
  the pass, and items already owed to open tickets, are all counted.
- **Theo (a regular):** greets you at the register and orders his favourite (a honey latte if there's
  syrup, otherwise a latte). Then he sits down and shows a speech bubble. Walk out from behind the counter
  to chat: a short 2-choice conversation, during which he won't leave. If you skip it, the results say
  he'll bring it up next visit ("optional but never missable").
- **Eight resident cats**, covering all six confirmed personalities (with a second Lazy and a second
  Curious), set up as a mid-game cafe. They're spawned from
  `CATS` in `cafe_data.gd`, so adding one is a single entry:

  | Cat | Personality | Look | Behaviour |
  |---|---|---|---|
  | Mochi | Playful | lilac-grey | Wanders and plays; does the mug event |
  | Biscuit | Lazy | taupe | Long naps, slow ambles |
  | Pepper | Curious | slate blue | Always on the move |
  | Inky | Nocturnal | black | Dozes through the day shift |
  | Clementine | Hunter | orange | Quick, prowling dashes |
  | Bao | Chatty | cream-white | Meows at everything |
  | Tofu | Lazy | grey | Sleeps anywhere |
  | Sprout | Curious | ginger | A kitten, high-pitched and into everything |

  The full cat schema (every field, and how each should be generated later) is in *Cat data schema* in
  `docs/Cats.md`.
  They all share one Kenney cat model, tinted per cat. Personality *effects* aren't implemented yet; for
  now the personalities only change how each cat moves.
- **Mochi (the playful one):** wanders the front of house and can be petted. About 45 seconds in, she jumps on a table
  (preferring one with someone sitting at it) and starts nudging a mug. You have 6 seconds to get out there
  and catch it, or it breaks and costs $2. She waits until you're not in a menu, minigame or chat, and a
  toast warns you when she starts.
- **Audio:** lo-fi cafe radio (three tracks in rotation, fading in, and dipping during conversations and
  at closing). Sound effects:
  - footsteps;
  - the door and shop bell when a customer arrives;
  - the till when an order is taken;
  - the grinder, an espresso pour while you pull the shot, and a steam hiss while you hold the wand;
  - a quality sting on each drink;
  - a plate clink at the pass, an order-up bell and coins for tips;
  - a grumble on walkouts;
  - cats meowing or purring when petted: real recordings plus the synthesized purr. Each cat has its own
    voice pitch, playful and curious cats meow more, lazy and sleepy ones mostly purr, and it never plays
    the same kind twice in a row;
  - clinking the mug faster and faster as it nears the edge (then a catch or a crash);
  - UI clicks;
  - the shop-door bell when you open, and the same bell as a two-note chime at closing.
- **Pathfinding:** customers walk around furniture using a navigation mesh, baked when the scene loads
  from the furniture colliders. Rearranging the room in the editor needs no extra setup.

### Tuning

- **Morning light** (sun and ambient levels before opening, and how long it takes to warm up) is in the
  `Morning` group on the `Cafe` root node.
- **Day, customer and money numbers** are exported on the `Cafe` root node (`scripts/cafe/cafe.gd`):
  customers per day, arrival gaps, queue and pickup patience, how long people sit, tip amounts, and
  when the mug event happens. Character scale and sitting height are there too.
- **How much you can carry** is `carry_capacity` on the `Barista`.
- **Minigame speed and zone sizes** are on `DrinkMinigame` (`scripts/cafe/ui/drink_minigame.gd`).
- **Menu, prep actions, the starting pantry, and Theo's lines** live in `scripts/cafe/cafe_data.gd`
  as plain dictionaries.
- **Camera:** the `Camera` node (`CafeCamera`) has pitch, yaw, distance and FOV; how strongly it follows
  you side to side and front to back, how far it looks ahead, how smoothly it tracks, and the area it
  stays within; and the focus zoom and pull. The framing updates live in the editor.
- **Movement feel:** `speed`, `acceleration`, `deceleration` and `walk_anim_speed` on the `Barista`, and
  `turn_speed` on its `Model`.
- **Lighting:** the `Sun` (DirectionalLight3D) and `WorldEnvironment` ambient settings.
- **Audio:** every sound is listed by name in `SOUNDS` in `scripts/autoload/audio.gd`, with its files,
  volume and pitch, so swapping or rebalancing a sound is a one-line change. Overall music and effects
  levels are the Music and SFX buses (the Audio panel at the bottom of the editor). The playlist is
  `PLAYLIST` in `cafe_data.gd`.
- **Layout:** the queue line, pickup spots and pickup overflow line are `Marker3D`s under `Markers/Queue`,
  `Markers/Pickup` and `Markers/PickupOverflow` (set in `tools/gen_cafe_layout.py`). Add or move them freely.
- **Navigation:** two navmeshes are baked at startup from everything in the `nav_source` group. People use
  the scene's `Navigation` region, baked from colliders. Cats get their own map (`Cafe._bake_cat_navigation`)
  baked from the furniture's actual models, so anything with about 0.3 m of room underneath (tables) can be
  walked under, and legs block wherever they really are. Swapping a model needs no extra setup. Only
  floor-level polygons are kept in both. Nothing re-bakes after startup yet (the Furniture tab will need to).
- **Character models:** the code assumes Kenney's mini characters. Swapping in a different rig will need:
  - Bone names: carrying uses `arm-left` / `arm-right` (`Barista._place_held`, `AnimatedModel.hold_arms`).
  - One bone per arm: `AnimatedModel.hand_position()` finds the fist as the arm bone's farthest vertices. A rig
    with upper arm / forearm / hand bones should use its hand bone (or a hand socket node in the model) instead,
    and hold the whole arm chain while carrying.
  - Animation names: `idle`, `walk`, `sit`, `holding-both`, `holding-right` (the carry poses).
  - Hand-tuned numbers: `character_scale` and `sit_height` (Cafe), the grip offsets and `held_scale`
    (Barista), and the cat navmesh's 0.4 m clearance.

  Plan: when the first non-Kenney character arrives, add a per-character rig profile (animation name map, arm
  bones, hand bones or sockets) with Kenney's values as the default. Not built yet, since the art style is open.

### Code map

| File | What it does |
|---|---|
| `scenes/cafe/cafe.tscn`, `scripts/cafe/cafe.gd` | 3D layout; runs the day (phases, arrivals, queue, tickets, the pass, seating, pay, events, pathfinding) |
| `scripts/cafe/cafe_day.gd` | One day's state: prep actions, pantry, stock, money, stats |
| `scripts/cafe/cafe_data.gd` | Content tables |
| `scripts/cafe/ticket.gd` | One order, from the register to the pass |
| `scripts/cafe/customer.gd` | Queue, pickup, seated and leaving states; patience; bubbles; the regular's chat |
| `scripts/cafe/barista.gd` | Movement (feel tuning), what you're carrying, and picking the closest interactable |
| `scripts/cafe/focus_marker.gd` | The bobbing arrow over whatever Interact will use |
| `scripts/cafe/interactable.gd` | Base class for anything you can use: `get_prompt()` / `interact()` |
| `scripts/cafe/station.gd` + `register.gd`, `espresso_machine.gd`, `pastry_case.gd`, `pass.gd`, `trash_bin.gd` | Counter equipment. The register's computer runs CafeOS before opening |
| `scripts/cafe/cafe_cat.gd`, `scenes/cafe/cat.tscn` | A cat: wandering (per-cat pace), petting, the mug event on a table. Spawned from `CafeData.CATS` |
| `scripts/cafe/seat.gd` | Where customers sit. Point its +Z at the table |
| `scripts/cafe/prop_3d.gd` | Places any model, centres its footprint, and adds an optional auto-sized box or cylinder collider. Use it for all furniture |
| `scripts/cafe/animated_model.gd` | Plays a Kenney character or pet animation by name and turns it to face a direction |
| `scripts/cafe/overlay_anchor.gd` | 2D drawing pinned above a 3D node (bubbles, bars, names) |
| `scripts/cafe/cafe_camera.gd` | The perspective follow camera, plus focus easing |
| `scripts/autoload/audio.gd` (`Audio`) | Music playlist and named sound effects (one-shots and loops), on the Music and SFX buses |
| `scripts/cafe/ui/computer_panel.gd` | CafeOS: the morning hub (Kitchen, Cats, Furniture, Upgrades, and opening up) |
| `scripts/cafe/ui/*` | HUD (status, goal line, ticket rail, what you're carrying), choice menu, minigame, dialogue, and results panels |

### Verified

A headless scripted day passed on the counter-service version. It covered:
- pathfinding from the door to a seat (routes around tables);
- the first customer reaching the register, and the register prompt;
- taking an order with Interact (paid at the register);
- carrying items to the pass and placing them with Interact;
- the customer collecting and sitting;
- serving all 5 customers with no walkouts;
- chatting with Theo at his table;
- catching the mug on a table;
- the results.

After the switch to the perspective camera, the same day passed again, with added checks on movement
(acceleration, top speed, stopping) and the target marker. The look was checked with rendered screenshots,
including comparing camera presets. The table-service versions (2D, then 3D) were played by
hand; the counter-service version hasn't been yet.

### Playtest notes

- **Round 1** (2D table service; 7 customers, 8–14s apart): stressful. That felt like **mid-game pacing**,
  about the limit without staff. It was retuned to an early-game day (5 customers, 16–24s apart). Keep the
  round 1 numbers as a reference for a later-game difficulty.
- **Round 1:** the mug broke while a drink was being made. That felt like bad luck rather than a choice, so
  cat events now wait until your hands are free.
- **Round 2** (3D table service): the gameplay felt like Diner Dash, not the intended behind-the-counter
  service. That led to the counter-service redesign above.
- **Round 3** (counter service, isometric): the isometric view felt limiting and a bit ugly. That led to
  full 3D with the perspective follow camera, plus a movement-feel pass.
- **Round 4** (perspective camera): the zoom felt right, but from behind the counter the bottom row of
  tables was cut off. Fixed by following mostly side to side, plus a slight zoom-out using a longer
  distance and narrower lens.

## Placeholder art

All from [Kenney](https://kenney.nl), CC0 (free for any use, and no credit required, though it's
appreciated). Only the models in use are in `assets/kenney/`, each folder with its `License.txt`.

| Folder | Pack | Used for |
|---|---|---|
| `furniture/` | [Furniture Kit](https://kenney.nl/assets/furniture-kit) | Walls, counter cabinets, coffee machine, till (a computer screen), round tables, chairs, rugs, plants, lamp, bookcase, bin |
| `food/` | [Food Kit](https://kenney.nl/assets/food-kit) | Croissant, muffin, cups, mug, honey, plates |
| `characters/` | [Mini Characters](https://kenney.nl/assets/mini-characters) | Barista and customers, animated (idle, walk, sit, holding-both, and more) |
| `pets/` | [Cube Pets](https://kenney.nl/assets/cube-pets) | Mochi (idle, walk, run, gestures) |

### Audio

| Folder | Source | Used for |
|---|---|---|
| `assets/audio/music/` | "Cat caffe", "A cup of tea", "Bartender" by **TAD**, from [lofi Compilation](https://opengameart.org/content/lofi-compilation) (CC0; the author asks for credit "if you can", see `CREDITS.txt`) | Cafe radio |
| `assets/audio/sfx/kenney/` | Kenney [Interface Sounds](https://kenney.nl/assets/interface-sounds), [Impact Sounds](https://kenney.nl/assets/impact-sounds), [RPG Audio](https://kenney.nl/assets/rpg-audio) (CC0) | Footsteps, clinks, bells, coins, door, UI |
| `assets/audio/sfx/cats/` | Meows and purrs by Kerzoven ([Cat Purr & Meow](https://opengameart.org/content/cat-purr-meow)), AntumDeluge ([Kitten Mew](https://opengameart.org/content/kitten-mew)) and IgnasD ([Meow](https://opengameart.org/content/meow)), all CC0; see `CREDITS.txt` | Petting the cats |
| `assets/audio/sfx/synth/` | Synthesized for this project | Grinder, espresso pour, milk steam, scald, purr (no CC0 recordings were readily available; replace with real ones later) |

### UI icons

`assets/ui/icons/`: from Kenney [Board Game Icons](https://kenney.nl/assets/board-game-icons) and
[Game Icons](https://kenney.nl/assets/game-icons) (CC0), with their licences. They're white, so the UI
tints them. Each personality's effect icons are set in `PERSONALITIES` in `cafe_data.gd`.

To add more models, download the pack, copy the `.glb` (plus its `Textures/colormap.png` if the model uses
one) into the matching folder, and drop it onto a `Prop3D`.

## Known shortcuts

- The layout is fixed in the scene, with no furniture editing in-game. CafeOS's Furniture and Upgrades
  tabs are placeholders, and the Cats roster is view-only.
- Avoidance is simple steering (`avoid_radius`, `cat_avoid_radius`, `avoid_strength` on the Cafe): walking
  customers and cats sidestep each other and the barista, but anyone standing still doesn't make way, the
  barista can still walk through people and cats, and a walker's last 0.4 m goes straight to its spot.
- The art styles don't match. The furniture and food are smooth low-poly, while the characters and cat
  are blocky. That's fine for a prototype, but not a look to keep.
- The till is a stand-in model (a computer screen). The sit pose is eyeballed. The latte and honey latte
  share a cup model, so in the barista's hands only the dot overhead tells them apart.
- One regular, one conversation, and no memory between days. "Another day" starts completely fresh.
- One cat event, always at the same time.
- No staff, no cafe upgrades, no customer–cat matchmaking.
- The coffee and purr sounds are synthesized placeholders, and the shop bell is a pitched-up heavy bell.
  Mixing levels were set by ear, without playtesting.
- No clock or time of day.

## Next steps

1. **Play the counter-service version.** Does the counter feel like the right home base? Is leaving it to
   chat or catch the mug a real choice, or just a chore? Tune the queue and pickup patience, carry
   capacity, and arrival rate.
2. **Staff** (the docs' relief valve). A hireable helper who runs the register, which frees you to work the
   floor and chat. That's the design notes' "staff takes orders, you chat at tables".
3. **Make the minigame feel good:** sound, a visual cup filling, and a little ceremony on a Perfect.
   It's the most repeated action.
4. **Persistence between days:** carry money and Theo's story progress forward, and have
   his next visit pick up the skipped chat. That tests "never missable" for real.
5. **Make personalities do something.** The five cats are in, but only their movement differs. Add their
   cafe effects from the design notes: Lazy calms impatient people in the queue, Curious finds dropped
   coins, Nocturnal draws superstitious customers, Hunter handles a "mouse in the kitchen" event, and so
   on. This also tests the matchmaking idea.
6. **More cat events** out front, at random times: a cat fight, a kitten on the curtains, the croissant thief.
7. **Fill in CafeOS:** carry money between days, then make the Upgrades tab real (a second group head, a
   bigger pastry case, more seats) and the Furniture tab (rearranging tables and decor before opening). The
   Cats roster becomes the place to manage cats once there are more of them.
8. **Connect to the dungeon.** Once the dungeon collects ingredients, feed the real haul into the pantry,
   and let the night's outcome change prep (the "fewer prep actions" option in *Day-Night Connection*).
9. **A cozy pass:** lamps that glow, window light, and calm open and close periods. Then dynamic music
   from the design notes: purring layers as cats settle, the tempo lifting during a rush, and rain on the
   windows.

## Open design questions this slice could answer

- Should the world pause during the minigame or chats, or keep running as it does now? (Cat events
  already wait for free hands.)
- How much should drink quality matter compared with speed?
- Is 2 items the right carrying limit?
- Do prep actions create interesting choices, or is the best choice always obvious?
- How often should you *need* to leave the counter? Too rarely, and the front of house is just
  decoration. Too often, and it's Diner Dash again.
