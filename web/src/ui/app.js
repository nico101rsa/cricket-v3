// The phone UI: one scrolling document, screens rendered from the game
// state, event delegation via data-action attributes. No framework.
(function () {
  'use strict';
  const C = globalThis.Cricket;
  const Game = C.game, S = C.stats, L = C.league, I = C.intent, Inn = C.innings;
  const KEY = 'cricket-v3-save', LIVE_KEY = 'cricket-v3-live';
  const SPEEDS = [1, 3, 10];

  const app = { state: null, screen: 'home', view: {}, sim: null, timeline: null, timer: null, flash: '' };

  // ---- persistence ------------------------------------------------------
  function load() {
    try { const t = localStorage.getItem(KEY); return t ? Game.deserialize(t) : null; } catch (e) { console.warn('load failed', e); return null; }
  }
  function save() {
    try { if (app.state) localStorage.setItem(KEY, Game.serialize(app.state)); } catch (e) { console.warn('save failed', e); app.flash = 'Could not save (storage full or blocked).'; }
  }
  function saveLive() {
    try { if (app.state && app.state.live) localStorage.setItem(LIVE_KEY, JSON.stringify(app.state.live)); else localStorage.removeItem(LIVE_KEY); } catch (e) { /* ignore */ }
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
  function buildTimeline(sim) {
    const tl = [];
    sim.match.innings1.events.forEach((ev) => tl.push({ type: 'ball', inn: 0, ev }));
    tl.push({ type: 'break' });
    sim.match.innings2.events.forEach((ev) => tl.push({ type: 'ball', inn: 1, ev }));
    tl.push({ type: 'end' });
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
    const l = st().live;
    if (!l.playing || l.anchorMs === null) return l.cursor;
    const step = ballMs() / (l.speed || 1);
    return Math.min(app.sim.timeline.length - 1, l.anchorCursor + Math.floor((Date.now() - l.anchorMs) / step));
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
      const item = app.sim.timeline[c];
      if (item.type === 'break' || item.type === 'end') { l.playing = false; l.anchorMs = null; l.anchorCursor = c; }
      saveLive();
      render();
    }
  }
  function startTicker() { if (!app.timer) app.timer = setInterval(tick, 200); }

  // Reduce the shown events of one innings into a display state.
  function inningsView(innIdx, shownEvents) {
    const sim = app.sim.sim.match;
    const inn = innIdx === 0 ? sim.innings1 : sim.innings2;
    const all = inn.events;
    const n = shownEvents;
    const bat = new Map(inn.xi.order.map((p, i) => [p.id, { id: p.id, pos: i + 1, runs: 0, balls: 0, out: false, how: null, bowlerId: null, fielderId: null }]));
    const bowl = new Map();
    const overs = new Map();
    let total = 0, wickets = 0;
    for (let i = 0; i < n; i++) {
      const e = all[i];
      const b = bat.get(e.strikerId); b.balls += 1; b.runs += e.runs;
      if (e.wicket) { b.out = true; b.how = e.how; b.bowlerId = e.bowlerId; b.fielderId = e.fielderId; wickets += 1; }
      total += e.runs;
      const c = bowl.get(e.bowlerId) || { id: e.bowlerId, balls: 0, runs: 0, wkts: 0 };
      c.balls += 1; c.runs += e.runs; if (e.wicket) c.wkts += 1; bowl.set(e.bowlerId, c);
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
    return { inn, total, wickets, balls, bat, bowl, overs, last, next, strikerId, nonStrikerId, bowlerId, curOver, done, target: inn.target, teamId: inn.xi.team.id, bowlingTeamId: inn.bowlingXI.team.id };
  }

  SCREENS.live = () => {
    if (!ensureLive()) return SCREENS.hub();
    startTicker();
    const s = st(), l = s.live;
    const tl = app.sim.timeline;
    const cursor = l.cursor;
    const item = tl[cursor];
    const f = Game.fixtureById(s, l.fixtureId);
    const m = app.sim.sim.match;
    // Which innings is on screen and how many of its events are shown.
    let innIdx, shown;
    if (item.type === 'ball') { innIdx = item.inn; shown = cursor - (innIdx ? m.innings1.events.length + 1 : 0) + 1; }
    else if (item.type === 'break') { innIdx = 0; shown = m.innings1.events.length; }
    else { innIdx = 1; shown = m.innings2.events.length; }
    const v = inningsView(innIdx, shown);
    const batTeam = team(v.teamId), bowlTeam = team(v.bowlingTeamId);
    const header = `<div class="score-head"><div class="score-team">${esc(batTeam.name)}</div><div class="score-big">${v.total}/${v.wickets}</div><div class="score-ov">${oversText(v.balls)} ov · RR ${v.balls ? (6 * v.total / v.balls).toFixed(2) : '0.00'}</div></div>`;
    let chase = '';
    if (innIdx === 1) {
      const need = v.target - v.total, left = 120 - v.balls;
      chase = need > 0 && left > 0 ? `<div class="chase">Need <b>${need}</b> off <b>${left}</b> · RRR ${(need * 6 / left).toFixed(2)}</div>` : need > 0 ? `<div class="chase">Target ${v.target}</div>` : '';
    } else {
      chase = `<div class="chase muted">First innings · ${esc(bowlTeam.abbr)} bowling</div>`;
    }
    const bline = (id, star) => { const b = v.bat.get(id); return b ? `<div class="batter ${star ? 'striker' : ''}">${star ? '▸ ' : ''}${esc(pname(id))} <b>${b.runs}</b> (${b.balls})</div>` : ''; };
    let batters = '';
    if (!v.done && v.wickets < 10) batters = `<div class="batters">${bline(v.strikerId, true)}${bline(v.nonStrikerId, false)}</div>`;
    const bc = v.bowlerId ? v.bowl.get(v.bowlerId) || { balls: 0, runs: 0, wkts: 0 } : null;
    const bowler = v.bowlerId ? `<div class="bowler">${esc(pname(v.bowlerId))} <span class="muted">${player(v.bowlerId).kind === 'PACE' ? 'pace' : 'spin'}</span> · ${oversText(bc.balls)}-${bc.runs}-${bc.wkts}</div>` : '';
    const thisOver = (v.overs.get(v.curOver) || []);
    const overStr = `<div class="this-over"><span class="muted">Over ${v.curOver}:</span> ${thisOver.length ? thisOver.map((x) => `<span class="ball b-${x}">${x}</span>`).join('') : '<span class="muted">—</span>'}</div>`;
    const prev = [...v.overs.keys()].filter((o) => o < v.curOver).slice(-4).map((o) => { const arr = v.overs.get(o); return `<div class="prev-over small"><span class="muted">${o}</span> ${arr.join(' ')} <span class="muted">(${arr.reduce((a, x) => a + (x === 'W' ? 0 : Number(x)), 0)})</span></div>`; }).join('');
    let event = '';
    if (v.last) {
      if (v.last.wicket) {
        const b = v.bat.get(v.last.strikerId);
        event = `<div class="event wicket">WICKET · ${esc(pname(v.last.strikerId))} ${esc(dismissalText(b))} · ${b.runs} (${b.balls})${v.last.nextInId && !v.done ? `<br><span class="small">Next in: ${esc(pname(v.last.nextInId))}</span>` : ''}</div>`;
      } else if (v.last.runs === 6) event = `<div class="event six">SIX · ${esc(pname(v.last.strikerId))}</div>`;
      else if (v.last.runs === 4) event = `<div class="event four">FOUR · ${esc(pname(v.last.strikerId))}</div>`;
    }
    let banner = '';
    if (item.type === 'break') banner = `<div class="banner">Innings break · ${esc(batTeam.name)} ${v.total}/${v.wickets}. ${esc(team(m.innings2.xi.team.id).name)} need ${v.total + 1}.<br>${btn('livePlay', 'Start the chase', '', 'primary')}</div>`;
    if (item.type === 'end') banner = `<div class="banner result"><b>${esc(m.resultLine())}</b><br>${btn('liveFinish', 'Scorecard', '', 'primary')}</div>`;
    const speedBtns = SPEEDS.map((x) => `<button class="chip ${l.speed === x ? 'active' : ''}" data-action="liveSpeed" data-speed="${x}">${x}×</button>`).join('');
    const controls = item.type === 'end' ? '' : `<div class="controls">${btn('livePlay', l.playing ? 'Pause' : 'Play', '', 'primary wide')}<div class="toggle">${speedBtns}</div><div class="row">${btn('liveSkip', 'Over ▸', 'data-what="over"', 'small')}${btn('liveSkip', 'Innings ▸▸', 'data-what="innings"', 'small')}${btn('liveSkip', 'End ⏭', 'data-what="end"', 'small')}</div></div>`;
    return `<header class="title live-title"><h2>${esc(team(f.homeId).abbr)} v ${esc(team(f.awayId).abbr)}</h2><p class="muted small">${esc(f.label || `Round ${f.round}`)} · ${ballMs() / 1000}s a ball at 1×</p></header>
      <section class="card live">${header}${chase}${batters}${bowler}${overStr}${event}${banner}${controls}${prev}</section>
      <p class="muted small center">The phone clock keeps the match moving even if the screen locks.</p>`;
  };

  // ---- scorecard --------------------------------------------------------
  function scorecardHtml(r) {
    const inn = (i) => {
      const t = team(i.teamId);
      return `<h3>${esc(t.name)} <span class="score-inline">${i.total}/${i.wickets} (${oversText(i.balls)} ov)</span>${i.target ? `<span class="muted small"> target ${i.target}</span>` : ''}</h3>
        <table class="table left-all sc"><tbody>${i.batters.filter((b) => b.balls || b.out).map((b) => `<tr><td>${esc(surname(b.id))}</td><td class="num">${b.runs}</td><td class="num muted">(${b.balls})</td><td class="muted small">${esc(dismissalText(b))}</td></tr>`).join('')}</tbody></table>
        ${i.batters.filter((b) => !b.balls && !b.out).length ? `<p class="muted small">Did not bat: ${i.batters.filter((b) => !b.balls && !b.out).map((b) => esc(surname(b.id))).join(', ')}</p>` : ''}
        ${i.fall.length ? `<p class="muted small">Fall: ${i.fall.map((f) => `${f.w}-${f.score}`).join(', ')}</p>` : ''}
        <table class="table sc"><thead><tr><th class="left">Bowling</th><th>O</th><th>R</th><th>W</th><th>Econ</th></tr></thead><tbody>${i.bowlers.map((c) => `<tr><td class="left">${esc(surname(c.id))}</td><td>${oversText(c.balls)}</td><td>${c.runs}</td><td>${c.wkts}</td><td>${c.balls ? (6 * c.runs / c.balls).toFixed(2) : '-'}</td></tr>`).join('')}</tbody></table>`;
    };
    return `<section class="card"><p class="result-line"><b>${esc(r.resultLine)}</b></p><p class="muted small">Toss: ${esc(team(r.homeBatsFirst ? r.homeId : r.awayId).name)}, batted first</p></section><section class="card">${inn(r.innings[0])}</section><section class="card">${inn(r.innings[1])}</section>`;
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
      <section class="card"><h3>Save</h3><p class="muted small">Your league lives in this browser. Copy the save text somewhere safe now and then, or paste one back in.</p>${btn('exportSave', 'Show save text', '', '')}${app.view.export ? `<textarea id="exportBox" class="savebox" readonly>${esc(app.view.export)}</textarea>${btn('copySave', 'Copy to clipboard', '', 'primary')}` : ''}
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
    if (st() && st().userTeamId && !confirm('Start a new league? Your current save will be replaced.')) return;
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
    ensureLive(); setPlaying(true); go('live');
  };
  A.playInstant = () => {
    const s = st(); const f = Game.nextUserFixture(s); if (!f) return;
    const err = Game.validateUserXI(s, s.userXI); if (err) { app.flash = err; render(); return; }
    Game.playOthersInRound(s, f); Game.playFixture(s, f); save();
    go('scorecard', { fixtureId: f.id, back: { screen: 'hub' } });
  };
  A.livePlay = () => { const l = st().live; const item = app.sim.timeline[l.cursor]; if (item.type === 'break') jumpTo(l.cursor + 1); setPlaying(!l.playing); render(); };
  A.liveSpeed = (d) => { const l = st().live; l.cursor = liveCursorNow(); l.speed = Number(d.speed); l.anchorMs = l.playing ? Date.now() : null; l.anchorCursor = l.cursor; saveLive(); render(); };
  A.liveSkip = (d) => {
    const l = st().live, tl = app.sim.timeline; const c = liveCursorNow(); const item = tl[c];
    let target = c;
    if (d.what === 'end') target = tl.length - 1;
    else if (d.what === 'innings') { target = c; while (target < tl.length - 1 && tl[target].type !== 'break' && tl[target].type !== 'end') target++; if (tl[target].type === 'break' && item.type === 'break') target = tl.length - 1; }
    else { // over
      if (item.type !== 'ball') return;
      const o = item.ev.over, inn = item.inn; target = c;
      while (target + 1 < tl.length && tl[target + 1].type === 'ball' && tl[target + 1].inn === inn && tl[target + 1].ev.over === o) target++;
      if (tl[target + 1] && tl[target + 1].type !== 'ball') target++;
    }
    jumpTo(target);
    if (tl[target].type !== 'ball') { l.playing = false; l.anchorMs = null; }
    render();
  };
  A.liveFinish = () => { const s = st(); const f = Game.finishLive(s, app.sim.sim); app.sim = null; save(); saveLive(); go('scorecard', { fixtureId: f.id, back: { screen: 'hub' } }); };
  A.exportSave = () => { app.view.export = Game.serialize(st()); render(); };
  A.copySave = async () => {
    const box = document.getElementById('exportBox'); if (!box) return;
    try { await navigator.clipboard.writeText(box.value); app.flash = 'Copied.'; } catch (e) { box.focus(); box.select(); app.flash = 'Select the text and copy it by hand.'; }
    render();
  };
  A.importSave = () => {
    const box = document.getElementById('importBox'); if (!box || !box.value.trim()) { app.flash = 'Paste a save first.'; render(); return; }
    try { const s = Game.deserialize(box.value.trim()); if (!confirm('Replace your current league with this save?')) return; app.state = s; app.sim = null; localStorage.removeItem(LIVE_KEY); save(); go('hub'); }
    catch (e) { app.flash = `That is not a valid save: ${e.message}`; render(); }
  };

  root.addEventListener('click', (e) => {
    const el = e.target.closest('[data-action]');
    if (!el || el.disabled) return;
    const fn = A[el.dataset.action];
    if (fn) { e.preventDefault(); fn(el.dataset, el); }
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden) tick(); });
  window.addEventListener('pageshow', () => tick());

  // ---- boot -------------------------------------------------------------
  app.state = load();
  if (app.state && app.state.live) { loadLive(); ensureLive(); app.state.live.playing = false; app.state.live.anchorMs = null; app.state.live.anchorCursor = app.state.live.cursor; }
  if (app.state && app.state.live) go('live');
  else if (app.state && app.state.userTeamId) go('hub');
  else if (app.state) go('pick');
  else go('home');

  // Test hook.
  window.CricketApp = { app, actions: A, go, render, Game, get state() { return app.state; } };
})();
