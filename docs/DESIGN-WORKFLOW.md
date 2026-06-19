# Design ↔ Build workflow (no more copy-paste)

Two Claudes, two jobs. The **GitHub repo is the shared channel** between them.

| | Claude.ai **design** chat | Claude **Code** (runs on Nico's Mac) |
|---|---|---|
| Sees your Mac / repo / Godot? | **No** — web sandbox | **Yes** — repo, Godot, the running game |
| Job | the visual *target* (specs + reference images) | *implements* it in Godot, renders the real screen |
| Can amend Godot? | No | Yes |

The design chat can't touch the build, so it can't "see Godot and change it" — that's Claude Code's job. The repo is how they hand work back and forth.

## The loop

```
 design (claude.ai)                     Claude Code (this Mac)
 ──────────────────                     ──────────────────────
 1. write spec + reference  ──►  docs/design-inbox/<screen>.md  ──►  2. "build the design in
    image                           (+ a reference PNG)                  design-inbox/<screen>"
                                                                     3. builds in Godot, renders
                                                                        the REAL screen →
                                                                        docs/mockups/latest/<screen>.png
                                                                        (commits + merges)
 5. amendments  ◄── 4. review: read the spec/code via the GitHub
    (back to 1)         connector; SEE the render (drag the latest PNG
                        into claude.ai, or paste its raw URL)
```

### Build → design requests go in the repo too (standing rule)
When **Claude Code** needs to ask design for something (a brief, a translation of an existing mockup, an amendment), it **always commits that request into the repo** as `docs/design-inbox/<screen>-REQUEST.md` — design reads it via the GitHub connector. Nico never copy-pastes a request into the chat. (Set 2026-06-19: the repo is the channel *both* ways, not just design → build.)

### Where things live (the agreed paths)
- **Design drops specs here:** `docs/design-inbox/<screen>.md` (the raw "GODOT-AI-PROMPT"-style brief + any reference image alongside).
- **Claude Code drops requests-to-design here:** `docs/design-inbox/<screen>-REQUEST.md`.
- **Claude Code renders here (stable, always-newest):** `docs/mockups/latest/<screen>.png` — design always reviews this path, no version chasing.
- Versioned build proofs also live in `docs/mockups/` (e.g. `season-hub-hifi-v2-built.png`); canonical specs get reconciled into `docs/superpowers/specs/`.

## claude.ai side — one-time setup (Nico)
1. In your claude.ai **Project**, add the **GitHub connector** and connect `nico101rsa/cricket-sim`.
   - Now design can **read** the spec + the committed code directly — you stop pasting code/specs in.
   - If the connector has **write** access, design can commit the next spec straight to `docs/design-inbox/` on a branch — then you stop pasting *specs* too. (If it's read-only, you save design's brief into `docs/design-inbox/` yourself — one file, not a full paste.)
2. **Seeing a render in claude.ai:** the reliable way is to **drag `docs/mockups/latest/<screen>.png` into the chat**. (The web chat views uploaded images reliably; fetching a URL is hit-or-miss.) The stable path means it's always the same file to grab. Raw URL if you want to try it:
   `https://raw.githubusercontent.com/nico101rsa/cricket-sim/main/docs/mockups/latest/<screen>.png`

## Handoff phrases (so it's one line each way)
- **To Claude Code:** "build the design in `design-inbox/season-hub`" (it reads the brief + reference, builds, renders, commits).
- **From Claude Code:** it always leaves the newest render at `docs/mockups/latest/<screen>.png` + says what to eyeball.

## Net effect
- **Specs/code:** read by design via the GitHub connector — no paste.
- **The next brief:** committed by design (write connector) or saved by you into `design-inbox/` — one file, not a paste.
- **The render:** one drag of a stable-named PNG.

That removes the two big paste hops; the only irreducible manual step is dragging one image into the web chat (the sandbox can't reach your Mac to grab it itself).
