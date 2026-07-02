# Form Mechanic + Affinity Bonus — Design (2026-07-03)

The last two designed-but-unbuilt gameplay mechanics (CONTEXT.md §Form, §Affinity),
built in one rung so they share a **single balance re-sweep**. After this rung the game
is mechanically complete per its own design docs; Nico's playtest pass follows, then the
iOS export (his ruling, 2026-07-03: functional game → self-playtest → export).

## Design authority

- **CONTEXT.md §Form:** temporary per-player performance multiplier, shown by the
  portrait's facial expression (already built, PR #109). Multiplies effective
  **Attributes in both ball-rolls**, roughly **×0.8 cold → ×1.15 hot**, batters and
  bowlers alike. **Per-ball ticks are Player-only** (boundaries, dismissals, dot
  streaks); everyone else's Form is static within a match. Key Moment `formEvent`
  effects may adjust anyone — **exception deferred, see DF9**. Form **persists between
  matches within a Season** and **resets at Season end**, alongside Jokers.
- **CONTEXT.md §Affinity:** tenure with the current Team; rises on STAY (wired, PR
  #104), resets on a move (wired). "Grants a temporary performance bonus (not permanent
  stat growth)" — the bonus is what this rung adds.

## Approaches considered

- **A (chosen): a `FormState` object threaded through the innings loop** — per-ball
  ticks + per-ball multiplier, exactly as §Form specifies. Off (null) = byte-identical,
  the sim's established extension pattern (IntentPlan, BoostPlan, DRSPolicy…).
- B: between-match form updates only (derive form from the last match's stat line, flat
  multiplier within a match). Cheaper but violates §Form's per-ball ticks and kills the
  intra-match momentum feel. Rejected.
- C: A + the Key Moment `formEvent` exception. The KM effect palette carries no
  formEvent today; building the palette entry + UI + balance in the same rung bloats it.
  Rejected for now (DF9).

## Decisions (DF1–DF12, AFK defaults unless marked)

- **DF1 — State:** new `Player.form_points: float` (`@export`, default `0.0`, clamp
  **[-3.0, +3.0]**) is the true Form state. The existing `Player.form: int` stays as the
  **banded display value**, kept in sync as `roundi(form_points)` whenever points settle
  — every existing consumer (portraits, hub chip, `SeasonView.form`, HoF) keeps working
  untouched. Effective band thresholds via `FormBand.of(roundi(points))`: HOT ≥ +1.5 ·
  STEADY (−0.5, +1.5) · TIRED [−1.5, −0.5] · COLD < −1.5.
- **DF2 — Multiplier** (piecewise linear, hits §Form's anchors exactly):
  `form_mult(points) = 1.0 + 0.05 × points` for points ≥ 0 (max ×1.15),
  `1.0 + (0.2/3) × points` for points < 0 (min ×0.8). Applied to **all four** of the
  Player's attributes at roll time (both ball-rolls: wicket and runs stages see it via
  the attribute inputs), batting and bowling alike. Opponents run at mult 1.0 (§Form:
  others static; we model their static value as neutral).
