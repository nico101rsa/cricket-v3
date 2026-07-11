# Music direction — Cricket v2

Last updated: 2026-07-11 (direction chosen 2026-06-12)

## The model

**Balatro, not FIFA.** This is a decision game the player stares at for 40-minute
sessions, so the music is one warm, hypnotic, mid-tempo instrumental loop that never
demands attention. No epic stadium anthems — they fatigue fast and fight the
card-table mood.

**Flavour:** lo-fi jazz-funk base with light Southern-Hemisphere summer accents —
kwela pennywhistle / marimba (South African township-jazz feel) and lazy surf-rock
guitar (Aussie summer arvo at the ground). Matches the SA + AUS soft-launch markets
without commentary clichés.

**Technical rules:**
- Generate every track at the **same bpm and similar key** so game-state
  cross-fades don't jar.
- Ask for "seamless loop" explicitly, but expect to trim the loop point manually
  in an audio editor — AI tools rarely loop cleanly out of the box.

## Generation prompts

Format that works for Suno/Udio/Stable Audio: genre tags + tempo + instrumentation
+ mood + "instrumental, seamless loop".

### Main gameplay loop

> Instrumental, seamless loop, 85 bpm. Laid-back lo-fi jazz-funk groove with warm
> Rhodes electric piano, soft brushed drums, round bassline, subtle vinyl crackle.
> Light kwela pennywhistle and marimba accents, South African township-jazz flavour.
> Lazy summer afternoon at a cricket ground. Hypnotic, relaxed, never builds to a
> climax. No vocals.

### Menu / career-hub theme (brighter, more melodic)

> Instrumental, 95 bpm. Sunny mid-tempo groove, clean surf-rock guitar, hand
> percussion, warm bass, marimba melody. Optimistic start-of-summer feeling, sport
> on the radio, nostalgic but modern. Loopable, no vocals, no big drops.

### Tension variant (high-stakes match moments)

> Instrumental, 85 bpm, same palette: Rhodes, brushed drums, marimba — but sparser,
> low pulsing bass, held chords, light tension. Quiet concentration before a
> decisive delivery. Loopable, no vocals.

## Tool choice (as of 2026-07-11)

| Tool | Verdict |
|---|---|
| **Suno** (Pro ~A$15/mo) | Best quality for this genre blend; commercial rights + stem separation on Pro (stems useful — e.g. pull drums for a quieter menu variant). Caveat: still in active training-data litigation; small residual risk. |
| **Stable Audio** | The conservative pick — trained on licensed AudioSparx data, cleanest commercial license, strong at instrumental loops with exact track lengths. Lower quality ceiling for full "songs". |
| **Udio** | Skip for now — mid-relaunch after the Oct 2025 UMG settlement; jointly-licensed platform due sometime 2026. |

**Plan:** prototype on Suno's free tier (no commercial rights, fine for finding the
sound); at ship time either pay for Suno Pro and accept the small residual risk, or
recreate the winning direction on Stable Audio. No decision needed until Theme 7 is
done and music actually matters.
