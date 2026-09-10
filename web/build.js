// Dependency-free build: concatenate the engine, game and UI scripts into one
// HTML file and copy the PWA files next to it. Output: dist/.
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const ROOT = __dirname;
const SRC = path.join(ROOT, 'src');
const DIST = path.join(ROOT, 'dist');
const ORDER = [
  'engine/tuning.js', 'engine/rng.js', 'engine/model.js', 'engine/ball.js', 'engine/intent.js', 'engine/bowling.js', 'engine/innings.js', 'engine/match.js',
  'game/names.js', 'game/generator.js', 'game/stats.js', 'game/league.js', 'game/game.js',
  'ui/app.js',
];

function build() {
  const build = process.env.CRICKET_BUILD || new Date().toISOString().slice(0, 16).replace('T', ' ');
  const css = fs.readFileSync(path.join(SRC, 'ui/style.css'), 'utf8');
  const scripts = ORDER.map((f) => `<script>\n${fs.readFileSync(path.join(SRC, f), 'utf8')}\n</script>`).join('\n');
  let html = fs.readFileSync(path.join(SRC, 'ui/index.html'), 'utf8');
  html = html.replace('/*__CSS__*/', () => css).replace('/*__SCRIPTS__*/', () => scripts).replace('__BUILD__', build);
  fs.rmSync(DIST, { recursive: true, force: true });
  fs.mkdirSync(DIST, { recursive: true });
  fs.writeFileSync(path.join(DIST, 'index.html'), html);
  for (const f of fs.readdirSync(path.join(ROOT, 'static'))) {
    let data = fs.readFileSync(path.join(ROOT, 'static', f));
    if (f === 'sw.js') data = Buffer.from(data.toString('utf8').replace('__BUILD__', build.replace(/[^A-Za-z0-9]/g, '')));
    fs.writeFileSync(path.join(DIST, f), data);
  }
  fs.writeFileSync(path.join(DIST, '.nojekyll'), '');
  const size = fs.statSync(path.join(DIST, 'index.html')).size;
  console.log(`built dist/index.html (${(size / 1024).toFixed(0)} KB) build ${build}`);
}
build();
