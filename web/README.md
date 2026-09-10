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
