'use strict';
// Cloud save client against the mock of the two Supabase functions, plus the
// save-format migration pin: every fixture under test/fixtures must load.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Cloud = require('../src/game/cloud.js');
const Game = require('../src/game/game.js');
const mock = require('../tools/mock_supabase.js');

test('sync codes: unambiguous alphabet, hash is stable and case/space-insensitive', async () => {
  const code = Cloud.genCode();
  assert.match(code, /^[a-z2-9]{4}(-[a-z2-9]{4}){3}$/, code);
  assert.ok(!/[01oil]/.test(code));
  const h1 = await Cloud.hashCode(code), h2 = await Cloud.hashCode(`  ${code.toUpperCase()} `);
  assert.equal(h1, h2);
  assert.equal(h1.length, 64);
  assert.notEqual(h1, await Cloud.hashCode(Cloud.genCode()));
});

test('client: miss, put, hit, revision conflict, bad key, wrong anon key, missing function', async () => {
  const srv = await mock.start();
  try {
    const c = Cloud.makeClient({ url: srv.url + '/', anonKey: srv.anonKey });
    const key = await Cloud.hashCode('abcd-efgh-jkmn-pqrs');
    assert.equal(await c.get(key), null);
    const save = { version: 2, seed: 1, meta: { savedAt: '2026-09-12T10:00:00.000Z', rev: 0 } };
    const r1 = await c.put(key, save, null);
    assert.deepEqual(r1, { conflict: false, rev: 1 });
    const got = await c.get(key);
    assert.equal(got.rev, 1);
    assert.deepEqual(got.data, save);
    const r2 = await c.put(key, { ...save, seed: 2 }, 1);
    assert.deepEqual(r2, { conflict: false, rev: 2 });
    const stale = await c.put(key, { ...save, seed: 3 }, 1);
    assert.equal(stale.conflict, true); assert.equal(stale.rev, 2); assert.equal(stale.data.seed, 2);
    const forced = await c.put(key, { ...save, seed: 4 }, null);
    assert.deepEqual(forced, { conflict: false, rev: 3 });
    await assert.rejects(c.put('short', save), /bad key/);
    const wrong = Cloud.makeClient({ url: srv.url, anonKey: 'nope' });
    await assert.rejects(wrong.get(key), /401/);
    assert.throws(() => Cloud.makeClient({ url: '', anonKey: 'x' }), /not configured/);
    const dead = Cloud.makeClient({ url: 'http://127.0.0.1:1', anonKey: 'x' });
    await assert.rejects(dead.get(key), /offline or blocked/);
  } finally { await srv.close(); }
});

test('newer(): the later savedAt wins, ties and blanks keep local', () => {
  const m = (t) => ({ savedAt: t });
  assert.equal(Cloud.newer(m('2026-01-02T00:00:00Z'), { meta: m('2026-01-01T00:00:00Z') }), 'local');
  assert.equal(Cloud.newer(m('2026-01-01T00:00:00Z'), { meta: m('2026-01-02T00:00:00Z') }), 'remote');
  assert.equal(Cloud.newer(m('2026-01-01T00:00:00Z'), { meta: m('2026-01-01T00:00:00Z') }), 'local');
  assert.equal(Cloud.newer(m(null), { meta: m('2026-01-01T00:00:00Z') }), 'remote');
  assert.equal(Cloud.newer(m('2026-01-01T00:00:00Z'), { meta: m(null) }), 'local');
  assert.equal(Cloud.newer(null, null), 'local');
});

test('every old save fixture loads, migrates to the current version and keeps playing', () => {
  const dir = path.join(__dirname, 'fixtures');
  const files = fs.readdirSync(dir).filter((f) => /^save-v\d+\.json$/.test(f));
  assert.ok(files.includes('save-v1.json'));
  for (const f of files) {
    const raw = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    const st = Game.deserialize(JSON.stringify(raw));
    assert.equal(st.version, Game.SAVE_VERSION, f);
    const orphans = Game.orphanStats(st);
    for (const [pid, seasons] of Object.entries(st.stats)) for (const no of Object.keys(seasons)) if (!(orphans[pid] && orphans[pid][no])) assert.deepEqual(seasons[no], Game.rebuildStats(st)[pid][no], `${f}: stats for player ${pid} season ${no} come from the scorecards`);
    assert.ok(Array.isArray(st.history), `${f}: history`);
    assert.ok(st.meta && 'savedAt' in st.meta && 'rev' in st.meta, `${f}: meta`);
    if (st.live) { assert.ok(Array.isArray(st.live.instructions), `${f}: live.instructions`); const sim = Game.liveMatch(st); assert.ok(sim.match.innings1.events.length > 0); Game.finishLive(st, sim); }
    for (const seasons of Object.values(st.stats)) for (const x of Object.values(seasons)) assert.ok(Array.isArray(x.last5b), `${f}: last5b`);
    const before = st.season.fixtures.filter((x) => x.result).length;
    Game.playRound(st);
    assert.ok(st.season.fixtures.filter((x) => x.result).length > before, `${f}: still plays`);
    assert.equal(Game.deserialize(Game.serialize(st)).version, Game.SAVE_VERSION);
  }
});
