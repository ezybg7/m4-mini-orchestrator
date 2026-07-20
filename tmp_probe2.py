import json, urllib.request, urllib.error

ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
        "eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9."
        "CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0")
base = "http://127.0.0.1:54321"

def hit(path, body=None, method='GET'):
    url = base + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + ANON, "apikey": ANON})
    try:
        r = urllib.request.urlopen(req, timeout=10)
        print(f"{method} {path} -> {r.status} {r.read()[:200].decode()}")
    except urllib.error.HTTPError as e:
        print(f"{method} {path} -> {e.code} {e.read()[:200].decode()}")
    except Exception as e:
        print(f"{method} {path} -> ERR {e!r}")

# REST (postgrest) — proves the DB/gateway path works
hit("/rest/v1/catalog_items?select=id&limit=1")
# a function that does NOT exist — if edge-runtime is UP, expect 404/boot error;
# if edge-runtime is DOWN, Kong returns the same 503 name-resolution error
hit("/functions/v1/does-not-exist", body={}, method='POST')
# the real function
hit("/functions/v1/parse-receipt", body={"mode": "receipt"}, method='POST')
