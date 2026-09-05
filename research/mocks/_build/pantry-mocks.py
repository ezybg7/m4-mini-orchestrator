#!/usr/bin/env python3
"""Build the Ambry pantry-group phone mocks (5 screens x today + 3 directions).

Output: ~/agents/research/mocks/pantry/<screen-slug>/{today,<direction-slug>}.html + manifest.json
Input:  ~/agents/research/screens/pantry.json (screen + direction names -> slugs)
Each file is an HTML fragment for a declarative shadow root: one <style>, one 390x844 .screen root.
"""
import json, re, pathlib

SRC = pathlib.Path('/Users/orchestrator/agents/research/screens/pantry.json')
OUT = pathlib.Path('/Users/orchestrator/agents/research/mocks/pantry')
slug = lambda n: re.sub(r'[^a-z0-9]+', '-', n.lower()).strip('-')[:60]

# ---------------------------------------------------------------- shared CSS (pasted into every file)
SHARED = r'''
.screen{width:390px;height:844px;overflow:hidden;position:relative;background:#F2F2F7;color:#000;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif;font-size:15px;line-height:1.3;-webkit-font-smoothing:antialiased}
.screen *{box-sizing:border-box;margin:0;padding:0}
.screen .sb{height:47px;display:flex;align-items:flex-end;justify-content:space-between;padding:0 28px 10px 32px;font-weight:600;font-size:15px}.screen .sb.w{background:#fff}
.screen .sb .r{display:flex;gap:6px;align-items:center}.screen .sig{display:flex;gap:1.5px;align-items:flex-end}.screen .sig i{width:3px;background:#000;border-radius:1px;height:4px}.screen .sig i+i{height:6px}.screen .sig i+i+i{height:8px}.screen .sig i+i+i+i{height:11px}
.screen .wifi{width:16px;height:8px;border:2.5px solid #000;border-bottom:0;border-radius:16px 16px 0 0;position:relative}.screen .wifi::after{content:"";position:absolute;left:3px;bottom:-2px;width:5px;height:5px;background:#000;border-radius:50%}
.screen .bat{width:25px;height:12px;border:1px solid rgba(0,0,0,.35);border-radius:4px;padding:1.5px;position:relative}.screen .bat::before{content:"";display:block;width:100%;height:100%;background:#000;border-radius:2px}.screen .bat::after{content:"";position:absolute;right:-4px;top:3px;width:2px;height:4px;background:rgba(0,0,0,.35);border-radius:0 1px 1px 0}
.screen .nav{height:44px;background:#fff;border-bottom:.5px solid #E5E5EA;display:flex;align-items:center;padding:0 10px 6px}.screen .nav .l{width:44px;display:flex;align-items:center}.screen .nav .t{flex:1;text-align:center;font-size:17px;font-weight:600;white-space:nowrap}.screen .nav .rt{min-width:44px;display:flex;justify-content:flex-end;align-items:center;gap:20px}.screen .txt{color:#1F7A35;font-weight:600;font-size:17px}
.screen .lt{display:flex;align-items:flex-end;justify-content:space-between;gap:12px;padding:8px 16px 0}.screen .lt .tt{display:flex;align-items:flex-end;gap:8px;flex:1}.screen .lt h1{font-size:34px;font-weight:700;letter-spacing:-.4px;line-height:41px}.screen .lt .st{font-size:13px;color:#6D6D72;padding-bottom:7px}
.screen .sw{padding:12px 16px 8px}.screen .search{display:flex;align-items:center;gap:6px;min-height:44px;padding:0 10px;border-radius:10px;background:#E3E3E8;color:#7F7F86}
.screen .tb{padding:12px 16px 8px;display:flex;flex-direction:column;gap:10px}.screen .fr{display:flex;align-items:center;gap:12px}.screen .fr .seg{flex:1}.screen .sel{color:#1F7A35;font-weight:600;padding:2px 4px;white-space:nowrap}
.screen .seg{display:flex;background:#E9E9EB;border-radius:9px;padding:2px}.screen .seg span{flex:1;text-align:center;font-size:13px;font-weight:500;color:#3C3C43;padding:6px 4px;border-radius:7px;white-space:nowrap}.screen .seg .on{background:#fff;font-weight:600;color:#000;box-shadow:0 3px 4px rgba(0,0,0,.12)}.screen .seg em{font-style:normal;color:#C93400;font-weight:700}
.screen .sh{display:flex;justify-content:space-between;align-items:center;padding:16px 32px 6px;font-size:13px;font-weight:600;color:#6D6D72;text-transform:uppercase;letter-spacing:.5px}.screen .sh b{font-weight:400}.screen .sh.sent{text-transform:none;letter-spacing:0}.screen .sh.danger{color:#D70015}.screen .sh .cnt{display:flex;align-items:center;gap:8px;font-weight:400}
.screen .grp{margin:0 16px;background:#fff;border-radius:10px;overflow:hidden}.screen .grp>*{position:relative}.screen .grp>*+*::before{content:"";position:absolute;left:56px;right:0;top:0;height:.5px;background:#E5E5EA;z-index:1}.screen .grp.t>*+*::before{left:16px}
.screen .row{display:flex;align-items:center;gap:8px;min-height:44px;padding:10px 16px;background:#fff}.screen .row.s{gap:12px;padding:8px 16px}.screen .lb{flex:1}.screen .vl{color:#6D6D72;text-align:right}.screen .vcol{display:flex;flex-direction:column;align-items:flex-end}.screen .cap{font-size:13px;color:#848B92;margin-top:2px}.screen .acc{color:#1F7A35}.screen .red{color:#D70015}.screen .warn{color:#C93400}
.screen .tile{width:32px;height:32px;border-radius:7px;background:#EFEFF1;display:flex;align-items:center;justify-content:center;font-size:17px;flex:none}.screen .main{flex:1;min-width:0;display:flex;flex-direction:column}.screen .name{font-size:16px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.screen .sub{font-size:12px;color:#6D6D72;margin-top:2px}
.screen .badge{font-size:12px;font-weight:600;font-variant-numeric:tabular-nums;border-radius:999px;padding:2px 8px;flex:none}.screen .badge.q{font-weight:400;color:#6D6D72;padding:0}.screen .badge.soon{background:#FFF3E0;color:#C93400}.screen .badge.over{background:#FFE5E7;color:#D70015}
.screen .stat{font-size:12px;font-weight:600;border-radius:999px;padding:4px 10px;min-width:64px;text-align:center;flex:none}.screen .stat.stocked{background:#E4F7E9;color:#166534}.screen .stat.low{background:#FFF3E0;color:#C93400}.screen .stat.out{background:#E9E9EB;color:#3C3C43}.screen .pl{font-size:12px;color:#6D6D72}
.screen .chips{display:flex;gap:8px;flex-wrap:wrap}.screen .chip{border:1px solid #E5E5EA;border-radius:999px;background:#fff;color:#3C3C43;font-size:13px;padding:6px 12px;white-space:nowrap}.screen .chip.on{background:#000;border-color:#000;color:#fff}.screen .chip.warnc{background:#FFF3E0;border-color:#FFF3E0;color:#C93400;font-weight:600}.screen .chip.zero{color:#848B92}
.screen .btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:44px;padding:10px 14px;border-radius:10px;font-size:15px;font-weight:600}.screen .btn.tinted{background:#E4F7E9;border:1px solid #A7DBB6;color:#1F7A35}.screen .btn.bordered{background:#fff;border:1px solid #E5E5EA}.screen .btn.primary{background:#000;color:#fff}.screen .btn.small{min-height:32px;padding:6px 12px;font-size:13px;align-self:flex-start;gap:6px}.screen .btn.dis{opacity:.4}
.screen .input{flex:1;min-height:44px;border:1px solid #E5E5EA;border-radius:10px;background:#fff;padding:0 12px;display:flex;align-items:center;color:#7F7F86}.screen .addrow{display:flex;align-items:center;gap:10px;padding:16px 16px 0}
.screen .veil{position:absolute;inset:0;background:rgba(0,0,0,.4)}.screen .sheet{position:absolute;left:0;right:0;bottom:0;background:#fff;border-radius:16px 16px 0 0;padding:8px 16px 32px;display:flex;flex-direction:column;gap:10px}.screen .handle{align-self:center;width:36px;height:5px;border-radius:3px;background:#C7C7CC}.screen .sheet h2{font-size:17px;font-weight:600}
.screen .menu{margin:0 -16px}.screen .mrow{display:flex;align-items:center;gap:12px;min-height:44px;padding:0 16px}.screen .mrow.red{color:#D70015}.screen .mrow.cancel{border-top:.5px solid #E5E5EA;margin-top:4px}.screen .grp.onsheet{margin:0;background:#F2F2F7}.screen .grp.onsheet .row{background:transparent}
.screen .swipe{position:relative;overflow:hidden;background:#fff}.screen .strip{position:absolute;top:0;bottom:0;width:78px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;color:#fff;font-size:12px;font-weight:600}.screen .strip.g{background:#34C759}.screen .strip.o{background:#FF9500}.screen .strip.b{background:#007AFF}.screen .strip.r{background:#FF3B30}
.screen .toast{position:absolute;left:16px;right:16px;bottom:50px;background:#1C1C1E;color:#fff;border-radius:10px;padding:12px 16px;display:flex;justify-content:space-between;align-items:center;gap:12px}.screen .toast b{color:#7FDCA0;font-weight:600}
.screen .tabs{position:absolute;left:0;right:0;bottom:0;height:83px;background:#fff;border-top:.5px solid #E5E5EA;display:flex;justify-content:space-around;padding:6px 8px 0}.screen .tab{width:64px;display:flex;flex-direction:column;align-items:center;font-size:10px;font-weight:500;color:#8E8E93}.screen .tab.on{color:#1F7A35}.screen .home{position:absolute;bottom:8px;left:128px;width:134px;height:5px;border-radius:3px;background:#000}
.screen .ic{display:inline-block;position:relative;flex:none}
.screen .chev{width:8px;height:8px;border:solid #848B92;border-width:1.5px 1.5px 0 0;transform:rotate(45deg)}.screen .chev.down{transform:rotate(135deg)}.screen .chev.back{width:12px;height:12px;border-color:#1F7A35;border-width:2.5px 0 0 2.5px;transform:rotate(-45deg);margin-left:8px}
.screen .more{width:26px;height:26px;border:1.5px solid #1F7A35;border-radius:50%}.screen .more::before{content:"";position:absolute;left:5px;top:10px;width:3px;height:3px;border-radius:50%;background:#1F7A35;box-shadow:6px 0 0 #1F7A35,12px 0 0 #1F7A35}
.screen .mag{width:12px;height:12px;border:1.8px solid currentColor;border-radius:50%;margin-right:4px}.screen .mag::after{content:"";position:absolute;width:2px;height:6px;background:currentColor;right:-4px;bottom:-5px;transform:rotate(-45deg);border-radius:1px}.screen .mag.big{width:17px;height:17px;border-width:2.2px;color:#1F7A35;margin:0 4px 0 0}.screen .mag.big::after{width:2.5px;height:8px;right:-5px;bottom:-7px}
.screen .plus{width:14px;height:14px}.screen .plus::before,.screen .plus::after{content:"";position:absolute;background:currentColor;left:6px;top:0;width:2px;height:14px;border-radius:1px}.screen .plus::after{transform:rotate(90deg)}
.screen .check{width:6px;height:11px;border:solid currentColor;border-width:0 2px 2px 0;transform:rotate(45deg);margin:-3px 4px 0 2px}
.screen .trash{width:13px;height:14px;border:1.5px solid #D70015;border-top-width:2px;border-radius:0 0 3px 3px;margin:4px 6px 0 4px}.screen .trash::before{content:"";position:absolute;left:-3.5px;top:-6px;width:18px;height:2px;background:#D70015;border-radius:1px}.screen .trash.lg{transform:scale(1.15)}
.screen .grip{width:22px;height:2px;background:#848B92;border-radius:1px;box-shadow:0 -6px 0 #848B92,0 6px 0 #848B92;margin-left:8px}
.screen .clock{width:15px;height:15px;border:2px solid currentColor;border-radius:50%}.screen .clock::before{content:"";position:absolute;left:4.5px;top:2px;width:2px;height:5px;background:currentColor}.screen .clock::after{content:"";position:absolute;left:4.5px;top:5.5px;width:4px;height:2px;background:currentColor}
.screen .cart{width:14px;height:9px;border:2px solid currentColor;border-top:0;border-radius:0 0 3px 3px;margin:4px 0 0 3px}.screen .cart::before{content:"";position:absolute;left:-5px;top:-4px;width:20px;height:2px;background:currentColor}.screen .cart::after{content:"";position:absolute;left:1px;bottom:-6px;width:3px;height:3px;border-radius:50%;background:currentColor;box-shadow:6px 0 0 currentColor}
.screen .pen{width:3px;height:12px;background:#848B92;transform:rotate(45deg);border-radius:1px;margin:0 6px}.screen .pen.k{background:#000;width:3.5px;height:16px}
.screen .circ{width:22px;height:22px;border:1.5px solid #848B92;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff}.screen .circ.on{background:#34C759;border-color:#34C759}
.screen .minus{width:22px;height:22px;border-radius:50%;background:#FF3B30}.screen .minus::before{content:"";position:absolute;left:5px;top:10px;width:12px;height:2px;background:#fff}.screen .plusc{width:22px;height:22px;border-radius:50%;background:#34C759;color:#fff;display:flex;align-items:center;justify-content:center}
.screen .x{width:14px;height:14px;color:#6D6D72}.screen .x::before,.screen .x::after{content:"";position:absolute;left:6px;top:0;width:2px;height:14px;background:currentColor;transform:rotate(45deg)}.screen .x::after{transform:rotate(-45deg)}
.screen .tray{width:16px;height:12px;border:1.8px solid currentColor;border-radius:2px;margin-top:2px}.screen .tray::after{content:"";position:absolute;left:2px;right:2px;bottom:2px;height:1.8px;background:currentColor}
.screen .dish{width:4px;height:16px;background:currentColor;border-radius:2px;margin:0 8px 0 10px}.screen .dish::before{content:"";position:absolute;left:-9px;top:0;width:3px;height:16px;background:currentColor;border-radius:2px}.screen .dish::after{content:"";position:absolute;left:-11px;top:0;width:7px;height:6px;border:2px solid currentColor;border-top:0;border-radius:0 0 4px 4px}
.screen .arr{width:10px;height:10px;border:solid #000;border-width:2px 0 0 2px;transform:rotate(45deg);margin:4px 5px 0}.screen .arr.dn{transform:rotate(225deg);margin-top:-2px}
.screen .mi{width:20px;height:20px;display:flex;align-items:center;justify-content:center;flex:none;color:#000}.screen .mi.red{color:#FF3B30}
.screen .tab .ico{width:24px;height:24px;position:relative;margin-bottom:3px}.screen .ico::before,.screen .ico::after{content:"";position:absolute;border:1.8px solid currentColor}
.screen .i-tray::before{left:2px;top:3px;width:20px;height:8px;border-radius:2px}.screen .i-tray::after{left:2px;top:13px;width:20px;height:8px;border-radius:2px}
.screen .i-check::before{left:3px;top:3px;width:18px;height:18px;border-radius:4px}.screen .i-check::after{left:8.5px;top:6px;width:5px;height:9px;border-width:0 1.8px 1.8px 0;transform:rotate(45deg)}
.screen .i-add::before{left:2px;top:2px;width:20px;height:20px;border-radius:50%}.screen .i-add::after{left:11px;top:6px;width:0;height:12px;border-width:0 0 0 1.8px}.screen .i-add i{position:absolute;left:6px;top:11px;width:12px;height:1.8px;background:currentColor}
.screen .i-book::before{left:4px;top:3px;width:16px;height:18px;border-radius:2px 4px 4px 2px}.screen .i-book::after{left:8px;top:3px;width:0;height:18px;border-width:0 0 0 1.8px}
.screen .i-person::before{left:2px;top:2px;width:20px;height:20px;border-radius:50%}.screen .i-person::after{left:8px;top:5.5px;width:8px;height:8px;border-radius:50%;box-shadow:0 9px 0 -1px currentColor}
'''.strip('\n')

