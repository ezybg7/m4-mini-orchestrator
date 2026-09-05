#!/usr/bin/env python3
"""Build the lists-recipes phone mocks: today + three directions for each of the 7 screens, plus manifest.json.

Input : ~/agents/research/screens/lists-recipes.json (screen / direction names → slugs)
Output: ~/agents/research/mocks/lists-recipes/<screen-slug>/{today,<direction-slug>}.html + manifest.json
Each mock is an HTML fragment (one <style>, one 390×844 .screen) meant for a declarative shadow root.
Content is the seeded household "Test Home" as of 2026-09-05. Light scheme, Ambry tokens (src/lib/theme.ts).
"""
import json, os, re

HOME = os.path.expanduser('~')
SRC = f'{HOME}/agents/research/screens/lists-recipes.json'
OUT = f'{HOME}/agents/research/mocks/lists-recipes'


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')[:60]


# ---------------------------------------------------------------- shared CSS (scoped under .screen at build time)
CSS_SRC = r'''
.screen{width:390px;height:844px;overflow:hidden;position:relative;background:#F2F2F7;color:#000;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Helvetica Neue",Arial,sans-serif;font-size:15px;line-height:1.3;-webkit-font-smoothing:antialiased}
.screen *{box-sizing:border-box;margin:0;padding:0}
.sb{height:47px;display:flex;align-items:flex-end;justify-content:space-between;padding:0 28px 10px 34px;font-size:15px;font-weight:600}
.sbr{display:flex;align-items:center;gap:6px}
.sig{display:flex;align-items:flex-end;gap:1.5px}
.sig i{display:block;width:3px;background:#000;border-radius:1px}
.wifi{width:16px;height:8px;border:2.5px solid #000;border-bottom:0;border-radius:16px 16px 0 0;position:relative}
.wifi::after{content:"";position:absolute;left:3px;bottom:-2px;width:5px;height:5px;background:#000;border-radius:50%}
.bat{width:25px;height:12px;border:1px solid rgba(0,0,0,.35);border-radius:4px;padding:1.5px;position:relative}
.bat i{display:block;height:100%;width:100%;background:#000;border-radius:2px}
.bat::after{content:"";position:absolute;right:-4px;top:3px;width:2px;height:4px;background:rgba(0,0,0,.35);border-radius:0 1px 1px 0}
.hi{position:absolute;left:128px;bottom:8px;width:134px;height:5px;border-radius:3px;background:#000}
.lt{display:flex;align-items:flex-end;justify-content:space-between;gap:12px;padding:8px 16px 0}
.lt h1{font-size:34px;font-weight:700;letter-spacing:-.4px;line-height:41px}
.nav{height:44px;background:#fff;border-bottom:.5px solid #E5E5EA;display:flex;align-items:center;padding:0 10px}
.nav .back{width:44px;display:flex;align-items:center}
.nav .ttl{flex:1;text-align:center;font-size:17px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.nav .rt{min-width:44px;display:flex;justify-content:flex-end;align-items:center;gap:20px}
.i-back{width:12px;height:12px;border-left:2.5px solid #1F7A35;border-bottom:2.5px solid #1F7A35;transform:rotate(45deg);margin-left:8px}
.chev{width:8px;height:8px;border-right:1.8px solid #848B92;border-bottom:1.8px solid #848B92;transform:rotate(-45deg);flex:none}
.chev.dn{transform:rotate(45deg)}
.chev.up{transform:rotate(-135deg)}
.sh{display:flex;align-items:center;gap:12px;padding:16px 32px 6px;font-size:13px;font-weight:600;color:#6D6D72;text-transform:uppercase;letter-spacing:.5px}
.sh>span:first-child{flex:1}
.sh.flush{padding-left:16px;padding-right:16px}
.sh b{font-weight:400}
.sh .act{text-transform:none;letter-spacing:0;color:#1F7A35;display:flex;align-items:center;gap:2px}
.grp{position:relative;margin:0 16px;background:#fff;border-radius:10px;overflow:hidden}
.grp.tgt{outline:2px solid #34C759;background:#E4F7E9}
.row{position:relative;display:flex;align-items:center;gap:12px;min-height:44px;padding:10px 16px}
.row+.row::before{content:"";position:absolute;left:var(--ins,56px);right:0;top:0;height:.5px;background:#E5E5EA}
.row.dim{opacity:.5}
.col{display:flex;flex-direction:column;gap:8px}
.pad{padding:12px 16px 16px;display:flex;flex-direction:column;gap:8px}
.px{padding:0 16px}
.grow{flex:1;min-width:0}
.t16{font-size:16px}
.t17{font-size:17px;font-weight:600}
.t22{font-size:22px;font-weight:600}
.c13{font-size:13px;color:#6D6D72}
.c12{font-size:12px}
.b{font-weight:600}
.mu{color:#6D6D72}
.fa{color:#848B92}
.soft{color:#3C3C43}
.acc{color:#1F7A35}
.suc{color:#166534}
.warn{color:#C93400}
.red{color:#D70015}
.ph{color:#7F7F86}
.strike{color:#6D6D72;text-decoration:line-through}
.ell{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.tile{width:31px;height:31px;border-radius:7px;background:#EFEFF1;display:flex;align-items:center;justify-content:center;font-size:16px;line-height:1;flex:none}
.tile.dim{opacity:.5}
.chk{width:22px;height:22px;border:1.5px solid #848B92;border-radius:4px;flex:none;position:relative}
.chk.on{background:#1F7A35;border-color:#1F7A35}
.chk.on::after{content:"";position:absolute;left:7px;top:2px;width:5px;height:11px;border-right:2px solid #fff;border-bottom:2px solid #fff;transform:rotate(45deg)}
.chk.s{width:18px;height:18px}
.chk.s.on::after{left:5px;top:1px;width:4px;height:9px}
.cap{font-size:13px;font-weight:600;border-radius:999px;padding:2px 8px;flex:none}
.cap.out{background:#EFEFF1;color:#6D6D72}
.cap.low{background:#FFF3E0;color:#C93400}
.badge{font-size:13px;color:#1F7A35;border:1px solid #A7DBB6;background:#E4F7E9;border-radius:999px;padding:2px 8px;flex:none}
.mchip{font-size:12px;color:#C93400;background:#FFF3E0;border-radius:999px;padding:2px 8px}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:44px;border-radius:10px;padding:10px 18px;font-size:15px;font-weight:600;white-space:nowrap}
.btn.pri{background:#000;color:#fff}
.btn.tint{background:#E4F7E9;border:1px solid #A7DBB6;color:#1F7A35}
.btn.bord{background:#fff;border:1px solid #E5E5EA;color:#000}
.btn.sec{color:#6D6D72;font-weight:400}
.btn.des{color:#D70015;font-weight:400}
.btn.lg{padding:14px 18px;font-size:16px}
.btn.sm{min-height:32px;padding:6px 14px;font-size:13px;align-self:flex-start}
.inp{display:flex;align-items:center;min-height:44px;border:1px solid #E5E5EA;border-radius:10px;background:#fff;padding:0 12px;font-size:15px}
.inp.multi{align-items:flex-start;padding:10px 12px;min-height:80px}
.srch{display:flex;align-items:center;gap:6px;min-height:44px;border-radius:10px;background:#E3E3E8;padding:0 10px;font-size:15px;color:#7F7F86}
.seg{display:flex;background:#E9E9EB;border-radius:9px;padding:2px}
.seg span{flex:1;text-align:center;font-size:13px;font-weight:500;color:#3C3C43;padding:6px 4px;border-radius:7px;white-space:nowrap}
.seg .on{background:#fff;font-weight:600;color:#000;box-shadow:0 3px 4px rgba(0,0,0,.12)}
.chips{display:flex;flex-wrap:wrap;gap:8px}
.chips.line{flex-wrap:nowrap;overflow:hidden}
.chip{display:inline-flex;align-items:center;gap:6px;font-size:13px;color:#3C3C43;border:1px solid #E5E5EA;background:#fff;border-radius:999px;padding:6px 12px;white-space:nowrap}
.chip.c{padding:4px 9px}
.chip.on{background:#000;border-color:#000;color:#fff}
.chip.tint{background:#E4F7E9;border-color:#A7DBB6;color:#1F7A35;font-weight:600}
.chip.warn{background:#FFF3E0;border-color:#FFF3E0;color:#C93400;font-weight:600}
.chip.out{background:#EFEFF1;border-color:#EFEFF1;color:#6D6D72}
.card{display:flex;align-items:center;gap:10px;background:#fff;border:1px solid #E5E5EA;border-radius:10px;padding:10px}
.card.v{flex-direction:column;align-items:stretch;gap:6px}
.seccard{background:#fff;border:1px solid #E5E5EA;border-radius:12px;padding:14px;display:flex;flex-direction:column;gap:10px}
.th{width:44px;height:44px;border-radius:8px;flex:none}
.th.big{width:64px;height:64px;border-radius:10px}
.th.fb{background:#E9E9EB;display:flex;align-items:center;justify-content:center;color:#848B92}
.g1{background:linear-gradient(135deg,#FBE7B9,#E3A362)}
.g2{background:linear-gradient(135deg,#E6C1B3,#8E3F33)}
.g3{background:linear-gradient(135deg,#F8D2C8,#CF5A3C)}
.g4{background:linear-gradient(135deg,#F6E7C6,#C48B48)}
.g5{background:linear-gradient(135deg,#DDE9E2,#5E8F79)}
.g6{background:linear-gradient(135deg,#EAD4D0,#7E3646)}
.photo{position:relative;width:100%;aspect-ratio:16/9;border-radius:10px;overflow:hidden}
.capn{position:absolute;left:8px;bottom:8px;font-size:11px;color:#fff;background:rgba(0,0,0,.35);padding:2px 8px;border-radius:999px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px;padding:0 16px}
.gt{aspect-ratio:1;border-radius:10px;position:relative;overflow:hidden}
.gt .nm{position:absolute;left:10px;right:10px;bottom:10px;color:#fff;font-size:13px;font-weight:600;text-shadow:0 1px 2px rgba(0,0,0,.6)}
.gt.fb{background:#E9E9EB;display:flex;align-items:center;justify-content:center;color:#848B92}
.gt.fb .nm{color:#000;text-shadow:none}
.ring{position:relative;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:700;flex:none}
.ring::before{content:"";position:absolute;inset:var(--st);border-radius:50%;background:#fff}
.ring b{position:relative}
.ring.sm{width:32px;height:32px;font-size:13px;--st:3px}
.ring.lg{width:72px;height:72px;font-size:26px;--st:6px}
.ring.easy{background:conic-gradient(#34C759 var(--p),#EFEFF1 0);color:#1F7A35}
.ring.mod{background:conic-gradient(#FF9500 var(--p),#EFEFF1 0);color:#C93400}
.ring.hard{background:conic-gradient(#FF3B30 var(--p),#EFEFF1 0);color:#D70015}
.stars{display:flex;gap:4px}
.stars i{display:block;width:16px;height:16px;background:#C7C7CC;clip-path:polygon(50% 0%,61% 35%,98% 35%,68% 57%,79% 91%,50% 70%,21% 91%,32% 57%,2% 35%,39% 35%)}
.stars i.on{background:#FF9500}
.stars.big{gap:8px}
.stars.big i{width:30px;height:30px}
.av{width:72px;height:72px;border-radius:50%;background:#E9E9EB;display:flex;align-items:center;justify-content:center;font-size:28px;font-weight:600;color:#6D6D72;flex:none}
.av.s{width:44px;height:44px;font-size:18px}
.av.m{width:56px;height:56px;font-size:22px}
.lbl{margin-top:12px;font-size:13px;font-weight:600;color:#6D6D72;text-transform:uppercase;letter-spacing:.5px}
.hint{font-size:13px;color:#6D6D72}
.dash{border:1px dashed #C7C7CC;border-radius:10px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;padding:16px;color:#6D6D72;font-size:13px}
.sl{flex:1;height:28px;position:relative;display:flex;align-items:center}
.sl .tr{height:4px;width:100%;background:#E5E5EA;border-radius:2px;overflow:hidden}
.sl .fl{height:100%;background:#34C759;width:var(--v)}
.sl .fm{position:absolute;top:8px;width:2px;height:12px;background:#C7C7CC;left:var(--f)}
.sl .tb{position:absolute;top:0;left:calc(var(--v) - 14px);width:28px;height:28px;border-radius:50%;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.3)}
.stp{display:flex;align-items:center;gap:12px;font-size:17px;font-weight:600}
.stp i{width:28px;height:28px;border-radius:50%;background:#EFEFF1;display:flex;align-items:center;justify-content:center;color:#000}
.backdrop{position:absolute;inset:0;background:rgba(0,0,0,.4)}
.sheet{position:absolute;left:0;right:0;bottom:0;background:#fff;border-radius:16px 16px 0 0;padding:8px 16px 32px;display:flex;flex-direction:column;gap:10px}
.sheet h3{font-size:17px;font-weight:600}
.handle{width:36px;height:5px;border-radius:3px;background:#C7C7CC;margin:0 auto}
.scard{background:#F2F2F7;border-radius:10px;padding:14px;display:flex;flex-direction:column;gap:10px;align-items:center}
.bar{display:flex;align-items:center;gap:12px;padding:10px 16px;border-top:.5px solid #E5E5EA;background:#fff}
.foot{position:absolute;left:0;right:0;bottom:0;padding:12px 16px 40px;background:rgba(242,242,247,.97);border-top:.5px solid #E5E5EA;display:flex;gap:10px}
.foot .btn{flex:1}
.kacc{position:absolute;left:0;right:0;bottom:0;height:56px;background:#D1D3D9;display:flex;align-items:center;justify-content:space-between;padding:0 12px 8px}
.strip{position:absolute;top:0;bottom:0;width:78px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:5px;color:#fff;font-size:12px;font-weight:600}
.strip.lead{left:0;background:#007AFF}
.lift{position:absolute;left:24px;right:24px;background:#fff;border-radius:10px;box-shadow:0 8px 24px rgba(0,0,0,.25);transform:rotate(-1.5deg) scale(1.02)}
.dots{display:flex;gap:6px;justify-content:center}
.dots i{width:7px;height:7px;border-radius:50%;background:#C7C7CC}
.dots i.on{background:#000}
.tabbar{position:absolute;left:0;right:0;bottom:0;height:83px;background:#fff;border-top:.5px solid #E5E5EA;display:flex;justify-content:space-around;padding:6px 8px 0}
.tab{display:flex;flex-direction:column;align-items:center;gap:3px;width:64px;font-size:10px;font-weight:500;color:#8E8E93}
.tab.on{color:var(--c)}
.ti{width:24px;height:24px;position:relative}
.ti::before,.ti::after{content:"";position:absolute}
.ti.pan::before{left:2px;right:2px;top:4px;height:7px;border:1.8px solid;border-radius:2px}
.ti.pan::after{left:2px;right:2px;top:13px;height:7px;border:1.8px solid;border-radius:2px}
.ti.lst::before{inset:2px;border:1.8px solid;border-radius:5px}
.ti.lst::after{left:8px;top:5px;width:5px;height:10px;border-right:1.8px solid;border-bottom:1.8px solid;transform:rotate(45deg)}
.ti.add::before{inset:1px;border:1.8px solid;border-radius:50%}
.ti.add::after{inset:1px;background:linear-gradient(currentColor,currentColor) center/1.8px 11px no-repeat,linear-gradient(currentColor,currentColor) center/11px 1.8px no-repeat}
.ti.bk::before{inset:3px 3px;border:1.8px solid;border-radius:3px}
.ti.bk::after{left:11px;top:3px;width:1.8px;height:18px;background:currentColor}
.ti.per::before{inset:1px;border:1.8px solid;border-radius:50%}
.ti.per::after{left:8px;top:5px;width:8px;height:8px;border:1.8px solid;border-radius:50%}
.ic{display:inline-block;width:20px;height:20px;position:relative;flex:none;color:inherit}
.ic::before,.ic::after{content:"";position:absolute}
.ic.s15{transform:scale(.75)}
.ic.s26{transform:scale(1.3)}
.ic.plus::before{left:9px;top:3px;width:2px;height:14px;background:currentColor;border-radius:1px}
.ic.plus::after{left:3px;top:9px;width:14px;height:2px;background:currentColor;border-radius:1px}
.ic.minus::after{left:4px;top:9px;width:12px;height:2px;background:currentColor;border-radius:1px}
.ic.more::before{left:8.5px;top:8.5px;width:3px;height:3px;border-radius:50%;background:currentColor;box-shadow:-6px 0 0 currentColor,6px 0 0 currentColor}
.ic.morec::before{inset:0;border:1.5px solid;border-radius:50%}
.ic.morec::after{left:8.5px;top:8.5px;width:3px;height:3px;border-radius:50%;background:currentColor;box-shadow:-5px 0 0 currentColor,5px 0 0 currentColor}
.ic.x::before,.ic.x::after{left:9px;top:3px;width:2px;height:14px;background:currentColor;border-radius:1px;transform:rotate(45deg)}
.ic.x::after{transform:rotate(-45deg)}
.ic.heart{background:currentColor;clip-path:polygon(50% 92%,12% 56%,5% 38%,9% 22%,22% 11%,37% 12%,50% 25%,63% 12%,78% 11%,91% 22%,95% 38%,88% 56%)}
.ic.heart.o::after{inset:3px;background:#fff;clip-path:polygon(50% 92%,12% 56%,5% 38%,9% 22%,22% 11%,37% 12%,50% 25%,63% 12%,78% 11%,91% 22%,95% 38%,88% 56%)}
.ic.flag::before{left:5px;top:2px;width:1.8px;height:16px;background:currentColor}
.ic.flag::after{left:6px;top:2px;width:10px;height:8px;border:1.8px solid;border-left:none;border-radius:0 2px 2px 0}
.ic.pen::before{left:8px;top:1px;width:5px;height:16px;border:1.8px solid;border-radius:2px 2px 0 0;transform:rotate(45deg);clip-path:polygon(0 0,100% 0,100% 78%,50% 100%,0 78%)}
.ic.fold::before{left:2px;top:6px;width:16px;height:11px;border:1.8px solid;border-radius:2px}
.ic.fold::after{left:2px;top:3px;width:7px;height:5px;border:1.8px solid;border-bottom:none;border-radius:2px 2px 0 0}
.ic.link::before,.ic.link::after{width:10px;height:5px;border:1.5px solid;border-radius:3px;transform:rotate(-45deg)}
.ic.link::before{left:2px;top:10px}
.ic.link::after{left:8px;top:5px}
.ic.bask::before{left:2px;right:2px;top:8px;height:9px;border:1.8px solid;border-top-width:2.5px;border-radius:0 0 4px 4px}
.ic.bask::after{left:6px;top:3px;width:8px;height:6px;border:1.8px solid;border-bottom:none;border-radius:5px 5px 0 0}
.ic.mag::before{left:2px;top:2px;width:12px;height:12px;border:2px solid;border-radius:50%}
.ic.mag::after{left:14px;top:12px;width:2px;height:7px;background:currentColor;transform:rotate(-45deg);border-radius:1px}
.ic.sort::before{left:3px;top:5px;width:6px;height:6px;border-left:1.8px solid;border-top:1.8px solid;transform:rotate(45deg)}
.ic.sort::after{left:11px;top:9px;width:6px;height:6px;border-right:1.8px solid;border-bottom:1.8px solid;transform:rotate(45deg)}
.ic.cam::before{left:1px;right:1px;top:5px;bottom:3px;border:1.8px solid;border-radius:3px}
.ic.cam::after{left:6px;top:8px;width:8px;height:8px;border:1.8px solid;border-radius:50%}
.ic.trash::before{left:4px;right:4px;top:6px;bottom:2px;border:1.8px solid;border-top:none;border-radius:0 0 3px 3px}
.ic.trash::after{left:2px;right:2px;top:4px;height:1.8px;background:currentColor}
.ic.ck::before{left:6px;top:3px;width:6px;height:11px;border-right:2px solid;border-bottom:2px solid;transform:rotate(45deg)}
.ic.circ::before{inset:3px;border:1.5px solid;border-radius:50%}
.ic.ckc{background:currentColor;border-radius:50%}
.ic.ckc::before{left:7px;top:3px;width:5px;height:10px;border-right:2px solid #fff;border-bottom:2px solid #fff;transform:rotate(45deg)}
.ic.clk::before{inset:2px;border:1.8px solid;border-radius:50%}
.ic.clk::after{left:9px;top:5px;width:1.8px;height:6px;background:currentColor;box-shadow:1.5px 4.5px 0 -0.3px currentColor}
.ic.open::before{left:8px;top:4px;width:8px;height:8px;border-top:1.8px solid;border-right:1.8px solid}
.ic.open::after{left:4px;top:10px;width:14px;height:1.8px;background:currentColor;transform:rotate(-45deg)}
.ic.fk::before{left:6px;top:3px;width:1.8px;height:14px;background:currentColor}
.ic.fk::after{left:12px;top:3px;width:1.8px;height:14px;background:currentColor}
.ic.ppl::before{left:2px;top:5px;width:8px;height:8px;border:1.8px solid;border-radius:50%}
.ic.ppl::after{left:10px;top:7px;width:7px;height:7px;border:1.8px solid;border-radius:50%}
.ic.glb::before{inset:2px;border:1.8px solid;border-radius:50%}
.ic.glb::after{left:7px;top:2px;width:6px;height:16px;border:1.8px solid;border-radius:50%}
.ic.clip::before{left:4px;top:3px;width:12px;height:15px;border:1.8px solid;border-radius:2px}
.ic.clip::after{left:7px;top:1px;width:6px;height:4px;border:1.8px solid;border-radius:2px;background:#fff}
.tri{display:inline-block;width:0;height:0;border-left:7px solid currentColor;border-top:4.5px solid transparent;border-bottom:4.5px solid transparent}
.icb{width:44px;height:44px;display:flex;align-items:center;justify-content:center;flex:none}
.itile{width:29px;height:29px;border-radius:7px;display:flex;align-items:center;justify-content:center;color:#fff;flex:none;font-size:14px}
'''


