# Cafe Gameplay

Part of [[- Overview|Cat Cafe Dungeon Crawler]] · status tags: see the legend in the hub · [[Decision Log]] · [[Open Questions]]

## Structure
- `[DECIDED]` A **limited number of customers per day** (fewer than 12, as a rough figure).
- `[DECIDED]` Each customer's **order is prepared by the player**, and an order may or may not include coffee or another drink.
- `[DECIDED]` **Minigames** for making coffee and drinks, but the game should not be entirely minigames.
- `[PROPOSED]` Drink minigame ideas: timing the espresso pull; steaming milk by listening for the right sound; latte art tracing (possibly cat faces) as an optional skill challenge. Keep each one to about 10 seconds.

## Service model
*Settled through the cafe prototype, 2026-10-01.*

- `[DECIDED]` (2026-10-01) **Counter service, not table service.** Customers queue at the register, order, wait at a pickup spot, and collect their order from the pass, then sit for a while. The player's home base is **behind the counter**. A first prototype with table service (taking orders and delivering to tables) felt too much like Diner Dash.
- `[DECIDED]` (2026-10-01) **The player can leave the counter**, and sometimes needs to: chatting with regulars at their tables, handling cat events out front. While you're out, nobody takes orders and the queue builds. That's the trade-off. Walking should never become back-and-forth busywork, so stations stay a few steps apart.
- `[DECIDED]` (2026-10-01) **Customers pay the menu price at the register; the tip comes at pickup**, based on drink quality and how long they waited.
- `[DECIDED]` (2026-10-01) **The player physically carries drinks and pastries to the pass**, and no further. Customers take their own order from the pass.
- `[DECIDED]` (2026-10-01) **Taking an order is a single button press** at the register, not a minigame.
- `[DECIDED]` (2026-10-01) **No bussing for now:** everything is served in to-go cups.
- `[PROPOSED]` Cat events wait until the player isn't in a menu, minigame or chat, so they're a choice rather than bad luck. In the prototype, losing a mug while making a drink felt unfair.
- `[PROPOSED]` Pacing from playtests: about 5 customers, roughly 20 seconds apart, felt right for an early day. 7 customers, 8–14 seconds apart, felt like mid-game: about the limit without staff.

## Morning prep phase
- `[DECIDED]` A **prep phase before opening** where dungeon ingredients go into **baked goods** and **coffee drinks**.
- `[DECIDED]` The prep phase is also when you **modify the cafe**: rearrange furniture, buy upgrades, manage cats.
- `[PROPOSED]` Treat prep as a limited number of **actions** (bake a batch, make a syrup, rearrange, groom a cat). This gives the night-to-day effect something concrete to modify (see section 9).
- `[PROPOSED]` Rare dungeon ingredients, such as moonflour and dream honey.

## Cat events
- `[DECIDED]` Cat events keep days varied. Brainstormed examples: breaking up a cat fight before it spreads; catching a mug a cat is nudging off the counter; getting a kitten down from the curtains; finding which cat is hiding the stolen croissant.

## Staff
- `[DECIDED]` Staff mainly **add capacity** as customer numbers grow, like in Dave the Diver. They **don't fully replace** the player's involvement.
- `[DECIDED]` If an employee takes orders, the player is **free to chat with customers at their tables**.
- `[PROPOSED]` Cats or staff could take over repetitive tasks as the game progresses, shifting the player's attention toward the interesting parts (stories, events, special orders, showing off rare ingredients).

## Matchmaking customers and cats
- `[LEANING]` Uncertain overall, but a possible way to vary days. The idea is seating customers near cats that suit them: an anxious student wants a calm cat, a rowdy group wants the chaotic one.

## Open / needs expansion
- `[OPEN]` The full menu: drinks, pastries, and other items.
- `[OPEN]` The full list of minigames, and which ones unlock over time.
- `[OPEN]` Layout and customization depth. How much is decorative versus functional?
- `[OPEN]` How customer satisfaction works beyond tips. The payment structure is settled (see Service model).
- `[OPEN]` Types of staff, and how you hire and upgrade them.
