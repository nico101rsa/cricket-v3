# Research: Mobile Game Launch Playbook

Full research report on launching indie mobile games. Reference doc — **not on the critical path while building**. Open this when launch becomes relevant.

Generated: 2026-05-19.

---

## TL;DR

- Real timeline (pre-AI): 12–18 months part-time for solo indie mobile 2D
- With AI: 8–16 weeks part-time achievable; calendar time still capped by App Store review + need for real soft-launch data
- Top 5 failure modes: scope creep, no marketing, bad onboarding, wrong monetisation for market, engine regret
- India ARPU: $3.03 vs US $200+ → hybrid only (rewarded ads primary, ₹15–₹149 IAPs secondary)
- Soft launch in PAK / BAN / SLK / UAE (cricket audience, smaller markets, no India bidding-war burn)
- Apple/Google review timelines are hard external limits (48hrs / 2–7 days)

---

## Workstream map — full surface area

### Product & Design
- In-match gameplay
- Meta / between-match systems
- League / competition structures
- Collectibles / jokers
- **Economy design** (separate from balance — soft + hard currency, sinks, faucets, gacha rates)
- **Onboarding & FTUE** — biggest D1 retention lever
- **Progression curve & long-term retention loops** (daily/weekly/seasonal)
- **Narrative / flavour text** writing

### Engineering
- Engine / runtime
- **Save system & cloud sync** (iCloud, Google Play Games Saved Games)
- **Backend** (leaderboards, anti-cheat, server-authoritative scores)
- **Analytics & telemetry** — must be in from day 1 of soft launch
- **A/B testing & remote config** (Firebase Remote Config / GameAnalytics)
- **Crash reporting** (Sentry / Crashlytics)
- **CI/CD & build pipelines** (TestFlight, Play Internal Testing, Fastlane)
- Cross-platform porting

### Content / Assets
- Art direction & style guide
- Sprite/UI production pipeline
- **Localisation** (Hindi + Tamil + Telugu for India)
- **Iconography & store assets** — A/B testing alone can swing CTR 2–3×
- Music
- SFX
- Commentary / VO

### Business & Ops
- Monetisation design (IAP + ads + rewarded)
- **Ad mediation setup** (LevelPlay / AppLovin MAX / AdMob)
- **Legal**: privacy policy, terms, DPDP Act 2023 (India), COPPA, IARC age ratings
- **Company/sole-trader entity & tax** (GST registration in India if revenue qualifies; ABN if Australian)
- **App store accounts** ($99/yr Apple, $25 one-off Google)

### Marketing & Community
- Pre-launch audience build (TikTok / Insta / Reddit / Discord)
- Devlog cadence
- Trailer / capsule production
- ASO (App Store Optimisation)
- Press / creator outreach
- Soft launch
- Paid UA
- Community management
- **Influencer seeding** — cricket creators on YouTube India move installs

### Live Ops (post-launch)
- Content calendar (matched to real cricket calendar — IPL, World Cups, Ashes)
- Events, battle pass, seasonal jokers
- Balance patches
- Community management
- Customer support / refund handling

---

## Engine choice — context for this project

**Godot 4.6 (Jan 2026)** is the indie default. Dedicated 2D renderer, native Android device mirroring, Play Billing + Apple StoreKit 2 built-in, MIT license, ~120MB editor, GDScript Python-like. With AI handling the ramp (Claude writes GDScript fluently), the "learning curve" objection is mostly gone.

**Unity** — safe choice for mobile scale, best ad-network/SDK ecosystem; Runtime Fee drama + 3D engine rendering 2D overhead.

**Cocos Creator 3.x** — strong for 2D mobile in India/SEA; less English docs.

**Capacitor/HTML5** — viable if you want zero new tooling. But animation polish, gesture feel, audio mixing all noticeably worse than native engines.

**Decision for this project: Godot** (locked 2026-05-19). Polish ceiling > dev speed since timeline isn't strict.

---

## Launch playbook

### Pre-launch (Months -6 to 0)

The marketing rule that breaks indies: "marketing decisions are made too late, after production priorities and budgets are locked." Start an audience the day you commit to the project.

- **Devlog cadence:** Weekly TikTok/Insta Reels (15–30s gameplay clips), monthly longer YouTube devlog, daily-ish presence in 2–3 communities. LocalThunk (Balatro) posted to r/roguelikes for 2 years before launch.
- **Pre-registration:** Target 10,000+ Play Store pre-registrations for meaningful launch day momentum. Pre-reg opens 90 days before launch.
- **Playable demo / TestFlight beta:** Ship at 60% polish to get retention data early. Most expensive mistake = polishing a broken core loop.
- **Trailer:** Hook in first 10 seconds, CTA at end. One 30s vertical for socials, one 60s horizontal for store.
- **Store page:** Icon + first screenshot drive 80% of install decisions. Plan 3 icon variants for A/B testing day 1.

