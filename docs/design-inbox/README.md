# Design inbox

Drop point for the **claude.ai design track**'s briefs (the "GODOT-AI-PROMPT"-style specs) + their reference images.

- One file per screen: `<screen>.md` (e.g. `season-hub.md`), reference image alongside (`<screen>-reference.png`).
- Tell Claude Code: **"build the design in `design-inbox/<screen>`"** — it builds in Godot, renders the real screen to `docs/mockups/latest/<screen>.png`, and reconciles the brief into `docs/superpowers/specs/`.

See `docs/DESIGN-WORKFLOW.md` for the full loop.