def scoped(css):
    rules = []
    for sel, body in re.findall(r'([^{}]+)\{([^{}]*)\}', css):
        sels = [s.strip() for s in sel.split(',')]
        sels = [s if s.startswith('.screen') else '.screen ' + s for s in sels]
        rules.append(','.join(sels) + '{' + body.strip() + '}')
    lines, cur = [], ''
    for r in rules:
        if cur and len(cur) + len(r) > 170:
            lines.append(cur); cur = r
        else:
            cur = (cur + r) if cur else r
    if cur: lines.append(cur)
    return '\n'.join(lines)


CSS = scoped(CSS_SRC)


def page(parts):
    return '<style>\n' + CSS + '\n</style>\n<div class="screen">\n' + '\n'.join(parts) + '\n</div>\n'


# ---------------------------------------------------------------- fragment helpers
SB = ('<div class="sb"><span>9:41</span><span class="sbr"><span class="sig"><i style="height:4px"></i><i style="height:6px"></i>'
      '<i style="height:8px"></i><i style="height:11px"></i></span><span class="wifi"></span><span class="bat"><i></i></span></span></div>')
HI = '<span class="hi"></span>'
CHEV = '<i class="chev"></i>'
TABS = [('pan', 'Pantry', '#1F7A35'), ('lst', 'Lists', '#1668A0'), ('add', 'Add', '#B04517'), ('bk', 'Recipes', '#7A3FA8'), ('per', 'Profile', '#525D6E')]


