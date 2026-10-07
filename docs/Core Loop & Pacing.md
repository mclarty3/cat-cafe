# Core Loop & Pacing

Part of [[- Overview|Cat Cafe Dungeon Crawler]] · status tags: see the legend in the hub · [[Decision Log]] · [[Open Questions]]

## The loop

1. **Morning prep.** Fill your pastry slots (croissants cost a little money; other pastries use dungeon ingredients) and prepare drink components. Adjust the cafe: furniture, upgrades (including more pastry slots), cat management.
2. **Cafe day.** Serve a small number of customers, handle cat events, and chat with regulars.
3. **Night.** Enter the dream dungeon for a run: rescue or befriend cats, gather ingredients, and progress.
4. **Wake up.** Return with what you banked, and the night's outcome affects the next morning.

## Decisions so far

- `[DECIDED]` About 65/35 dungeon to cafe time.
- `[DECIDED]` Dungeon runs last **10–30 minutes**, depending on the player's current goals.
- `[PROPOSED]` The cafe day, including prep, lasts about **8–12 minutes** to keep the ratio. With fewer than 12 customers, that's roughly a minute per customer, including the drink minigame, which means minigames should be short and quick.
- `[PROPOSED]` The player chooses the run length based on their goal:
  - **Shallow nights:** about 10 minutes in early biomes for common ingredients and common cats.
  - **Deep nights:** 25+ minutes pushing toward a possessed cat boss.
- `[PROPOSED]` The cafe should feel like where dungeon progress pays off and gets shown off, never like a chore standing between runs.

## Open
- `[OPEN]` How many in-game days is a full playthrough? Is there a calendar, seasons, or a deadline, or is it open-ended?
- `[OPEN]` Can the player skip a night or a day?
- `[OPEN]` Are there other time slots (for example, a midday activity like Dave the Diver's second dive)?
- `[OPEN]` Is there a **daily rating** and/or a longer-term **cafe reputation**? What feeds it (customers served, walkouts, chats, cat events handled or not) and what does it change (how many customers come, which regulars visit, unlocks)? The prototype's cat fight already sends nearby customers home early and counts them, as a hook for this.

## Not yet discussed

- **Game length and structure:** total playtime, chapters, ending, post-game. *Proposed ending: freeing the relative's lost cat (final boss), with play continuing afterward. See [[Setting & Lore#Main story]].*