### Soft launch (4–8 weeks)

**For a cricket game**, swap typical Philippines/Norway for **Pakistan, Bangladesh, Sri Lanka, UAE** — same audience, smaller markets, organic discovery without competing in India's bidding war.

Metrics to watch (industry benchmarks):
- D1 retention: 25–30% baseline, 31–33% top quartile iOS
- D7: 8–15%
- D30: 3–5%
- Session length: 4–8 min (2:45 match → 2–3 sessions = healthy)
- ARPDAU: $0.02–0.05 for indie casual, $0.10+ is good
- Tutorial completion: aim >70%

If D1 <25% — fix onboarding before scaling UA. If D7 <5% — fix the meta loop before adding content.

### Global launch

- Apple review: 24–48hrs typical, plan 7-day buffer
- Google Play review: 2–7 days for new apps (tightened recently)
- Age rating via IARC questionnaire (free, both stores)
- Featuring chase: pitch Apple/Google editorial 4–6 weeks pre-launch via App Store Connect and Play Console
- Launch Thursday in India during IPL window for max contextual relevance

### Live ops

Lightweight solo model: monthly themed event tied to real cricket calendar (IPL season Mar–May, T20 World Cup, Ashes). Battle pass refresh every 6–8 weeks. Balance patch monthly. New joker drop every 2 weeks.

Pull plug honestly if D30 <2% after 3 months — sunk cost is the final indie killer.

---

## Indie mobile economics — brutal numbers

- Mobile games average **$40k lifetime per title** vs $6M console / $2M PC
- Median Steam indie: $4k lifetime
- Top 1% earn 90% of indie revenue
- 70% of solo projects "fail" by author's own definition
- 97.3% of mobile games "fail" if you count chasing saturated trends

Realistic indie cricket game by your own standards: 10k MAU, $200–500/mo revenue. Breakout: 100k+ MAU, $5–15k/mo. Above that needs paid UA.

### India monetisation specifics
- ARPU $3.03 vs US $200+
- Indian players pay in ₹15–20 microtransactions via UPI
- Hybrid only: rewarded ads primary, small IAPs secondary, no premium upfront
- Battle pass at ₹79–149 (~$1–2) is proven Indian price point
- **Avoid interstitials between matches** — kills retention faster than it earns

### Ad networks
Start with **LevelPlay (ironSource) or AppLovin MAX** for mediation; add AdMob, Unity Ads, Meta Audience Network as networks. Don't ship without mediation — single-network revenue is 30–50% lower.

### Store fees
Apple and Google both 15% under $1M/yr revenue (Small Business Programs). Apply day 1.

---

## Time/effort reality (pre-AI baselines)

- Balatro: ~2.5 years (originally side project, full-time Jan 2023, shipped Feb 2024)
- Vampire Survivors: ~9 months solo to v1
- Buckshot Roulette: weeks, single mechanic, 8M+ copies sold
- Hitwicket: 5+ years, team-based, $20M funding round 2026
- Solo 2D mobile baseline: 6–12 months full-time
- Part-time learning context: multiply 3–4×

**With AI compression: 8–16 weeks part-time achievable for personal-scope V1.** Calendar time bottleneck shifts from "build" to "App Store review + need for real soft-launch data."

---

## Top 5 indie mobile failure modes

1. **Scope creep** — #1 killer. "Just add multiplayer" / "just add campaign" turns 6 months into 3 years. Multiplayer especially.
2. **No marketing until launch week** — games launched cold die in 48hrs
3. **Bad onboarding/FTUE** — D1 <20% means no amount of UA will be profitable
4. **Wrong monetisation model** — premium upfront in India is dead; aggressive interstitials anywhere
5. **Engine/stack regret** — comfortable over right means shipping something that feels off, can't fix without rewriting

Honourable mentions: burnout (60% of indies), no analytics (flying blind through soft launch), launching during a major release week.

---

## Cricket audio — practical path

Licensed Hindi commentary (Harsha Bhogle / Ravi Shastri) is not realistic for indie — talent fees are six figures USD plus per-clip rights.

Layered approach:
1. **Crowd ambience** (loopable, royalty-free) — base layer, modulated by tension
2. **Reactive crowd stingers** — gasp, roar, applause, groan, triggered by event
3. **Stadium SFX** — bat on ball (multiple weights), stumps, fielder dive, umpire signal
4. **Text-based commentary** — Reigns-style scrolling text, EN + HI (just translation, no VO)
5. **~30 generic VO stingers** ("OUT!", "SIX!", "What a shot!") from Fiverr Hindi VA (₹5–10k) or English (~$200–500)

