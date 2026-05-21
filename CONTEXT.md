# Cricket Sim — Context

The game's domain glossary. Source of truth for terminology used across design docs, code, and UI copy. Implementation details do not belong here.

A mobile cricket sim mashing Reigns × Balatro × management. You are a rising cricketer; play is roguelite-shaped Seasons of ~2:45 Matches, climbing a Career grid within a chosen origin Country.

## Language

**Player**:
The player-character — a single rising cricketer, guided by you (the human) through a Career. Has an aging avatar (the split-bg portrait, DESIGN_HANDOFF §16.3). Captains the team in-Match — i.e. makes the Key Moment decisions. **Not** a club manager: squad-management systems (transfers, youth, stadium) are deferred well past first build.
_Note_: "Player" always means this in-game cricketer. For the human, say "you" or "the user".

**Match**:
One ~2:45 game of T20 cricket. The inner loop. 5–8 Key Moments wrapped around auto-sim segments.

**Key Moment**:
A 3-second swipe-decision card overlay inside a Match. 8 archetypes (Powerplay Exit, Wicket Crisis, etc.) — see DESIGN_HANDOFF §3. The locus of player agency in-match.

**Season**:
One playthrough of a single grid cell — one Level at one Tour. ~20–30 minutes (one sitting). A 7-game round-robin league phase (8-team league); the top 4 advance to a semi-final, then The Final (for 1st/2nd) or the 3rd-place playoff — 9 Matches on the full path. Miss the top 4 and the Season ends at 7 Matches. Jokers acquired between Matches persist within a Season; reset at Season end.
_Avoid_: "Run" for this unit — it collides with cricket *runs* (the score).

**The Final**:
The championship Match of a Season, contested by the two semi-final winners. A Season does not always end in The Final — lose your semi-final and your Season ends instead in the 3rd-place playoff.

**Career**:
The player's whole journey through one Country's **progression grid** — a 2D space of cells, each cell a (Level × Tour) pair, each cell played as one Season. A new Career starts at the bottom-left cell (Club, Tour 1). Beating a cell opens the cell above (next Tour) and across (next Level). The Career is complete when the Player wins the top Level — wins The Final of Province's Premium tour, which unlocks only after both Club's and City's Premium tours have been won. Not a linear climb: the player fills the grid at their own pace.

**Tour**:
The difficulty axis — eight named difficulty steps *within* a Level ("up" the grid). In order, easiest to hardest: Practise tour, Home Tour summer, Home Tour winter, Home Tour evening, Away Tour summer, Away Tour winter, Away Tour evening, Premium tour. Home tours are gentler, Away tours harder, the Premium tour the showcase finale (a mixture of conditions). Equivalent to Slay-the-Spire "Ascension" / Balatro "Stake", but as one axis of a 2D grid rather than a single line.
_Avoid_: "League" for this concept — "league" is reserved for its natural cricket meaning (a competition).

**Country**:
The origin axis. You pick one Country at Career start — typically your real-world origin. Each Country has its own ladder of Levels and its own roster of teams. Replayability vector: beat one Country's Career → unlock another.
**Structurally a master-data axis** — same ladder template, same screens, same mechanics; the variation is team names, surname pool, palette key, optional pitch-flavor tunables. Adding a Country = filling in a data file, not writing new code or designing new screens.
**Primary target Countries: South Africa and Australia** (see `docs/adr/0001-primary-target-south-africa-and-australia.md`). Both ship in first build — creator's playtest friends are in both. India deferred; the India-centric framing in DESIGN_HANDOFF §2 is legacy and will be unwound.