def tabbar(active):
    tabs = ''.join(f'<div class="tab{" on" if k == active else ""}" style="--c:{c}"><span class="ti {k}"></span>{l}</div>' for k, l, c in TABS)
    return f'<div class="tabbar">{tabs}</div>' + HI


def lt(title, right=''):
    return f'<div class="lt"><h1>{title}</h1>{right}</div>'


def nav(title, right='', back=True):
    b = '<span class="back"><i class="i-back"></i></span>' if back else '<span class="back"></span>'
    return f'<div class="nav">{b}<span class="ttl">{title}</span><span class="rt">{right}</span></div>'


def sh(title, count=None, right='', cls=''):
    c = f'<b>{count}</b>' if count is not None else ''
    return f'<div class="sh{" " + cls if cls else ""}"><span>{title}</span>{c}{right}</div>'


def act(label, icon=''):
    return f'<span class="act">{icon}{label}</span>'


def grp(*rows, cls='', style=''):
    st = f' style="{style}"' if style else ''
    return f'<div class="grp{" " + cls if cls else ""}"{st}>' + ''.join(rows) + '</div>'


def ic(name, extra=''):
    return f'<i class="ic {name}{" " + extra if extra else ""}"></i>'


def cap(kind):
    return f'<span class="cap {kind}">{"Out" if kind == "out" else "Low"}</span>'


def grow(name, glyph, kind=None, checked=False, strike=None, sub=None, trailing='', dim=False):
    """A GroceryRow: checkbox · category tile · name (· caption) · cap · trailing."""
    strike = checked if strike is None else strike
    text = f'<span class="t16{" strike" if strike else ""}">{name}</span>' + (f'<span class="c13">{sub}</span>' if sub else '')
    return (f'<div class="row{" dim" if dim else ""}" style="--ins:93px"><span class="chk{" on" if checked else ""}"></span>'
            f'<span class="tile{" dim" if checked else ""}">{glyph}</span><span class="grow col" style="gap:1px">{text}</span>{cap(kind) if kind else ""}{trailing}</div>')


def sugg(name, glyph, kind):
    return f'<div class="row" style="--ins:59px"><span class="tile">{glyph}</span><span class="grow t16">{name}</span>{cap(kind)}{ic("plus", "acc")}</div>'


def cart_hdr(count):
    return f'<div class="sh"><span>In your cart</span><b>{count}</b><span class="acc">{ic("morec")}</span></div>'


def restock_btn(n):
    return f'<div class="px" style="margin-top:12px;margin-bottom:4px"><div class="btn pri">{ic("bask")}Restock {n} to Kitchen</div></div>'


ADD_FIELD = '<div class="px" style="padding-top:12px;padding-bottom:8px"><div class="inp ph">Add to your list…</div></div>'
SUGGESTED = sh('Suggested', 2) + grp(sugg('Yogurt', '🥚', 'out'), sugg('Olive oil', '🫙', 'low'))


def srow(label, value='', lead='', chev=True, ins=16, extra=''):
    v = f'<span class="mu">{value}</span>' if value else ''
    return f'<div class="row" style="--ins:{ins}px">{lead}<span class="grow">{label}</span>{v}{extra}{CHEV if chev else ""}</div>'


def ring(v, size='sm'):
    band = 'easy' if v < 4 else 'mod' if v < 7 else 'hard'
    return f'<span class="ring {size} {band}" style="--p:{v * 10:.0f}%"><b>{v:g}</b></span>'


def stars(n, big=False):
    return f'<span class="stars{" big" if big else ""}">' + ''.join('<i class="on"></i>' if i < n else '<i></i>' for i in range(5)) + '</span>'


def th(g, big=False):
    if g == 'fb':
        return f'<span class="th fb{" big" if big else ""}">{ic("fk")}</span>'
    return f'<span class="th {g}{" big" if big else ""}"></span>'


def chip(label, cls=''):
    return f'<span class="chip{" " + cls if cls else ""}">{label}</span>'


def chips(*cs, line=False):
    return f'<div class="chips{" line" if line else ""}">' + ''.join(cs) + '</div>'


def btn(label, cls='pri', icon='', style=''):
    st = f' style="{style}"' if style else ''
    return f'<div class="btn {cls}"{st}>{icon}{label}</div>'


def mchips(*names):
    return '<span style="display:flex;gap:6px;margin-top:2px">' + ''.join(f'<span class="mchip">{n}</span>' for n in names) + '</span>'


