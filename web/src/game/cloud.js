// Cloud save: one JSON row per sync code in a Supabase table, reached only
// through two Postgres functions (see web/supabase/schema.sql). The code is
// hashed on the device with SHA-256; the hash is the row key. No library:
// two fetch calls against the PostgREST rpc endpoint.
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  const ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789'; // no 0/o/1/l/i
  // A fresh sync code: 16 unambiguous characters in four groups (~80 bits).
  function genCode(random) {
    const rnd = random || ((n) => { const a = new Uint32Array(n); globalThis.crypto.getRandomValues(a); return Array.from(a); });
    const vals = rnd(16);
    let out = '';
    for (let i = 0; i < 16; i++) { if (i && i % 4 === 0) out += '-'; out += ALPHABET[vals[i] % ALPHABET.length]; }
    return out;
  }
  const normCode = (code) => String(code || '').trim().toLowerCase();
  async function hashCode(code) {
    const c = globalThis.crypto && globalThis.crypto.subtle;
    if (!c) throw new Error('cloud save needs a secure page (https)');
    const buf = await c.digest('SHA-256', new TextEncoder().encode('cricket-v3:' + normCode(code)));
    return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
  }

  function makeClient(cfg, fetchImpl) {
    const f = fetchImpl || globalThis.fetch;
    const base = String(cfg.url || '').replace(/\/+$/, '');
    if (!base || !cfg.anonKey) throw new Error('cloud save is not configured');
    // The legacy anon key is a JWT and also goes in Authorization; the newer
    // publishable keys (sb_publishable_…) go in apikey only.
    const headers = { 'Content-Type': 'application/json', apikey: cfg.anonKey };
    if (/^eyJ/.test(cfg.anonKey)) headers.Authorization = `Bearer ${cfg.anonKey}`;
    async function rpc(name, body) {
      let res;
      try {
        res = await f(`${base}/rest/v1/rpc/${name}`, { method: 'POST', headers, body: JSON.stringify(body) });
      } catch (e) { throw new Error('offline or blocked: ' + e.message); }
      const text = await res.text();
      let json = null;
      try { json = text ? JSON.parse(text) : null; } catch (e) { json = null; }
      if (!res.ok) {
        const msg = (json && (json.message || json.hint || json.error)) || text || `HTTP ${res.status}`;
        throw new Error(res.status === 404 ? 'function not found: run supabase/schema.sql in the SQL editor' : `HTTP ${res.status}: ${msg}`);
      }
      return json;
    }
    return {
      // null when nothing is stored yet, else { data, rev, updated_at }.
      get: (key) => rpc('cricket_get', { p_key: key }),
      // { conflict: false, rev } or { conflict: true, rev, data } when expectedRev is stale.
      put: (key, data, expectedRev) => rpc('cricket_put', { p_key: key, p_payload: data, p_expected: expectedRev === undefined ? null : expectedRev }),
    };
  }

  // Which copy wins: the one saved later. Ties and missing stamps keep local.
  function newer(localMeta, remoteData) {
    const l = (localMeta && localMeta.savedAt) || '';
    const r = (remoteData && remoteData.meta && remoteData.meta.savedAt) || '';
    if (!r) return 'local';
    if (!l) return 'remote';
    return r > l ? 'remote' : 'local';
  }

  return (Cricket.cloud = { ALPHABET, genCode, normCode, hashCode, makeClient, newer });
});