# ---------------------------------------------------------------- fragments
def sb(white=False):
    return f'<div class="sb{" w" if white else ""}"><span>9:41</span><span class="r"><span class="sig"><i></i><i></i><i></i><i></i></span><span class="wifi"></span><span class="bat"></span></span></div>'
MORE = '<i class="ic more"></i>'
ADD_ALL = '<span class="btn tinted small"><i class="ic cart"></i>Add all</span>'
def nav(title, right=''):
    return f'<div class="nav"><span class="l"><i class="ic chev back"></i></span><span class="t">{title}</span><span class="rt">{right}</span></div>'
def lt(title, sub=None, right=''):
    s = f'<span class="st">{sub}</span>' if sub else ''
    return f'<div class="lt"><span class="tt"><h1>{title}</h1>{s}</span>{right}</div>'
def search(ph, wrap=True):
    f = f'<div class="search"><i class="ic mag"></i>{ph}</div>'
    return f'<div class="sw">{f}</div>' if wrap else f
def seg(opts, on):
    return '<div class="seg">' + ''.join(f'<span class="on">{o}</span>' if o == on else f'<span>{o}</span>' for o in opts) + '</div>'
def sh(title, count=None, cls='', press=None):
    c = f'<b>{count}</b>' if count is not None and press is None else ''
    if press is not None:
        c = f'<span class="cnt">{count}<i class="ic chev{" down" if press == "open" else ""}"></i></span>'
    return f'<div class="sh{(" " + cls) if cls else ""}"><span>{title}</span>{c}</div>'