def rcard(g, title, meta, right='', chipsx='', badge=''):
    """RecipeRowItem / CookList card: bordered card, 44 thumb, title, one meta line, optional missing chips, ring, chevron."""
    return (f'<div class="card">{th(g)}<span class="grow col" style="gap:2px"><span class="b">{title}</span><span class="c13">{meta}</span>{chipsx}</span>'
            f'{badge}{right}{CHEV}</div>')


def rrow(g, title, meta, right='', chipsx=''):
    """The same content as an inset GroupedRow (the direction mocks' row idiom)."""
    return f'<div class="row" style="--ins:72px">{th(g)}<span class="grow col" style="gap:2px"><span class="b">{title}</span><span class="c13">{meta}</span>{chipsx}</span>{right}{CHEV}</div>'


def rating_line(n, text):
    return f'<div style="display:flex;align-items:center;gap:6px">{stars(n)}<span class="c13">{text}</span></div>'


def steprow(n, text):
    return f'<div class="row" style="--ins:16px;align-items:flex-start"><span class="mu" style="width:20px">{n}.</span><span class="grow">{text}</span></div>'


STEPS = ['Whisk the flour and eggs together.', 'Add the milk, then rest the batter for 10 minutes.',
         'Melt the butter in a pan over medium heat.', 'Ladle in the batter and cook 2 minutes a side until golden.',
         'Stack and serve warm.']
BIO = 'Weeknight cooking from whatever is already in the fridge. Wellington on Sundays.'


def cookcard(i, text, state='todo', chipx=''):
    """Cook-mode step card. state: done · now · todo · dim."""
    icon = ic('ckc', 'acc s26') if state == 'done' else ic('circ', 'fa s26')
    op = {'done': 'opacity:.7', 'dim': 'opacity:.45'}.get(state, '')
    tx = 'color:#6D6D72;text-decoration:line-through' if state == 'done' else ''
    return (f'<div class="card" style="align-items:flex-start;gap:12px;padding:14px;{op}">{icon}<span class="grow col" style="gap:4px">'
            f'<span class="lbl" style="margin:0">Step {i}</span><span style="font-size:19px;line-height:27px;{tx}">{text}</span>{chipx}</span></div>')


def slider(v, floor):
    return f'<div class="sl" style="--v:{v}%;--f:{floor}%"><div class="tr"><div class="fl"></div></div><i class="fm"></i><i class="tb"></i></div>'


def stepper(n):
    return f'<span class="stp"><i>{ic("minus")}</i>{n}<i>{ic("plus")}</i></span>'


def ccard(g, title, byline, tags, right):
    """CommunityCard: 64 photo, title, byline · meta, tags, ring."""
    return (f'<div class="card" style="gap:12px">{th(g, True)}<span class="grow col" style="gap:3px"><span class="t16 b">{title}</span>'
            f'<span class="c13">{byline}</span><span class="c13">{tags}</span></span>{right}</div>')


# ================================================================ 1. Lists tab
def lists_today():
    return [SB, lt('Lists'), ADD_FIELD,
            sh('To buy', 3), grp(grow('Apples', '🥬', 'low'), grow('Butter', '🥚', 'out'), grow('Bread', '🌾')),
            cart_hdr(1), grp(grow('Milk', '🥚', checked=True)), restock_btn(1),
            SUGGESTED, tabbar('lst')]


def lists_a():
    right = f'<div class="btn tint sm" style="margin-bottom:6px">{ic("bask")}Restock 1</div>'
    ghost = '<div class="row" style="--ins:93px;opacity:.3"><span class="chk"></span><span class="tile">🧁</span><span class="grow t16">Bread</span></div>'
    target = '<div class="row" style="min-height:51px;justify-content:center"><span class="c13 acc b">Drop here — Ambry files Bread here for Test Home from now on</span></div>'
    return [SB, lt('Lists', right),
            '<div class="px" style="padding-top:12px"><div class="srch">' + ic('mag') + 'Add to your list…</div></div>',
            sh('Produce', 1), grp(grow('Apples', '🥬', 'low')),
            sh('Dairy & Eggs', 1), grp(grow('Butter', '🥚', 'out')),
            sh('Baking', 1), grp(ghost),
            sh('Grains & Pasta', 0), grp(target, cls='tgt'),
            sh('Bought', 1, right=f'<span class="acc">{ic("morec")}</span>'),
            grp('<div class="row" style="--ins:16px"><span class="grow acc b">Show 1 bought</span><i class="chev dn"></i></div>'),
            SUGGESTED,
            '<div class="lift" style="top:448px">' + grow('Bread', '🧁') + '</div>',
            tabbar('lst')]


def lists_b():
    strip = chips(chip('Milk'), chip('Eggs'), chip('Bananas'), chip('Bread'), chip('Yogurt <span class="cap out" style="padding:0 6px;font-size:11px">Out</span>'),
                  chip('Olive oil <span class="cap low" style="padding:0 6px;font-size:11px">Low</span>'), chip('Coffee'), chip('Rice'),
                  chip('Onions'), chip('Cheese'), chip('Pasta'), chip('Tomatoes'))
    add = grp(f'<div class="row" style="--ins:59px"><span class="tile">{ic("plus", "mu")}</span><span class="grow t16 ph">Add something else…</span></div>', style='margin-top:12px')
    return [SB, lt('Lists'), sh('Buy again', 12), '<div class="px">' + strip + '</div>', add,
            sh('To buy', 3), grp(grow('Apples', '🥬', 'low'), grow('Butter', '🥚', 'out'), grow('Bread', '🌾')),
            cart_hdr(1), grp(grow('Milk', '🥚', checked=True)), restock_btn(1),
            tabbar('lst')]


def lists_c():
    panel = ('<div style="position:absolute;left:0;right:0;bottom:83px;background:#fff;border-radius:16px 16px 0 0;padding-top:8px">'
             '<div class="handle"></div><div class="grp" style="margin:12px 16px 8px;background:#F2F2F7">'
             + grow('Milk', '🥚', checked=True, strike=False, sub='Tap to put it back on the list')
             + f'<div class="row" style="--ins:16px"><span class="red">{ic("trash")}</span><span class="grow red">Clear without restocking</span></div>'
             + '<div class="row" style="--ins:16px;justify-content:center"><span class="mu">Cancel</span></div></div>'
             f'<div class="bar"><span class="grow t16 b">In your cart <span class="mu" style="font-weight:400">· 1</span></span>{btn("Restock", "pri", ic("bask"))}</div></div>')
    return [SB, lt('Lists'), ADD_FIELD,
            sh('To buy', 3), grp(grow('Apples', '🥬', 'low'), grow('Butter', '🥚', 'out'), grow('Bread', '🌾')),
            SUGGESTED, '<div class="backdrop" style="bottom:83px"></div>', panel, tabbar('lst')]


# ================================================================ 2. Restock review
def revrow(name, loc, expiry, catg=None, checked=True):
    """CaptureReviewList row: checkbox · name · [location chip · expiry] · category."""
    meta = f'<span style="display:flex;align-items:center;gap:8px;flex-wrap:wrap">{chip(loc)}<span class="c13">{expiry}</span></span>'
    catx = f'<span class="c13">{catg}</span>' if catg else ''
    return (f'<div class="row{"" if checked else " dim"}" style="--ins:50px;align-items:flex-start"><span class="chk{" on" if checked else ""}" style="margin-top:4px"></span>'
            f'<span class="grow col" style="gap:6px"><span class="t16">{name}</span>{meta}{catx}</span></div>')


def restock_today():
    head = ('<div class="pad" style="gap:10px"><div class="t17">4 bought items</div><div style="display:flex;justify-content:space-between;align-items:center">'
            + btn('Put everything in…', 'bord sm') + '<span class="c13" style="display:flex;align-items:center;gap:6px"><span class="chk s on"></span>3 of 4</span></div></div>')
    return [SB, nav('Restock'), head,
            grp(revrow('Milk', '🧊 Fridge', 'expires Sep 12 · 7d', 'Dairy & Eggs'), revrow('Butter', '🧊 Fridge', 'expires Nov 4 · 60d', 'Dairy & Eggs'),
                revrow('Bread', '🥫 Pantry', 'expires Sep 10 · 5d', 'Grains & Pasta')),
            '<div class="c13 b" style="padding:16px 16px 6px">Not adding 1 — tick to include</div>',
            grp(revrow('Dish soap', '🥫 Pantry', 'no expiry estimate', None, checked=False)),
            '<div class="foot">' + btn('Add 3 items to pantry', 'pri lg') + '</div>', HI]


def restock_a():
    cart = grp(grow('Milk', '🥚', checked=True, strike=False, sub='expires Sep 12 · 7d', trailing=chip('🧊 Fridge')),
               grow('Butter', '🥚', checked=True, strike=False, sub='expires Nov 4 · 60d', trailing=chip('🧊 Fridge')),
               grow('Dish soap', '🛒', checked=True, strike=False, sub='Not in the catalog', trailing='<span class="cap out">Skip</span>', dim=True))
    return [SB, lt('Lists'), ADD_FIELD,
            sh('To buy', 2), grp(grow('Apples', '🥬', 'low'), grow('Bread', '🌾')),
            cart_hdr(3), cart, '<div class="px" style="margin-top:12px">' + btn('Add 2 to pantry', 'pri') + '</div>',
            SUGGESTED, tabbar('lst')]


def destrow(name, expiry, checked=True, shift=0):
    st = f'--ins:50px;{"transform:translateX(78px);background:#fff;" if shift else ""}'
    return (f'<div class="row{"" if checked else " dim"}" style="{st}"><span class="chk{" on" if checked else ""}"></span>'
            f'<span class="grow col" style="gap:1px"><span class="t16">{name}</span><span class="c13">{expiry}</span></span></div>')