Music: commission one composer for 5–7 loops (menu, low-tension match, high-tension, six-celebration, wicket, victory, defeat). Budget $1–3k upcoming composer / Indian indie composers $500–1500.

---

## Recommended phase plan (pre-AI baseline — adjust down with AI)

| Phase | Length | Output |
|---|---|---|
| 0 · Decisions | 1 week | Engine locked, repo, GameAnalytics, social accounts, 1-page brief |
| 1 · Prototype | 2–3 months | 2:45 match loop end-to-end, ugly art, 1 league, 5 jokers, 3 batters + 3 bowlers, private TestFlight |
| 2 · Vertical slice | 3–4 months | Real art for one full flow, meta loop, audio, onboarding, save/load, public TestFlight 50–100 |
| 3 · Content + soft launch | 3 months | All jokers, all leagues, battle pass v1, ad mediation, IAPs, EN+HI loc, crash <1%, soft launch PAK/BAN/SLK/UAE |
| 4 · Global launch | 1–2 months prep | ASO, trailer, creator outreach, Apple/Google featuring pitch, launch Thursday in IPL window |
| 5 · Live ops | Ongoing | Monthly cricket-calendar event, battle pass refresh 6–8 weeks, monthly balance patch |

---

## Sources

- [LocalThunk — Balatro Timeline](https://localthunk.com/blog/balatro-timeline-3aarh)
- [Insider Gaming — Balatro stress behind success](https://insider-gaming.com/localthunk-the-balatro-timeline-solo-dev/)
- [Ziva — Solo Game Development in 2026](https://ziva.sh/blogs/solo-game-development)
- [Juego Studios — Indie Game Development Cost Guide 2026](https://www.juegostudio.com/blog/indie-game-development-cost)
- [Koderspedia — Best Game Engines for 2D Games 2026](https://koderspedia.com/best-game-engines-for-2d-games/)
- [App Radar — Mobile Game Engines 2026](https://appradar.com/blog/mobile-game-engines-development-platforms)
- [GameAnalytics — 2025 Mobile Gaming Benchmarks](https://www.gameanalytics.com/reports/2025-mobile-gaming-benchmarks)
- [MAF — Mobile Game Retention Benchmarks](https://maf.ad/en/blog/mobile-game-retention-benchmarks/)
- [Bruin — Soft Launch CPI Benchmark by Geo](https://getbruin.com/use-cases/mobile-gaming/soft-launch-cpi-benchmark-by-geo/)
- [Audiencelab — Mobile Game Monetization 2026](https://audiencelab.ai/blog/mobile-game-monetization-strategies)
- [Outlook Respawn — India's Gaming ARPU](https://respawn.outlookindia.com/gaming/gaming-originals/is-indias-low-gaming-arpu-sustainable-for-publishers)
- [Gitnux — Indie Game Industry Statistics 2026](https://gitnux.org/indie-game-industry-statistics/)
- [Glance — Why Do Most Indie Mobile Games Fail](https://thisisglance.com/learning-centre/why-do-most-indie-mobile-games-fail)
- [Medium ATNO — Why 90% of Indie Games Fail](https://medium.com/@atnoforgamedev/why-90-of-indie-games-fail-and-the-5-things-successful-ones-do-differently-91922b4c09d3)
- [Wayline — Scope Creep in Indie Games](https://www.wayline.io/blog/scope-creep-indie-games-avoiding-development-hell)
- [Indian Startup News — Hitwicket $20M funding](https://indianstartupnews.com/funding/metasports-secures-20-million-funding-to-grow-hitwicket-across-global-markets-11770432)
- [Wayline — Pre-Launch Campaigns](https://www.wayline.io/blog/market-new-indie-game-pre-launch-content-strategies)
- [Qonversion — Apple Small Business Program 2026](https://qonversion.io/blog/apple-reduces-app-store-commission-to-15)
- [Adapty — App Store Small Business Program 2026](https://adapty.io/blog/app-store-small-business-program/)
- [Game Growth Advisor — LiveOps Strategy 2026](https://gamegrowthadvisor.com/blog/2026-03-31-liveops-strategy-mobile-games-guide/)
- [PocketGamer.biz — 2026 Live Ops Trends](https://www.pocketgamer.biz/2026-live-ops-trends-templatisation-personalisation-and-ai/)
- [Tenjin — Ad Monetization Benchmark 2026](https://tenjin.com/blog/ad-mon-gaming-2026/)
- [IndieGameBusiness — Why Games Fail 2026](https://indiegamebusiness.com/production-secrets-why-some-games-fail/)