def item(glyph, name, sub, badge=None, kind='q', stat=None, trash=False, lead='', tail='', style=''):
    b = f'<span class="badge {kind}">{badge}</span>' if badge else ''
    s = f'<span class="stat {stat.lower()}">{stat}</span>' if stat else ''
    t = '<i class="ic trash"></i>' if trash else ''
    st = f' style="{style}"' if style else ''
    return f'<div class="row"{st}>{lead}<span class="tile">{glyph}</span><span class="main"><span class="name">{name}</span><span class="sub">{sub}</span></span>{b}{s}{tail}{t}</div>'
def srow(label, value='', chev=True, cap=None, lcls='', vcls=''):
    v = f'<span class="vl {vcls}">{value}</span>' if value else ''
    if cap: v = f'<span class="vcol"><span class="vl {vcls}">{value}</span><span class="cap">{cap}</span></span>'
    c = '<i class="ic chev"></i>' if chev else ''
    return f'<div class="row s"><span class="lb {lcls}">{label}</span>{v}{c}</div>'
def strip(cls, label, icon, pos):
    return f'<span class="strip {cls}" style="{pos}"><i class="ic {icon}"></i>{label}</span>'
def mrow(icon, label, cls=''):
    return f'<div class="mrow{(" " + cls) if cls else ""}"><span class="mi{" red" if "red" in cls else ""}">{icon}</span>{label}</div>'
