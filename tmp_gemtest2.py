import base64, json, struct, urllib.request, urllib.error, zlib

key = None
with open('/Users/orchestrator/code/pantry/supabase/functions/.env') as f:
    for line in f:
        if line.startswith('GEMINI_API_KEY='):
            key = line.split('=', 1)[1].strip()

FOOD_CATEGORIES = ["produce","dairy_eggs","meat_seafood","grains_pasta","baking","canned",
                   "spices","condiments_oils","snacks","beverages","leftovers","other"]
SCHEMA = {"type":"OBJECT","properties":{"items":{"type":"ARRAY","items":{"type":"OBJECT",
    "properties":{"raw_text":{"type":"STRING"},"name":{"type":"STRING"},
        "quantity_text":{"type":"STRING","nullable":True},"confidence":{"type":"NUMBER"},
        "category":{"type":"STRING","enum":FOOD_CATEGORIES}},
    "required":["raw_text","name","confidence","category"]}}},"required":["items"]}
PROMPT = ("This image is a shopping receipt. Extract the purchased food line items.\n"
          "Return every distinct FOOD or DRINK item as one entry in \"items\" (at most 60).")

# Build a tiny valid PNG (solid gray) so the request is well-formed image input.
def gray_png(w=64, h=64, val=200):
    raw = b''.join(b'\x00' + bytes([val, val, val]) * w for _ in range(h))
    def chunk(t, d):
        c = t + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)
    idat = zlib.compress(raw, 9)
    return sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', idat) + chunk(b'IEND', b'')

img_b64 = base64.b64encode(gray_png()).decode()

def run(label, gen_config):
    body = {"contents":[{"parts":[{"inline_data":{"mime_type":"image/png","data":img_b64}},
                                   {"text":PROMPT}]}], "generationConfig":gen_config}
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=" + key
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type":"application/json"}, method='POST')
    try:
        r = urllib.request.urlopen(req, timeout=60)
        d = json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(label, "HTTP", e.code, e.read()[:400].decode()); return
    cand = (d.get("candidates") or [{}])[0]
    fr = cand.get("finishReason")
    parts = cand.get("content", {}).get("parts")
    txt = parts[0].get("text") if parts else None
    print(label, "finishReason=", fr, "| usage=", d.get("usageMetadata"))
    print("   text=", (txt[:120] if txt else txt))

# 1) Exactly what the Edge Function sends today.
run("[current 8192, no thinkingConfig]", {"response_mime_type":"application/json",
    "response_schema":SCHEMA, "temperature":0.1, "maxOutputTokens":8192})
# 2) Same but with thinking disabled.
run("[thinkingBudget=0]           ", {"response_mime_type":"application/json",
    "response_schema":SCHEMA, "temperature":0.1, "maxOutputTokens":8192,
    "thinkingConfig":{"thinkingBudget":0}})
