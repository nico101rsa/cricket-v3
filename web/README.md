# Cricket v3 — the web app

Text cricket management for a phone. Ten clubs, Pretoria v Sydney, you run one.

```
cd web
node --test            # engine, game and Python-parity tests
node build.js          # -> dist/index.html (+ PWA files)
CHROMIUM_PATH=/opt/pw-browsers/chromium-1194/chrome-linux/chrome node tools/smoke.js   # headless iPhone run + screenshots
python3 tools/make_golden.py > test/golden.json   # regenerate the Python tape (run from the repo root)
```

No dependencies. Scripts use a UMD guard so the same files run under `node --test` and inline in the page.
Deployed by `.github/workflows/ci.yml` to GitHub Pages on every push to `main`.

## Cloud save (Supabase)

One row per sync code, reached only through two SQL functions. Setup once:

1. Create a Supabase project, open the SQL editor, paste `supabase/schema.sql`, Run.
2. Project settings → API: copy the Project URL and the anon public key into `src/config.js` (commit) or type them under More → Cloud save.
3. In the game: More → Cloud save → New code → Link this device. Same code on every other device.

`tools/mock_supabase.js` stands in for the two functions in tests and the smoke run: `node tools/mock_supabase.js 8787` runs it by hand.
Save format: `SAVE_VERSION` + `migrate()` in `src/game/game.js`; every old version has a fixture in `test/fixtures/` that must keep loading.
