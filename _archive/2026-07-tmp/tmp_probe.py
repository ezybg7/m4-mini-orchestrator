import json, urllib.request, urllib.error, socket

ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
        "eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9."
        "CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0")

for host in ("127.0.0.1", "10.0.0.74"):
    base = f"http://{host}:54321"
    # 1) TCP reachability
    try:
        s = socket.create_connection((host, 54321), timeout=3); s.close()
        print(f"[{host}] TCP 54321 OPEN")
    except Exception as e:
        print(f"[{host}] TCP 54321 CLOSED -> {e!r}"); continue
    # 2) invoke the function with a deliberately invalid payload to see its status/body
    url = base + "/functions/v1/parse-receipt"
    body = json.dumps({"mode": "receipt"}).encode()  # missing image -> expect 422 if reachable
    req = urllib.request.Request(url, data=body, method='POST', headers={
        "Content-Type": "application/json", "Authorization": "Bearer " + ANON, "apikey": ANON})
    try:
        r = urllib.request.urlopen(req, timeout=15)
        print(f"[{host}] POST -> HTTP {r.status} {r.read()[:300].decode()}")
    except urllib.error.HTTPError as e:
        print(f"[{host}] POST -> HTTP {e.code} {e.read()[:300].decode()}")
    except Exception as e:
        print(f"[{host}] POST -> ERR {e!r}")
