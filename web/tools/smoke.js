// Drive the built game in headless Chromium at iPhone size: new league, pick
// a club, pick the XI, play a live match at top speed, read the scorecard and
// table, reload mid-match and resume. Screenshots go to tools/shots/.
'use strict';
const path = require('node:path');
const fs = require('node:fs');
const { chromium, devices } = require(require.resolve('playwright', { paths: [process.env.NODE_PATH || '/opt/node22/lib/node_modules'] }));
const mock = require('./mock_supabase.js');

const DIST = path.join(__dirname, '..', 'dist', 'index.html');
const SHOTS = path.join(__dirname, 'shots');
fs.mkdirSync(SHOTS, { recursive: true });
const url = 'file://' + DIST;

(async () => {
  const cloud = await mock.start();
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const ctx = await browser.newContext({ ...devices['iPhone 13'], locale: 'en-ZA' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  const shot = (name) => page.screenshot({ path: path.join(SHOTS, `${name}.png`), fullPage: false });
  // The build bakes Nico's Supabase URL and key into config.js; blank them so the More card shows the inputs and we can point at the stand-in.
  const unbake = (p) => p.evaluate(() => { const c = window.Cricket.config.cloud; c.url = ''; c.anonKey = ''; window.CricketApp.render(); });
  const must = (cond, msg) => { if (!cond) throw new Error(`smoke: ${msg}`); };

  await page.goto(url);
  await page.waitForSelector('#seed');
  must(!!(await page.$('.screen-home .cloud-card #cloudCode')), 'a fresh browser can link with a sync code from the home screen');
  await page.fill('#seed', '42');
  await shot('01-home');
  await page.click('[data-action=newLeague]');
  await page.waitForSelector('.team-card');
  must((await page.$$('.team-card')).length === 10, 'ten clubs to choose from');
  await shot('02-pick');
  await page.click('.team-card:nth-child(3) [data-action=chooseTeam]');
  await page.waitForSelector('.screen-hub');
  await shot('03-hub');
  await page.click('[data-action=go][data-screen=xi]');
  await page.waitForSelector('.screen-xi');
  await shot('04-xi');
  await page.click('[data-action=preset][data-preset=attacking]');
  await page.click('[data-action=playLive]');
  await page.waitForSelector('.screen-live');
  // The match opens on a decision card: your openers or your opening bowler.
  await page.waitForSelector('.decide');
  await shot('05-live-decide');
  await page.emulateMedia({ colorScheme: 'dark' });
  await shot('05a-live-decide-dark');
  await page.emulateMedia({ colorScheme: 'light' });
  // Give an instruction: the match re-simulates from that ball, the card stays.
  await page.click('.decide [data-action=instruct]:not(.active)');
  await page.waitForSelector('.decide');
  const nIns = await page.evaluate(() => window.CricketApp.state.live.instructions.length);
  must(nIns === 1, `one instruction recorded, got ${nIns}`);
  must((await page.$$('.decide .chip.active')).length >= 1, 'chosen instruction is highlighted');
  // Reload mid-match: the game must come back on the live screen at the same ball.
  const before = await page.evaluate(() => window.CricketApp.state.live.cursor);
  await page.reload();
  await page.waitForSelector('.screen-live');
  const after = await page.evaluate(() => window.CricketApp.state.live.cursor);
  must(after >= before, `resume cursor ${after} >= ${before}`);
  must((await page.evaluate(() => window.CricketApp.state.live.instructions.length)) === 1, 'instruction survives a reload');
  await page.click('[data-action=liveSpeed][data-speed="10"]');
  await page.click('[data-action=livePlay]');
  await page.waitForTimeout(1500);
  await shot('05b-live');
  // Batters: the one in longest on top, the striker starred.
  const starred = await page.$$eval('.batter .bname', (els) => els.map((e) => e.textContent).filter((t) => t.endsWith('*')).length);
  must(starred <= 1, `at most one striker starred, got ${starred}`);
  await page.click('[data-action=liveSkip][data-what=innings]');
  await page.waitForSelector('.banner');
  must((await page.$$('.banner + details table.sc')).length >= 1, 'first-innings scorecard shown at the break');
  await shot('06-break');
  await page.click('[data-action=livePlay]');
  await page.waitForTimeout(700);
  await shot('07-chase');
  if (await page.$('.decide')) await page.click('.decide [data-action=livePlay]');
  await page.waitForTimeout(1200);
  await shot('07b-chase-live');
  // Tap a batter or bowler of your own team mid-innings to change an instruction.
  const tappable = await page.$('.batter[data-action=liveTap], .bowler[data-action=liveTap]');
  if (tappable) { await tappable.click(); await page.waitForSelector('.decide'); await shot('07c-tap'); await page.click('[data-action=liveTapClose]'); }
  await page.click('[data-action=liveSkip][data-what=end]');
  await page.waitForSelector('.banner.result');
  await shot('08-result');
  await page.click('[data-action=liveFinish]');
  await page.waitForSelector('.screen-scorecard');
  await shot('09-scorecard');
  await page.click('[data-action=go][data-screen=table]');
  await page.waitForSelector('.screen-table');
  const played = await page.evaluate(() => window.CricketApp.state.season.fixtures.filter((f) => f.result).length);
  must(played === 5, `round 1 fully played, got ${played}`);
  await shot('10-table');
  await page.click('[data-action=go][data-screen=squad]');
  await page.waitForSelector('.screen-squad');
  await shot('11-squad');
  await page.click('.screen-squad tr[data-action=player]');
  await page.waitForSelector('.screen-player');
  await shot('12-player');
  await page.click('[data-action=go][data-screen=stats]');
  await page.waitForSelector('.screen-stats');
  await shot('13-stats');
  // Instant sim of a round, then sim the season from More.
  await page.click('[data-action=go][data-screen=hub]');
  await page.click('[data-action=simRound]');
  await page.waitForSelector('.screen-scorecard');
  page.on('dialog', (d) => d.accept());
  await page.click('[data-action=go][data-screen=more]');
  await page.waitForSelector('.screen-more');
  await shot('14-more');
  await page.click('[data-action=simSeason]');
  await page.waitForSelector('.screen-hub');
  const stage = await page.evaluate(() => window.CricketApp.state.season.stage);
  must(stage === 'done', `season done, got ${stage}`);
  await shot('15-season-over');
  await page.click('[data-action=go][data-screen=table]');
  await shot('16-final-table');
  await page.click('[data-action=go][data-screen=hub]');
  await page.click('[data-action=nextSeason]');
  await page.waitForSelector('.screen-hub');
  const no = await page.evaluate(() => window.CricketApp.state.season.no);
  must(no === 2, 'season 2 started');
  // Export and re-import the save.
  await page.click('[data-action=go][data-screen=more]');
  await page.click('[data-action=exportSave]');
  const text = await page.inputValue('#exportBox');
  must(text.length > 1000, 'export has content');
  await page.click('summary');
  await page.fill('#importBox', text);
  await page.click('[data-action=importSave]');
  await page.waitForSelector('.screen-hub');
  // Cloud save against the stand-in server: link, push, then a second "device".
  await page.click('[data-action=go][data-screen=more]');
  await unbake(page);
  await page.waitForSelector('#cloudUrl');
  await shot('17-cloud-setup');
  await page.fill('#cloudUrl', cloud.url);
  await page.fill('#cloudKey', cloud.anonKey);
  await page.click('[data-action=cloudGenCode]');
  const code = await page.inputValue('#cloudCode');
  must(/^[a-z2-9]{4}(-[a-z2-9]{4}){3}$/.test(code), `generated code ${code}`);
  await page.click('[data-action=cloudLink]');
  await page.waitForFunction(() => window.CricketApp.cloud.status === 'idle' && window.CricketApp.state.meta.rev >= 1, null, { timeout: 5000 });
  must(cloud.rows.size === 1, 'one row in the cloud');
  await shot('18-cloud-linked');
  // A change on this device reaches the cloud.
  const revBefore = await page.evaluate(() => window.CricketApp.state.meta.rev);
  await page.click('[data-action=go][data-screen=hub]');
  await page.click('[data-action=simRound]');
  await page.waitForSelector('.screen-scorecard');
  await page.waitForFunction((r) => window.CricketApp.state.meta.rev > r, revBefore, { timeout: 8000 });
  const played1 = await page.evaluate(() => window.CricketApp.state.season.fixtures.filter((f) => f.result).length);
  must([...cloud.rows.values()][0].data.season.fixtures.filter((f) => f.result).length === played1, 'cloud row has the new round');
  // Reload keeps the link and the save.
  await page.reload();
  await page.waitForSelector('.screen-hub');
  must(await page.evaluate(() => !!window.CricketApp.cloud.client), 'still linked after reload');
  // Second device: fresh browser context, same code, gets the same career.
  const ctx2 = await browser.newContext({ ...devices['iPhone 13'], locale: 'en-ZA' });
  const p2 = await ctx2.newPage();
  p2.on('pageerror', (e) => errors.push('dev2 ' + String(e)));
  await p2.goto(url);
  await p2.waitForSelector('#seed');
  await unbake(p2);
  await p2.waitForSelector('.screen-home #cloudUrl');
  await p2.fill('#cloudUrl', cloud.url);
  await p2.fill('#cloudKey', cloud.anonKey);
  await p2.fill('#cloudCode', code.toUpperCase());
  p2.on('dialog', (d) => d.accept());
  await p2.click('[data-action=cloudLink]');
  await p2.waitForSelector('.screen-hub', { timeout: 8000 });
  const seed2 = await p2.evaluate(() => window.CricketApp.state.seed);
  const seed1 = await page.evaluate(() => window.CricketApp.state.seed);
  const played2 = await p2.evaluate(() => window.CricketApp.state.season.fixtures.filter((f) => f.result).length);
  must(seed1 === seed2 && played1 === played2, `second device has the same career (${seed1}/${played1} v ${seed2}/${played2})`);
  await p2.evaluate(() => window.CricketApp.go('more'));
  await p2.waitForSelector('.screen-more');
  await shot.call(null, '19-cloud-second-device').catch(() => {});
  await p2.screenshot({ path: path.join(SHOTS, '19-cloud-second-device.png') });
  // Play a round on device 2, then device 1 comes back to the front and picks it up.
  await p2.evaluate(() => window.CricketApp.go('hub'));
  await p2.click('[data-action=simRound]');
  await p2.waitForSelector('.screen-scorecard');
  await p2.waitForFunction((n) => window.CricketApp.state.meta.rev > n, played2, { timeout: 8000 }).catch(() => {});
  const played3 = await p2.evaluate(() => window.CricketApp.state.season.fixtures.filter((f) => f.result).length);
  must(played3 > played2, 'device 2 played a round');
  await page.evaluate(() => window.CricketApp.cloudPull('test'));
  await page.waitForFunction((n) => window.CricketApp.state.season.fixtures.filter((f) => f.result).length === n, played3, { timeout: 8000 });
  await page.waitForSelector('.screen-hub');
  await shot('20-cloud-pulled');
  await ctx2.close();
  must(errors.length === 0, `console errors: ${errors.join(' | ')}`);
  console.log(`smoke OK: ${fs.readdirSync(SHOTS).length} screenshots in ${SHOTS}, save ${(text.length / 1024).toFixed(0)} KB, cloud rev ${[...cloud.rows.values()][0].rev}`);
  await browser.close();
  await cloud.close();
})().catch((e) => { console.error(e); process.exit(1); });