CANCEL = '<div class="mrow cancel">Cancel</div>'
def sheet(title, inner):
    return f'<div class="veil"></div><div class="sheet"><span class="handle"></span><h2>{title}</h2>{inner}</div>'
def toast(msg, action=None):
    return f'<div class="toast"><span>{msg}</span>{f"<b>{action}</b>" if action else ""}</div>'
HOME = '<div class="home"></div>'
TABS = ('<div class="tabs"><span class="tab on"><span class="ico i-tray"></span>Pantry</span><span class="tab"><span class="ico i-check"></span>Lists</span>'
        '<span class="tab"><span class="ico i-add"><i></i></span>Add</span><span class="tab"><span class="ico i-book"></span>Recipes</span><span class="tab"><span class="ico i-person"></span>Profile</span></div>' + HOME)
FILTER = '<div class="fr">' + seg(['All', 'Expiring', 'Low', 'Out'], 'All') + '<span class="sel">Select</span></div>'
def card(glyph, n, unit, name):
    return f'<div class="card"><div class="ct"><span class="cg">{glyph}</span><span class="cc"><b>{n}</b>{unit}</span></div><div class="cn">{name}</div></div>'
GRID = '<div class="grid">' + card('🧊', 3, 'foods', 'Fridge') + card('🥫', 3, 'foods', 'Pantry') + card('❄️', 1, 'food', 'Freezer') + '<div></div></div>'
# Test Home rows (added Sep 4; labels as the app prints them)
MILK = dict(glyph='🥚', name='Milk', sub='added Sep 4', badge='7d', kind='soon')
EGGS = dict(glyph='🥚', name='Eggs', sub='added Sep 4', badge='35d')
BANANAS = dict(glyph='🥬', name='Bananas', sub='added Sep 4', badge='no est.')
FRIDGE_TODAY = sh('Dairy &amp; Eggs', 2) + '<div class="grp">' + item(**EGGS, stat='Stocked') + item(**MILK, stat='Stocked') + '</div>' + sh('Produce', 1) + '<div class="grp">' + item(**BANANAS, stat='Stocked') + '</div>'
LOC_TB = '<div class="tb">' + search('Search this location', False) + FILTER + '</div>'

# ---------------------------------------------------------------- per-screen CSS
CSS_PANTRY = r'''
.screen .gc{padding:8px 16px}.screen .sum{display:flex;align-items:center;gap:12px;background:#fff;border-radius:10px;padding:12px 16px;margin-bottom:16px}.screen .sicon{width:30px;height:30px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;background:#FF9500;flex:none}.screen .sicon.idle{background:#EFEFF1;color:#6D6D72}.screen .sicon.info{background:#007AFF}
.screen .stitle{flex:1;font-size:16px;font-weight:600}.screen .scount{font-size:17px;font-weight:600;color:#6D6D72}
.screen .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.screen .card{background:#fff;border-radius:12px;padding:10px 12px}.screen .ct{display:flex;align-items:center;justify-content:space-between}.screen .cg{font-size:26px;line-height:32px}.screen .cc{font-size:13px;font-weight:600;color:#6D6D72;display:flex;align-items:baseline;gap:3px}.screen .cc b{font-size:22px;font-weight:700;color:#000;font-variant-numeric:tabular-nums}.screen .cn{margin-top:8px;font-size:15px;font-weight:600;color:#3C3C43}
.screen .fig{font-size:22px;font-weight:700;font-variant-numeric:tabular-nums}.screen .fig.m{color:#6D6D72}.screen .lg{font-size:22px;line-height:28px;width:30px}.screen .cw{padding:0 16px 8px;display:flex;gap:8px;align-items:center}.screen .bar{width:12px;height:4px;background:currentColor;border-radius:1px;box-shadow:0 -5px 0 currentColor}.screen .ring{width:14px;height:14px;border:2.5px solid currentColor;border-radius:50%}
'''.strip('\n')
CSS_LOC = r'''
.screen .hint{display:flex;align-items:flex-start;gap:12px;background:#fff;border:1px solid #E5E5EA;border-radius:10px;padding:10px 12px;font-size:13px;color:#6D6D72}.screen .hint b{color:#1F7A35;font-weight:600;white-space:nowrap}
.screen .cw{display:flex;gap:8px;align-items:center;white-space:nowrap;overflow:hidden;margin-right:-16px}
'''.strip('\n')
CSS_ZONES = r'''
.screen .intro{padding:16px 16px;font-size:13px;color:#6D6D72;line-height:17px}.screen .zn{font-size:16px;display:flex;align-items:center;padding:11px 0}.screen .zn+.sub13{font-size:13px;color:#6D6D72;margin:-8px 0 8px}
'''.strip('\n')
CSS_EXP = r'''
.screen .cta{padding:8px 16px;display:flex;flex-direction:column;gap:10px}.screen .foot{text-align:center;font-size:13px;color:#6D6D72;padding:14px 16px}.screen .sh .btn{align-self:center}
'''.strip('\n')
CSS_ITEM = r'''
.screen .hd{display:flex;align-items:center;gap:12px;padding:12px 16px 0}.screen .hero{width:56px;height:56px;border-radius:10px;background:#EFEFF1;display:flex;align-items:center;justify-content:center;font-size:28px;flex:none}.screen .ht{flex:1;min-width:0}.screen .nm{display:block;font-size:17px;font-weight:600;min-height:44px;line-height:44px}.screen .meta{display:block;font-size:13px;color:#6D6D72;margin-top:-6px;padding:0 2px}
.screen .row.chiprow{padding:10px 16px}.screen .notes{min-height:76px;align-items:flex-start;padding:12px 16px;color:#7F7F86}.screen .nut{margin:16px 16px 0;background:#fff;border:1px solid #E5E5EA;border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:2px}.screen .nut b{font-size:16px;font-weight:700}.screen .nut span{font-size:13px;color:#6D6D72}.screen .del{margin-top:28px}
.screen .cal{display:flex;flex-direction:column;gap:6px}.screen .calh{font-size:15px;font-weight:600;padding:0 4px}.screen .wk{display:grid;grid-template-columns:repeat(7,1fr);text-align:center;font-size:12px;font-weight:600;color:#848B92}.screen .days{display:grid;grid-template-columns:repeat(7,1fr);row-gap:2px}.screen .days span{height:28px;line-height:28px;text-align:center;font-size:15px;border-radius:50%;width:32px;margin:0 auto}.screen .days .o{color:#C7C7CC}.screen .days .td{color:#1F7A35;font-weight:700}.screen .days .on{background:#000;color:#fff;font-weight:600}
.screen .tcol{flex-direction:column;align-items:stretch;gap:8px;padding:10px 16px}.screen .input.focus{border-color:#1F7A35;color:#000;min-height:40px}.screen .caret{width:2px;height:20px;background:#1F7A35;margin-left:1px}.screen .echo{font-size:13px;color:#1F7A35;font-weight:600}
.screen .kb{position:absolute;left:0;right:0;bottom:0;background:#D1D3D9;padding-bottom:36px}.screen .acb{height:44px;background:#F2F2F7;border-bottom:.5px solid #C7C7CC;display:flex;justify-content:flex-end;align-items:center;padding:0 16px;color:#007AFF;font-weight:600;font-size:17px}.screen .kr{display:flex;justify-content:center;gap:6px;margin-top:10px;padding:0 3px}.screen .k{width:33px;height:42px;background:#fff;border-radius:5px;box-shadow:0 1px 0 #898A8D;display:flex;align-items:center;justify-content:center;font-size:22px}.screen .k.w{width:42px;background:#ACB0BA}.screen .k.sp{flex:1;font-size:16px}.screen .k.go{width:88px;background:#007AFF;color:#fff;font-size:16px}
.screen .acts{display:flex;gap:6px;padding:12px 16px 0}.screen .acts .btn{padding:6px 8px;flex:none}
'''.strip('\n')