def restock_b():
    move = act('Move all…')
    swiped = grp('<div class="strip lead"><i class="chev" style="border-color:#fff;transform:rotate(135deg)"></i>Fridge</div>' + destrow('Bread', 'expires Sep 10 · 5d', shift=78))
    return [SB, nav('Restock'), '<div class="pad" style="padding-bottom:0"><div class="t17">4 bought items</div></div>',
            sh('Fridge', 2, right=move), grp(destrow('Milk', 'expires Sep 12 · 7d'), destrow('Butter', 'expires Nov 4 · 60d')),
            sh('Pantry', 1, right=move), swiped,
            sh('Freezer', 0), grp('<div class="row" style="justify-content:center;min-height:52px"><span class="c13" style="border:1.5px dashed #C7C7CC;border-radius:8px;padding:6px 12px">Nothing headed here — swipe or drag a row to move it</span></div>'),
            sh('Not adding', 1), grp(destrow('Dish soap', 'Not in the catalog · tick to include', checked=False)),
            '<div class="foot">' + btn('Add 3 items to pantry', 'pri lg') + '</div>', HI]


def restock_c():
    def line(glyph, title, sub, muted=False):
        return (f'<div class="row" style="--ins:59px"><span class="tile">{glyph}</span><span class="grow col" style="gap:1px">'
                f'<span class="t16{" mu" if muted else ""}">{title}</span><span class="c13">{sub}</span></span></div>')
    sheet = ('<div class="sheet"><div class="handle"></div><h3>Add 3 to your pantry</h3>'
             + grp(line('🧊', '2 to Fridge', 'Milk · Butter'), line('🥫', '1 to Pantry', 'Bread'), line('🛒', 'Skipping 1: Dish soap', 'Not in the catalog — review to include it', True), style='margin:0;background:#F2F2F7')
             + btn('Add to pantry', 'pri lg') + btn('Review first…', 'bord') + btn('Cancel', 'sec') + '</div>')
    return [SB, lt('Lists'), ADD_FIELD,
            sh('To buy', 1), grp(grow('Apples', '🥬', 'low')),
            cart_hdr(4), grp(grow('Milk', '🥚', checked=True), grow('Butter', '🥚', checked=True), grow('Bread', '🌾', checked=True), grow('Dish soap', '🛒', checked=True)),
            restock_btn(4), tabbar('lst'), '<div class="backdrop"></div>', sheet]


# ================================================================ 3. Recipes tab
def recipes_today():
    head = ('<div style="display:flex;justify-content:space-between;align-items:center;margin-top:4px"><span style="font-size:18px;font-weight:600">My recipes</span>'
            f'<span style="display:flex;align-items:center;gap:14px">{ic("sort", "mu")}{btn("+ Add recipe")}</span></div>')
    folders = f'<div class="card"><span class="itile" style="background:#E4F7E9;width:32px;height:32px;border-radius:8px;color:#1F7A35">{ic("fold")}</span><span class="grow b">Folders</span><span class="mu">1</span>{CHEV}</div>'
    return [SB, lt('Recipes'), '<div class="pad">',
            '<div class="seg"><span>Cook</span><span class="on">My recipes</span><span>Community</span></div>', head, folders,
            '<div class="sh flush" style="padding:12px 0 6px"><span>Yours</span></div>',
            rcard('g1', 'Test Pancakes', 'Breakfast · Quick · 20 min · ★ 4.0 (1)', ring(2.5), badge='<span class="badge">Household</span>'),
            rcard('fb', 'Banana custard', '25 min'),
            '<div class="sh flush" style="padding:12px 0 6px"><span>Favorites</span></div>',
            rcard('g2', 'Wellington', 'by Everett · 2 h 30 min · ★ 4.8 (12)', ring(7.5)),
            '</div>', tabbar('bk')]


def recipes_a():
    right = f'<span style="display:flex;gap:20px;align-items:center;padding-bottom:8px">{ic("mag", "s26")}{ic("plus", "s26")}</span>'
    return [SB, lt('Recipes', right),
            '<div class="px" style="padding-top:12px">' + chips(chip('Under 30 min'), chip('Uses expiring'), chip('Favorites')) + '</div>',
            '<div class="px" style="padding-top:10px">' + btn('✨ Ask for ideas for your 1 expiring item', 'tint') + '</div>',
            sh('You can make', 1), grp(rrow('g4', 'Banana custard', '25 min · ✓ You have everything · uses 1 expiring item')),
            sh('Almost there', 2), grp(rrow('g1', 'Test Pancakes', '20 min · Missing 1 ingredient', ring(2.5), mchips('Butter')),
                                       rrow('g2', 'Wellington', '2 h 30 min · Missing 2 ingredients', ring(7.5), mchips('Beef', 'Pastry'))),
            sh('Library'), grp(srow('My recipes', '3'), srow('Folders', '1'), srow('Community')),
            tabbar('bk')]


def recipes_b():
    def tile(bg, inner):
        return f'<span class="itile" style="background:{bg}">{inner}</span>'
    menu = grp(srow('What can I make', '1', tile('#34C759', ic('ck')), ins=57), srow('Favorites', '1', tile('#FF3B30', ic('heart', 's15')), ins=57),
               srow('Recent', '', tile('#007AFF', ic('clk')), ins=57), srow('Folders', '1', tile('#FF9500', ic('fold')), ins=57),
               srow('Household', '1', tile('#525D6E', ic('ppl')), ins=57), srow('Community', '', tile('#7A3FA8', ic('glb')), ins=57),
               srow('Ideas', '3 left this month', tile('#B04517', '✨'), ins=57), style='margin-top:16px')
    return [SB, lt('Recipes', f'<span style="padding-bottom:8px">{ic("plus", "s26")}</span>'),
            '<div class="px" style="padding-top:12px"><div class="srch">' + ic('mag') + 'Search all your recipes</div></div>', menu,
            grp(srow('Add a recipe', '', tile('#000', ic('plus')), ins=57), style='margin-top:24px'),
            '<div class="c13" style="padding:8px 32px">Every row opens a plain recipe list; search covers titles and ingredients across all of them.</div>',
            tabbar('bk')]


def recipes_c():
    right = f'<span style="display:flex;gap:20px;align-items:center;padding-bottom:8px">{ic("plus", "s26")}{ic("more", "s26")}</span>'
    return [SB, lt('Recipes', right),
            '<div class="px" style="padding-top:12px"><div class="srch">' + ic('mag') + 'Search recipes</div></div>',
            '<div class="px" style="padding-top:8px">' + chips(chip('All', 'on'), chip('Can make'), chip('Almost'), chip('Favorites'), chip('Folder…'), chip(ic('ppl') + 'Community', 'tint')) + '</div>',
            '<div class="pad" style="gap:6px">',
            rcard('g4', 'Banana custard', '✓ You have everything · 25 min · uses 1 expiring item'),
            rcard('g1', 'Test Pancakes', 'Missing Butter · 20 min · ★ 4.0 (1)', ring(2.5), badge='<span class="badge">Household</span>'),
            rcard('g2', 'Wellington', 'Missing Beef, Pastry · 2 h 30 min · by Everett · ★ 4.8 (12)', ring(7.5)),
            '</div>', tabbar('bk')]


# ================================================================ 4. Recipe detail
PHOTO = '<div class="photo g1"><span class="capn">Photo · Test Pancakes</span></div>'
TITLE = f'<div style="display:flex;align-items:center;gap:12px"><span class="grow t22" style="margin-top:4px">Test Pancakes</span>{ring(2.5, "lg")}</div>'
META = '<div class="c13">Serves 4 · 20 min · Household</div>'
RATING = rating_line(4, '4.0 · 1 rating')
DESC = '<div class="soft">Sunday-morning pancakes from the test kitchen.</div>'


def ingline(text, ok=True):
    return f'<div style="display:flex;align-items:center;gap:8px">{ic("ck", "suc s15") if ok else ic("circ", "warn s15")}<span class="grow{"" if ok else " mu"}">{text}</span>{ic("link", "acc s15")}</div>'


def detail_today():
    steps = ''.join(f'<div style="display:flex;gap:8px"><span class="mu">{i + 1}.</span><span class="grow" style="line-height:22px">{s}</span></div>' for i, s in enumerate(STEPS[:3]))
    return [SB, nav('Test Pancakes', ic('heart', 'o') + ic('fold') + ic('pen')), '<div class="pad">', PHOTO, TITLE, META, RATING, DESC,
            chips(chip('Breakfast'), chip('Quick')),
            '<div class="lbl" style="margin-top:16px">Ingredients</div>',
            '<div class="seccard">' + ingline('1 cup Flour') + ingline('2 Eggs') + ingline('1 cup Milk') + ingline('2 tbsp Butter', ok=False) + '</div>',
            '<div class="lbl" style="margin-top:16px">Steps</div>', '<div class="seccard">' + steps + '</div>',
            '</div>', HI]


def irow(text, ok=True, trailing=''):
    return f'<div class="row" style="--ins:48px">{ic("ck", "suc s15") if ok else ic("circ", "warn s15")}<span class="grow{"" if ok else " mu"}">{text}</span>{ic("link", "acc s15")}{trailing}</div>'