- **DF3 — Tick table** (Player-only, quarter-point granularity; first sweep targets):
  - batting: boundary (4 or 6) **+0.25** · dismissed **−1.0** · every 6 *consecutive*
    dot balls on strike **−0.25** (streak resets on any run/boundary/wicket/innings end)
  - bowling (the Player's overs only): wicket **+0.5** · boundary conceded **−0.25**
  - clamp to [−3, +3] after every tick. Ticks apply **immediately** — the next ball is
    rolled at the new multiplier (intra-innings momentum).
- **DF4 — `FormState`** (`scripts/domain/form_state.gd`, RefCounted): constructed
  per sim run from `start_points` + a static `base_mult` (the Affinity bonus, DF7);
  `mult() -> float` = `base_mult × form_mult(points)`; tick methods
  (`on_player_boundary`, `on_player_dismissed`, `on_player_dot`, `on_player_wicket`,
  `on_player_conceded_boundary`) own the streak counter + clamps. Pure state, no RNG.
- **DF5 — Threading:** new trailing optional `form_state = null` on
  `simulate_innings` / `simulate_match` / `simulate_match_teams` (the same instance
  crosses both innings of a match, so batting form carries into the bowling innings).
  **null = byte-identical** (whole existing suite must stay green unmodified — the
  proof the default path didn't move). `MatchResult` gains `form_end: float`
  (RefCounted, not serialized — same as every other result field).
  Inside the loop the multiplier applies at the two player touchpoints only:
  the striker dict when `s["is_player"]`, and `bat_attack/bat_control` when
  `player_bowling`. Tick calls ride the existing outcome handling (the `formed`
  detection block already isolates player boundary/wicket).
- **DF6 — Persistence + reset:**
  - **Live season:** `SeasonPlay` seeds each `MatchSession` sim with the current
    `form_points` (same route as jokers, via `make_session`/`_resim` — resim re-runs
    from the *match-start* value so interactive re-simulation stays deterministic);
    on `commit_player_result` the match's `form_end` settles into `Player.form_points`
    (+ `form` int sync). **Season end resets both to 0** in the same place carry-over
    election clears jokers. Decisions-replay reproduces form byte-for-byte because each
    replayed match re-derives it in sequence (nothing new is serialized in the save —
    `form_points` lives on the Player resource, which is already persisted).
  - **Headless career sim:** the Player's matches inside `SeasonResolver` (league +
    playoffs) thread one `FormState` across the season, reset each season — so the
    balance harness measures the same game Nico plays.
- **DF7 — Affinity bonus:** `affinity_mult = 1.0 + 0.01 × clampf(affinity, 0, 5)`
  (max **+5%** at the hub's AFF_FULL = 5 display cap), passed as `FormState.base_mult`.
  Applies to the Player's attributes only, both disciplines, static within a match.
  Live + headless both. (Affinity increment/reset rules already exist — untouched.)
- **DF8 — Where form does NOT apply:** teammates, opponents, auto-resolved (non-player)
  fixtures, and the opponent's danger man. Player-only, exactly §Form.
- **DF9 — Deferred, recorded:** the Key Moment `formEvent` exception (KMs adjusting
  anyone's Form) — no KM carries a formEvent today; queue as its own small rung if the
  playtest wants it. Also deferred: a form-delta recap on the Result screen (DN7
  dropped it when the concept didn't exist; it exists now — add only if Nico asks).
- **DF10 — Balance re-sweep (single, shared, gate to merge):** with form+affinity ON at
  affinity 0:
  1. `probe_scoring_env` — env within the pegged real-T20 bands (~153.5 / RR ~8.13);
     player-only form should barely move team totals, re-peg only if it drifts.
  2. Build-balance: 4 reference builds, win-rate spread ≤ ~2pp, pay spread ≤ ~₸1.
  3. No-joker symmetric floor: stays in the fair-fight zone (~45–50%).
  4. Form-reactive jokers spot-check (they trigger on form *events*, not the new value
     — mechanically independent, expect no band moves).
  DF3/DF2/DF7 constants are the tuning dials if anything lands outside tolerance;
  results recorded in the spec's Results section (stat-provenance rules apply).
  Long sweeps run detached (`nohup … > /tmp/log`) with a log-grepping watcher.
- **DF11 — UI in this rung:** none beyond what exists. The hub chip + portrait follow
  `Player.form` automatically after each committed match. (Eyeball check: play two
  matches in the real game, watch the face/chip move.)
- **DF12 — Tuning constants live as consts on `FormState`** (documented in-file),
  promoted to a resource only if a future sweep needs to search them programmatically.

## Architecture

```
scripts/domain/form_state.gd        ← FormState: points, ticks, clamps, mult()
ball path (per ball, player only):  striker attrs / player-bowling attrs × form_state.mult()
innings_resolver.simulate_innings   ← +form_state (ticks ride the outcome handling)
match_resolver.simulate_match(_teams) ← +form_state (one instance, both innings)
MatchResult.form_end                ← carried out of the sim
match_session / season_play         ← live: seed from Player.form_points, settle on commit, reset at season end
season_resolver                     ← headless: thread across the season, reset per season
player.gd                           ← +form_points float (form int stays, synced roundi)
```

## Testing

- `FormState` unit table: tick values, dot-streak reset semantics, clamps, multiplier
  anchors (0→1.0, +3→1.15, −3→0.8), affinity base_mult composition.
- Byte-identity: `form_state = null` leaves existing pinned sims byte-identical (the
  whole current suite, unmodified, is that proof).
- Determinism: same seed + same start points → identical `form_end`; resim from the
  same start value reproduces the same match (MatchSession pin).
- Persistence: two-match `SeasonPlay` pin — match 1's `form_end` is match 2's start;
  season end resets to 0; cross-session save/replay round-trip byte-equal (extend the
  existing resume pin test).
- A directional sanity pin: a scripted innings where the player hits early boundaries
  ends with more points than one where they're dismissed early (no magnitude pinning —
  the sweep owns magnitudes).

## Risks / watch-outs

- The rich-get-richer loop (good start → higher mult → better finish) raises variance
  by design; the sweep (DF10) is the guard that it doesn't move the fairness ledger.
- `_resim` runs on every interactive decision — always seed from match-START points
  (never the evolving value), or resims compound form and desync replay.
- iCloud " 2" conflict files appeared mid-rung already once today — sweep before every
  test run.
