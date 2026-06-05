# Player lifecycle — hard permadeath

V1 Player lifecycle has **two end-states** and **no other ways out**: the Player either **wins the Province's Premium tour Final** (Win-out) or the human **manually retires them** via a corner button on the Season hub. Both archive the Player to the **LegendsArchive** and trigger a new Player Creation. There is no auto-drop, no non-selection, no age-based retirement, no team-release path. Hard permadeath, two triggers, single archive transition.

Reasons:

1. **Seasons-played becomes a real cost.** Permadeath gives the Hall of Fame meaning. The "now beat that" replay loop hooks off finite Player-lives, not just numerical scores — every Legend on the wall represents a specific Career that cannot be retried.
2. **Auto-drop balance is hard before the baseline loop is playtested.** Layering an unproven failure mode on an unproven success loop is bad sequencing. We need to know what "good Career" feels like before we can decide what "your Career ends here" should look like.
3. **Architecturally cheap to add later.** An auto-drop trigger added post-launch is the same state transition as Manual retire, just counter-triggered instead of button-triggered. The `LifecycleManager.end_career(reason)` signature already takes a reason — adding a third trigger is one new caller, zero rewrite cost.
4. **Form-anchored, not Team-anchored.** If/when Theme 9 ships auto-drop, the trigger anchors on **Player form** (low runs over last K innings, lost Key Moments, etc.), **not Team result**. A good Player on a bad Team shouldn't be punished for the Team's losses. This is recorded here so the future implementer doesn't have to re-discover the principle.

The Manual-retire button is the cheap escape-hatch for *"I'm stuck and want to roll a new Player"* — it covers the player-experience case that auto-drop would otherwise need to solve, without requiring any failure detection or balance work.

Decided 2026-06-01 alongside the Player Creation spec at `docs/superpowers/specs/2026-06-01-player-creation-design.md` §2, formalised at implementation-plan time.

## Considered alternatives

- **Auto-drop on Team relegation.** The Player is dropped when their Team finishes bottom of the table. Rejected — punishes the Player for the Team's mistakes, conflates the Team-management layer with the Player-life layer. Holds for Theme 9 *only* if anchored on Player form, not Team result.
- **Age-based retirement.** Player retires after N Seasons regardless of form. Rejected for V1 because the Career-length feel hasn't been playtested; a hard age cap might make Careers too short or too long before we know which. Holds for Theme 9.
- **No permadeath; Players persist across Careers.** Rejected — would gut the Hall of Fame's meaning and remove the "finite life" frame the game's identity rests on. Anti to the spec's core thesis.
- **Soft retire — Player keeps playing but loses upgrades.** Rejected — too mechanically novel to add at V1; the simple binary (alive / archived) reads cleaner.
