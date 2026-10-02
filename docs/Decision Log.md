# Decision Log

Part of [[- Overview|Cat Cafe Dungeon Crawler]] · status tags: see the legend in the hub · [[Decision Log]] · [[Open Questions]]

Every `[DECIDED]` and `[REJECTED]` item across the design notes. Add new decisions with a date, and update the tag in the area note too.

## New decisions

| Date | Decision | Note |
|---|---|---|
| 2026-09-30 | Enter the dream by **going to sleep**; portal rejected | [[Setting & Lore]] |
| 2026-09-30 | Cats in the dungeon are a **loadout choice**, not an AI companion | [[Cats]] |
| 2026-09-30 | Exit rooms are **sunbeam rooms**; exiting has **no cost** | [[Dream Dungeon Structure]] |
| 2026-09-30 | Rejected broom / rolling pin as the main weapon (want something weapon-ier) | [[Combat, Movement & Bosses]] |
| 2026-09-30 | **One personality per cat**, with one cafe effect and one dungeon effect | [[Cats]] |
| 2026-09-30 | Roster: Lazy, Playful, Curious, Nocturnal, Hunter, Chatty in; **Affectionate rejected** | [[Cats]] |
| 2026-09-30 | Boss cats give a permanent ability **and** join the roster | [[Cats]] |
| 2026-09-30 | Bond builds from **both** the cafe and the dungeon, into one meter | [[Cats]] |
| 2026-09-30 | **Only rare cats** can have more than one personality | [[Cats]] |
| 2026-09-30 | **Keepsakes:** strength based on bond at adoption, in their own limited slots | [[Cats]] |
| 2026-09-30 | Regulars' story beats are **optional in the moment, never missable** | [[Customers & Regulars]] |
| 2026-09-30 | Cafe view is **isometric / 3D-feeling**, not literal overhead *(superseded 2026-10-01)* | [[Atmosphere, Art & Audio]] |
| 2026-10-01 | Cafe is **full 3D with a perspective follow camera**; isometric rejected | [[Atmosphere, Art & Audio]] |
| 2026-10-01 | **Counter service**, not table service; the player can leave the counter | [[Cafe Gameplay]] |
| 2026-10-01 | Price paid **at the register**, tip **at pickup** | [[Cafe Gameplay]] |
| 2026-10-01 | Player **carries items to the pass**, no further | [[Cafe Gameplay]] |
| 2026-10-01 | Taking an order is a **single press**; **to-go cups**, no bussing for now | [[Cafe Gameplay]] |
| 2026-10-01 | Regulars are **chatted with at their table** | [[Customers & Regulars]] |

# From the seed brainstorm

*All of these came from the initial web-UI brainstorm; exact dates weren't recorded. Logged 2026-09-30.*

## [[- Overview|Concept]]

