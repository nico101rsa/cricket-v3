// Drive the built game in headless Chromium at iPhone size: new league, pick
// a club, pick the XI, play a live match at top speed, read the scorecard and
// table, reload mid-match and resume. Screenshots go to tools/shots/.
'use strict';
const path = require('node:path');
const fs = require('node:fs');
const { chromium, devices } = require(require.resolve('playwright', { paths: [process.env.NODE_PATH || '/opt/node22/lib/node_modules'] }));

const DIST = path.join(__dirname, '..', 'dist', 'index.html');
const SHOTS = path.join(__dirname, 'shots');
fs.mkdirSync(SHOTS, { recursive: true });
const url = 'file://' + DIST;

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const ctx = await browser.newContext({ ...devices['iPhone 13'], locale: 'en-ZA' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  const shot = (name) => page.screenshot({ path: path.join(SHOTS, `${name}.png`), fullPage: false });
  const must = (cond, msg) => { if (!cond) throw new Error(`smoke: ${msg}`); };

  await page.goto(url);
  await page.waitForSelector('#seed');
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
  must(errors.length === 0, `console errors: ${errors.join(' | ')}`);
  console.log(`smoke OK: ${fs.readdirSync(SHOTS).length} screenshots in ${SHOTS}, save ${(text.length / 1024).toFixed(0)} KB`);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