# ---------------------------------------------------------------- screen 1: Pantry overview tab
P_TODAY = sb() + lt('Pantry') + search('Search your whole pantry') + '<div class="gc">' + \
    '<div class="sum"><span class="sicon"><i class="ic clock"></i></span><span class="stitle">Expiring Soon</span><span class="scount">1</span><i class="ic chev"></i></div>' + GRID + \
    '<div class="btn bordered" style="margin-top:8px"><i class="ic plus"></i>Add location</div></div>' + TABS
def tile(icon_cls, icon, n, name, mcls=''):
    return f'<div class="card"><div class="ct"><span class="sicon {icon_cls}">{icon}</span><span class="fig {mcls}">{n}</span></div><div class="cn">{name}</div></div>'
P_A = sb() + lt('Pantry') + search('Search your whole pantry') + '<div class="gc"><div class="grid">' + \
    tile('', '<i class="ic clock"></i>', 1, 'Expiring') + tile('idle', '<i class="ic bar"></i>', 0, 'Low', 'm') + tile('idle', '<i class="ic ring"></i>', 0, 'Out', 'm') + tile('info', '<i class="ic tray"></i>', 7, 'All') + \
    '</div></div>' + sh('Locations') + '<div class="grp t">' + \
    ''.join(f'<div class="row s"><span class="lg">{g}</span><span class="lb">{n}</span><span class="vl">{c}</span><i class="ic chev"></i></div>' for g, n, c in [('🧊', 'Fridge', '3 foods'), ('🥫', 'Pantry', '3 foods'), ('❄️', 'Freezer', '1 food')]) + \
    '</div><div class="gc" style="padding-top:16px"><div class="btn bordered"><i class="ic plus"></i>Add location</div></div>' + TABS
def shelf(glyph, name, count, rows):
    return sh(f'{glyph} {name}', count, press='closed') + '<div class="grp">' + rows + f'<div class="row s"><span class="lb acc">Show all {count}</span><i class="ic chev"></i></div></div>'
P_B = sb() + lt('Pantry') + search('Search your whole pantry') + '<div style="padding:0 16px 8px">' + \
    '<div class="seg"><span class="on">All</span><span>Expiring <em>1</em></span><span>Low</span><span>Out</span></div></div>' + \
    shelf('🧊', 'Fridge', 3, item(**MILK, stat='Stocked') + item(**EGGS, stat='Stocked') + item(**BANANAS, stat='Stocked')) + \
    shelf('🥫', 'Pantry', 3, item('🫙', 'Olive oil', 'added Sep 4', '540d', stat='Stocked') + item('🌾', 'Pasta', 'added Sep 4', '730d', stat='Stocked') + item('🌾', 'Rice', 'added Sep 4', '730d', stat='Stocked')) + \
    shelf('❄️', 'Freezer', 1, item('🥬', 'Peas', 'added Sep 4', 'no est.', stat='Stocked')) + TABS
P_C = sb() + lt('Pantry', right=MORE) + search('Search your whole pantry') + \
    '<div class="cw"><span class="chip warnc">Expiring 1</span><span class="chip zero">Low 0</span><span class="chip zero">Out 0</span></div>' + \
    '<div class="gc">' + GRID + '</div>' + TABS + \
    sheet('Expiring · 1', '<div class="grp onsheet"><div class="swipe">' + strip('g', 'Used', 'check', 'left:0') + item('🥚', 'Milk', 'Fridge', '7d', 'soon', trash=True, style='transform:translateX(78px)') + '</div></div>' +
          '<div class="menu"><div class="mrow"><span class="lb">Open list</span><i class="ic chev"></i></div>' + CANCEL + '</div>')

# ---------------------------------------------------------------- screen 2: Location screen (Fridge)
L_TODAY = sb(True) + nav('🧊 Fridge', MORE) + LOC_TB + FRIDGE_TODAY + HOME
L_A = sb(True) + nav('🧊 Fridge', '<i class="ic mag big"></i>' + MORE) + '<div class="tb">' + seg(['All 3', 'Expiring 1', 'Low 0', 'Out 0'], 'All 3') + '</div>' + \
    sh('Dairy &amp; Eggs', 2, press='open') + '<div class="grp">' + item(**EGGS, stat='Stocked') + item(**MILK, stat='Stocked') + '</div>' + sh('Produce', 1, press='closed') + \
    sheet('Fridge', '<div class="menu">' + mrow('<i class="ic pen k"></i>', 'Edit location') + mrow('<i class="ic tray"></i>', 'Zones') + mrow('<i class="ic tray" style="border-radius:2px 2px 6px 6px"></i>', 'Move all items to…') +
          mrow('<i class="ic circ" style="width:18px;height:18px;border-color:#000"></i>', 'Select items') + mrow('<i class="ic arr" style="margin:0 5px 0"></i><i class="ic arr dn" style="margin-left:-2px"></i>', 'Sort by') +
          mrow('<i class="ic trash" style="border-color:#FF3B30"></i>', 'Delete location', 'red') + CANCEL + '</div>')
