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
The player's whole journey through one Country's **progression grid** — a 2D space of cells, each cell a (Level × Tour) pair, each cell played as one Season. A new Career starts at the bottom-left cell (Club, Tour 1). **Starting Team is picked by the Player from the 3 lowest-star Teams** at Club Level — a rookie underdog choice (you don't get parachuted into the top franchise). Beating a cell opens the cell above (next Tour); **beating Tour 6 (Evening Mamba) is the League gate — it unlocks the next Level at its Tour 1** (the *readiness gate*, career-line-balancing ruling 2026-06-14; raised from Tour 4 so you must clear most of a League before climbing, so no single climb strategy dominates — supersedes the difficulty-sheet v2 Tour-4 gate). Tours 7–8 (Evening Mixed, Premier) are the optional stay-and-farm stretch: prize escalation makes higher tours of your current Level pay more, competing with jumping Levels early. The Career is complete when the Player wins the top Level — wins The Final of Province's Premier tour. There is no gate on reaching it (ruling 2026-06-12): Club's and City's Premier trophies are an *optional* chase, made appealing by the Grand-Final prize + the Premier super prize (difficulty-sheet v2 prize objects), not required.

**Tour**:
The difficulty axis — eight named difficulty steps *within* a Level ("up" the grid). In order, easiest to hardest (difficulty-sheet v2, 2026-06-12 — tour names carry **pitch conditions**; names-only until the conditions-mechanics rung): Flat & Warm, Spin, Green Mamba (seaming), Day Mixed, Evening Spin, Evening Mamba (the League-gate / readiness tour, career-line balancing 2026-06-14), Evening Mixed, Premier (the showcase finale, with a deliberate difficulty jump into it). Equivalent to Slay-the-Spire "Ascension" / Balatro "Stake", but as one axis of a 2D grid rather than a single line. Each Tour defines a strength distribution (mean × spread); every team in that Tour's league — including the Player's Team — draws its **battingStrength** and **bowlingStrength** from this distribution at the start of each **Season**. Climbing Tours scales the whole league together; the Player's Team rises with the Tour, not against it.
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
- **Win a Level** — win The Final of that Level's Premier tour (its 8th/last Tour). The Level's championship trophy. Winning Province's completes the Career; Club's and City's trophies are optional milestones (no longer an unlock gate — ruling 2026-06-12), incentivised by the **Grand-Final prize + Premier super prize** (difficulty-sheet v2: Club ₸250 / City ₸500 / Province ₸750 super prize on top of escalated match prizes; trophy *surface* design still deferred).

**Joker**:
A stacking modifier card purchased with **Tons** at the **Shop**. Balatro layer. Common / Rare / Legendary rarity — cost (in Tons) scales with rarity, such that a Player frequently cannot afford every Joker on offer (deliberate scarcity → the "if only I had more money" feeling). Up to 4 slots visible during a Match — see DESIGN_HANDOFF §16.7. Each Joker is either a passive verb buff or a conditional trigger; the authoring grammar is fixed (ADR 0007) and composes from the 6-verb palette (ADR 0006). **Season-scoped by default** — all owned Jokers reset at Season end, with one exception: at end-of-Season the Player may elect to **carry over** one owned Joker (their choice; "none" is valid) into next Season's starting slots, alongside the free starter Common from that Season's opening Shop.

**Shop**:
A between-Match meta-loop event where the Player allocates accumulated **Tons**. Up to **5 Shop visits per Season** — fewer if the Player misses the playoffs:
- 1 at **Season start** — free; pick 1 starter **Joker** from a set of 3 Commons (no Tons cost)
- 1 **after Match 3** (always)
- 1 **after Match 5** (always)
- 1 **before the semi-final** (only if Player finished top 4 in the league phase)
- 1 **before the championship Match** (The Final or 3rd-place playoff — only if Player made the semi)

At each post-Match Shop the Player may take **one of each** action (zero of an action is fine; the visit is *capped at one per type*, not required to use all four): buy 1 Joker (from a set of 1 Common + 1 Rare + 1 Legendary), upgrade 1 **Attribute** (+1), sell 1 owned Joker for partial Tons refund, **hold** 1 offered Joker. Holding makes that specific offered Joker re-appear in the next Shop's offer set alongside 2 fresh randoms; held offers **expire at Season end** if not bought. Buying a Joker when all 4 slots are full prompts a slot-replacement pick. The Shop is the primary surface for the **Strategic** skill layer (ADR 0003) — the Jokers-vs-Attributes-vs-bank trade-off lives here.

**Kit Room**:
The in-fiction name for the **Shop** — a warm-lit room visually distinct from the cool match screens, the place the Player visits between Matches to spend **Tons**. Mechanically identical to "Shop"; "Kit Room" is the world-facing label used in UI copy and commentary.
_Avoid_: "Store", "market" — say "Kit Room" in UI, "Shop" in design/code.

**Kit Manager**:
The non-playable persona who runs the **Kit Room** — a familiar club-staff archetype (the kit-man) who greets the Player on every visit with a contextual line. The first persona in a meta-loop screen; future meta-loop screens (Offer, Career Grid, etc.) may grow their own personas (scout, coach, etc.) following the same pattern.

**Manager Boost**:
Mid-Match action — pressing the green button applies a side-aware all-Attribute boost: **batting Attributes** (`Power`, `Composure`) while batting; **bowling Attributes** (`Attack`, `Control`) while bowling. No menu, no choice — the only decision is *when* to press. Magnitude is locked at press from the water-meter's current fill % (50% fill → half the maximum buff; 100% → full). Once pressed, the meter **drains** during the active boost; when it reaches 0% the boost ends and the meter starts recharging. Higher fill at press therefore gives both a *stronger* and a *longer* boost — a single-axis trade. See DESIGN_HANDOFF §16.8.

**Team**:
The Player's side — the Player plus ten teammates — sitting at one **Level**. Carries a **★ star rating** on a **0.5–5.0 scale in half-star increments** (10 possible values, displayed `★★★★½` etc.) reflecting franchise strength *relative* to its Level's other Teams: 5.0★ = elite franchise, 0.5★ = perennial cellar-dweller. Star rating is mostly durable across Seasons but mutates Markov-style each Season: roughly **30% chance of a ±0.5 swing** (form change, personnel turnover) and **5% chance of a ±1.0 catastrophic swing** (board fight, manager exit, captain retirement — flavoured in commentary the following Season via `Team.lastSeasonEvent`). Clamped at **0.5 floor and 5.0 ceiling**. Star rating is **invariant across Tours** within a Level — climbing Tours rescales all Teams' absolute strengths up, but preserves ranks. Per-Match actual strengths (`battingStrength`, `bowlingStrength`) derive from the Team's stars + current Tour's distribution + small per-Season noise. Team identity (name, palette, the Player's **Affinity** with them) persists across Seasons. The Team the Player is on defines the Player's current Level. Stronger Teams (higher star rating) pay less and give the Player less playing time. Tuning: durability model ADR 0009; the 20%/5% percentages are V1 strawman, balance-harness tuned.