**Level**:
A rung on the Country ladder — a content/prestige tier, each with its own competition and roster. Full draft for South Africa: Club, City, Province, U-20, B-side, National (Proteas), International. First build ships the bottom three: Club, City, Province. Each Level has its own 8-Tour difficulty band; the bands **overlap** — a higher Level has a higher ceiling but a gentle entry (its Practise tour is easier than the Level below's top Tours).
**Structurally the expensive axis** — each new Level adds opposition-strength tuning, promotion/career-meta mechanics, distinct league naming per Country, and "feels different not just harder" balancing work.

**Beat** / **Win** — two distinct outcomes:
- **Beat a Season** — finish top 3 in that Season. Unlocks grid progression. The everyday currency of climbing.
- **Win a Level** — win The Final of that Level's Premium tour (its 8th/last Tour). The Level's championship trophy. The three Level-wins are a required, ordered endgame ladder: Province's Premium tour unlocks only after Club's and City's Premium tours are both won. Winning Province's completes the Career.

**Joker**:
A stacking modifier card acquired between Matches inside a Season. Balatro layer. Common / Rare / Legendary rarity. Up to 4 slots visible during a Match — see DESIGN_HANDOFF §16.7.

**Manager Boost**:
Mid-Match consumable that interrupts the auto-sim with a green Reigns card. Strength = water-meter fill % at the moment of use — see DESIGN_HANDOFF §16.8.

**Team**:
A cricket side the Player plays for — the other ten players around them. Each Team sits at one Level and has a strength. The Team you are on defines your current Level. Stronger Teams pay less.

**Offer**:
A recruitment proposal from a Team to the Player, generated at the end of every Tour (at least one always available). Accepting an Offer moves the Player to that Team. Offer quality scales with the Player's strength and the current Team's final log position.

**Pay**: *(working name)*
The career currency, and the single channel of permanent growth. A base contract amount from the current Team, scaled by the Player's on-field performance (runs, wickets, Key Moments won). Spent to upgrade the Player's stats. Core trade-off: stronger Teams pay a lower base — and on a strong Team you play less, which lowers the performance multiplier too.

**Affinity**:
A single value tracking the Player's tenure with their current Team. Rises the longer the player stays; resets when they accept an Offer to move. Grants a temporary performance bonus (not permanent stat growth). The counterweight to Offers — an Offer tempts a move, Affinity rewards loyalty.

**Seasons played**:
A lifetime counter of every Season the Player has played, win or lose. The Career-completion metric — finishing the Career in fewer Seasons played is the score to beat ("beat the game in 34 — now beat that"). Because the Player's skills can be fully maxed, Seasons played is the meaningful measure of mastery, not raw power.

## Relationships

- A **Career** belongs to exactly one **Country**.
- A **Career** is a **progression grid** of **Seasons** — one Season per (**Level** × **Tour**) cell.
- A new Career starts at the bottom-left cell: **Club**, **Tour 1**.
- A **Season** is up to 9 **Matches** — a 7-game league phase, then (top 4 only) a semi-final and a placing match (The Final or 3rd-place playoff).
- A Player **beats** a Season by finishing **top 3** (1st/2nd via The Final, 3rd via the 3rd-place playoff). Beating a Season unlocks grid progression; finishing 4th or lower does not.
- A Player **wins a Level** by winning The Final of that Level's Premium tour. Winning Club's and City's Premium tours is **required** to unlock Province's; winning Province's Premium tour completes the **Career**.
- **Seasons played** ticks up by one for every **Season** — beaten or failed.
- A **Match** contains 5–8 **Key Moments**.
- **Jokers** are scoped to a **Season** (acquired between Matches, reset at Season end).
- **Manager Boost** is scoped to a single **Match**.
- A **Player** plays for one **Team** at a time; the Team sets the current **Level**.
- An **Offer** comes from a **Team**; accepting it moves the Player to that Team.
- **Pay** is earned from the current Team and spent on Player upgrades.
- **Affinity** builds with the current **Team** and resets when an **Offer** is accepted.

**Level** ("across" the grid) and **Tour** ("up" the grid) are independent grid coordinates. Difficulty rises with both, but the Level bands overlap — promotion to a new Level eases you in via its Practise tour, then ramps past anything the Level below offered.

## Example dialogue

> **Designer:** "If I lose The Final, did I still beat the Season?"
> **Domain:** "Yes — losing The Final is 2nd place, which is top 3. You beat the Season and progress on the grid. Jokers still reset (Season-scoped); your Player and grid progress persist."

> **Designer:** "And if I lose the 3rd-place playoff?"
> **Domain:** "Then you finished 4th — you did not beat the Season. You retry the same cell, keeping everything (skills, grid unlocks, Level-wins); the only cost is the Season added to your Seasons-played tally."

## Flagged ambiguities

- **"League"** — was proposed as the difficulty-axis name. **Resolved: the difficulty axis is "Tour".** "League" stays reserved for its natural cricket meaning (a competition, e.g. the Club League).
- **"Level"** — **Resolved: "Level" is the term.** Fine for internal use; revisit only if it confuses players in-UI later.
- **Player-character name** — **Resolved: "Player".** Always refers to the in-game cricketer; the human is "you" / "the user". DESIGN_HANDOFF §1's "captain" still describes the in-Match role.
- **Failing a Season** — **Resolved.** Finish 4th or lower → the Season is not beaten; retry the same cell. You keep everything — grid unlocks, the Player's skills, Level-wins. The only cost is a Season added to the Seasons-played tally with no progression gained.
- **Difficulty topology** — **Resolved: overlapping Level bands.** Each Level has its own 8-Tour band; bands overlap heavily (Club difficulty 1–8, City 2–10, Province 3–12). Promotion eases you in via a gentle Practise tour, then ramps higher than the Level below. Deliberate difficulty "jumps" (skipped numbers in the difficulty sheet) sit at the Home→Away and →Premium transitions. *(Source: creator's difficulty spreadsheet — worth saving into `docs/` as a reference.)*