- `[DECIDED]` Genre lineage: day business / night dungeon, in the family of **Recettear** (Ryan's first game of this kind and the original inspiration), **Moonlighter**, and **Dave the Diver**.
- `[DECIDED]` The business is a **cat cafe**: making coffee and food, handling cat-related events, and talking with customers.
- `[DECIDED]` The dungeon is where you find **rare cats** and **ingredients** for better coffee and pastries.
- `[DECIDED]` The dungeon is the **main focus**, at roughly **65% dungeon / 35% cafe** (for comparison, Dave the Diver is about 80/20).

## [[Core Loop & Pacing]]

- `[DECIDED]` About 65/35 dungeon to cafe time.
- `[DECIDED]` Dungeon runs last **10–30 minutes**, depending on the player's current goals.

## [[Setting & Lore]]

- `[DECIDED]` The dungeon is **otherworldly and dreamlike**. It is **NOT** a physical multi-level complex under the cafe.

## [[Cats]]

- `[DECIDED]` Each cat has **personality traits that affect cafe gameplay**. Examples brainstormed: a lazy lap cat calms stressed customers; a playful kitten draws in families but knocks things over; a grumpy old tom is loved by one specific regular and hated by everyone else.
- `[DECIDED]` Cats also have **dungeon-side effects or abilities**. Examples brainstormed: seeing in the dark to reveal traps, squeezing through gaps to reach hidden rooms, sensing ghosts, pushing things off ledges as a puzzle mechanic.
- `[DECIDED]` **Cats are friends, never captured.** No Pokémon-style catching.
- `[DECIDED]` **Strong possessed cats** serve as enemies or bosses. You defeat them to free them and bring them home.
- `[DECIDED]` **Lesser cats** appear throughout the dungeon across runs and are won over through a **befriending minigame** or by **completing a task** for them.
- `[DECIDED]` Rescued cats come to the cafe, warm up over time, form bonds with regulars, and eventually get **adopted**. Adoption gives rewards (money, reputation, story) and frees space for new rescues.
- `[DECIDED]` To keep players from feeling punished for getting attached: they can mark favorites as **permanent cafe residents**, and **adopted cats come back to visit** with their new owners.

## [[Cafe Gameplay]]

- `[DECIDED]` A **limited number of customers per day** (fewer than 12, as a rough figure).
- `[DECIDED]` Each customer's **order is prepared by the player**, and an order may or may not include coffee or another drink.
- `[DECIDED]` **Minigames** for making coffee and drinks, but the game should not be entirely minigames.
- `[DECIDED]` A **prep phase before opening** where dungeon ingredients go into **baked goods** and **coffee drinks**.
- `[DECIDED]` The prep phase is also when you **modify the cafe**: rearrange furniture, buy upgrades, manage cats.
- `[DECIDED]` Cat events keep days varied. Brainstormed examples: breaking up a cat fight before it spreads; catching a mug a cat is nudging off the counter; getting a kitten down from the curtains; finding which cat is hiding the stolen croissant.
- `[DECIDED]` Staff mainly **add capacity** as customer numbers grow, like in Dave the Diver. They **don't fully replace** the player's involvement.
- `[DECIDED]` If an employee takes orders, the player is **free to chat with customers at their tables**.

## [[Customers & Regulars]]

- `[DECIDED]` **Regulars have ongoing stories**, revealed through conversations over many visits. This is a key emotional driver (Coffee Talk-style).
- `[DECIDED]` Conversations are signaled with a **speech bubble** at the table.

## [[Dream Dungeon Structure]]

- `[DECIDED]` **2D, metroidvania-inspired roguelite** with a **Hollow Knight / Dead Cells** feel.
- `[DECIDED]` Priorities: **good movement**, **some platforming**, **satisfying combat**.
- `[DECIDED]` **Meta progression.** Leading idea: **permanent movement abilities** unlocked through cats or story progress, which make previously unreachable areas accessible.
- `[DECIDED]` There's a **voluntary way to wake up** and return home with your loot. It should be **reasonably easy**, but **not available anywhere**. It exists only in **specific rooms in each area**.
- `[DECIDED]` Let players **start runs deeper** once they've unlocked it (assuming floor-like progression). Proposed name: lucid-dream anchors, unlocked by beating biome guardians or rescuing boss cats.
- `[REJECTED]` Attaching **conditions or penalties** to starting deeper (for example, less health or fewer ingredient slots).

## [[Combat, Movement & Bosses]]

- `[DECIDED]` **Possessed cats** are major bosses. Defeating one rescues the cat.

## [[Day-Night Connection]]

- `[DECIDED]` The **outcome of the previous night affects the next cafe day**.

## [[Atmosphere, Art & Audio]]

- `[DECIDED]` The cafe is **very cozy** with **jazzy music** (lo-fi / cafe jazz) and a comforting atmosphere, as in Coffee Talk.
- `[DECIDED]` Coffee Talk achieves its mood through **restraint**: warm lighting, slow pacing, nothing rushing you. The cafe should have **calm periods before opening and after closing** that feel like a breather.
- `[DECIDED]` **Dynamic music** (agreed direction), with brainstormed specifics:
  - purring adds soft layers as more cats settle in
  - the tempo picks up during a rush
  - rain on the windows changes the mix