**Offer**:
A recruitment proposal from a **Team** to the **Player**. Two trigger points per Season:

- **One mid-Season Offer** (after Match 4): a single take-it-or-leave-it. **Accepting switches Teams immediately** — the Player finishes the Season for the new Team, inheriting their current league position, remaining fixtures, and playoff prospects. **Affinity resets immediately.** The Player's personal stats (runs, wickets, Key Moments won) and **Tons** earned from Matches 1–4 stay with the Player. Narrative: *"This Team isn't going anywhere — take the gamble and join a contender."* Tons / personal stats accumulate normally for the rest of the Season under the new Team.
- **Three end-of-Season Offers**: a choose-from-three set; staying is always an option. Accepting locks in the move for next Season.

The Offer shows the Team's **★ star rating** (durable identity) plus a current-Season form delta (e.g. "+ above baseline" / "− below baseline"). Stars give the *signal that makes Offers readable* — the Team durability model (ADR 0009) is what makes Offer evaluation a real skill, not a coin flip. Accepting any Offer resets **Affinity**. Offer quality scales with the Player's strength and the current Team's recent league finishes. Cross-**Level** Offers appear only once the Career grid has unlocked the higher-Level cell; beating a Level-N cell guarantees at least one Level-(N+1) Offer in the next end-of-Season Offer set.