def detail_a():
    addbtn = f'<span class="icb" style="width:32px;height:32px;border-radius:50%;background:#E4F7E9;border:1px solid #A7DBB6;color:#1F7A35">{ic("plus", "s15")}</span>'
    return [SB, nav('', ic('heart', 'o') + ic('more')), '<div class="pad" style="padding-bottom:0">', PHOTO, TITLE, META, RATING, DESC, '</div>',
            sh('Ingredients', right=act('Tap a missing one to add it')),
            grp(irow('1 cup Flour'), irow('2 Eggs'), irow('1 cup Milk'), irow('2 tbsp Butter', ok=False, trailing=addbtn)),
            sh('Steps'), grp(steprow(1, STEPS[0]), steprow(2, STEPS[1])),
            '<div class="foot">' + btn('Start cooking', 'pri lg') + btn('Add 1 missing', 'tint lg') + '</div>', HI]


def detail_b():
    hero = ('<div style="display:flex;gap:12px;align-items:center"><div class="photo g1" style="width:120px;height:90px;aspect-ratio:auto;flex:none"><span class="capn">Photo</span></div>'
            f'<span class="grow col" style="gap:4px"><span class="t17">Test Pancakes</span><span class="c13">Serves 4 · 20 min · Household</span>{RATING}</span>{ring(2.5)}</div>')
    def card(i, text, chipx=''):
        return f'<div class="card v"><span class="lbl" style="margin:0">Step {i}</span><span>{text}</span>{chipx}</div>'
    timer = lambda m: '<div style="display:flex">' + chip(ic('clk', 's15') + f'{m} min <i class="tri"></i>', 'tint') + '</div>'
    return [SB, nav('', ic('heart', 'o') + ic('more')), '<div class="pad" style="gap:12px">', hero,
            '<div class="seg"><span>Ingredients</span><span class="on">Steps</span></div>',
            card(1, STEPS[0]), card(2, STEPS[1], timer(10)), card(3, STEPS[2]), card(4, STEPS[3], timer(2)), card(5, STEPS[4]),
            '</div>', '<div class="foot">' + btn('Start cooking', 'pri lg') + '</div>', HI]


def detail_c():
    hero = ('<div class="grp" style="margin-top:12px"><div class="g1" style="height:140px;position:relative"><span class="capn">Photo · Test Pancakes</span></div>'
            f'<div style="padding:12px 16px;display:flex;flex-direction:column;gap:6px"><div style="display:flex;align-items:center;gap:12px"><span class="grow t22">Test Pancakes</span>{ring(2.5)}</div>'
            f'<div class="c13">Serves 4 · 20 min · Household</div>{RATING}</div></div>')
    def qrow(q, name, ok=True):
        return f'<div class="row" style="--ins:16px"><span class="mu" style="width:56px">{q}</span><span class="grow{"" if ok else " mu"}">{name}</span>{ic("ck", "suc s15") if ok else ic("circ", "warn s15")}</div>'
    return [SB, nav('', ic('heart', 'o') + ic('more')), hero,
            sh('Actions'), grp(srow('Start cooking'), srow('Add missing to list', '1'), f'<div class="row" style="--ins:16px"><span class="grow">Serves</span>{stepper(4)}</div>'),
            sh('Ingredients', right=act('Quantities follow Serves')), grp(qrow('1 cup', 'Flour'), qrow('2', 'Eggs'), qrow('1 cup', 'Milk'), qrow('2 tbsp', 'Butter', ok=False)),
            sh('Steps'), grp(steprow(1, STEPS[0])), HI]


# ================================================================ 5. Cook mode
def cook_today():
    cards = [cookcard(i + 1, s, 'done' if i == 0 else 'todo') for i, s in enumerate(STEPS)]
    return [SB, nav('Test Pancakes'), '<div class="lbl px" style="margin-top:12px">1 of 5 done</div>', '<div class="pad" style="gap:10px">',
            *cards, btn('Done cooking', 'pri lg', style='margin-top:6px'), '</div>', HI]


def cook_a():
    running = '<div style="display:flex;align-items:center;gap:8px;margin-top:4px">' + chip(ic('clk', 's15') + '7:12 left', 'on') + '<span class="c13">of 10 min · rings when done</span></div>'
    later = '<div style="display:flex;margin-top:4px">' + chip(ic('clk', 's15') + '2 min <i class="tri"></i>') + '</div>'
    return [SB, nav('Test Pancakes'),
            grp(f'<div class="row" style="--ins:16px"><span class="grow">Ingredients</span><span class="mu">4</span><i class="chev dn"></i></div>', style='margin-top:12px'),
            '<div class="lbl px" style="margin-top:12px">1 of 5 done</div>', '<div class="pad" style="gap:10px">',
            cookcard(1, STEPS[0], 'done'), cookcard(2, STEPS[1], 'now', running), cookcard(3, STEPS[2], 'dim'), cookcard(4, STEPS[3], 'dim', later), cookcard(5, STEPS[4], 'dim'),
            '</div>', '<div class="foot">' + btn('Finish (1 of 5)', 'pri lg') + '</div>', HI]


def cook_b():
    return [SB, nav('Test Pancakes'), '<div class="pad" style="gap:16px;padding-top:20px">',
            '<div style="display:flex;justify-content:space-between;align-items:center"><span class="lbl" style="margin:0">Step 2 of 5</span><span class="dots"><i></i><i class="on"></i><i></i><i></i><i></i></span></div>',
            f'<div style="font-size:24px;line-height:32px;font-weight:500">{STEPS[1]}</div>',
            '<div style="display:flex">' + chip(ic('clk', 's15') + '10 min <i class="tri"></i>', 'tint') + '</div>', '</div>',
            sh('This step uses'), grp('<div class="row" style="--ins:59px"><span class="tile">🥚</span><span class="grow t16">Milk</span><span class="mu">1 cup</span></div>'),
            '<div class="foot" style="flex-direction:column;gap:10px;background:#F2F2F7;border-top:none"><div class="c13" style="text-align:center">Swipe either way · Done replaces Next on step 5</div>'
            '<div style="display:flex;gap:10px"><div class="btn bord lg" style="flex:1;min-height:56px">Back</div><div class="btn pri lg" style="flex:2;min-height:56px">Next</div></div></div>', HI]


def cook_c():
    cards = [cookcard(i + 1, s, 'done') for i, s in enumerate(STEPS)]
    sheet = ('<div class="sheet" style="gap:12px"><div class="handle"></div>'
             f'<div class="scard"><span class="t17">How did it turn out?</span>{stars(4, True)}</div>'
             '<div class="scard" style="align-items:stretch"><span class="t17">Used anything up?</span><span class="c13">Tap once for Low, again for Out. Skip if nothing ran down.</span>'
             + chips(chip('Flour'), chip('Eggs · Low', 'warn'), chip('Milk · Out', 'out')) + '</div>'
             + btn('Done', 'pri lg') + '</div>')
    return [SB, nav('Test Pancakes'), '<div class="lbl px" style="margin-top:12px">5 of 5 done</div>', '<div class="pad" style="gap:10px">', *cards, '</div>',
            '<div class="backdrop"></div>', sheet, HI]


# ================================================================ 6. Editor, import, ideas
def ingedit(name, qty):
    return (f'<div class="col" style="gap:6px"><div style="display:flex;align-items:center;gap:8px">{ic("link", "acc")}<div class="inp grow">{name}</div>{ic("trash", "fa")}</div>'
            f'<div class="c13 acc" style="padding-left:28px">→ {name}</div><div style="display:flex;align-items:center;gap:8px"><div class="inp grow">{qty}</div>{chip("Optional")}'
            '<i class="chev up" style="border-color:#E5E5EA"></i><i class="chev dn" style="border-color:#3C3C43"></i></div></div>')


def editor_today():
    form = ('<div class="lbl">Title</div><div class="inp">Test Pancakes</div>'
            f'<div class="lbl">Photo</div><div class="dash">{ic("cam", "fa")}Add a photo</div>'
            '<div class="lbl">Servings</div><div class="inp" style="width:96px">4</div>'
            '<div class="lbl">Time</div><div class="hint">Start to plate, including time it just sits.</div>'
            '<div style="display:flex;align-items:center;gap:8px"><div class="inp" style="width:72px">0</div><span class="mu">h</span><div class="inp" style="width:72px">20</div><span class="mu">min</span><span class="c13 acc b" style="margin-left:4px">Clear</span></div>'
            '<div class="lbl">Difficulty</div><div class="hint">0 easiest — 10 hardest. More ingredients or a longer cook raise the starting point.</div>'
            f'<div style="display:flex;align-items:center;gap:8px"><span class="b" style="min-width:36px">2.5</span>{slider(25, 10)}<span class="c13 acc b">Clear</span></div>'
            '<div class="lbl">Tags</div><div class="hint">Tags are how you and other people find this later — a couple is plenty.</div>'
            + chips(chip('Breakfast ✕'), chip('Quick ✕')) + btn('Choose tags') + '<div class="inp ph">Or add your own…</div>'
            '<div class="lbl">Description</div><div class="inp">Sunday-morning pancakes from the test kitchen.</div>'
            '<div class="lbl">Ingredients</div>' + ingedit('Flour', '1 cup') + ingedit('Eggs', '2'))
    return [SB, nav('New recipe'),
            f'<div style="position:absolute;top:91px;left:0;right:0;bottom:0;overflow:hidden"><div class="pad" style="transform:translateY(-205px)">{form}</div></div>', HI]