L_B = sb(True) + nav('🧊 Fridge', MORE) + '<div class="tb"><div class="hint"><span>Swipe a row to mark it low, out, or add it to your list</span><b>Got it</b></div>' + search('Search this location', False) + FILTER + '</div>' + \
    sh('Dairy &amp; Eggs', 2) + '<div class="grp">' + item(**EGGS, tail='<span class="pl">Stocked</span>') + \
    '<div class="swipe">' + strip('o', 'Low', 'bar', 'left:0') + strip('r', 'Out', 'ring', 'left:78px') + item(**MILK, tail='<span class="pl">Stocked</span>', style='transform:translateX(156px)') + '</div></div>' + \
    sh('Produce', 1) + '<div class="grp">' + item(**BANANAS, tail='<span class="pl">Stocked</span>') + '</div>' + HOME
L_C = sb(True) + nav('🧊 Fridge', MORE) + '<div class="tb">' + search('Search this location', False) + \
    '<div class="cw"><span class="chip on">All 3</span><span class="chip warnc">Expiring 1</span><span class="chip zero">Low 0</span><span class="chip zero">Out 0</span><span class="chip">Door 1</span><span class="chip">Top shelf 1</span><span class="sel">Select</span></div></div>' + \
    '<div class="grp" style="margin-top:8px">' + item('🥚', 'Milk', 'Door · added Sep 4', '7d', 'soon', stat='Stocked') + item('🥚', 'Eggs', 'Top shelf · added Sep 4', '35d', stat='Stocked') + item(**BANANAS, stat='Stocked') + '</div>' + HOME

# ---------------------------------------------------------------- screen 3: Zones editor
def zrow(name, count=None):
    c = f'<span class="sub13">{count}</span>' if count else ''
    return f'<div class="row"><span class="main"><span class="zn">{name}<i class="ic pen"></i></span>{c}</span><i class="ic trash lg"></i><span class="grip"></span></div>'
Z_TODAY = sb(True) + nav('Zones') + '<p class="intro">Zones are the shelves inside this location — pin an item to one and it groups there instead of under its category. Tap a name to rename it, or hold its handle to reorder.</p>' + \
    '<div class="grp t">' + zrow('Door', '1 item') + zrow('Top shelf') + '</div>' + \
    '<div class="addrow"><div class="input">New zone (e.g. Top shelf)</div><span class="btn primary small dis">Add</span></div>' + HOME
Z_A = sb(True) + nav('🧊 Fridge', MORE) + LOC_TB + \
    sh('Door', 1, press='open') + '<div class="grp">' + item(**MILK, stat='Stocked') + '</div>' + sh('Top shelf', 1, press='open') + '<div class="grp">' + item(**EGGS, stat='Stocked') + '</div>' + \
    sh('Produce', 1) + '<div class="grp">' + item(**BANANAS, stat='Stocked') + '</div>' + \
    sheet('Door', '<div class="menu">' + mrow('<i class="ic pen k"></i>', 'Rename…') + mrow('<i class="ic arr"></i>', 'Move up') + mrow('<i class="ic arr dn"></i>', 'Move down') +
          mrow('<i class="ic trash" style="border-color:#FF3B30"></i>', 'Delete zone', 'red') + CANCEL + '</div>')
Z_B = sb(True) + nav('Zones', '<span class="txt">Done</span>') + '<p class="intro">Zones are the shelves inside this location.</p><div class="grp t">' + \
    '<div class="row s"><i class="ic minus"></i><span class="lb">Door</span><span class="vl">1 item</span><span class="grip"></span></div>' + \
    '<div class="row s"><i class="ic minus"></i><span class="lb">Top shelf</span><span class="vl">0 items</span><span class="grip"></span></div>' + \
    '<div class="row s"><i class="ic plusc"><i class="ic plus" style="width:12px;height:12px;transform:scale(.8)"></i></i><span class="lb acc">Add zone…</span></div></div>' + HOME
Z_C = sb(True) + nav('🧊 Fridge', MORE) + LOC_TB + FRIDGE_TODAY + \
    sheet('Fridge', '<div class="addrow" style="padding:0"><div class="input">New zone</div><span class="btn primary small dis">Add</span></div><div class="grp t onsheet">' +
          '<div class="row"><span class="main"><span class="name">Door</span><span class="sub">1 item</span></span><span class="grip"></span><i class="ic x" style="margin-left:14px"></i></div>' +
          '<div class="row"><span class="main"><span class="name">Top shelf</span></span><span class="grip"></span><i class="ic x" style="margin-left:14px"></i></div></div><div class="menu">' + CANCEL + '</div>')

# ---------------------------------------------------------------- screen 4: Expiring screen
COOK = '<div class="btn tinted"><i class="ic dish"></i>See what you can make with these</div>'
MILK_X = dict(glyph='🥚', name='Milk', sub='Fridge', badge='7d', kind='soon', trash=True)
BAN_X = dict(glyph='🥬', name='Bananas', sub='Fridge', badge='1d overdue', kind='over', trash=True)
E_TODAY = sb(True) + nav('', ADD_ALL) + lt('Expiring Soon', '1 item this week') + '<div class="cta">' + COOK + '</div>' + \
    sh('In 7 days · Sep 11', 1, 'sent') + '<div class="grp">' + item(**MILK_X) + '</div>' + HOME
E_A = sb(True) + nav('', MORE) + lt('Expiring Soon', '2 items this week') + \
    '<div class="sh sent danger"><span>Overdue</span><span class="cnt"><span class="btn tinted small">Snooze all +2d</span><b>1</b></span></div>' + \
    '<div class="grp">' + item(**BAN_X, lead='<i class="ic circ on"><i class="ic check"></i></i>') + '</div>' + \
    sh('In 7 days · Sep 11', 1, 'sent') + '<div class="grp">' + item(**MILK_X, lead='<i class="ic circ"></i>') + '</div>' + toast('Used “Bananas”', 'Undo') + HOME
E_B = sb(True) + nav('', ADD_ALL) + lt('Expiring Soon', '2 items this week') + '<div class="cta">' + seg(['By day', 'By shelf'], 'By shelf') + COOK + '</div>' + \
    sh('🧊 Fridge', 2) + '<div class="grp">' + item('🥬', 'Bananas', 'added Sep 4', '1d overdue', 'over', trash=True) + item('🥚', 'Milk', 'added Sep 4', '7d', 'soon', trash=True) + '</div>' + HOME
