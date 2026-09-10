import json, urllib.request, urllib.error

key = None
with open('/Users/orchestrator/code/pantry/supabase/functions/.env') as f:
    for line in f:
        if line.startswith('GEMINI_API_KEY='):
            key = line.split('=', 1)[1].strip()
print("key prefix:", key[:5], "len:", len(key))

payload = json.dumps({"contents": [{"parts": [{"text": "Say OK"}]}]}).encode()
base = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"


def call(label, url, headers):
    req = urllib.request.Request(url, data=payload, headers=headers, method='POST')
    try:
        r = urllib.request.urlopen(req, timeout=30)
        print(label, "HTTP", r.status, r.read()[:300].decode())
    except urllib.error.HTTPError as e:
        print(label, "HTTP", e.code, e.read()[:400].decode())
    except Exception as e:
        print(label, "ERR", repr(e))


call("A query-param ?key=", base + "?key=" + key, {"Content-Type": "application/json"})
call("B header x-goog   ", base, {"Content-Type": "application/json", "x-goog-api-key": key})

try:
    r = urllib.request.urlopen("https://generativelanguage.googleapis.com/v1beta/models?key=" + key, timeout=30)
    d = json.loads(r.read())
    print("MODELS ok:", [m["name"] for m in d.get("models", [])][:8])
except urllib.error.HTTPError as e:
    print("MODELS HTTP", e.code, e.read()[:300].decode())
except Exception as e:
    print("MODELS ERR", repr(e))
