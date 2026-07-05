# Cricket-moment scene system — generation prompt

Saved 2026-07-05. Reframed from the viral Three.js "SDF blend-shell" character prompt (Fable 5, xHigh). The key move: ask for **one scene *system* + a scene-descriptor JSON format**, not N hand-made scenes — so every cricket moment falls out of the same engine and new ones cost ~20 lines of JSON.

## The one decision before you run it: Three.js or Godot?

The prompt below is the **Three.js (web)** version — proven ground for that style, fast and cheap to prototype, but nothing ports directly into the Godot game.

- **Three.js prototype (recommended first):** lock the visual style fast, decide if you love it, then commission a Godot port as its own rung. The SDF blend-shell trick is a vertex shader + merged meshes — Godot does both, but Fable has less Godot muscle-memory, so expect more iteration there.
- **Godot version:** swap the first line to "Build in Godot 4.6 with GDScript" and the shader clause to "using a Godot spatial shader (vertex-stage SDF snap) on `ArrayMesh`-merged primitives". Everything else (action verbs, ball presets, scene descriptor) transfers as concepts.

---

## Prompt (Three.js prototype version)

Build with Three.js a **procedural cricket-moment scene system** — a single engine that renders any cricket dismissal or highlight as a short, juicy, self-contained clip, where each *scene is ~20 lines of JSON* an AI can author endlessly.

**Characters:** use a procedurally-generated ragdoll style — primitive shapes (capsules/cones) merged into one draw call, with a vertex shader that snaps every vertex onto the combined smooth-min SDF surface so seams vanish, SDF-gradient normals for continuous lighting, and SDF-proximity color blends — toon-styled, mobile-performant, no skinning or raymarching. A character (bowler, batter, keeper, fielder, umpire) is ~15 lines of JSON.

**Cricket action layer:** procedural, no animation clips. Composable *action verbs* driven by IK and state machines — run-up-and-deliver (fast/spin variants), bat swing / defend / leave / pull, keeper crouch-and-take, fielder dive / chase / throw, batter walk-off, bowler wicket-celebration. Actions retarget automatically to any character rig.

**Ball:** a first-class physics object with trajectory presets (yorker, bouncer, edge, straight, lofted-six, ground-drive) and reactive collisions — stumps cartwheel and bails fly on contact, bat deflects the ball, catch snaps it to the hand.

**Camera + juice per moment:** selectable cameras (behind-the-bowler, slip, square-leg, boundary, umpire) with cinematic moves; heavy polish — slow-mo on impact, freeze-frame, screen shake, dust/impact particles, crowd swell.

**Scene descriptor (the payoff):** each scene is JSON — `{ characters, action, ball_preset, outcome, camera, timing, juice }`. The engine plays it as a ~4–6s clip. Author these scenes as data:

- **Bowled** — behind-bowler cam, yorker, stumps cartwheel, freeze on the shattered wicket.
- **Caught behind** — slip cam, edge preset, keeper dive-and-take, slow-mo grab.
- **Six** — boundary cam, lofted preset, ball into the crowd, camera tracks it out.
- **LBW appeal** — square-leg cam, ball raps the pad, bowler + keeper appeal, umpire raises finger.
- **Run out** — square cam, ground-drive, fielder chase-and-throw, stumps broken mid-dive.
- **Clean drive for four** — boundary pan, ground-drive, ball races away.

Goal: a unique, endlessly AI-generatable cricket-highlight style with billion-dollar-game juice — *"HOLY SH\*\* this was done with AI?"* quality. Run at xHigh reasoning effort.

---

## Source notes (what made the original prompt work)

- Asked for a **system + data format**, not an asset — the "~15 lines of JSON per character" is the payoff that makes it AI-generatable.
- Separated reusable layers: character tech → action verbs → ball physics → camera/juice → scene descriptor.
- Kept a hard quality/juice bar ("HOLY SH\*\* this was AI?", "next billion dollar game").
- Original build: Fable 5, xHigh effort, ~90 min active work, ~27.5M tokens, ~US$75.