E_C = sb(True) + nav('', ADD_ALL) + lt('Expiring Soon', '1 item this week') + '<div class="cta">' + COOK + '</div>' + sh('In 7 days · Sep 11', 1, 'sent') + \
    '<div class="grp"><div class="swipe">' + strip('o', 'Later', 'clock', 'right:78px') + strip('b', 'List', 'cart', 'right:0') + item(**MILK_X, style='transform:translateX(-156px)') + '</div></div>' + \
    '<div class="foot">Showing 7 days · <span class="acc">Change</span></div>' + \
    sheet('Milk', '<div class="chips"><span class="chip">+3d</span><span class="chip">+1w</span><span class="chip">+2w</span><span class="chip">+1m</span></div><div class="menu"><div class="mrow"><span class="lb">Type a date</span><i class="ic chev"></i></div>' + CANCEL + '</div>')

# ---------------------------------------------------------------- screen 5: Item screen (Milk)
HEAD = '<div class="hd"><span class="hero">🥚</span><span class="ht"><span class="nm">Milk</span><span class="meta">Dairy &amp; Eggs · added Sep 4</span></span></div>'
STATUS = '<div class="row s"><span class="lb" style="flex:none">Status</span>' + seg(['Stocked', 'Low', 'Out'], 'Stocked').replace('class="seg"', 'class="seg" style="flex:1"') + '</div>'
STORAGE = sh('Storage') + '<div class="grp t">' + srow('Location', '🧊 Fridge') + STATUS + '</div>'
NUDGES = '<div class="row s chiprow"><span class="chips"><span class="chip">+3d</span><span class="chip">+1w</span><span class="chip">+2w</span><span class="chip">+1m</span></span></div>'
EXPIRES = srow('Expires', 'Sep 11 · 7d', chev=False, cap='estimated from shelf life')
TAIL = sh('Notes') + '<div class="grp t"><div class="row s notes">Anything worth remembering (opened date, brand…)</div></div>' + \
    '<div class="nut"><b>Nutrition</b><span>No nutrition info available for this food.</span></div><div class="grp t del"><div class="row s"><span class="lb red">Delete item</span></div></div>'
I_TODAY = sb(True) + nav('') + HEAD + STORAGE + sh('Expiry') + '<div class="grp t">' + EXPIRES + NUDGES + srow('Type a date') + srow('Clear date', chev=False, lcls='acc') + '</div>' + TAIL + HOME
WEEKS = [[30, 31, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 11, 12], [13, 14, 15, 16, 17, 18, 19], [20, 21, 22, 23, 24, 25, 26], [27, 28, 29, 30, 1, 2, 3]]
def cal():
    cells = []
    for wi, w in enumerate(WEEKS):
        for d in w:
            out = (wi == 0 and d > 7) or (wi == 4 and d < 7)
            cls = 'o' if out else 'on' if d == 11 else 'td' if d == 5 else ''
            cells.append(f'<span class="{cls}">{d}</span>')
    return '<div class="cal"><div class="calh">September 2026</div><div class="wk"><span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span></div><div class="days">' + ''.join(cells) + '</div></div>'
I_A = sb(True) + nav('') + HEAD + STORAGE + sh('Expiry') + '<div class="grp t">' + srow('Expires', 'Sep 11 · 7d', cap='estimated from shelf life', vcls='warn') + '</div>' + TAIL + \
    sheet('Expires', '<div class="chips"><span class="chip">Today</span><span class="chip">Tomorrow</span><span class="chip">+3d</span><span class="chip">+1w</span><span class="chip">+2w</span><span class="chip">+1m</span></div>' + cal() +
          '<div class="menu"><div class="mrow"><span class="lb">Type a date</span><i class="ic chev"></i></div><div class="mrow acc">Clear date</div>' + CANCEL + '</div>')
def keys(row, cls=''):
    return f'<div class="kr">{cls}' + ''.join(f'<span class="k">{c}</span>' for c in row) + '</div>'
KB = '<div class="kb"><div class="acb">Done</div>' + keys('QWERTYUIOP') + keys('ASDFGHJKL') + \
    '<div class="kr"><span class="k w"></span>' + ''.join(f'<span class="k">{c}</span>' for c in 'ZXCVBNM') + '<span class="k w"></span></div>' + \
    '<div class="kr"><span class="k w" style="font-size:16px">123</span><span class="k sp">space</span><span class="k go">done</span></div></div>'
I_B = sb(True) + nav('') + HEAD + STORAGE + sh('Expiry') + '<div class="grp t">' + EXPIRES + NUDGES + \
    '<div class="row s tcol"><span>Type a date</span><div class="input focus">in 10 days<i class="caret"></i></div><span class="echo">→ Sep 15 · Tue · 10d</span></div>' + srow('Clear date', chev=False, lcls='acc') + '</div>' + KB
I_C = sb(True) + nav('') + HEAD + \
    '<div class="acts"><span class="btn tinted small"><i class="ic check"></i>Used</span><span class="btn tinted small"><i class="ic clock"></i>+2 days</span><span class="btn tinted small"><i class="ic cart"></i>Add to list</span><span class="btn tinted small"><i class="ic tray"></i>Move</span></div>' + \
    sh('Storage') + '<div class="grp t">' + srow('Where', '🧊 Fridge · Door') + STATUS + '</div>' + sh('Expiry') + '<div class="grp t">' + srow('Expires', 'Sep 11 · 7d', chev=False, cap='estimated from shelf life', vcls='warn') + NUDGES + srow('Type a date') + srow('Clear date', chev=False, lcls='acc') + '</div>' + \
    TAIL + toast('Added “Milk” to your list') + HOME

