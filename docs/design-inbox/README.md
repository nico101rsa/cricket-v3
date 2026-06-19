# Design inbox

The shared channel between the **claude.ai design track** and **Claude Code** — used **both directions**.

**Design → build (briefs):**
- One file per screen: `<screen>.md` (e.g. `season-hub.md`), reference image alongside (`<screen>-reference.png`).
- Tell Claude Code: **"build the design in `design-inbox/<screen>`"** — it builds in Godot, renders the real screen to `docs/mockups/latest/<screen>.png`, and reconciles the brief into `docs/superpowers/specs/`.

**Build → design (requests):**
- Claude Code commits any request to design as `<screen>-REQUEST.md` (e.g. `in-match-REQUEST.md`) so design reads it via the GitHub connector — Nico never pastes a request. **Standing rule** (see `docs/DESIGN-WORKFLOW.md`).

See `docs/DESIGN-WORKFLOW.md` for the full loop.
