# Cats

Part of [[- Overview|Cat Cafe Dungeon Crawler]] · status tags: see the legend in the hub · [[Decision Log]] · [[Open Questions]]

Cats are the thread connecting both halves of the game.

## Traits
- `[DECIDED]` Each cat has **personality traits that affect cafe gameplay**. Examples brainstormed: a lazy lap cat calms stressed customers; a playful kitten draws in families but knocks things over; a grumpy old tom is loved by one specific regular and hated by everyone else.
- `[DECIDED]` Cats also have **dungeon-side effects or abilities**. Examples brainstormed: seeing in the dark to reveal traps, squeezing through gaps to reach hidden rooms, sensing ghosts, pushing things off ledges as a puzzle mechanic.
- `[PROPOSED]` Newly rescued cats arrive skittish and need time in the cafe to warm up before they're ready for either role, which pulls the player back to the cafe.

## How you get cats
- `[DECIDED]` **Cats are friends, never captured.** No Pokémon-style catching.
- `[DECIDED]` **Strong possessed cats** serve as enemies or bosses. You defeat them to free them and bring them home.
- `[DECIDED]` **Lesser cats** appear throughout the dungeon across runs and are won over through a **befriending minigame** or by **completing a task** for them.
- `[PROPOSED]` The befriending minigame: approach slowly, slow blink, offer the right treat, and be patient while the cat tests you. Different cats want different approaches.

## Rescue → rehabilitate → adopt out
- `[DECIDED]` Rescued cats come to the cafe, warm up over time, form bonds with regulars, and eventually get **adopted**. Adoption gives rewards (money, reputation, story) and frees space for new rescues.
- `[DECIDED]` To keep players from feeling punished for getting attached: they can mark favorites as **permanent cafe residents**, and **adopted cats come back to visit** with their new owners.
- `[DECIDED]` (2026-09-30) **Keepsakes:** an adopted cat leaves something behind (a collar, a toy) that gives a **permanent, weaker version** of its trait.
- `[DECIDED]` (2026-09-30) **A keepsake's strength depends on the cat's bond level when it was adopted.** Bonding is never wasted, and adoption becomes a timing choice: adopt early for space and the reward, or wait for a stronger keepsake.
- `[DECIDED]` (2026-09-30) Keepsakes go in **their own limited slots** (about 3), so 30 adoptions don't add up to 30 stacked bonuses. The loadout becomes cats equipped (strong) plus keepsakes equipped (weaker).
- `[PROPOSED]` *(Claude suggestion)* A keepsake is about **half** the cat's equipped strength at that bond level.

## Cats in the dungeon
- `[DECIDED]` (2026-09-30) Cats are a **loadout choice, not an AI companion** running around the screen. Tight combat like Hollow Knight's depends on precise control, and a wandering companion clutters it.
- `[PROPOSED]` What equipping means: an equipped cat could give a passive trait, a cooldown ability, or a charm-style effect, appearing briefly when its ability triggers.
- `[PROPOSED]` Swapping cats could happen in the exit/safe rooms.

## Personality system
*First trait session: 2026-09-30.*

- `[DECIDED]` (2026-09-30) **One personality per cat, with one effect in each half**: a cafe effect and a dungeon effect (when equipped), both coming from the same personality. Simple and easy to read.
- `[DECIDED]` (2026-09-30) **Only rare cats** can have more than one personality. This gives rarity a clear meaning. See the rarity tiers under Needs expansion.
- `[LEANING]` (2026-09-30) **Traits get stronger over time**, through bonding in the cafe and/or use in the dungeon.
- `[DECIDED]` (2026-09-30) **Bond comes from both halves and fills one meter.** Time in the cafe builds it slowly, and taking the cat on runs builds it faster, so neither play style is held back.
- How a trait growing stronger interacts with adoption is settled through keepsakes (see Rescue → rehabilitate → adopt out).

### Personality roster
Effects are first ideas and will be tuned. Status = whether the personality is in the roster.

| Status       | Personality                  | In the cafe                                        | In the dungeon (equipped)                   |
| ------------ | ---------------------------- | -------------------------------------------------- | ------------------------------------------- |
| `[DECIDED]`  | **Lazy**                     | Calms stressed or impatient customers              | Standing still slowly heals you             |
| `[DECIDED]`  | **Playful**                  | Brings in families, but knocks things over         | Occasionally bats projectiles away          |
| `[DECIDED]`  | **Curious**                  | Finds dropped coins and lost items around the cafe | Reveals hidden walls and secret rooms       |
| `[DECIDED]`  | **Nocturnal**                | A "lucky black cat" draws superstitious customers  | Sees in the dark and reveals traps          |
| `[DECIDED]`  | **Hunter**                   | Handles "mouse in the kitchen" events              | Bonus damage to small enemies               |
| `[DECIDED]`  | **Chatty**                   | Announces customers and hurries the staff          | Warns you about enemies off-screen          |
| `[LEANING]`  | **Greedy**                   | Begs, so customers buy extra pastries to share     | Enemies drop more ingredients               |
| `[PROPOSED]` | **Grumpy** *(Ryan: maybe)*   | One regular loves them, everyone else is put off   | Damages enemies that hit you                |
| `[PROPOSED]` | **Skittish** *(Ryan: maybe)* | Hides, and bolts during noisy events               | Longer dodge; warns you just before attacks |
| `[PROPOSED]` | **Aloof** *(Ryan: maybe)*    | Draws well-off customers who pay more              | Blocks one hit per room                     |
| `[PROPOSED]` | **Clumsy** *(Ryan: maybe)*   | Causes chaos, sometimes lucky                      | Random effects, some good and some bad      |
| `[REJECTED]` | **Affectionate**             | Speeds up regulars' stories and raises tips        | Makes befriending wild cats easier          |