# ---------------------------------------------------------------- assembly
LOOK = {
    'Pantry overview tab': ('The grid as shipped: one Expiring Soon summary row above three location cards, Add location as the footer button, no pantry-wide Low/Out anywhere.', {
        'A': 'Four count tiles (Expiring 1 · Low 0 · Out 0 · All 7) replace the summary row, and the shelves become one inset list of rows with counts and chevrons — tile = state, row = place.',
        'B': 'No grid: each shelf is a pressable section header with its three soonest rows inline and a Show all row, under a pantry-wide All/Expiring/Low/Out segment; the page already runs past the tab bar with seven items.',
        'C': 'Cards kept; a chip row (Expiring 1 tone-coloured, Low/Out muted at zero) sits over the grid, the ellipsis on the title holds New/Reorder location, the footer button is gone, and the Expiring chip has opened its triage sheet with a Used swipe revealed.'}),
    'Location screen': ('Fridge as shipped: search field and All/Expiring/Low/Out segment beside Select, then category sections whose rows carry an urgency badge and a tap-to-cycle Stocked chip.', {
        'A': 'Search moved behind a header magnifier and Select into the ellipsis, segment labels carry counts, section headers are pressable and Produce is collapsed; the sheet shows the menu with its new Select items and Sort by rows.',
        'B': 'The Stocked chip is now a passive grey word, a first-use hint explains the gesture, and Milk is swiped open on its leading edge to show the new Low / Out actions (trailing edge carries +2 days / List).',
        'C': 'No section headers: one list ordered by urgency (Milk 7d first) under a scrolling chip row of counts including zone chips, with the zone as a caption on pinned rows; the chip row scrolls (Top shelf and Select sit past its clipped end). (Door/Top shelf are illustrative — Test Home seeds no zones.)'}),
    'Zones editor': ('The pushed editor as shipped: an intro paragraph, a boxless inline rename field with a pencil per zone, trash and drag handle, and a standing New zone field with an Add button. (Door/Top shelf are illustrative — Test Home seeds no zones.)', {
        'A': 'There is no editor: this is the location screen, whose zone headers (Door, Top shelf) are pressable and have opened a Door sheet with Rename / Move up / Move down / Delete zone; category headers stay static.',
        'B': 'A Settings-style list in Edit mode: red minus circles and drag handles on each SettingsRow (name · N items), an Add zone… insert row, a one-line intro and Done in the bar — no standing text field.',
        'C': 'The editor is a sheet over the Fridge screen titled with the location: New zone field on top, rows with a handle and an ×, Cancel always; the same sheet doubles as the pin picker.'}),
    'Expiring screen': ('As shipped: Add all in the bar, large title with the count, one tinted Cook CTA, then day sections in sentence case — Milk under "In 7 days · Sep 11" with its shelf as the subtitle and a trash.', {
        'A': 'The list opens straight on food: the Cook CTA and Add all live in the ellipsis, every row has a leading tap-to-complete circle (Bananas just tapped, toast with Undo) and the red Overdue header carries Snooze all +2d. (Bananas is shown overdue to exercise that header.)',
        'B': 'A By day · By shelf segment above the Cook CTA; By shelf groups the same rows under a Fridge header sorted by urgency with "added Sep 4" as the subtitle since the shelf is now the header.',
        'C': 'The trailing swipe reads Later instead of +2 days and has opened a sheet with the item screen\'s nudge chips and Type a date; a footer under the list says "Showing 7 days · Change".'}),
    'Item screen': ('Milk as rebuilt in #173: hero tile beside the boxless name, STORAGE (Location ▸, Status segment), EXPIRY as four rows (value + provenance, nudge chips, Type a date ▸, Clear date), Notes, the nutrition placeholder, Delete item.', {
        'A': 'EXPIRY collapses to one Expires row with the value in urgency orange and a chevron; tapping it opened a scheduler sheet — quick chips, a September month grid with Sep 11 selected, Type a date, Clear date, Cancel — so the page is a third shorter.',
        'B': 'Everything as today except Type a date, which is now one short field ("in 10 days") with a live echo "→ Sep 15 · Tue · 10d" beneath it and the keyboard up; the eight-digit mask is only the fallback.',
        'C': 'Four small tinted buttons (Used · +2 days · Add to list · Move) sit under the heading, Location and Zone merge into one "Where · 🧊 Fridge · Door" row, and the toast shows the new grocery hand-off.'}),
}
SCREENS = [
    ('Pantry overview tab', CSS_PANTRY, P_TODAY, [P_A, P_B, P_C]),
    ('Location screen', CSS_LOC, L_TODAY, [L_A, L_B, L_C]),
    ('Zones editor', CSS_ZONES + CSS_LOC, Z_TODAY, [Z_A, Z_B, Z_C]),
    ('Expiring screen', CSS_EXP, E_TODAY, [E_A, E_B, E_C]),
    ('Item screen', CSS_ITEM, I_TODAY, [I_A, I_B, I_C]),
]

def compose(css, body):
    html = '<style>\n' + SHARED + '\n' + css + '\n</style>\n<div class="screen">\n' + body.replace('><div class="sb', '>\n<div class="sb') + '\n</div>\n'
    # one top-level block per line keeps the fragment readable without inflating the line count
    for tag in ('<div class="nav"', '<div class="lt"', '<div class="sw"', '<div class="tb"', '<div class="sh', '<div class="grp', '<div class="gc"', '<div class="cw"', '<div class="cta"',
                '<div class="hd"', '<div class="acts"', '<div class="nut"', '<div class="addrow"', '<p class="intro"', '<div class="foot"', '<div class="tabs"', '<div class="home"',
                '<div class="toast"', '<div class="veil"', '<div class="sheet"', '<div class="menu"', '<div class="kb"', '<div style=', '<div class="btn bordered"', '<div class="cal"',
                '<div class="row', '<div class="swipe"', '<div class="mrow', '<div class="kr"', '<span class="handle"', '<div class="chips"', '<div class="input"'):
        html = html.replace(tag, '\n' + tag)
    return re.sub(r'\n{2,}', '\n', html)

research = json.load(open(SRC))
manifest = []
for (name, css, today, dirs), spec in zip(SCREENS, research):
    assert spec['screen'] == name, (spec['screen'], name)
    s = slug(name); folder = OUT / s; folder.mkdir(parents=True, exist_ok=True)
    (folder / 'today.html').write_text(compose(css, today), encoding='utf-8')
    entry = {'screen': name, 'screen_slug': s, 'today': {'file': f'{s}/today.html', 'look_for': LOOK[name][0]}, 'directions': []}
    for d, body in zip(spec['directions'], dirs):
        ds = slug(d['name']); letter = d['name'][0]
        (folder / f'{ds}.html').write_text(compose(css, body), encoding='utf-8')
        entry['directions'].append({'name': d['name'], 'slug': ds, 'file': f'{s}/{ds}.html', 'look_for': LOOK[name][1][letter]})
    manifest.append(entry)
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
for f in sorted(OUT.rglob('*.html')):
    n = f.read_text(encoding='utf-8').count('\n')
    print(f'{n:4d}  {f.relative_to(OUT)}' + ('   <-- OVER 220' if n > 220 else ''))
