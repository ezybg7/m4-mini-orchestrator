// Local dev anon key (well-known supabase-demo key; not a secret).
const anon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
const url = 'http://127.0.0.1:54321/rest/v1/catalog_items?select=id&limit=1';
(async () => {
  try {
    const r = await fetch(url, { headers: { apikey: anon, Authorization: 'Bearer ' + anon, Prefer: 'count=exact' } });
    console.log('REST status:', r.status, '| content-range:', r.headers.get('content-range'));
  } catch (e) {
    console.log('query failed:', e.message);
  }
})();
