// The phone UI: one scrolling document, screens rendered from the game
// state, event delegation via data-action attributes. No framework.
(function () {
  'use strict';
  const C = globalThis.Cricket;
  const Game = C.game, S = C.stats, L = C.league, I = C.intent, Inn = C.innings, Cloud = C.cloud;
  const KEY = 'cricket-v3-save', LIVE_KEY = 'cricket-v3-live', CLOUD_KEY = 'cricket-v3-cloud';
  const SPEEDS = [1, 3, 10];

  const app = { state: null, screen: 'home', view: {}, sim: null, timeline: null, timer: null, flash: '' };

  // ---- persistence ------------------------------------------------------
  function load() {
    try { const t = localStorage.getItem(KEY); return t ? Game.deserialize(t) : null; } catch (e) { console.warn('load failed', e); return null; }
  }
  // Every local save stamps meta.savedAt (the cloud tie-breaker) and queues a
  // cloud push. persistLocal() writes without stamping (used after a pull).
  function save() {
    if (app.state) { app.state.meta = app.state.meta || { savedAt: null, rev: 0 }; app.state.meta.savedAt = new Date().toISOString(); }
    persistLocal();
    scheduleCloudPush(1500);
  }
  function persistLocal() {
    try { if (app.state) localStorage.setItem(KEY, Game.serialize(app.state)); } catch (e) { console.warn('save failed', e); app.flash = 'Could not save (storage full or blocked).'; }
  }
  function saveLive() {
    try { if (app.state && app.state.live) localStorage.setItem(LIVE_KEY, JSON.stringify(app.state.live)); else localStorage.removeItem(LIVE_KEY); } catch (e) { /* ignore */ }
    scheduleCloudPush(15000);
  }
  function loadLive() {
    try { const t = localStorage.getItem(LIVE_KEY); if (t && app.state && app.state.live) { const l = JSON.parse(t); if (l.fixtureId === app.state.live.fixtureId) Object.assign(app.state.live, l); } } catch (e) { /* ignore */ }
  }

  // ---- helpers ----------------------------------------------------------
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const st = () => app.state;
  const team = (id) => Game.teamById(st(), id);
  const player = (id) => st().players[id];
  const pname = (id) => { const p = player(id); return `${p.firstName[0]}. ${p.surname}`; };
  const surname = (id) => player(id).surname;
  const roleText = (p) => (p.role === 'BATTER' ? 'bat' : p.role === 'ALLROUNDER' ? `ar/${p.kind === 'PACE' ? 'pace' : 'spin'}` : (p.kind === 'PACE' ? 'pace' : 'spin'));
  const userTeam = () => team(st().userTeamId);
  const isUser = (id) => id === st().userTeamId;
  const nrrText = (x) => (x >= 0 ? '+' : '') + x.toFixed(2);
  const oversText = Inn.oversText;
  const btn = (action, label, extra = '', cls = '') => `<button class="btn ${cls}" data-action="${action}" ${extra}>${label}</button>`;
  function dismissalText(b) {
    if (!b.out) return 'not out';
    const bw = surname(b.bowlerId);
    if (b.how === 'c') return `c ${surname(b.fielderId)} b ${bw}`;
    if (b.how === 'c&b') return `c & b ${bw}`;
    if (b.how === 'st') return `st ${surname(b.fielderId)} b ${bw}`;
    if (b.how === 'lbw') return `lbw b ${bw}`;
    return `b ${bw}`;
  }

  // ---- rendering --------------------------------------------------------
  const root = document.getElementById('app');
  function render() {
    const html = (SCREENS[app.screen] || SCREENS.home)();
    const nav = app.state && app.state.userTeamId && !['live', 'home', 'pick'].includes(app.screen) ? navBar() : '';
    const flash = app.flash ? `<div class="flash">${esc(app.flash)}</div>` : '';
    root.innerHTML = `${nav}${flash}<main class="screen screen-${app.screen}">${html}</main>`;
    app.flash = '';
    window.scrollTo(0, app.view.scrollY || 0);
    app.view.scrollY = 0;
  }
  function go(screen, view = {}) { app.screen = screen; app.view = view; render(); }
  function navBar() {
    const items = [['hub', 'Home'], ['table', 'Table'], ['fixtures', 'Fixtures'], ['squad', 'Squad'], ['stats', 'Stats'], ['more', 'More']];
    return `<nav class="nav">${items.map(([k, l]) => `<button class="nav-btn ${app.screen === k ? 'active' : ''}" data-action="go" data-screen="${k}">${l}</button>`).join('')}</nav>`;
  }

  const SCREENS = {};

  SCREENS.home = () => {
    const s = st();
    let cont = '';
    if (s && s.userTeamId) {
      const t = userTeam();
      cont = `<section class="card"><h2>${esc(t.name)}</h2><p class="muted">${esc(t.city)} · Season ${s.season.no} · ${stageText()}</p>${btn('go', 'Continue', 'data-screen="hub"', 'primary')}</section>`;
    } else if (s) {
      cont = `<section class="card"><p>League created. Choose your club.</p>${btn('go', 'Choose a club', 'data-screen="pick"', 'primary')}</section>`;
    }
    const seed = app.view.seed || Math.floor(Math.random() * 900000 + 100000);
    return `<header class="title"><h1>Cricket</h1><p class="muted">Text cricket management. Ten clubs, Pretoria v Sydney. You run one.</p></header>
      ${cont}
      <section class="card"><h3>${s ? 'Start a new league' : 'New league'}</h3>
      <label>League seed <input id="seed" type="text" inputmode="numeric" value="${esc(seed)}"></label>
      <p class="muted small">The same seed always makes the same ten clubs.</p>
      ${btn('newLeague', s ? 'New league (replaces your save)' : 'Create league', '', s ? 'danger' : 'primary')}</section>`;
  };

  SCREENS.pick = () => {
    const s = st();
    return `<header class="title"><h2>Choose your club</h2><p class="muted">Ten clubs, five from each city. The blurbs are all you get.</p></header>
      ${s.teams.map((t) => `<section class="card team-card"><h3>${esc(t.name)} <span class="muted small">${esc(t.city)}</span></h3><p class="blurb">${esc(t.blurb)}</p>${btn('chooseTeam', `Manage ${esc(t.name)}`, `data-id="${t.id}"`, 'primary')}</section>`).join('')}`;
  };

  function stageText() {
    const s = st().season;
    if (s.stage === 'league') { const nf = Game.nextFixture(st()); return nf ? `Round ${nf.round} of 9` : 'League done'; }
    if (s.stage === 'semis') return 'Semi-finals';
    if (s.stage === 'final') return 'The Final';
    return `Season over · Champions: ${esc(team(s.champion).name)}`;
  }

  SCREENS.hub = () => {
    const s = st(), t = userTeam();
    const nf = Game.nextUserFixture(s);
    const any = Game.nextFixture(s);
    const rows = L.table(s.teams, s.season.fixtures);
    const me = rows.find((r) => r.teamId === t.id);
    let next = '';
    if (s.season.stage === 'done') {
      const champ = team(s.season.champion);
      next = `<section class="card"><h3>${isUser(champ.id) ? 'Champions!' : 'Season over'}</h3><p>${esc(champ.name)} won the title. You finished ${ordinal(me.pos)} in the league.</p>${btn('nextSeason', `Start season ${s.season.no + 1}`, '', 'primary')}<p class="muted small">Everyone ages a year. Career stats carry over.</p></section>`;
    } else if (nf) {
      const home = nf.homeId === t.id, opp = team(home ? nf.awayId : nf.homeId);
      const label = nf.label || `Round ${nf.round}`;
      next = `<section class="card"><h3>Next: ${esc(label)}</h3><p class="fixture-line">v ${esc(opp.name)} <span class="muted">(${home ? 'home' : 'away'})</span></p><p class="blurb small">${esc(opp.blurb)}</p>
        ${btn('go', 'Pick XI and play', 'data-screen="xi"', 'primary')} ${btn('simRound', 'Sim this round', '', '')}</section>`;
    } else if (any) {
      next = `<section class="card"><h3>${stageText()}</h3><p>You are not in this stage. Sim the remaining matches.</p>${btn('simRound', 'Sim next matches', '', 'primary')}</section>`;
    }
    const mini = rows.slice(0, 4).concat(me.pos > 4 ? [me] : []);
    return `<header class="title"><h2>${esc(t.name)}</h2><p class="muted">${esc(t.city)} · Season ${s.season.no} · ${stageText()}</p></header>
      ${next}
      <section class="card"><h3>Table</h3>${tableHtml(mini, true)}${btn('go', 'Full table', 'data-screen="table"', 'link')}</section>
      ${formHtml()}`;
  };

  function ordinal(n) { const s = ['th', 'st', 'nd', 'rd'], v = n % 100; return n + (s[(v - 20) % 10] || s[v] || s[0]); }
  function formHtml() {
    const s = st(), t = userTeam();
    const played = Game.userFixtures(s).filter((f) => f.result);
    if (!played.length) return '';
    const items = played.slice(-5).map((f) => { const r = f.result; const w = r.outcome === 'TIE' ? 'T' : ((r.outcome === 'HOME_WIN') === (f.homeId === t.id) ? 'W' : 'L'); return `<span class="pill pill-${w}">${w}</span>`; });
    return `<section class="card"><h3>Recent form</h3><p class="form">${items.join(' ')}</p>${btn('go', 'All fixtures', 'data-screen="fixtures"', 'link')}</section>`;
  }

  function tableHtml(rows, compact = false) {
    return `<table class="table"><thead><tr><th>#</th><th class="left">Team</th><th>P</th><th>W</th><th>L</th>${compact ? '' : '<th>T</th>'}<th>Pts</th><th>NRR</th></tr></thead><tbody>
      ${rows.map((r) => `<tr class="${isUser(r.teamId) ? 'me' : ''}"><td>${r.pos}</td><td class="left">${compact ? esc(team(r.teamId).abbr) : esc(r.name)}</td><td>${r.p}</td><td>${r.w}</td><td>${r.l}</td>${compact ? '' : `<td>${r.t}</td>`}<td><b>${r.pts}</b></td><td>${nrrText(r.nrr)}</td></tr>`).join('')}</tbody></table>`;
  }

  SCREENS.table = () => {
    const s = st();
    const rows = L.table(s.teams, s.season.fixtures);
    const po = s.season.fixtures.filter((f) => f.stage !== 'league');
    let playoffs = '';
    if (po.length) playoffs = `<section class="card"><h3>Playoffs</h3>${po.map((f) => fixtureRow(f)).join('')}</section>`;
    return `<header class="title"><h2>League table</h2><p class="muted">Season ${s.season.no} · top four make the playoffs</p></header><section class="card">${tableHtml(rows)}</section>${playoffs}`;
  };

  function fixtureRow(f) {
    const mine = f.homeId === st().userTeamId || f.awayId === st().userTeamId;
    const line = f.result ? esc(f.result.resultLine) : '<span class="muted">to play</span>';
    const score = f.result ? `<span class="muted small">${scoreLine(f.result)}</span>` : '';
    const label = f.label ? `<span class="muted small">${esc(f.label)}</span> ` : '';
    const inner = `${label}<b>${esc(team(f.homeId).abbr)}</b> v <b>${esc(team(f.awayId).abbr)}</b><br>${line} ${score}`;
    return f.result ? `<div class="fixture ${mine ? 'mine' : ''}" data-action="viewResult" data-id="${f.id}">${inner}</div>` : `<div class="fixture ${mine ? 'mine' : ''}">${inner}</div>`;
  }
  function scoreLine(r) { return r.innings.map((i) => `${esc(team(i.teamId).abbr)} ${i.total}/${i.wickets}`).join(' · '); }

  SCREENS.fixtures = () => {
    const s = st();
    const rounds = [...new Set(s.season.fixtures.map((f) => f.round))];
    return `<header class="title"><h2>Fixtures</h2><p class="muted">Tap a played match for the scorecard. Yours are marked.</p></header>
      ${rounds.map((r) => { const fs = s.season.fixtures.filter((f) => f.round === r); return `<section class="card"><h3>${fs[0].stage === 'league' ? `Round ${r}` : (fs[0].stage === 'semi' ? 'Semi-finals' : 'Final')}</h3>${fs.map(fixtureRow).join('')}</section>`; }).join('')}`;
  };

  // ---- squad and players ------------------------------------------------
  function statLine(v, which) {
    const s = which === 'career' ? v.career : v.season;
    const bat = s.bat.inns ? `${s.bat.runs} @ ${S.avgText(s)}` : '-';
    const bowl = s.bowl.balls ? `${s.bowl.wkts}w @ ${S.fmt2(S.econ(s))}` : '-';
    return { bat, bowl };
  }
  SCREENS.squad = () => {
    const s = st(), t = userTeam();
    const which = app.view.which || 'season';
    const vs = Game.visibleSquad(s, t.id);
    return `<header class="title"><h2>Squad</h2><p class="muted">${esc(t.name)} · ${vs.length} players. Tap a name.</p></header>
      <div class="toggle">${['season', 'career'].map((w) => `<button class="chip ${which === w ? 'active' : ''}" data-action="squadView" data-which="${w}">${w === 'season' ? `Season ${s.season.no}` : 'Career'}</button>`).join('')}</div>
      <section class="card"><table class="table left-all"><thead><tr><th>Name</th><th>Age</th><th>Role</th><th>Bat</th><th>Bowl</th></tr></thead><tbody>
      ${vs.map((v) => { const l = statLine(v, which); return `<tr data-action="player" data-id="${v.id}"><td>${esc(v.surname)}</td><td>${v.age}</td><td>${roleText(v)}</td><td>${l.bat}</td><td>${l.bowl}</td></tr>`; }).join('')}</tbody></table>
      <p class="muted small">Bat = runs @ average. Bowl = wickets @ economy.</p></section>`;
  };

  SCREENS.player = () => {
    const v = Game.visible(st(), player(app.view.id));
    const t = team(app.view.teamId || st().userTeamId);
    const block = (label, s) => `<h3>${label}</h3><table class="table"><thead><tr><th>M</th><th>I</th><th>NO</th><th>R</th><th>HS</th><th>Avg</th><th>SR</th><th>50s</th></tr></thead><tbody><tr><td>${s.matches}</td><td>${s.bat.inns}</td><td>${s.bat.no}</td><td>${s.bat.runs}</td><td>${S.hsText(s)}</td><td>${S.avgText(s)}</td><td>${S.fmt1(S.batSR(s))}</td><td>${s.bat.fifties}</td></tr></tbody></table>
      <table class="table"><thead><tr><th>O</th><th>R</th><th>W</th><th>Best</th><th>Avg</th><th>Econ</th><th>3w</th></tr></thead><tbody><tr><td>${oversText(s.bowl.balls)}</td><td>${s.bowl.runs}</td><td>${s.bowl.wkts}</td><td>${S.bestText(s)}</td><td>${S.fmt1(S.bowlAvg(s))}</td><td>${S.fmt2(S.econ(s))}</td><td>${s.bowl.threes}</td></tr></tbody></table>`;
    return `<header class="title"><h2>${esc(v.firstName)} ${esc(v.surname)}</h2><p class="muted">${esc(t.name)} · age ${v.age} · ${roleText(v)}</p></header>
      <section class="card">${block(`Season ${st().season.no}`, v.season)}<p class="muted small">Last innings: ${esc(S.last5Text(v.season))}</p></section>
      <section class="card">${block('Career', v.career)}</section>
      ${btn('back', 'Back', '', 'link')}`;
  };

  SCREENS.stats = () => {
    const s = st();
    const all = [];
    for (const t of s.teams) for (const id of t.squadIds) all.push({ id, teamId: t.id, s: S.seasonOf(s.stats, id, s.season.no) });
    const bats = all.filter((x) => x.s.bat.inns).sort((a, b) => b.s.bat.runs - a.s.bat.runs).slice(0, 12);
    const bowls = all.filter((x) => x.s.bowl.balls).sort((a, b) => (b.s.bowl.wkts - a.s.bowl.wkts) || (S.econ(a.s) - S.econ(b.s))).slice(0, 12);
    const row = (x, cells) => `<tr class="${isUser(x.teamId) ? 'me' : ''}" data-action="player" data-id="${x.id}" data-team="${x.teamId}"><td class="left">${esc(surname(x.id))}</td><td>${esc(team(x.teamId).abbr)}</td>${cells}</tr>`;
    return `<header class="title"><h2>League stats</h2><p class="muted">Season ${s.season.no}</p></header>
      <section class="card"><h3>Most runs</h3><table class="table"><thead><tr><th class="left">Name</th><th>Team</th><th>R</th><th>Avg</th><th>SR</th></tr></thead><tbody>${bats.map((x) => row(x, `<td>${x.s.bat.runs}</td><td>${S.avgText(x.s)}</td><td>${S.fmt1(S.batSR(x.s))}</td>`)).join('') || '<tr><td colspan="5" class="muted">No matches yet</td></tr>'}</tbody></table></section>
      <section class="card"><h3>Most wickets</h3><table class="table"><thead><tr><th class="left">Name</th><th>Team</th><th>W</th><th>Avg</th><th>Econ</th></tr></thead><tbody>${bowls.map((x) => row(x, `<td>${x.s.bowl.wkts}</td><td>${S.fmt1(S.bowlAvg(x.s))}</td><td>${S.fmt2(S.econ(x.s))}</td>`)).join('') || '<tr><td colspan="5" class="muted">No matches yet</td></tr>'}</tbody></table></section>`;
  };

  // ---- pick XI ----------------------------------------------------------
  SCREENS.xi = () => {
    const s = st(), t = userTeam();
    const xi = s.userXI;
    const vs = Game.visibleSquad(s, t.id);
    const byId = new Map(vs.map((v) => [v.id, v]));
    const nf = Game.nextUserFixture(s);
    const opp = nf ? team(nf.homeId === t.id ? nf.awayId : nf.homeId) : null;
    const err = Game.validateUserXI(s, xi);
    const rowOf = (v, i) => { const l = statLine(v, 'season'); return `<tr><td>${i + 1}</td><td data-action="player" data-id="${v.id}">${esc(v.surname)} <span class="muted small">${roleText(v)} ${v.age}</span></td><td class="small">${l.bat}</td><td class="small">${l.bowl}</td><td class="ctl">${btn('xiUp', '▲', `data-i="${i}"`, 'mini')}${btn('xiDown', '▼', `data-i="${i}"`, 'mini')}${btn('xiDrop', '✕', `data-id="${v.id}"`, 'mini')}</td></tr>`; };
    const bench = vs.filter((v) => !xi.order.includes(v.id));
    return `<header class="title"><h2>Pick your XI</h2><p class="muted">${nf ? `${esc(nf.label || `Round ${nf.round}`)} v ${esc(opp.name)} (${nf.homeId === t.id ? 'home' : 'away'})` : ''}</p></header>
      <section class="card"><h3>Game plan</h3><div class="toggle">${Object.entries(I.PRESETS).map(([k, p]) => `<button class="chip ${xi.preset === k ? 'active' : ''}" data-action="preset" data-preset="${k}">${p.label}</button>`).join('')}</div><p class="muted small">${esc(I.PRESETS[xi.preset].blurb)}</p></section>
      <section class="card"><h3>Batting order <span class="muted">(${xi.order.length}/11)</span></h3><table class="table left-all xi"><thead><tr><th>#</th><th>Player</th><th>Bat</th><th>Bowl</th><th></th></tr></thead><tbody>${xi.order.map((id, i) => rowOf(byId.get(id), i)).join('')}</tbody></table></section>
      <section class="card"><h3>Bowlers <span class="muted">(${xi.bowlers.length}/5)</span></h3><div class="chips">${xi.order.map((id) => { const v = byId.get(id); const on = xi.bowlers.includes(id); return `<button class="chip ${on ? 'active' : ''}" data-action="toggleBowler" data-id="${id}">${esc(v.surname)} <span class="small">${v.kind === 'PACE' ? 'pace' : 'spin'}</span></button>`; }).join('')}</div><p class="muted small">Five bowlers, four overs each. Pace bowls the powerplay and the death, spin the middle.</p></section>
      <section class="card"><h3>Bench <span class="muted">(${bench.length})</span></h3>${bench.length ? `<table class="table left-all"><tbody>${bench.map((v) => { const l = statLine(v, 'season'); return `<tr><td data-action="player" data-id="${v.id}">${esc(v.surname)} <span class="muted small">${roleText(v)} ${v.age}</span></td><td class="small">${l.bat}</td><td class="small">${l.bowl}</td><td class="ctl">${btn('xiAdd', '＋', `data-id="${v.id}"`, 'mini')}</td></tr>`; }).join('')}</tbody></table>` : '<p class="muted">Everyone is in.</p>'}</section>
      <section class="card sticky-actions">${err ? `<p class="error">${esc(err)}</p>` : ''}${btn('playLive', 'Play live', err ? 'disabled' : '', 'primary')} ${btn('playInstant', 'Sim instantly', err ? 'disabled' : '', '')} ${btn('suggest', 'Suggest XI', '', 'link')} ${btn('go', 'Back', 'data-screen="hub"', 'link')}</section>`;
  };

  // ---- live match ---------------------------------------------------------
  // The timeline is one item per ball plus stop items the replay pauses on:
  // 'decide' (a batter or bowler of YOUR team comes in: stats + instruction),
  // 'break' (innings break, full scorecard) and 'end'. Every item carries inn
  // (which innings is on screen) and shown (how many of its balls are shown).
  function buildTimeline(sim) {
    const s = st(), m = sim.match, tl = [];
    for (const inn of [0, 1]) {
      const r = inn === 0 ? m.innings1 : m.innings2;
      const userBats = r.xi.team.id === s.userTeamId, userBowls = r.bowlingXI.team.id === s.userTeamId;
      if (inn === 1) tl.push({ type: 'break', inn: 0, shown: m.innings1.events.length });
      if (userBats) tl.push({ type: 'decide', inn, shown: 0, kind: 'bat', ids: [r.xi.order[0].id, r.xi.order[1].id], title: 'Your openers' });
      const seen = new Set();
      r.events.forEach((ev, k) => {
        if (userBowls && !seen.has(ev.bowlerId)) { seen.add(ev.bowlerId); tl.push({ type: 'decide', inn, shown: k, kind: 'bowl', ids: [ev.bowlerId], title: k === 0 ? 'Your opening bowler' : 'New bowler' }); }
        tl.push({ type: 'ball', inn, shown: k + 1, ev });
        if (userBats && ev.wicket && ev.nextInId && k + 1 < r.events.length) tl.push({ type: 'decide', inn, shown: k + 1, kind: 'bat', ids: [ev.nextInId], title: 'New batter' });
      });
    }
    tl.push({ type: 'end', inn: 1, shown: m.innings2.events.length });
    return tl;
  }
  function ensureLive() {
    const s = st();
    if (!s.live) return false;
    if (!app.sim || app.sim.fixtureId !== s.live.fixtureId) {
      const sim = Game.liveMatch(s);
      app.sim = { fixtureId: s.live.fixtureId, sim, timeline: buildTimeline(sim) };
    }
    return true;
  }
  const ballMs = () => st().settings.ballMs || 3000;
  function liveCursorNow() {
    const l = st().live, tl = app.sim.timeline;
    if (!l.playing || l.anchorMs === null) return l.cursor;
    const step = ballMs() / (l.speed || 1);
    const c = Math.min(tl.length - 1, l.anchorCursor + Math.floor((Date.now() - l.anchorMs) / step));
    // The clock never runs past a stop item, however long the phone was locked.
    for (let i = l.anchorCursor + 1; i <= c; i++) if (tl[i].type !== 'ball') return i;
    return c;
  }
  function setPlaying(playing) {
    const l = st().live;
    l.cursor = liveCursorNow();
    l.playing = playing;
    l.anchorMs = playing ? Date.now() : null;
    l.anchorCursor = l.cursor;
    saveLive();
  }
  function jumpTo(cursor) {
    const l = st().live;
    l.cursor = Math.min(app.sim.timeline.length - 1, Math.max(0, cursor));
    l.anchorMs = l.playing ? Date.now() : null;
    l.anchorCursor = l.cursor;
    saveLive();
  }
  function tick() {
    if (app.screen !== 'live' || !st().live || !app.sim) return;
    const l = st().live;
    const c = liveCursorNow();
    if (c !== l.cursor) {
      l.cursor = c;
      if (app.sim.timeline[c].type !== 'ball') { l.playing = false; l.anchorMs = null; l.anchorCursor = c; }
      saveLive();
      render();
    }
  }
  function startTicker() { if (!app.timer) app.timer = setInterval(tick, 200); }
  // From a stop item: step past it and play if the next item is a ball.
  function playOn() {
    const tl = app.sim.timeline;
    const c = liveCursorNow();
    if (tl[c].type !== 'ball' && c < tl.length - 1) jumpTo(c + 1);
    setPlaying(tl[st().live.cursor].type === 'ball');
    app.view.tap = null;
    render();
  }

  // Reduce the shown events of one innings into a display state.
  function inningsView(innIdx, shownEvents) {
    const sim = app.sim.sim.match;
    const inn = innIdx === 0 ? sim.innings1 : sim.innings2;
    const all = inn.events;
    const n = shownEvents;
    const bat = new Map(inn.xi.order.map((p, i) => [p.id, { id: p.id, pos: i + 1, runs: 0, balls: 0, fours: 0, sixes: 0, out: false, how: null, bowlerId: null, fielderId: null }]));
    const bowl = new Map();
    const overs = new Map();
    const fall = [];
    let total = 0, wickets = 0, lastWicketBall = 0, lastWicketScore = 0;
    for (let i = 0; i < n; i++) {
      const e = all[i];
      const b = bat.get(e.strikerId); b.balls += 1; b.runs += e.runs;
      if (e.runs === 4) b.fours += 1; else if (e.runs === 6) b.sixes += 1;
      if (e.wicket) { b.out = true; b.how = e.how; b.bowlerId = e.bowlerId; b.fielderId = e.fielderId; wickets += 1; fall.push({ w: wickets, score: total, ball: i + 1, batterId: e.strikerId }); lastWicketBall = i + 1; lastWicketScore = total; }
      total += e.runs;
      const c = bowl.get(e.bowlerId) || { id: e.bowlerId, balls: 0, runs: 0, wkts: 0, dots: 0 };
      c.balls += 1; c.runs += e.runs; if (e.wicket) c.wkts += 1; if (!e.runs) c.dots += 1; bowl.set(e.bowlerId, c);
      const o = overs.get(e.over) || []; o.push(e.wicket ? 'W' : String(e.runs)); overs.set(e.over, o);
    }
    const last = n ? all[n - 1] : null;
    const next = n < all.length ? all[n] : null;
    const balls = n;
    const strikerId = next ? next.strikerId : (last ? (last.wicket ? last.nextInId : last.strikerId) : inn.xi.order[0].id);
    const nonStrikerId = next ? next.nonStrikerId : (last ? last.nonStrikerId : inn.xi.order[1].id);
    const bowlerId = next ? next.bowlerId : (last ? last.bowlerId : null);
    const curOver = next ? next.over : (last ? last.over : 1);
    const done = n >= all.length;
    const partnership = { runs: total - lastWicketScore, balls: balls - lastWicketBall };
    const lastWicket = fall.length ? fall[fall.length - 1] : null;
    const card = { teamId: inn.xi.team.id, total, wickets, balls, target: inn.target, batters: [...bat.values()], bowlers: [...bowl.values()], fall };
    return { inn, total, wickets, balls, bat, bowl, overs, last, next, strikerId, nonStrikerId, bowlerId, curOver, done, partnership, lastWicket, card, target: inn.target, teamId: inn.xi.team.id, bowlingTeamId: inn.bowlingXI.team.id };
  }

  // One player's card for a decision: visible stats, form, and the instruction
  // chips (only for your own players). `from` is the ball the call applies from.
  const BAT_OPTS = [[0, 'Defend', 'Keep the wicket. Fewer boundaries, fewer risks.'], ['', 'Play the plan', 'Follow the game plan for the match state.'], [2, 'Attack', 'Go after the bowling. More runs, more risk.']];
  const BOWL_OPTS = [['contain', 'Contain', 'Bowl tight. Fewer runs, fewer wickets.'], ['', 'Normal', 'Bowl to the plan.'], ['attack', 'Attack', 'Hunt wickets. Goes for runs if it misses.']];
  const insLabel = (kind, val) => { const o = (kind === 'bat' ? BAT_OPTS : BOWL_OPTS).find((x) => String(x[0]) === String(val === null ? '' : val)); return o ? o[1] : ''; };
  function liveCard(id, kind, inn, from, mine) {
    const p = player(id), v = Game.visible(st(), p);
    const cur = Game.instructionFor(st().live.instructions, inn, from, id, kind);
    const rows = (label, x) => (kind === 'bat'
      ? `<tr><td class="left">${label}</td><td>${x.matches}</td><td>${x.bat.inns}</td><td>${x.bat.runs}</td><td>${S.avgText(x)}</td><td>${S.fmt1(S.batSR(x))}</td><td>${S.hsText(x)}</td></tr>`
      : `<tr><td class="left">${label}</td><td>${x.matches}</td><td>${oversText(x.bowl.balls)}</td><td>${x.bowl.wkts}</td><td>${S.fmt2(S.econ(x))}</td><td>${S.fmt1(S.bowlAvg(x))}</td><td>${S.bestText(x)}</td></tr>`);
    const head = kind === 'bat' ? '<th></th><th>M</th><th>I</th><th>R</th><th>Avg</th><th>SR</th><th>HS</th>' : '<th></th><th>M</th><th>O</th><th>W</th><th>Econ</th><th>Avg</th><th>Best</th>';
    const form = kind === 'bat' ? S.last5Text(v.season) : S.last5BowlText(v.season);
    const opts = kind === 'bat' ? BAT_OPTS : BOWL_OPTS;
    const chips = mine ? `<div class="toggle">${opts.map(([val, label]) => `<button class="chip ${String(cur === null ? '' : cur) === String(val) ? 'active' : ''}" data-action="instruct" data-kind="${kind}" data-id="${id}" data-inn="${inn}" data-from="${from}" data-value="${val}">${label}</button>`).join('')}</div><p class="muted small">${esc(opts.find((x) => String(x[0]) === String(cur === null ? '' : cur))[2])}</p>` : '';
    return `<div class="pcard"><div class="pcard-head"><b>${esc(p.firstName)} ${esc(p.surname)}</b> <span class="muted small">${roleText(p)} · age ${p.age}</span></div>
      <table class="table sc"><thead><tr>${head}</tr></thead><tbody>${rows(`Season ${st().season.no}`, v.season)}${rows('Career', v.career)}</tbody></table>
      <p class="small"><span class="muted">Form (last five${kind === 'bat' ? ' innings' : ' spells'}):</span> ${esc(form)}</p>${chips}</div>`;
  }
  // Short stats line for an incoming opposition batter.
  function batterBlurb(id) {
    const v = Game.visible(st(), player(id)), c = v.career;
    return c.bat.inns ? `avg ${S.avgText(c)} · SR ${S.fmt1(S.batSR(c))} · form ${esc(S.last5Text(v.season))}` : 'no innings yet';
  }

  SCREENS.live = () => {
    if (!ensureLive()) return SCREENS.hub();
    startTicker();
    const s = st(), l = s.live, tl = app.sim.timeline, m = app.sim.sim.match;
    const item = tl[l.cursor];
    const f = Game.fixtureById(s, l.fixtureId);
    const innIdx = item.inn;
    const v = inningsView(innIdx, item.shown);
    const batTeam = team(v.teamId), bowlTeam = team(v.bowlingTeamId);
    const userBats = isUser(v.teamId), userBowls = isUser(v.bowlingTeamId);
    const maxBalls = 120;
    const phase = v.balls >= maxBalls ? '' : `<span class="phase">${I.PHASE_NAMES[I.phaseOf(v.curOver)]}</span>`;
    const header = `<div class="score-head"><div class="score-team">${esc(batTeam.name)} <span class="muted small">${userBats ? 'you bat' : userBowls ? 'you bowl' : ''}</span></div><div class="score-big">${v.total}/${v.wickets}</div><div class="score-ov">${oversText(v.balls)} ov · RR ${v.balls ? (6 * v.total / v.balls).toFixed(2) : '0.00'}<br>${phase}</div></div>`;
    let chase = '';
    if (innIdx === 1) {
      const need = v.target - v.total, left = maxBalls - v.balls;
      chase = need > 0 && left > 0 && v.wickets < 10 ? `<div class="chase">Need <b>${need}</b> off <b>${left}</b> · RRR ${(need * 6 / left).toFixed(2)} · ${10 - v.wickets} wkts in hand</div>` : need > 0 ? `<div class="chase">Target ${v.target}</div>` : '';
    } else {
      const proj = v.balls >= 12 && v.balls < maxBalls && v.wickets < 10 ? ` · at this rate ${Math.round(v.total + (maxBalls - v.balls) * v.total / v.balls)}` : '';
      chase = `<div class="chase muted">First innings · ${esc(bowlTeam.abbr)} bowling${proj}</div>`;
    }
    // Batters: the one in longest on top, the striker marked *. Yours are tappable.
    const insTag = (kind, id) => { const val = Game.instructionFor(l.instructions, innIdx, v.balls, id, kind); return val === null ? '' : ` <span class="tag">${esc(insLabel(kind, val))}</span>`; };
    const bline = (b) => {
      const star = b.id === v.strikerId;
      const sr = b.balls ? Math.round(100 * b.runs / b.balls) : 0;
      return `<div class="batter ${star ? 'striker' : ''}" ${userBats ? `data-action="liveTap" data-kind="bat" data-id="${b.id}"` : ''}><span class="bname">${esc(pname(b.id))}${star ? '*' : ''}</span> <b>${b.runs}</b> <span class="muted">(${b.balls})</span> <span class="muted small">SR ${sr}${b.fours || b.sixes ? ` · ${b.fours}×4 ${b.sixes}×6` : ''}</span>${userBats ? insTag('bat', b.id) : ''}</div>`;
    };
    let batters = '';
    if (!v.done && v.wickets < 10) {
      const pair = [v.strikerId, v.nonStrikerId].filter((id) => id !== null && id !== undefined).map((id) => v.bat.get(id)).filter(Boolean).sort((a, b) => a.pos - b.pos);
      batters = `<div class="batters">${pair.map(bline).join('')}<div class="muted small">Partnership ${v.partnership.runs} (${v.partnership.balls})${userBats ? ' · tap a batter to instruct' : ''}</div></div>`;
    }
    const bc = v.bowlerId ? v.bowl.get(v.bowlerId) || { balls: 0, runs: 0, wkts: 0 } : null;
    const bowler = v.bowlerId ? `<div class="bowler" ${userBowls ? `data-action="liveTap" data-kind="bowl" data-id="${v.bowlerId}"` : ''}><span class="muted">Bowling:</span> ${esc(pname(v.bowlerId))} <span class="muted small">${player(v.bowlerId).kind === 'PACE' ? 'pace' : 'spin'}</span> · <b>${oversText(bc.balls)}-${bc.runs}-${bc.wkts}</b>${bc.balls ? ` <span class="muted small">econ ${(6 * bc.runs / bc.balls).toFixed(1)}</span>` : ''}${userBowls ? insTag('bowl', v.bowlerId) : ''}</div>` : '';
    const thisOver = (v.overs.get(v.curOver) || []);
    const overStr = `<div class="this-over"><span class="muted">Over ${v.curOver}:</span> ${thisOver.length ? thisOver.map((x) => `<span class="ball b-${x}">${x}</span>`).join('') : '<span class="muted">—</span>'}</div>`;
    const prev = [...v.overs.keys()].filter((o) => o < v.curOver).slice(-4).reverse().map((o) => { const arr = v.overs.get(o); return `<div class="prev-over small"><span class="muted">${o}</span> ${arr.join(' ')} <span class="muted">(${arr.reduce((a, x) => a + (x === 'W' ? 0 : Number(x)), 0)})</span></div>`; }).join('');
    let event = '';
    if (v.last) {
      if (v.last.wicket) {
        const b = v.bat.get(v.last.strikerId);
        const nextIn = v.last.nextInId && !v.done ? `<br><span class="small">Next in: ${esc(pname(v.last.nextInId))} · ${batterBlurb(v.last.nextInId)}</span>` : '';
        event = `<div class="event wicket">WICKET · ${esc(pname(v.last.strikerId))} ${esc(dismissalText(b))} · ${b.runs} (${b.balls})${nextIn}</div>`;
      } else if (v.last.runs === 6) event = `<div class="event six">SIX · ${esc(pname(v.last.strikerId))}</div>`;
      else if (v.last.runs === 4) event = `<div class="event four">FOUR · ${esc(pname(v.last.strikerId))}</div>`;
    }
    const lastWkt = v.lastWicket && !(v.last && v.last.wicket) ? `<div class="muted small">Last wicket: ${esc(pname(v.lastWicket.batterId))} ${v.bat.get(v.lastWicket.batterId).runs} (${v.bat.get(v.lastWicket.batterId).balls}) · ${v.lastWicket.score}/${v.lastWicket.w} in ${oversText(v.lastWicket.ball)} ov</div>` : '';
    // Decision card (a stop item) or a tapped player.
    let decide = '';
    if (item.type === 'decide') {
      const mine = item.kind === 'bat' ? userBats : userBowls;
      decide = `<div class="decide"><h3>${esc(item.title)}</h3>${item.ids.map((id) => liveCard(id, item.kind, innIdx, item.shown, mine)).join('')}${btn('livePlay', 'Play on', '', 'primary wide')}</div>`;
    } else if (app.view.tap && item.type === 'ball') {
      const t = app.view.tap;
      decide = `<div class="decide"><h3>${t.kind === 'bat' ? 'Batter' : 'Bowler'} instruction <span class="muted small">from now</span></h3>${liveCard(t.id, t.kind, innIdx, v.balls, t.kind === 'bat' ? userBats : userBowls)}${btn('liveTapClose', 'Done', '', 'wide')}</div>`;
    }
    let banner = '';
    if (item.type === 'break') banner = `<div class="banner">Innings break · ${esc(batTeam.name)} ${v.total}/${v.wickets}. ${esc(team(m.innings2.xi.team.id).name)} need ${v.total + 1}.<br>${btn('livePlay', 'Start the chase', '', 'primary')}</div><details open><summary>First innings scorecard</summary>${inningsCardHtml(app.sim.sim.summary.innings[0])}</details>`;
    if (item.type === 'end') banner = `<div class="banner result"><b>${esc(m.resultLine())}</b><br>${btn('liveFinish', 'Scorecard', '', 'primary')}</div>`;
    const speedBtns = SPEEDS.map((x) => `<button class="chip ${l.speed === x ? 'active' : ''}" data-action="liveSpeed" data-speed="${x}">${x}×</button>`).join('');
    const playLabel = item.type === 'ball' ? (l.playing ? 'Pause' : 'Play') : 'Play on';
    const controls = item.type === 'end' ? '' : `<div class="controls">${item.type === 'decide' || item.type === 'break' ? '' : btn('livePlay', playLabel, '', 'primary wide')}<div class="toggle">${speedBtns}</div><div class="row">${btn('liveSkip', 'Over ▸', 'data-what="over"', 'small')}${btn('liveSkip', 'Innings ▸▸', 'data-what="innings"', 'small')}${btn('liveSkip', 'End ⏭', 'data-what="end"', 'small')}</div></div>`;
    const soFar = item.type === 'break' ? '' : `<details><summary>Scorecard so far</summary>${innIdx === 1 ? `<h3 class="muted small">First innings</h3>${inningsCardHtml(app.sim.sim.summary.innings[0])}` : ''}${inningsCardHtml(v.card)}</details>`;
    return `<header class="title live-title"><h2>${esc(team(f.homeId).abbr)} v ${esc(team(f.awayId).abbr)}</h2><p class="muted small">${esc(f.label || `Round ${f.round}`)} · ${ballMs() / 1000}s a ball at 1× · ${innIdx === 1 ? `${esc(team(m.innings1.xi.team.id).abbr)} made ${m.innings1.total}/${m.innings1.wickets}` : 'first innings'}</p></header>
      <section class="card live">${header}${chase}${batters}${bowler}${overStr}${event}${lastWkt}${decide}${banner}${controls}${prev}${soFar}</section>
      <p class="muted small center">The phone clock keeps the match moving even if the screen locks. Your batters and bowlers stop the clock when they come in.</p>`;
  };

  // ---- scorecard --------------------------------------------------------
  // One innings card from a stored-result shape (also built live from the replay).
  function inningsCardHtml(i) {
    const t = team(i.teamId);
    const dnb = i.batters.filter((b) => !b.balls && !b.out);
    return `<h3>${esc(t.name)} <span class="score-inline">${i.total}/${i.wickets} (${oversText(i.balls)} ov)</span>${i.target ? `<span class="muted small"> target ${i.target}</span>` : ''}</h3>
      <table class="table left-all sc"><tbody>${i.batters.filter((b) => b.balls || b.out).map((b) => `<tr><td>${esc(surname(b.id))}</td><td class="num">${b.runs}${b.out ? '' : '*'}</td><td class="num muted">(${b.balls})</td><td class="muted small">${esc(dismissalText(b))}</td></tr>`).join('')}</tbody></table>
      ${dnb.length ? `<p class="muted small">Did not bat: ${dnb.map((b) => esc(surname(b.id))).join(', ')}</p>` : ''}
      ${i.fall.length ? `<p class="muted small">Fall: ${i.fall.map((f) => `${f.w}-${f.score}`).join(', ')}</p>` : ''}
      ${i.bowlers.length ? `<table class="table sc"><thead><tr><th class="left">Bowling</th><th>O</th><th>R</th><th>W</th><th>Econ</th></tr></thead><tbody>${i.bowlers.map((c) => `<tr><td class="left">${esc(surname(c.id))}</td><td>${oversText(c.balls)}</td><td>${c.runs}</td><td>${c.wkts}</td><td>${c.balls ? (6 * c.runs / c.balls).toFixed(2) : '-'}</td></tr>`).join('')}</tbody></table>` : ''}`;
  }
  function scorecardHtml(r) {
    return `<section class="card"><p class="result-line"><b>${esc(r.resultLine)}</b></p><p class="muted small">Toss: ${esc(team(r.homeBatsFirst ? r.homeId : r.awayId).name)}, batted first</p></section><section class="card">${inningsCardHtml(r.innings[0])}</section><section class="card">${inningsCardHtml(r.innings[1])}</section>`;
  }
  SCREENS.scorecard = () => {
    const f = Game.fixtureById(st(), app.view.fixtureId);
    if (!f || !f.result) return SCREENS.hub();
    return `<header class="title"><h2>${esc(team(f.homeId).name)} v ${esc(team(f.awayId).name)}</h2><p class="muted">${esc(f.label || `Round ${f.round}`)} · Season ${st().season.no}</p></header>${scorecardHtml(f.result)}${btn('back', 'Back', '', 'link')}`;
  };

  // ---- more ---------------------------------------------------------------
  SCREENS.more = () => {
    const s = st();
    const bm = s.settings.ballMs;
    return `<header class="title"><h2>More</h2></header>
      <section class="card"><h3>Ball speed</h3><div class="toggle">${[2000, 3000, 4000].map((ms) => `<button class="chip ${bm === ms ? 'active' : ''}" data-action="ballMs" data-ms="${ms}">${ms / 1000}s</button>`).join('')}</div><p class="muted small">Seconds per ball at 1× in a live match.</p></section>
      ${cloudCardHtml()}
      <section class="card"><h3>Save text</h3><p class="muted small">The save also lives in this browser. Copy the text somewhere safe now and then, or paste one back in.</p>${btn('exportSave', 'Show save text', '', '')}${app.view.export ? `<textarea id="exportBox" class="savebox" readonly>${esc(app.view.export)}</textarea>${btn('copySave', 'Copy to clipboard', '', 'primary')}` : ''}
      <details><summary>Import a save</summary><textarea id="importBox" class="savebox" placeholder="Paste save text here"></textarea>${btn('importSave', 'Load this save (replaces current)', '', 'danger')}</details></section>
      <section class="card"><h3>Season shortcuts</h3>${btn('simSeason', 'Sim to the end of the season', '', 'danger')}<p class="muted small">Plays every remaining match instantly with your current XI.</p></section>
      <section class="card"><h3>League</h3><p class="muted small">Seed ${esc(s.seed)} · save v${s.version} · ${esc(window.CRICKET_BUILD || 'dev')}</p>${btn('go', 'New league', 'data-screen="home"', 'link')}</section>`;
  };

  // ---- actions ----------------------------------------------------------
  const A = {};
  A.go = (d) => go(d.screen);
  A.back = () => { if (app.view.back) go(app.view.back.screen, app.view.back.view); else go('hub'); };
  A.newLeague = () => {
    const el = document.getElementById('seed');
    const raw = (el && el.value.trim()) || String(Math.floor(Math.random() * 1e6));
    const seed = /^\d+$/.test(raw) ? Number(raw) >>> 0 : raw;
    if (st() && st().userTeamId && !confirm(`Start a new league? Your current save will be replaced${cloudLinked() ? ', in the cloud too' : ''}.`)) return;
    app.state = Game.newLeague(seed); app.sim = null;
    localStorage.removeItem(LIVE_KEY);
    save(); go('pick');
  };
  A.chooseTeam = (d) => { Game.chooseTeam(st(), Number(d.id)); save(); go('hub'); };
  A.nextSeason = () => { Game.nextSeason(st()); st().userXI = Game.suggestXI(st(), st().userTeamId); app.sim = null; save(); go('hub'); };
  A.simRound = () => {
    const s = st();
    const err = Game.validateUserXI(s, s.userXI); if (err) { app.flash = err; go('xi'); return; }
    const f = Game.nextUserFixture(s);
    Game.playRound(s); save();
    if (f && f.result) go('scorecard', { fixtureId: f.id, back: { screen: 'hub' } }); else go('hub');
  };
  A.simSeason = () => {
    const s = st();
    const err = Game.validateUserXI(s, s.userXI); if (err) { app.flash = err; go('xi'); return; }
    if (!confirm('Sim every remaining match of the season instantly?')) return;
    Game.simToEndOfSeason(s); save(); go('hub');
  };
  A.viewResult = (d) => go('scorecard', { fixtureId: Number(d.id), back: { screen: app.screen, view: app.view } });
  A.player = (d, el) => { const teamId = d.team ? Number(d.team) : (team(st().userTeamId).squadIds.includes(Number(d.id)) ? st().userTeamId : st().teams.find((t) => t.squadIds.includes(Number(d.id))).id); go('player', { id: Number(d.id), teamId, back: { screen: app.screen, view: app.view } }); };
  A.squadView = (d) => go('squad', { which: d.which });
  A.ballMs = (d) => { st().settings.ballMs = Number(d.ms); if (st().live) { setPlaying(st().live.playing); } save(); render(); };
  // XI editing
  const xi = () => st().userXI;
  A.preset = (d) => { xi().preset = d.preset; save(); render(); };
  A.xiUp = (d) => { const i = Number(d.i); if (i > 0) { const o = xi().order; [o[i - 1], o[i]] = [o[i], o[i - 1]]; save(); keepScroll(); render(); } };
  A.xiDown = (d) => { const i = Number(d.i); const o = xi().order; if (i < o.length - 1) { [o[i + 1], o[i]] = [o[i], o[i + 1]]; save(); keepScroll(); render(); } };
  A.xiDrop = (d) => { const id = Number(d.id); xi().order = xi().order.filter((x) => x !== id); xi().bowlers = xi().bowlers.filter((x) => x !== id); save(); keepScroll(); render(); };
  A.xiAdd = (d) => { const id = Number(d.id); if (xi().order.length >= 11) { app.flash = 'Drop someone first: an XI is eleven.'; } else xi().order.push(id); save(); keepScroll(); render(); };
  A.toggleBowler = (d) => { const id = Number(d.id); const b = xi().bowlers; if (b.includes(id)) xi().bowlers = b.filter((x) => x !== id); else if (b.length >= 5) app.flash = 'Five bowlers only. Untick one first.'; else b.push(id); save(); keepScroll(); render(); };
  A.suggest = () => { st().userXI = Game.suggestXI(st(), st().userTeamId); save(); render(); };
  function keepScroll() { app.view.scrollY = window.scrollY; }
  A.playLive = () => {
    const s = st(); const f = Game.nextUserFixture(s); if (!f) return;
    try { Game.startLive(s, f); } catch (e) { app.flash = e.message; render(); return; }
    app.sim = null; save(); saveLive();
    ensureLive(); setPlaying(false); go('live');
  };
  A.playInstant = () => {
    const s = st(); const f = Game.nextUserFixture(s); if (!f) return;
    const err = Game.validateUserXI(s, s.userXI); if (err) { app.flash = err; render(); return; }
    Game.playOthersInRound(s, f); Game.playFixture(s, f); save();
    go('scorecard', { fixtureId: f.id, back: { screen: 'hub' } });
  };
  A.livePlay = () => { const l = st().live; const item = app.sim.timeline[liveCursorNow()]; if (item.type !== 'ball') playOn(); else { setPlaying(!l.playing); render(); } };
  A.liveTap = (d) => { const t = app.view.tap; app.view.tap = t && t.id === Number(d.id) && t.kind === d.kind ? null : { kind: d.kind, id: Number(d.id) }; if (app.view.tap) setPlaying(false); keepScroll(); render(); };
  A.liveTapClose = () => { app.view.tap = null; keepScroll(); render(); };
  A.instruct = (d) => {
    const l = st().live; const c = liveCursorNow();
    const value = d.value === '' ? null : (d.kind === 'bat' ? Number(d.value) : d.value);
    Game.instruct(st(), { inn: Number(d.inn), from: Number(d.from), playerId: Number(d.id), kind: d.kind, value });
    // Re-simulate: everything up to the cursor is unchanged, so the cursor stays.
    app.sim = null; ensureLive();
    l.cursor = Math.min(c, app.sim.timeline.length - 1); l.anchorCursor = l.cursor; if (l.playing) l.anchorMs = Date.now();
    if (app.sim.timeline[l.cursor].type !== 'ball') { l.playing = false; l.anchorMs = null; }
    save(); saveLive(); keepScroll(); render();
  };
  A.liveSpeed = (d) => { const l = st().live; l.cursor = liveCursorNow(); l.speed = Number(d.speed); l.anchorMs = l.playing ? Date.now() : null; l.anchorCursor = l.cursor; saveLive(); render(); };
  A.liveSkip = (d) => {
    const l = st().live, tl = app.sim.timeline; const c = liveCursorNow(); const item = tl[c];
    let target = c;
    if (d.what === 'end') target = tl.length - 1;
    else if (d.what === 'innings') { target = c; if (item.type === 'break') target++; while (target < tl.length - 1 && tl[target].type !== 'break' && tl[target].type !== 'end') target++; }
    else { // over: to the end of this over, or the next stop item if one comes first
      if (item.type === 'end') return;
      if (item.type !== 'ball') { target = c + 1; }
      const first = tl[target];
      if (first.type === 'ball') {
        const o = first.ev.over, inn = first.inn;
        while (target + 1 < tl.length && tl[target + 1].type === 'ball' && tl[target + 1].inn === inn && tl[target + 1].ev.over === o) target++;
        if (tl[target + 1] && tl[target + 1].type !== 'ball') target++;
      }
    }
    jumpTo(target);
    if (tl[target].type !== 'ball') { l.playing = false; l.anchorMs = null; }
    app.view.tap = null;
    render();
  };
  A.liveFinish = () => { const s = st(); const f = Game.finishLive(s, app.sim.sim); app.sim = null; save(); saveLive(); go('scorecard', { fixtureId: f.id, back: { screen: 'hub' } }); };
  // ---- cloud save (Supabase) --------------------------------------------
  // Settings per device in localStorage: url + anon key (or the build's
  // config.js) and the sync code. The save is pushed a moment after every
  // local save and pulled when the app opens or comes back to the front.
  // The later savedAt wins; the cloud row's rev catches stale overwrites.
  const cloud = { cfg: null, client: null, status: 'off', lastSync: null, lastError: '', timer: null, due: 0, busy: false, again: false, lastPull: 0 };
  function cloudLoad() {
    let saved = {};
    try { saved = JSON.parse(localStorage.getItem(CLOUD_KEY) || '{}') || {}; } catch (e) { saved = {}; }
    const def = (C.config && C.config.cloud) || {};
    cloud.cfg = { url: saved.url || def.url || '', anonKey: saved.anonKey || def.anonKey || '', code: saved.code || '', key: saved.key || '', lastSync: saved.lastSync || null };
    cloud.lastSync = cloud.cfg.lastSync;
    cloud.client = null;
    if (cloud.cfg.url && cloud.cfg.anonKey && cloud.cfg.key) { try { cloud.client = Cloud.makeClient(cloud.cfg); cloud.status = 'idle'; } catch (e) { cloud.status = 'off'; } } else cloud.status = 'off';
  }
  function cloudStore() { try { localStorage.setItem(CLOUD_KEY, JSON.stringify({ url: cloud.cfg.url, anonKey: cloud.cfg.anonKey, code: cloud.cfg.code, key: cloud.cfg.key, lastSync: cloud.lastSync })); } catch (e) { /* ignore */ } }
  const cloudLinked = () => !!cloud.client;
  const configBaked = () => !!(C.config && C.config.cloud && C.config.cloud.url && C.config.cloud.anonKey);
  function cloudRender() { if (app.screen === 'more') { snapshotInputs(); render(); } }
  function snapshotInputs() {
    for (const [id, k] of [['cloudUrl', 'cloudUrl'], ['cloudKey', 'cloudKey'], ['cloudCode', 'cloudCode']]) { const el = document.getElementById(id); if (el) app.view[k] = el.value; }
  }
  function cloudFail(e) { cloud.status = 'error'; cloud.lastError = e && e.message ? e.message : String(e); console.warn('cloud', e); cloudRender(); }
  function scheduleCloudPush(ms) {
    if (!cloudLinked() || !app.state) return;
    const due = Date.now() + ms;
    if (cloud.timer && cloud.due <= due) return;
    if (cloud.timer) clearTimeout(cloud.timer);
    cloud.due = due;
    cloud.timer = setTimeout(() => { cloud.timer = null; cloudPush(); }, ms);
  }
  async function cloudPush() {
    if (!cloudLinked() || !app.state) return;
    if (cloud.busy) { cloud.again = true; return; }
    cloud.busy = true; cloud.status = 'syncing'; cloudRender();
    try {
      const s = st();
      const r = await cloud.client.put(cloud.cfg.key, s, s.meta.rev || null);
      if (r.conflict) {
        if (Cloud.newer(s.meta, r.data) === 'remote') { adoptRemote(r.data, r.rev, 'Loaded a newer save from the cloud.'); return; }
        const r2 = await cloud.client.put(cloud.cfg.key, s, r.rev);
        if (r2.conflict) throw new Error('cloud keeps changing under us; try again');
        s.meta.rev = r2.rev;
      } else s.meta.rev = r.rev;
      persistLocal();
      cloud.status = 'idle'; cloud.lastError = ''; cloud.lastSync = new Date().toISOString(); cloudStore(); cloudRender();
    } catch (e) { cloudFail(e); }
    finally { cloud.busy = false; if (cloud.again) { cloud.again = false; scheduleCloudPush(500); } }
  }
  async function cloudPull(why) {
    if (!cloudLinked()) return;
    cloud.lastPull = Date.now();
    cloud.status = 'syncing'; cloudRender();
    try {
      const r = await cloud.client.get(cloud.cfg.key);
      if (!r) { if (app.state) await cloudPush(); else { cloud.status = 'idle'; cloudRender(); } return; }
      if (!app.state || Cloud.newer(st().meta, r.data) === 'remote') { adoptRemote(r.data, r.rev, why || 'Loaded your save from the cloud.'); return; }
      st().meta.rev = r.rev; persistLocal();
      if ((st().meta.savedAt || '') > ((r.data.meta && r.data.meta.savedAt) || '')) await cloudPush();
      else { cloud.status = 'idle'; cloud.lastError = ''; cloud.lastSync = new Date().toISOString(); cloudStore(); cloudRender(); }
    } catch (e) { cloudFail(e); }
  }
  function adoptRemote(data, rev, why, opts = {}) {
    let s;
    try { s = Game.migrate(JSON.parse(JSON.stringify(data))); } catch (e) { cloudFail(new Error('cloud save is unreadable: ' + e.message)); return; }
    s.meta.rev = rev;
    app.state = s; app.sim = null;
    if (s.live) { ensureLive(); const l = s.live; l.cursor = liveCursorNow(); l.playing = false; l.anchorMs = null; l.anchorCursor = l.cursor; }
    persistLocal(); saveLive();
    cloud.status = 'idle'; cloud.lastError = ''; cloud.lastSync = new Date().toISOString(); cloudStore();
    app.flash = why;
    if (s.live) go('live'); else if (!s.userTeamId) go('pick'); else if (opts.home || app.screen === 'live' || app.screen === 'home') go('hub'); else { if (app.screen === 'more') snapshotInputs(); render(); }
  }
  function describeSave(d) {
    try { const t = d.teams.find((x) => x.id === d.userTeamId); return `${t ? t.name : 'no club yet'}, season ${d.season ? d.season.no : '-'}, saved ${d.meta && d.meta.savedAt ? new Date(d.meta.savedAt).toLocaleString() : 'unknown'}`; } catch (e) { return 'unknown'; }
  }
  function cloudCardHtml() {
    const cfg = cloud.cfg;
    const fmtT = (iso) => (iso ? new Date(iso).toLocaleTimeString() : 'never');
    let status = '';
    if (cloudLinked()) {
      const code = app.view.showCode ? cfg.code : cfg.code.replace(/[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}/, '····-····-····');
      const line = cloud.status === 'error' ? `<span class="error">Problem: ${esc(cloud.lastError)}</span>` : cloud.status === 'syncing' ? 'Syncing…' : `Synced ${fmtT(cloud.lastSync)}${st() && st().meta.rev ? ` · rev ${st().meta.rev}` : ''}`;
      status = `<p>Linked with code <b class="mono">${esc(code)}</b> ${btn('cloudShowCode', app.view.showCode ? 'Hide' : 'Show', '', 'mini')} ${btn('cloudCopyCode', 'Copy', '', 'mini')}</p><p class="small">${line}</p>
        <p class="muted small">Type the same code into the game on your other device and it plays the same career. Anyone with the code can read and overwrite it, so keep it to yourself.</p>
        ${btn('cloudSyncNow', 'Sync now', '', '')} ${btn('cloudUnlink', 'Unlink this device', '', 'link')}`;
    } else {
      const setup = configBaked() ? '' : `<label>Project URL <input id="cloudUrl" type="text" autocapitalize="off" autocorrect="off" placeholder="https://xxxx.supabase.co" value="${esc(app.view.cloudUrl ?? cfg.url)}"></label>
        <label>Anon key <input id="cloudKey" type="text" autocapitalize="off" autocorrect="off" placeholder="eyJ…" value="${esc(app.view.cloudKey ?? cfg.anonKey)}"></label>
        <p class="muted small">Both from Supabase → Project settings → API. Run <code>web/supabase/schema.sql</code> in the SQL editor once. Or commit them in <code>web/src/config.js</code> so every device has them.</p>`;
      status = `${setup}<label>Sync code <input id="cloudCode" type="text" autocapitalize="off" autocorrect="off" placeholder="abcd-efgh-jkmn-pqrs" value="${esc(app.view.cloudCode ?? cfg.code)}"></label>
        <p class="muted small">First device: make a new code. Other devices: type that code.</p>
        ${btn('cloudGenCode', 'New code', '', '')} ${btn('cloudLink', 'Link this device', '', 'primary')}
        ${cloud.status === 'error' ? `<p class="error small">${esc(cloud.lastError)}</p>` : ''}`;
    }
    return `<section class="card"><h3>Cloud save</h3><p class="muted small">Play the same career on the phone and on the web. The save goes to your Supabase project after every change and comes back when you open the game elsewhere; the later save wins.</p>${status}</section>`;
  }
  A.cloudGenCode = () => { snapshotInputs(); app.view.cloudCode = Cloud.genCode(); render(); };
  A.cloudShowCode = () => { app.view.showCode = !app.view.showCode; render(); };
  A.cloudCopyCode = async () => { try { await navigator.clipboard.writeText(cloud.cfg.code); app.flash = 'Code copied.'; } catch (e) { app.flash = cloud.cfg.code; } render(); };
  A.cloudLink = async () => {
    snapshotInputs();
    const url = (configBaked() ? C.config.cloud.url : (app.view.cloudUrl || '')).trim();
    const anonKey = (configBaked() ? C.config.cloud.anonKey : (app.view.cloudKey || '')).trim();
    const code = Cloud.normCode(app.view.cloudCode || '');
    if (!/^https?:\/\//.test(url)) { app.flash = 'Enter the project URL (starts with https://).'; render(); return; }
    if (!anonKey) { app.flash = 'Enter the anon key.'; render(); return; }
    if (code.replace(/-/g, '').length < 12) { app.flash = 'A sync code is at least 12 characters. Tap New code to make one.'; render(); return; }
    let key;
    try { key = await Cloud.hashCode(code); } catch (e) { app.flash = e.message; render(); return; }
    cloud.cfg = { url, anonKey, code, key, lastSync: null };
    try { cloud.client = Cloud.makeClient(cloud.cfg); } catch (e) { cloud.client = null; app.flash = e.message; render(); return; }
    cloud.status = 'syncing'; cloud.lastError = ''; cloudStore(); render();
    try {
      const r = await cloud.client.get(key);
      if (!r) { if (app.state) await cloudPush(); else { cloud.status = 'idle'; cloudStore(); render(); } app.flash = app.state ? 'Linked. Your save is in the cloud.' : 'Linked. Nothing in the cloud yet: create a league.'; render(); return; }
      if (!app.state) { adoptRemote(r.data, r.rev, 'Linked. Loaded your save from the cloud.', { home: true }); return; }
      const same = r.data.seed === st().seed && r.data.meta && r.data.meta.savedAt === st().meta.savedAt;
      if (same) { st().meta.rev = r.rev; persistLocal(); cloud.status = 'idle'; cloud.lastSync = new Date().toISOString(); cloudStore(); app.flash = 'Linked. Already in sync.'; render(); return; }
      if (confirm(`The cloud already has a save: ${describeSave(r.data)}.\n\nOK loads it onto this device (replacing this device's save). Cancel keeps this device's save and overwrites the cloud.`)) adoptRemote(r.data, r.rev, 'Linked. Loaded your save from the cloud.', { home: true });
      else { st().meta.rev = r.rev; save(); await cloudPush(); app.flash = 'Linked. This device\'s save is now in the cloud.'; render(); }
    } catch (e) { cloudFail(e); }
  };
  A.cloudUnlink = () => { cloud.client = null; cloud.status = 'off'; cloud.cfg.code = ''; cloud.cfg.key = ''; cloudStore(); app.view.cloudCode = ''; app.flash = 'Unlinked. The save stays in the cloud and on this device.'; render(); };
  A.cloudSyncNow = () => { if (cloud.timer) { clearTimeout(cloud.timer); cloud.timer = null; } cloudPull('Loaded a newer save from the cloud.'); };
  A.exportSave = () => { app.view.export = Game.serialize(st()); render(); };
  A.copySave = async () => {
    const box = document.getElementById('exportBox'); if (!box) return;
    try { await navigator.clipboard.writeText(box.value); app.flash = 'Copied.'; } catch (e) { box.focus(); box.select(); app.flash = 'Select the text and copy it by hand.'; }
    render();
  };
  A.importSave = () => {
    const box = document.getElementById('importBox'); if (!box || !box.value.trim()) { app.flash = 'Paste a save first.'; render(); return; }
    try { const s = Game.deserialize(box.value.trim()); if (!confirm(`Replace your current league with this save${cloudLinked() ? ' (in the cloud too)' : ''}?`)) return; app.state = s; app.sim = null; localStorage.removeItem(LIVE_KEY); save(); go('hub'); }
    catch (e) { app.flash = `That is not a valid save: ${e.message}`; render(); }
  };

  root.addEventListener('click', (e) => {
    const el = e.target.closest('[data-action]');
    if (!el || el.disabled) return;
    const fn = A[el.dataset.action];
    if (fn) { e.preventDefault(); fn(el.dataset, el); }
  });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { if (cloud.timer) { clearTimeout(cloud.timer); cloud.timer = null; cloudPush(); } return; }
    tick();
    if (cloudLinked() && Date.now() - cloud.lastPull > 20000) cloudPull('Loaded a newer save from the cloud.');
  });
  window.addEventListener('pageshow', () => tick());

  // ---- boot -------------------------------------------------------------
  app.state = load();
  // A match that was playing when the app closed catches up to the clock, then waits.
  if (app.state && app.state.live) { loadLive(); ensureLive(); const l = app.state.live; l.cursor = liveCursorNow(); l.playing = false; l.anchorMs = null; l.anchorCursor = l.cursor; }
  if (app.state && app.state.live) go('live');
  else if (app.state && app.state.userTeamId) go('hub');
  else if (app.state) go('pick');
  else go('home');
  cloudLoad();
  if (cloudLinked()) cloudPull('Loaded a newer save from the cloud.');

  // Test hook.
  window.CricketApp = { app, actions: A, go, render, Game, cloud, cloudPull, cloudPush, get state() { return app.state; } };
})();