def editor_a():
    def ing(name, qty):
        return f'<div class="row" style="--ins:16px"><span class="grow t16">{name}</span><span class="mu">{qty}</span>{ic("link", "acc s15")}</div>'
    tchips = chips(chip('15', 'c'), chip('30', 'c'), chip('45', 'c'), chip('1 h', 'c'), chip('1 h 30', 'c'), chip('2 h', 'c'), chip('More…', 'c on'), line=True)
    gchips = chips(chip('Breakfast', 'c on'), chip('Quick', 'c on'), chip('Dinner', 'c'), chip('Vegetarian', 'c'), chip('More…', 'c'), line=True)
    more = grp('<div class="row" style="--ins:16px"><span class="grow b">More details</span><i class="chev dn"></i></div>',
               srow('Add a photo', '', ic('cam', 'mu'), ins=48),
               f'<div class="row" style="--ins:16px"><span class="grow">Serves</span>{stepper(4)}</div>',
               f'<div class="row" style="--ins:16px;flex-direction:column;align-items:stretch;gap:8px"><div style="display:flex;justify-content:space-between"><span>Time</span><span class="mu">20 min</span></div>{tchips}</div>',
               f'<div class="row" style="--ins:16px"><span style="width:84px">Difficulty</span><span class="b" style="min-width:32px">2.5</span>{slider(25, 10)}</div>',
               f'<div class="row" style="--ins:16px;flex-direction:column;align-items:stretch;gap:8px"><span>Tags</span>{gchips}</div>',
               '<div class="row" style="--ins:16px"><span class="grow ph">Description — a line about this recipe</span></div>', style='margin-top:12px')
    return [SB, nav('New recipe'), '<div class="pad" style="padding-bottom:0"><div class="inp">Test Pancakes</div></div>',
            sh('Ingredients', right=act('Add', ic('plus', 's15'))), grp(ing('Flour', '1 cup'), ing('Eggs', '2'), ing('Milk', '1 cup'), ing('Butter', '2 tbsp')),
            sh('Steps', right=act('Add step', ic('plus', 's15'))), grp(steprow(1, STEPS[0]), steprow(2, STEPS[1])),
            more, grp(srow('Visibility', 'Household'), style='margin-top:24px'),
            f'<div class="kacc"><i class="chev dn" style="border-color:#3C3C43;margin-left:8px"></i>{btn("Save")}</div>', HI]


def editor_b():
    clipboard = grp(f'<div class="row" style="--ins:48px">{ic("link", "acc")}<span class="grow col" style="gap:1px"><span class="b acc">Import from smittenkitchen.com</span>'
                    f'<span class="c13 ell">From your clipboard · smittenkitchen.com/…/banana-bread</span></span>{CHEV}</div>'
                    f'<div class="row" style="--ins:48px">{ic("clip", "acc")}<span class="grow col" style="gap:1px"><span class="b">Paste recipe text</span>'
                    f'<span class="c13">Any recipe in words — Ambry reads it into fields</span></span>{CHEV}</div>', style='margin:0;border:1px solid #A7DBB6;background:#E4F7E9')
    lines = ''.join(f'<div style="display:flex;align-items:center;justify-content:space-between;gap:8px"><span>{q}</span>{chip("→ " + l, "tint")}</div>'
                    for q, l in [('1 cup flour', 'Flour'), ('2 eggs', 'Eggs'), ('1 cup milk', 'Milk'), ('2 tbsp butter', 'Butter')])
    return [SB, nav('New recipe'), '<div class="pad">', clipboard, '<div class="inp ph" style="margin-top:4px">Name this recipe</div>',
            '<div class="lbl">Ingredients</div>',
            f'<div class="inp multi" style="flex-direction:column;align-items:stretch;gap:6px">{lines}<span class="ph">Paste your ingredient list — one per line</span></div>',
            '<div class="hint">Each line is linked as you paste. Tap a link to change it.</div>', '<div class="inp ph">Add ingredient…</div>',
            '<div class="lbl">Steps</div><div class="inp multi ph" style="min-height:72px">Paste or type the steps, one per line</div>',
            btn('Create recipe', 'pri lg', style='margin-top:16px'), '</div>', HI]


def editor_c():
    def lrow(q, link, cls='tint'):
        return f'<div class="row" style="--ins:16px"><span class="grow">{q}</span>{chip("→ " + link, cls)}</div>'
    card = ('<div class="grp" style="margin:0;padding:16px;display:flex;flex-direction:column;gap:6px"><span class="t22">Banana custard</span>'
            '<span class="soft">Eggs, milk and a ripe banana, baked soft — from what you have.</span><span class="c13">Private draft · uses 1 expiring item</span></div>')
    return [SB, nav('Review recipe'), '<div class="pad"><div class="c13">From your ideas · saved just now. Imports from a link land here too.</div>', card, '</div>',
            sh('Ingredients', 4, right=act('4 linked · tap to change')),
            grp(lrow('2 eggs', 'Eggs'), lrow('1 cup milk', 'Milk'), lrow('1 ripe banana', 'Banana'), lrow('2 tbsp sugar', 'Brown sugar?', 'warn')),
            sh('Steps', 4), grp(steprow(1, 'Whisk the eggs with the sugar.'), steprow(2, 'Warm the milk and mash the banana into it.'),
                                f'<div class="row" style="--ins:16px"><span class="grow mu">2 more steps</span>{CHEV}</div>'),
            '<div class="foot" style="flex-direction:column;gap:8px">' + btn('Save', 'pri lg') + btn('Edit first', 'bord lg') + '</div>', HI]


# ================================================================ 7. Creator profile
def linkcard(label, host):
    return (f'<div class="card" style="width:100%;gap:8px;min-height:44px;padding:6px 12px">{ic("link", "acc")}<span class="grow col" style="gap:0">'
            f'<span class="acc" style="font-weight:500">{label}</span><span class="c13">{host}</span></span>{ic("open", "fa")}</div>')


def profile_today():
    return [SB, nav('Everett', ic('flag', 'fa')),
            f'<div class="pad" style="align-items:center"><span class="av">E</span><span class="t17">Everett</span><span class="c13">12 recipes · 0 followers · 0 following</span>'
            f'<span style="text-align:center">{BIO}</span>{linkcard("Blog", "everett.cooks")}{linkcard("Newsletter", "everett.substack.com")}</div>',
            '<div class="pad" style="padding-top:0">',
            ccard('g2', 'Wellington', 'by Everett · 2 h 30 min · ★ 4.8 (12)', 'Dinner · Special occasion', ring(7.5)),
            ccard('g3', 'Shakshuka', 'by Everett · 30 min · ★ 4.6 (8)', 'Dinner · Vegetarian', ring(3)),
            ccard('g5', 'Miso salmon', 'by Everett · 25 min · ★ 4.4 (5)', 'Dinner · Quick', ring(4.5)),
            ccard('fb', 'Weeknight ragù', 'by Everett · 45 min · ★ 4.2 (3)', 'Dinner', ring(5)),
            '</div>', HI]


def gtile(g, name):
    if g == 'fb':
        return f'<div class="gt fb">{ic("fk", "s26")}<span class="nm">{name}</span></div>'
    return f'<div class="gt {g}"><span class="nm">{name}</span></div>'


def profile_a():
    statsx = ''.join(f'<span class="col" style="gap:0;align-items:center"><span class="t17">{n}</span><span class="c13">{l}</span></span>' for n, l in [('12', 'Recipes'), ('48', 'Followers'), ('12', 'Following')])
    card = ('<div class="grp" style="margin-top:12px;padding:16px;display:flex;flex-direction:column;align-items:center;gap:10px"><span class="av">E</span>'
            f'<span style="font-size:20px;font-weight:600">Everett</span><div style="display:flex;gap:28px">{statsx}</div><span style="text-align:center">{BIO}</span>'
            f'<span class="c13"><span class="acc b">everett.cooks</span> and 2 more</span>{btn("Follow", "tint", style="width:100%")}</div>')
    return [SB, nav('', ic('flag', 'fa')), card,
            '<div class="grid" style="margin-top:16px">' + gtile('g2', 'Wellington') + gtile('g3', 'Shakshuka') + gtile('g5', 'Miso salmon') + gtile('fb', 'Weeknight ragù')
            + gtile('g4', 'Banana bread') + gtile('fb', 'Lemon roast chicken') + '</div>', HI]


def profile_b():
    return [SB, nav('Everett', btn('Follow', 'tint sm')), '<div class="pad" style="gap:10px">',
            f'<div style="display:flex;gap:12px;align-items:center"><span class="av m">E</span><span class="grow col" style="gap:2px"><span class="t17">Everett</span><span class="c13">{BIO}</span></span></div>',
            grp(f'<div class="row" style="--ins:16px">{ic("ck", "acc")}<span class="grow b acc">You can make 3 of Everett’s 12 recipes</span></div>', style='margin:0;background:#E4F7E9;border:1px solid #A7DBB6'),
            chips(chip('All', 'on'), chip('Can make'), chip('Almost')),
            rcard('g3', 'Shakshuka', '✓ You have everything · 30 min · ★ 4.6 (8)', ring(3)),
            rcard('g4', 'Banana bread', '✓ You have everything · uses 1 expiring item · 1 h', ring(2)),
            rcard('fb', 'Weeknight ragù', '✓ You have everything · 45 min · ★ 4.2 (3)', ring(5)),
            rcard('g5', 'Miso salmon', 'Missing 1 ingredient · 25 min · ★ 4.4 (5)', ring(4.5), mchips('Salmon')),
            rcard('g2', 'Wellington', 'Missing 2 ingredients · 2 h 30 min · ★ 4.8 (12)', ring(7.5), mchips('Beef', 'Pastry')),
            '</div>', HI]


