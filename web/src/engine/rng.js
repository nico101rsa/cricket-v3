// Seeded PRNG (mulberry32) plus helpers. Every engine function takes an rng
// object with random() in [0,1); the tape test feeds a recorded Python stream
// through the same interface.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  function mulberry32(a) {
    a = a >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // 32-bit string hash (FNV-1a) so a typed seed like "durban" works.
  function hashString(s) {
    let h = 0x811c9dc5;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 0x01000193);
    }
    return h >>> 0;
  }

  // Mix a base seed with integer parts into a fresh 32-bit seed, so one match
  // can be replayed without simulating the ones before it.
  function deriveSeed(base, ...parts) {
    let h = (typeof base === 'string' ? hashString(base) : base >>> 0) ^ 0x9E3779B9;
    for (const p of parts) {
      h = Math.imul(h ^ (p >>> 0), 0x85EBCA6B);
      h ^= h >>> 13;
      h = Math.imul(h, 0xC2B2AE35);
      h ^= h >>> 16;
    }
    return h >>> 0;
  }

  function makeRng(seed) {
    const next = mulberry32(typeof seed === 'string' ? hashString(seed) : seed);
    const rng = {
      seed,
      random: next,
      int(n) { return Math.floor(next() * n); },          // 0..n-1
      range(lo, hi) { return lo + Math.floor(next() * (hi - lo + 1)); }, // inclusive
      uniform(lo, hi) { return lo + next() * (hi - lo); },
      pick(arr) { return arr[Math.floor(next() * arr.length)]; },
      gauss() {
        let u = 0, v = 0;
        while (u === 0) u = next();
        while (v === 0) v = next();
        return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
      },
      shuffle(arr) {
        const a = arr.slice();
        for (let i = a.length - 1; i > 0; i--) {
          const j = Math.floor(next() * (i + 1));
          [a[i], a[j]] = [a[j], a[i]];
        }
        return a;
      },
    };
    return rng;
  }

  return (Cricket.rng = { mulberry32, hashString, deriveSeed, makeRng });
});