**Tons** (₸):
The career currency. A base contract amount from the current Team, scaled by the Player's on-field performance (runs, wickets, Key Moments won). A single shared pool spent on two things: **Player Attribute upgrades** (permanent growth, Career-scoped) and **Jokers** (Season-scoped power). The central Meta-layer trade-off is allocating Tons between the two — bank for permanent growth, or burn now for this-Season strength. **Tons persist across Seasons** — it is a Career-scoped bank, never reset within a Career. Hoarding (skip Jokers now, bank for an Attribute upgrade later) is a legitimate Meta-layer strategy. Per-Tour scarcity comes from prices scaling with Tour difficulty, not from a clock. Core career trade-off on top: stronger Teams pay a lower base — and on a strong Team you play less, which lowers the performance multiplier too. The ₸ glyph is documented in [ADR 0008](docs/adr/0008-currency-name-and-mark.md); assets live in [`docs/brand/`](docs/brand/).

**Affinity**:
A single value tracking the Player's tenure with their current Team. Rises the longer the player stays; resets when they accept an Offer to move. Grants a temporary performance bonus (not permanent stat growth). The counterweight to Offers — an Offer tempts a move, Affinity rewards loyalty.

**Seasons played**:
A lifetime counter of every Season the Player has played, win or lose. The Career-completion metric — finishing the Career in fewer Seasons played is the score to beat ("beat the game in 34 — now beat that"). Because the Player's skills can be fully maxed, Seasons played is the meaningful measure of mastery, not raw power.

**Career Records**:
The persistent set of Career-wide highlights the Player has accumulated — visible as a drill-down from the **Career grid**. Two components:
- **Global rank** — the Player's position against every other player across all Levels & Tours, displayed as `#X / 2,112` (population = 8 Tours × 3 Levels × 8 Teams × 11 players). Computed analytically from the Tour distributions, not by simulating other players (ADR 0011).
- **Records rail** — derivative stats from the auto-sim: Highest score, Best bowling figures, Most sixes in an innings, Fastest fifty, Fastest hundred, Player of the Match count. Each shows context (e.g. "vs Karoo Kings, in the 118*").

