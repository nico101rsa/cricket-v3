// A stand-in for the two Supabase functions in supabase/schema.sql, for tests
// and the smoke run (the sandbox cannot reach supabase.com). In-memory, CORS
// open, same request/response shapes as PostgREST rpc.
'use strict';
const http = require('node:http');

function start(port = 0, anonKey = 'test-anon') {
  const rows = new Map(); // key -> { data, rev, updated_at }
  const server = http.createServer((req, res) => {
    const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'apikey, authorization, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
    if (req.method === 'OPTIONS') { res.writeHead(204, cors); res.end(); return; }
    let body = '';
    req.on('data', (c) => { body += c; });
    req.on('end', () => {
      const send = (status, obj) => { res.writeHead(status, { ...cors, 'Content-Type': 'application/json' }); res.end(obj === undefined ? '' : JSON.stringify(obj)); };
      if (req.headers.apikey !== anonKey) return send(401, { message: 'Invalid API key' });
      const m = /^\/rest\/v1\/rpc\/(\w+)$/.exec(req.url);
      if (!m || req.method !== 'POST') return send(404, { message: 'not found' });
      let p; try { p = JSON.parse(body || '{}'); } catch (e) { return send(400, { message: 'bad json' }); }
      if (m[1] === 'cricket_get') { const r = rows.get(p.p_key); return send(200, r ? { data: r.data, rev: r.rev, updated_at: r.updated_at } : null); }
      if (m[1] === 'cricket_put') {
        if (typeof p.p_key !== 'string' || p.p_key.length !== 64) return send(400, { message: 'bad key' });
        const cur = rows.get(p.p_key);
        if (cur && p.p_expected !== null && p.p_expected !== undefined && cur.rev !== p.p_expected) return send(200, { conflict: true, rev: cur.rev, data: cur.data });
        const rev = (cur ? cur.rev : 0) + 1;
        rows.set(p.p_key, { data: p.p_payload, rev, updated_at: new Date().toISOString() });
        return send(200, { conflict: false, rev });
      }
      send(404, { message: `Could not find the function public.${m[1]}` });
    });
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve({ server, rows, anonKey, url: `http://127.0.0.1:${server.address().port}`, close: () => new Promise((r) => server.close(r)) })));
}

module.exports = { start };
if (require.main === module) start(Number(process.argv[2] || 8787)).then((s) => console.log(`mock supabase on ${s.url} (anon key: ${s.anonKey})`));
