import re,sys,collections
pats={
 'postgres connection string with password': re.compile(r'postgres(?:ql)?://[^\s\'"`]+:[^\s\'"`@]+@[^\s\'"`]+'),
 'Anthropic key': re.compile(r'sk-ant-[A-Za-z0-9_-]{20,}'),
 'Resend key': re.compile(r'\bre_[A-Za-z0-9]{16,}'),
 'RevenueCat key': re.compile(r'\b(?:appl|goog|amzn|strp)_[A-Za-z0-9]{16,}|\bsk_[A-Za-z0-9]{24,}|\bwhsec_[A-Za-z0-9]{16,}'),
 'JWT': re.compile(r'eyJ[A-Za-z0-9_-]{15,}\.eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}'),
 'AWS key id': re.compile(r'\bAKIA[0-9A-Z]{16}\b'),
 'private key block': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY'),
 'Google API key': re.compile(r'\bAIza[0-9A-Za-z_-]{35}\b'),
 'Google OAuth client id': re.compile(r'\b\d{6,}-[a-z0-9]+\.apps\.googleusercontent\.com\b'),
 'GitHub token': re.compile(r'\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}'),
 'Slack token': re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{10,}'),
 'Cloudflare token-ish': re.compile(r'(?i)cloudflare[_-]?(?:api[_-]?)?token\s*[:=]\s*[\'"]?[A-Za-z0-9_-]{30,}'),
 'Expo token': re.compile(r'(?i)expo[_-]?(?:access[_-]?)?token\s*[:=]\s*[\'"]?[A-Za-z0-9_-]{20,}'),
 'secret env assignment': re.compile(r'(?i)\b(?:BETTER_AUTH_SECRET|AUTH_SECRET|JWT_SECRET|WEBHOOK_SECRET|REVENUECAT_SECRET_KEY|REVENUECAT_WEBHOOK_SECRET|SENTRY_AUTH_TOKEN|ANTHROPIC_API_KEY|RESEND_API_KEY|NEON_API_KEY|CF_API_TOKEN|EXPO_TOKEN|SUPABASE_SERVICE_ROLE_KEY)\s*[:=]\s*[\'"]?(?!\$\{|process\.env|<|\.\.\.|your[-_ ]|xxx|changeme|placeholder|env\.|sk-ant-\.\.\.|re_\.\.\.)[A-Za-z0-9_./+=-]{12,}'),
 'password literal': re.compile(r'(?i)\bpassword\s*[:=]\s*[\'"][^\'"]{6,}[\'"]'),
 'seeded dev password': re.compile(r'password123'),
 'neon endpoint id': re.compile(r'\bep-[a-z]+-[a-z]+-a6[a-z0-9]{6,8}\b'),
}
hits=collections.defaultdict(set); commit=None; file=None
for line in sys.stdin:
    if line.startswith('commit '): commit=line.split()[1][:8]; continue
    if line.startswith('+++ b/'): file=line[6:].strip(); continue
    if not line.startswith('+') or line.startswith('+++'): continue
    for name,rx in pats.items():
        for m in rx.finditer(line):
            v=m.group(0); red=(v[:6]+'…'+v[-3:]) if len(v)>12 else (v[:3]+'…')
            hits[(name,file)].add((commit,red))
for (name,file),vals in sorted(hits.items()):
    ex=sorted(vals)[:3]
    print(f"{name:42s} {str(file):66s} x{len(vals):<3d} e.g. {', '.join(c+':'+r for c,r in ex)}")
print('(scan complete)')
