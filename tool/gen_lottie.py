#!/usr/bin/env python3
"""gen_lottie.py — Jana aset Lottie minimal (buatan sendiri, tiada lesen pihak ketiga).

Lottie ialah JSON; fail dijana secara prosedur supaya app memiliki aset sepenuhnya
(lihat docs/ASSETS.md). Output: assets/lottie/{coin,confetti,badge_up,soft_lose}.json
"""
import json
import math
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "lottie"
OUT.mkdir(parents=True, exist_ok=True)

def write(name, anim):
    (OUT / name).write_text(json.dumps(anim, separators=(",", ":")))
    print("tulis", name)

def base(w, h, op, fr=60):
    return {"v": "5.7.4", "fr": fr, "ip": 0, "op": op, "w": w, "h": h,
            "nm": "gen", "ddd": 0, "assets": [], "layers": []}

def shape_layer(name, ind, op, items, color, pos, scale=None, opacity_kf=None):
    layer = {
        "ddd": 0, "ind": ind, "ty": 4, "nm": name, "sr": 1,
        "ks": {
            "o": opacity_kf if opacity_kf else {"a": 0, "k": 100},
            "r": {"a": 0, "k": 0},
            "p": pos,
            "a": {"a": 0, "k": [0, 0, 0]},
            "s": scale if scale else {"a": 0, "k": [100, 100, 100]},
        },
        "ao": 0,
        "shapes": [{"ty": "gr", "it": items + [
            {"ty": "fl", "c": {"a": 0, "k": color}, "o": {"a": 0, "k": 100}},
            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]},
             "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0}, "o": {"a": 0, "k": 100}},
        ], "nm": "g"}],
        "ip": 0, "op": op, "st": 0, "bm": 0,
    }
    return layer

def ellipse(size):
    return {"ty": "el", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [size, size]}}

def rect(w, h, r=0):
    d = {"ty": "rc", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [w, h]}}
    if r:
        d["r"] = {"a": 0, "k": r}
    return d

def updown(frames, a, b):
    return {"a": 1, "k": [{"t": 0, "s": a, "e": b, "i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                           {"t": frames, "s": b}]}

# 1) coin.json — syiling melambung naik-turun + kilauan
anim = base(200, 200, 45)
coin = shape_layer("coin", 1, 45, [
    ellipse(120),
    {"ty": "el", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [86, 86]}},
], color=[1.0, 0.78, 0.28, 1], pos=updown(45, [100, 150, 0], [100, 60, 0]))
coin["shapes"][0]["it"].insert(1, {"ty": "fl", "c": {"a": 0, "k": [0.85, 0.55, 0.1, 1]},
                                   "o": {"a": 0, "k": 100}})
anim["layers"].append(coin)
write("coin.json", anim)

# 2) confetti.json — konfeti menang (8 keping jatuh berputar)
anim = base(300, 300, 90)
cols = [[1, .4, .4, 1], [1, .78, .28, 1], [.4, .8, .55, 1], [.4, .55, .95, 1],
        [.8, .5, .9, 1], [.35, .85, .8, 1], [1, .55, .75, 1], [.95, .9, .4, 1]]
for i in range(8):
    x = 30 + i * 33
    drop = {"a": 1, "k": [
        {"t": 0, "s": [x, -10, 0], "e": [x + (i % 3 - 1) * 40, 320, 0],
         "i": {"x": [0.3], "y": [1]}, "o": {"x": [0.7], "y": [0]}},
        {"t": 90, "s": [x + (i % 3 - 1) * 40, 320, 0]}]}
    rot = {"a": 1, "k": [{"t": 0, "s": [0, 0, 0]}, {"t": 90, "s": [0, 360 * (1 + i % 2), 0]}]}
    anim["layers"].append(shape_layer(f"c{i}", i + 1, 90, [rect(14, 22, 4)],
                                      cols[i], drop, scale={"a": 0, "k": [100, 100, 100]}))
    anim["layers"][-1]["ks"]["r"] = rot
write("confetti.json", anim)

# 3) badge_up.json — lencana naik tier (bulatan + jalur, scale pop)
anim = base(240, 240, 50)
pop = {"a": 1, "k": [{"t": 0, "s": [0, 0, 100], "e": [108, 108, 100], "i": {"x": [0.2], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                     {"t": 18, "s": [100, 100, 100]}]}
anim["layers"].append(shape_layer("badge", 1, 50, [ellipse(150)], [0.95, 0.62, 0.13, 1],
                                  {"a": 0, "k": [120, 120, 0]}, scale=pop))
anim["layers"].append(shape_layer("band", 2, 50, [rect(90, 26, 12)], [1, 1, 1, 1],
                                  {"a": 0, "k": [120, 120, 0]}, scale=pop))
anim["layers"].append(shape_layer("star", 3, 50, [rect(26, 26, 6)], [1, 1, 1, 1],
                                  {"a": 0, "k": [120, 120, 0]}, scale=pop))
write("badge_up.json", anim)

# 4) soft_lose.json — kalah lembut (bulatan pudar turun perlahan)
anim = base(240, 240, 70)
fade = {"a": 1, "k": [{"t": 0, "s": 100, "e": 0, "i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                      {"t": 70, "s": 0}]}
sink = {"a": 1, "k": [{"t": 0, "s": [120, 110, 0], "e": [120, 150, 0], "i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                      {"t": 70, "s": [120, 150, 0]}]}
l = shape_layer("lose", 1, 70, [ellipse(120)], [0.55, 0.6, 0.72, 1], sink, opacity_kf=fade)
anim["layers"].append(l)
write("soft_lose.json", anim)

print("Selesai.")