def profile_c():
    def lrow(label, host):
        return f'<div class="row" style="--ins:16px"><span class="grow">{label}</span><span class="mu">{host}</span>{ic("open", "fa")}</div>'
    def prow(g, t, m, r):
        return f'<div class="row" style="--ins:72px">{th(g)}<span class="grow col" style="gap:2px"><span class="b">{t}</span><span class="c13">{m}</span></span>{r}{CHEV}</div>'
    return [SB, nav('', ic('more')),
            grp(f'<div class="row" style="--ins:16px;padding:12px 16px"><span class="av s">E</span><span class="grow col" style="gap:1px"><span class="t17">Everett</span><span class="c13">12 recipes</span></span>{btn("Follow", "tint sm")}</div>', style='margin-top:12px'),
            sh('Links'), grp(lrow('Blog', 'everett.cooks'), lrow('Newsletter', 'everett.substack.com'), lrow('Instagram', 'instagram.com')),
            grp(srow('Followers', '48'), srow('Following', '12'), style='margin-top:24px'),
            sh('Recipes', 12, right=f'<span class="acc">{ic("morec")}</span>'),
            grp(prow('g2', 'Wellington', '2 h 30 min · ★ 4.8 (12)', ring(7.5)), prow('g3', 'Shakshuka', '30 min · ★ 4.6 (8)', ring(3)), prow('g5', 'Miso salmon', '25 min · ★ 4.4 (5)', ring(4.5)),
                prow('fb', 'Weeknight ragù', '45 min · ★ 4.2 (3)', ring(5)), prow('g4', 'Banana bread', '1 h · ★ 4.7 (9)', ring(2))), HI]


# ================================================================ registry: screen → (today builder, [direction builders]) + look_for copy
BUILDERS = {
    'Lists tab': (lists_today, [lists_a, lists_b, lists_c]),
    'Restock review': (restock_today, [restock_a, restock_b, restock_c]),
    'Recipes tab': (recipes_today, [recipes_a, recipes_b, recipes_c]),
    'Recipe detail': (detail_today, [detail_a, detail_b, detail_c]),
    'Cook mode': (cook_today, [cook_a, cook_b, cook_c]),
    'Recipe editor, import and ideas': (editor_today, [editor_a, editor_b, editor_c]),
    'Creator profile': (profile_today, [profile_a, profile_b, profile_c]),
}

LOOK = {
    'Lists tab': [
        'The keyboard field is the only way in; To Buy has no aisle headers, the one bought row (Milk) still sits in the reading list, and the green-turned-ink Restock button travels under it above Suggested.',
        'Aisle headers are back (Produce · Dairy & Eggs · Baking · Grains & Pasta), the field is a search-style bar, Bought collapses to one “Show 1 bought” row, and a lifted Bread row mid-drag is leaving the wrong aisle for a glowing target that says the categoriser will remember.',
        'A Buy Again chip strip (recent restocks plus Out/Low pantry names) sits where the field was; the keyboard hides behind a collapsed “Add something else…” row; Suggested is gone because the strip absorbed it.',
        'No bought rows in the scroll — To Buy runs straight into Suggested; the count and Restock live in a bar above the tab bar, and tapping the count has expanded it into the bought list with un-buy, Clear and Cancel.'],
    'Restock review': [
        'A pushed screen: summary, “Put everything in…” pill and a 3-of-4 bulk tick, then one card per bought row with a location chip and “expires Sep 12 · 7d”, an unlinked Dish soap under a “Not adding” divider, and the commit button pinned at the bottom.',
        'No push: it is the Lists tab, and the In Your Cart rows themselves carry the Fridge chip and expiry caption; Dish soap wears a Skip pill instead of a divider, and “Add 2 to pantry” commits in place as the section footer.',
        'Rows regroup under Fridge / Pantry / Freezer / Not adding with a “Move all…” per header; Bread is caught mid-swipe showing the leading blue Fridge strip; the empty Freezer group is a drop target, the divider became a section.',
        'A sheet over the Lists tab does the whole job in three lines (2 to Fridge, 1 to Pantry, Skipping 1: Dish soap) with Add to pantry primary, “Review first…” as the way into today’s screen, and a Cancel row because it commits.'],
    'Recipes tab': [
        'A second “My recipes” heading under the Recipes large title, sort glyph and Add recipe beside it, then Folders and Yours / Favorites cards — Cook, the headline, is a segment you have to remember to tap.',
        'The ranking is the landing: filter chips and the ideas button up top, You Can Make / Almost There as inset grouped rows with time on the meta line, and My recipes · Folders · Community demoted to a Library group beneath.',
        'No segments and no list — a search field then a Settings-style index (What can I make · Favorites · Recent · Folders · Household · Community · Ideas), each a push; the tab has become a menu.',
        'One list of every rankable recipe under a chip row where Community is the last, tinted chip; each card carries its makeability verdict in the meta line and + / ⋯ in the title bar replace the two square buttons.'],
    'Recipe detail': [
        'The name appears twice (nav bar and body), four icon-only header controls, ✓/○ ingredients that are status only, and Start cooking — with its 3-button Alert — is below the fold under the steps.',
        'An empty nav title so the name is drawn once, heart plus ⋯ instead of four glyphs, the missing Butter row carries a 44pt +, and a sticky footer pairs Start cooking with a tinted “Add 1 missing” so the Alert is gone.',
        'A compact 4:3 hero row, then an Ingredients | Steps segmented control; the Steps pane shows detected durations as tappable “10 min ▶” chips and Start cooking is pinned.',
        'Everything is an inset card in a fixed order — hero, then an Actions group where Start cooking, Add missing (1) and a − 4 + Serves stepper are Settings rows — before Ingredients and Steps.'],
    'Cook mode': [
        'A flat scroll of five equal bordered step cards, a 1 OF 5 DONE caption, no ingredients and no timer; Done cooking sits at the end of the list, and the ticks live only in memory.',
        'The current step is the only full-ink card while done and later steps dim; a collapsed Ingredients (4) row sits on top; step 2’s “10 minutes” has become a running timer chip; Finish (1 of 5) is a sticky footer.',
        'One step per page: Step 2 of 5 in 24pt, the one ingredient this step uses with its quantity, a 10 min timer chip, page dots, and 56pt Back / Next buttons at the bottom instead of a list.',
        'The all-done sheet is two stacked cards: the star rating, then “Used anything up?” chips for the in-stock ingredients — Eggs tapped once to Low, Milk twice to Out — above a single Done.'],
    'Recipe editor, import and ideas': [
        'Today’s form scrolled to its middle: Servings and Time as number pads, the difficulty slider with its readout and Clear, Tags with a Choose button and a free-text field, and the three-line ingredient editor rows.',
        'Title → Ingredients → Steps are the whole form; everything else hides under an expanded “More details” group of keyboard-free rows (photo, − 4 + serves, time chips, slider, tag chips), and Save rides the keyboard accessory bar.',
        'The clipboard is read on open — a tinted card offers “Import from smittenkitchen.com” in one tap or “Paste recipe text” — and the ingredient field is a multiline paste box where each pasted line already wears its link chip.',
        'A saved idea (Banana custard, from Eggs · Milk · Bananas) lands on a read-only review card instead of a toast: 4 ingredients with tappable link chips (one doubtful, in amber), a steps summary, then Save and Edit first.'],
    'Creator profile': [
        'Everett’s name in both the nav bar and the body, an inert “0 followers · 0 following” stats line, bordered link rows, and community cards that still say “by Everett” on his own page — no Follow yet.',
        'An Instagram-style header card — three stat buttons, a bio, the first link “and 2 more”, and a full-width tinted Follow — above a two-column photo grid where photo-less recipes fall back to grey tiles.',
        'The stats line is about you: “You can make 3 of Everett’s 12 recipes”, with All / Can make / Almost chips, cook status on every row, and a compact Follow tucked in the nav bar’s right slot.',
        'A Settings-style contact card: identity row with Follow as its accessory, a Links group, Followers 48 › / Following 12 › rows, then a dense Recipes (12) list with 44pt thumbnails and a ⋯ sort.'],
}


def main():
    screens = json.load(open(SRC, encoding='utf-8'))
    manifest = []
    for sc in screens:
        name = sc['screen']
        today_fn, dir_fns = BUILDERS[name]
        looks = LOOK[name]
        sslug = slug(name)
        d = f'{OUT}/{sslug}'
        os.makedirs(d, exist_ok=True)
        open(f'{d}/today.html', 'w', encoding='utf-8').write(page(today_fn()))
        entry = {'screen': name, 'screen_slug': sslug, 'today': {'file': f'{sslug}/today.html', 'look_for': looks[0]}, 'directions': []}
        for i, direction in enumerate(sc['directions']):
            dslug = slug(direction['name'])
            open(f'{d}/{dslug}.html', 'w', encoding='utf-8').write(page(dir_fns[i]()))
            entry['directions'].append({'name': direction['name'], 'slug': dslug, 'file': f'{sslug}/{dslug}.html', 'look_for': looks[i + 1]})
        manifest.append(entry)
    json.dump(manifest, open(f'{OUT}/manifest.json', 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
    print('wrote', sum(1 + len(e['directions']) for e in manifest), 'mocks +', f'{OUT}/manifest.json')


if __name__ == '__main__':
    main()
