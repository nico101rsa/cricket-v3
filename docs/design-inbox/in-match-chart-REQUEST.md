# Design review — In-Match run-rate chart (build fidelity)

**Built 2026-06-23.** The run-rate chart from `docs/mockups/in-match-hi-fi-v1.html`
(the `.chart` block) is now implemented in the interactive match screen — it was
previously missing (a plain CRR number stood in for it). Pure presentation; no
sim/balance change.

**Please compare the build to your mockup and flag any deltas:**

- Rendered build (synthetic 4 states):
  - `docs/mockups/in-match-chart-1st-innings-v1.png` (par line)
  - `docs/mockups/in-match-chart-chase-v1.png` (target line)
  - `docs/mockups/in-match-chart-boundary-over-v1.png`
  - `docs/mockups/in-match-chart-wicket-over-v1.png`
- Real-data, in context (full screen): `docs/mockups/latest/in-match.png`
- Locked design: `docs/mockups/in-match-hi-fi-v1.html`

**Specific questions:**
1. **Worm** — stroke weight / glow / dot sizing vs the mockup's white worm?
2. **Bars** — blue / gold(boundary) / red(wicket) palette + the "now" pulse read right?
3. **Backdrop** — moon / floodlights / stand-band atmosphere close enough, or too
   sparse/busy? (The mockup's per-seat crowd silhouettes were simplified to a slim
   dark stand band because at phone size a per-seat dotted row read as a stray
   gridline cutting across the plot — flag if you want the seats back.)
4. **Target/par line** — colour, dash, and label placement (`par 8.0` 1st inns /
   `target 8.x` 2nd inns) acceptable?
5. **Axis/legend** — over numbers + CRR legend legible at phone size?

**Decisions already baked (flag if you disagree):**
- 1st innings shows a fixed **par RR (8.0)** line (no chase yet); 2nd innings the
  real chase RR.
- Win-probability corner indicator deferred (not built this rung).
- Bar colour priority: wicket > boundary > normal.