Career Records are persistent across **Seasons** within a Career; they reset only when the Player starts a New Career. They are a *display* surface, not a gameplay surface — no Tons payout, no balance impact, just legacy and the "now beat that" prompt.
_Avoid_: "Achievements" (that's the deferred Theme 8 Collection layer — a different surface).

**Attribute**:
The four sim stats every player carries. Batting: **Power** (pushes ball outcomes toward boundaries) and **Composure** (resists dismissal). Bowling: **Attack** (raises wicket chance) and **Control** (restricts runs and extras). The Player's Attributes are real and grow with **Tons**; every other player's are derived from their **Team**'s strength.

**Intent**:
The team's aggression posture during a Match — one of three bands: Defensive, Balanced, Aggressive. The captain (the Player) sets it via Key Moment decisions; a higher band lifts both scoring and dismissal chance together.

**Form**:
A temporary per-player performance multiplier reflecting current confidence — shown by the player's facial expression in their portrait (hot / steady / tired / cold, DESIGN_HANDOFF §16.3). Multiplies effective **Attributes** in both ball-rolls (roughly ×0.8 cold → ×1.15 hot). Applies to batters and bowlers alike. Distinct from Attribute: Form is transient, Attributes are persistent. **Per-ball Form ticks are Player-only** (driven by boundaries, dismissals, dot streaks, etc.); every other player's Form is otherwise static within a Match. **Key Moment `formEvent` effects are an exception** — they can adjust anyone's Form (teammate, opponent), but only from explicit Key Moment effects, never from per-ball events. Player Form persists between Matches within a **Season** and resets at Season end, alongside **Jokers**.

**Season hub**:
The persistent between-Match screen *within* a Season — the "home" the Player returns to after every Match's **Result**. Shows current league position, fixtures remaining, owned **Jokers**, **Tons** balance, **Affinity**, Player **Attributes**, current **Team** identity. Hosts entry points to the **Shop** and **Offer** when their cadence triggers. Distinct from the **Career grid** — the Career grid is the *between-Season* screen (you only see it once a Season ends).
_Avoid_: "Dashboard", "lobby" — use "Season hub".

## Relationships

- A **Career** belongs to exactly one **Country**.
- A **Career** is a **progression grid** of **Seasons** — one Season per (**Level** × **Tour**) cell.
- A new Career starts at the bottom-left cell: **Club**, **Tour 1**.
- A **Season** is up to 9 **Matches** — a 7-game league phase, then (top 4 only) a semi-final and a placing match (The Final or 3rd-place playoff).
- A Player **beats** a Season by finishing **top 3** (1st/2nd via The Final, 3rd via the 3rd-place playoff). Beating a Season unlocks the next Tour; beating **Tour 6 (Evening Mamba)** also unlocks the next Level at its Tour 1 (the readiness gate, career-line balancing 2026-06-14; raised from Tour 4). Finishing 4th or lower unlocks nothing.
- A Player **wins a Level** by winning The Final of that Level's Premier tour. Winning Province's Premier tour completes the **Career**; Club's and City's Premier trophies are optional (no unlock gate — ruling 2026-06-12), paid via the Grand-Final prize + Premier super prize.
- **Seasons played** ticks up by one for every **Season** — beaten or failed.
- A **Match** contains 5–8 **Key Moments**.
- A **Match** is resolved ball-by-ball; each ball is a contest between the batter's and bowler's **Attributes**, modulated by **Intent**, **Form**, conditions, **Jokers** and **Manager Boost**.
- Only the **Player**'s **Attributes** are real and persistent; every other player's are derived from their **Team**'s strength. The ball-resolution maths is identical regardless of who is involved.
- **Jokers** are scoped to a **Season** (acquired at the **Shop** between Matches, reset at Season end — with the single-Joker end-of-Season carry-over exception).
- **Manager Boost** is scoped to a single **Match**.
- A **Player** plays for one **Team** at a time; the Team sets the current **Level**.
- An **Offer** comes from a **Team**; accepting it moves the Player to that Team.
- **Tons** are earned from the current Team and spent at the post-Match Shop on Player **Attribute** upgrades (permanent) and **Jokers** (Season-scoped) from one shared pool.
- **Affinity** builds with the current **Team** and resets when an **Offer** is accepted.
- A **Tour** defines a strength distribution; every team in that Tour's league draws its battingStrength and bowlingStrength from it at the start of each **Season**. The Player's Team scales with whichever Tour the Player is currently playing — staying with the same Team across Tours means a fresh strength draw each Season at the new Tour's level.
- Moving across **Levels** requires accepting an **Offer** from a Team at the new Level. Beating a Level-N cell guarantees at least one Level-(N+1) Offer in the next end-of-Season Offer set, provided the Career grid has unlocked the higher cell.

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
- **Difficulty topology** — **Resolved: overlapping Level bands, v2 (2026-06-12 evening).** Each Level has its own 8-Tour band; bands overlap (Club difficulty 1–10, City 5–15, Province 9–20 — City Tour 1 = Club Tour 5 exactly). A linear 1-step ramp inside each Level, then a deliberate jump into the Premier tour (+3/+4/+5 by Level). Promotion eases you in via a gentle Flat & Warm tour, then ramps higher than the Level below. *(Source: creator's difficulty spreadsheet v2, transcribed at `docs/difficulty-sheet-v2.md`; supersedes the v1 bands 1–8/2–10/3–12.)*
