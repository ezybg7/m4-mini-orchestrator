import json, urllib.request, urllib.error

key = None
with open('/Users/orchestrator/code/pantry/supabase/functions/.env') as f:
    for line in f:
        if line.startswith('GEMINI_API_KEY='):
            key = line.split('=', 1)[1].strip()

body = {"contents": [{"parts": [{"text": "Say OK"}]}]}
url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=" + key
req = urllib.request.Request(url, data=json.dumps(body).encode(),
                             headers={"Content-Type": "application/json"}, method='POST')
try:
    r = urllib.request.urlopen(req, timeout=60)
    print("HTTP", r.status, "-> OK, quota available again")
except urllib.error.HTTPError as e:
    print("HTTP", e.code)
    print(e.read().decode())