Patterns so far: cafe effects fall into four groups (which customers come, how they behave, what they spend, which events happen). Dungeon effects fall into three (combat, exploration, loot).

### Boss cats
- `[DECIDED]` (2026-09-30) A rescued boss cat gives a **permanent meta-progression ability** (movement tech and similar) **and** joins the roster as a normal cat you can keep in the cafe and equip in the dungeon.
- `[LEANING]` (2026-09-30) *(Ryan's idea)* The higher-tier ability comes from **the nightmare energy that was possessing the cat**, which you take in when you defeat it, rather than from the cat itself.

## Cat data schema
*Added 2026-10-01 from the cafe prototype. The prototype hand-writes 8 cats (`CATS` in `scripts/cafe/cafe_data.gd` on the `ryan` branch), but most cats will eventually be **generated**, so every field below needs a generation rule, not just a value.*

- `[DECIDED]` (2026-10-01) Most cats will be **mostly randomly generated**, and each needs a **unique description** and a **unique-ish voice**. Boss cats are the exception: they're hand-authored story characters.

### Fields

"In prototype" shows what the prototype already has, and under what name.

| Field | What it is | In prototype | Generation notes |
|---|---|---|---|
| **id** | Stable unique key, used for saves | `mochi`, `biscuit`... | Generated (e.g. a counter or UUID). Never shown to the player |
| **name** | Display name | yes | Drawn from name pools (food, plants, small words) with no duplicates among current cats. Possibly renameable by the player `[OPEN]` |
| **personality** | 1 normally; 2+ only for **rare** cats | one | Weighted draw from the roster. Rarity decides how many (see Personality system) |
| **rarity** | Common / rare / boss... | no | Rolled per cat, weighted by where it was found. Tiers still `[OPEN]` |
| **description** | 1–2 sentences of character | `blurb` | **Must be unique.** Build it from a **personality template** + a random **quirk** from a large pool + a touch of **appearance** ("a grey shadow who..."). Track used quirks so no two cats share one |
| **origin** | Where and how you got them | `since` (free text) | Structured data (biome or room, method: rescued / befriended / adopted-in, and the day), rendered to text. Feeds the backstory and the description |
| **appearance** | How they look | `tint` + `swatch` (one shared model, recoloured) | Later: base model or breed, coat colour and **pattern** (tabby, calico, tuxedo...), eye colour, size or age (kitten / adult / senior). Palettes per breed keep combinations plausible. `swatch` (the UI colour) should be derived, not hand-set |
| **voice** | How they sound | `voice.pitch`, `voice.meowy` | Pick a **voice set** (a bank of recorded meows and purrs; we'll need several so cats don't sound alike) + a pitch inside a range set by size or age (kittens higher). `meowy` (meow vs purr when petted) leans on personality (Chatty high, Lazy low) plus random variation |
| **behaviour** | How they move around the cafe | `walk_speed`, `idle` (nap length) | Derived from personality and age, plus a small random variation |
| **mischief** | Which events they can cause | `mischief` (yes/no) | Becomes a list of event types, mostly implied by personality (Playful knocks mugs, Hunter chases mice...) |
| **bond** | The single bond meter (cafe + dream) | no | Starts low (or warming up, for skittish new rescues). Not generated |
| **status** | In the cafe, resident (favourite), up for adoption, adopted (visits) | no | Starts "in the cafe". Changes through play |
| **keepsake** | What they leave when adopted | no | Generated at adoption from personality + bond (see Rescue → rehabilitate → adopt out) |
| **boss ability** | Boss cats only: the permanent ability | no | Hand-authored per boss |

### Generation guidelines
- `[PROPOSED]` *(Claude suggestion)* Split each cat into **authored pools** (names, quirks, description templates, voice sets, palettes) and **rolled choices** that pick from them. Then the pools can grow without touching code, and uniqueness is just "don't reuse a pick while that cat exists".
- `[PROPOSED]` *(Claude suggestion)* Make the **personality** drive everything else (description template, behaviour, voice leanings, mischief), so a cat reads as a coherent character rather than a pile of random stats.
- `[PROPOSED]` *(Claude suggestion)* Use a **seed per cat**, so a cat can be regenerated identically from saves or for debugging.
- `[OPEN]` How many voice sets are needed for cats to feel distinct, and where they come from (recordings vs processing a few base recordings).


## Needs expansion
- `[OPEN]` Caps on how many cats the cafe can hold, and how that scales.
- `[OPEN]` Cat needs and care (feeding, grooming, affection), and how much of that exists at all.
- `[OPEN]` Cat roster size, breeds, and rarity tiers.

> Likely to split later into Traits, Acquisition, and Adoption notes.
