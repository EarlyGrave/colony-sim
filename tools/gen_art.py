#!/usr/bin/env python3
"""Generates the game's pixel-art sprites into assets/sprites/.

Deterministic (fixed seeds), no external assets. Sprites are authored at
16 px per tile and drawn 2x in game with nearest filtering.

    python3 tools/gen_art.py
"""
import os
import random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")

PAL = {
    ".": None,
    "k": "#1a1420",  # outline
    # people
    "o": "#e07b28", "O": "#a8541a",  # prison jumpsuit
    "s": "#f0c8a0", "S": "#c89670",  # skin
    "h": "#4a3020",  # hair
    "b": "#3a78d0", "B": "#24508c",  # engineer helmet
    "g": "#9fd06a", "G": "#6a9a3c",  # sick skin
    "w": "#f4f0e8",
    # creatures
    "r": "#c83a2c", "R": "#8a2018",
    "p": "#7a2a4a", "P": "#4e1830", "y": "#ffd23a",
    "a": "#8fcf3a", "A": "#4f8a1e",  # spitter acid green
    "d": "#9a7b4f", "D": "#5e4a2c",  # burrower earth
    # metal
    "m": "#7c8794", "M": "#4f5866", "l": "#b8c2cc", "t": "#4fb3a9",
}


def rgba(hex_color, a=255):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def grid(rows, pal=PAL):
    h = len(rows)
    w = len(rows[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == w, "row %d has %d chars, want %d: %r" % (y, len(row), w, row)
        for x, ch in enumerate(row):
            c = pal[ch]
            if c:
                img.putpixel((x, y), rgba(c))
    return img


def mirror(halves):
    """Left halves -> full symmetric rows."""
    return [h + h[::-1] for h in halves]


def recolor(rows, mapping):
    return ["".join(mapping.get(ch, ch) for ch in row) for row in rows]


def save(img, name):
    img.save(os.path.join(OUT, name + ".png"))


# --- Colonists ----------------------------------------------------------------

COLONIST = mirror([
    "........",
    ".....kkk",
    "....khhh",
    "...khhhh",
    "...khsss",
    "...kssks",
    "...kssss",
    "....ksss",
    "...kkooo",
    "..kooooo",
    ".kOoOooo",
    ".ksoOooo",
    "..kooooo",
    "...kOOOk",
    "...kOOOk",
    "...kkkk.",
])


def colonists():
    save(grid(COLONIST), "colonist")
    eng = list(COLONIST)
    eng[1] = mirror([".....kkk"])[0]
    eng[2] = mirror(["....kbbb"])[0]
    eng[3] = mirror(["...kbbbb"])[0]
    eng[4] = mirror(["..kBBBBB"])[0]
    save(grid(eng), "colonist_engineer")
    save(grid(recolor(COLONIST, {"s": "g", "S": "G"})), "colonist_sick")
    save(grid(recolor(eng, {"s": "g", "S": "G"})), "colonist_engineer_sick")


# Four-direction walk sheets for the pseudo-3D view: 3 columns (idle, step A,
# step B) x 4 rows (down, left, right, up), 16 px frames.
COLONIST_BACK = COLONIST[:4] + [
    "...khhhhhhhhk...",
    "...khhhhhhhhk...",
    "...khhhhhhhhk...",
    "....khhhhhhk....",
    "...kkooooookk...",
    "..kooooooooook..",
    ".kOoOowwwwoOoOk.",
    ".ksoOooooooOosk.",
    "..kooooooooook..",
] + COLONIST[13:]

COLONIST_SIDE = [
    "................",
    "......kkkkk.....",
    ".....khhhhhk....",
    "....khhhhhhhk...",
    "....khhhsssssk..",
    "....khhssskssk..",
    "....khsssssssk..",
    ".....kssssssk...",
    ".....kkooookk...",
    "....koooooook...",
    "....kOooOoook...",
    "....kOoosOook...",
    "....koooooook...",
    ".....kOOOOk.....",
    ".....kOOOOk.....",
    ".....kkkkkk.....",
]

FRONT_STEP = [
    "...kOOOkkOOOk...",
    "...kOOOk.kkkk...",
    "...kkkk.........",
]
SIDE_STEP_A = [
    "....kOOk.kOOk...",
    "...kOOk...kOOk..",
    "...kkk.....kkk..",
]
SIDE_STEP_B = [
    ".....kOOOk......",
    ".....kOOOk......",
    ".....kkkkk......",
]


def _legs(rows, legs):
    return rows[:13] + legs


def _flip(rows):
    return [r[::-1] for r in rows]


def walk_sheet(front, back, side):
    down = [front, _legs(front, FRONT_STEP), _legs(front, _flip(FRONT_STEP))]
    up = [back, _legs(back, _flip(FRONT_STEP)), _legs(back, FRONT_STEP)]
    right = [side, _legs(side, SIDE_STEP_A), _legs(side, SIDE_STEP_B)]
    left = [_flip(f) for f in right]
    sheet = Image.new("RGBA", (16 * 3, 16 * 4), (0, 0, 0, 0))
    for row, frames in enumerate([down, left, right, up]):
        for col, rows in enumerate(frames):
            sheet.paste(grid(rows), (col * 16, row * 16))
    return sheet


def helmet(rows):
    out = list(rows)
    for i in range(1, 4):
        out[i] = out[i].replace("h", "b")
    return out


def colonist_sheets():
    front_eng = list(COLONIST)
    front_eng[1] = mirror([".....kkk"])[0]
    front_eng[2] = mirror(["....kbbb"])[0]
    front_eng[3] = mirror(["...kbbbb"])[0]
    front_eng[4] = mirror(["..kBBBBB"])[0]
    variants = {
        "colonist": (COLONIST, COLONIST_BACK, COLONIST_SIDE),
        "colonist_engineer": (front_eng, helmet(COLONIST_BACK), helmet(COLONIST_SIDE)),
    }
    for name, (f, b, sd) in variants.items():
        save(walk_sheet(f, b, sd), name + "_sheet")
        sick = {"s": "g", "S": "G"}
        save(walk_sheet(recolor(f, sick), recolor(b, sick), recolor(sd, sick)), name + "_sick_sheet")


# --- Creatures ----------------------------------------------------------------

def creatures():
    crawler = mirror([
        "........",
        "..k.....",
        "...k....",
        "....kkkk",
        "...krrrr",
        "..krrwkr",
        "k.krrrrr",
        ".kkrrrrR",
        "..krrRrR",
        "k.krrRrR",
        ".kkrrRrR",
        "..krrrrr",
        "k..krrrr",
        "....krrr",
        ".....kkk",
        "........",
    ])
    save(grid(crawler), "crawler")
    brute = mirror([
        ".k......",
        ".kk.....",
        "..kkkkkk",
        "..kppppp",
        ".kppyypp",
        ".kpppppp",
        "kppPwPwP",
        "kppppppp",
        "kpPppppp",
        "kpPPpppp",
        "kpPPPppp",
        ".kpPPppp",
        ".kpppppp",
        "..kPPk..",
        "..kPPk..",
        "..kkkk..",
    ])
    save(grid(brute), "brute")
    spitter = mirror([
        "........",
        "....kkkk",
        "...kaaaa",
        "..kaaaaA",
        "..kawawA",
        "..kaaaaa",
        "..kaakkk",
        "...kayyy",
        "..kaaaaA",
        ".kaaaAAA",
        ".kaaaaAA",
        "..kaaAAk",
        "..kaakk.",
        ".kk.kk..",
        ".k..k...",
        "........",
    ])
    save(grid(spitter), "spitter")
    burrower = mirror([
        "........",
        "........",
        "...kk...",
        "..kddkkk",
        ".kddddDD",
        ".kdwdwDD",
        "kddddddd",
        "kdddkkkk",
        "kddkyyyy",
        "kdddkkkk",
        ".kdddDDD",
        ".kkddDDD",
        "..kkdDDD",
        "...kkkkk",
        "........",
        "........",
    ])
    save(grid(burrower), "burrower")
    # region FX3: Metropolis drones (metal palette, placeholder art)
    drone_scout = mirror([
        "........", "........", "........", "...kkkkk", "..kmmmmm", ".kmllwmm",
        ".kmmmmmm", "kmmMMMMM", "kmmmmmmm", ".kMMMMMM", "..kkkkkk", "...k.k..",
        "........", "........", "........", "........",
    ])
    save(grid(drone_scout), "drone_scout")
    drone_gunner = mirror([
        "........", "...kkkkk", "..kmmmmm", ".kmmwwmm", ".kmmmmmm", "kkmMMMMM",
        "kykmmmmm", "kykmmMMM", "kkkmmmmm", ".kMMMMMM", ".kmmmmmm", "..kMMkkk",
        "..kkk...", "........", "........", "........",
    ])
    save(grid(drone_gunner), "drone_gunner")
    drone_enforcer = mirror([
        "...kkkkk", "..kmmmmm", ".kmlllll", ".kmmwymw", ".kmmmmmm", "kkMMMMMM",
        "kmmmmmmm", "kmtmmMMM", "kmmmmmmm", "kmMMMMMM", ".kmmmmmm", ".kMMMMMM",
        "..kmmkkk", "..kMMk..", "..kkkk..", "........",
    ])
    save(grid(drone_enforcer), "drone_enforcer")
    # endregion


# --- Turret ---------------------------------------------------------------------

def turret():
    top = [
        "........",
        "...kkkkk",
        "..kMMMMM",
        ".kMmmmmm",
        ".kMmlmmm",
        ".kMmmmmm",
        ".kMmmmmt",
        ".kMmmmtt",
    ]
    rows = mirror(top)
    rows = rows + rows[::-1]
    save(grid(rows), "turret_base")
    barrel = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "....kkkk........",
        "...kmmmmkkkkkkk.",
        "...kmllmllllllk.",
        "...kmMMmMMMMMMk.",
        "...kmmmmkkkkkkk.",
        "....kkkk........",
        "................",
        "................",
        "................",
        "................",
        "................",
    ]
    save(grid(barrel), "turret_barrel")


# --- Big buildings (drawn with primitives) --------------------------------------

def refinery():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = rgba(PAL["k"])
    # platform
    d.rectangle([1, 6, 30, 30], fill=rgba("#3b3f47"), outline=k)
    d.rectangle([2, 26, 29, 29], fill=rgba("#2a2d33"))
    for x in range(4, 29, 6):
        d.point((x, 28), fill=rgba("#e0b030"))
    # tank with essence window
    d.rectangle([4, 9, 16, 25], fill=rgba("#6c7480"), outline=k)
    d.rectangle([5, 10, 6, 24], fill=rgba("#9aa4b0"))
    d.rectangle([8, 12, 13, 22], fill=rgba("#2a1838"), outline=k)
    d.rectangle([9, 16, 12, 21], fill=rgba("#b46cff"))
    d.rectangle([9, 15, 12, 15], fill=rgba("#e2c2ff"))
    # chimney with waste glow
    d.rectangle([20, 2, 25, 18], fill=rgba("#555b66"), outline=k)
    d.rectangle([21, 3, 22, 17], fill=rgba("#7c8490"))
    d.rectangle([20, 1, 25, 3], fill=rgba("#7fbf3f"), outline=k)
    # pipes
    d.rectangle([16, 20, 27, 22], fill=rgba("#8a6a40"), outline=k)
    d.rectangle([26, 18, 28, 25], fill=rgba("#8a6a40"), outline=k)
    # control panel
    d.rectangle([19, 24, 24, 27], fill=rgba("#2c3a3a"), outline=k)
    d.point((20, 25), fill=rgba("#ff4040"))
    d.point((22, 25), fill=rgba("#40ff80"))
    save(img, "refinery")


def capsule():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = rgba(PAL["k"])
    # scorch mark
    d.ellipse([0, 4, 31, 31], fill=rgba("#2a221a", 160))
    # fins
    d.polygon([(3, 26), (8, 16), (8, 28)], fill=rgba("#8a6a1a"), outline=k)
    d.polygon([(28, 26), (23, 16), (23, 28)], fill=rgba("#8a6a1a"), outline=k)
    # hull
    d.ellipse([6, 2, 25, 29], fill=rgba("#c9a227"), outline=k)
    d.ellipse([8, 4, 14, 24], fill=rgba("#e8c650"))
    d.rectangle([7, 18, 24, 20], fill=rgba("#7a5c14"))
    # hatch / window
    d.ellipse([11, 7, 20, 15], fill=rgba("#2c4a66"), outline=k)
    d.ellipse([13, 8, 16, 11], fill=rgba("#8ac8f0"))
    # warning stripes
    for x in range(9, 23, 4):
        d.rectangle([x, 22, x + 1, 24], fill=rgba("#1a1420"))
    save(img, "capsule")


# --- Items --------------------------------------------------------------------------

def items():
    ore = grid([
        "................",
        "................",
        "................",
        "................",
        "......kkkk......",
        "....kkMvvMk.....",
        "...kMvVVvMMk....",
        "...kMvVVvvMk....",
        "..kMMvvvMMvMk...",
        "..kMMMMMMvVMk...",
        "...kMMMMMMMk....",
        "....kkkkkkk.....",
        "................",
        "................",
        "................",
        "................",
    ], {**PAL, "v": "#9b6cff", "V": "#d3a8ff"})
    save(ore, "item_ore")
    refined = grid([
        "................",
        "................",
        "................",
        "......kkk.......",
        ".....kwWwk......",
        "......kWk.......",
        ".....kVvVk......",
        "....kVvvvVk.....",
        "....kvvVvvk.....",
        "....kvvvvvk.....",
        "....kvVvvvk.....",
        ".....kvvvk......",
        "......kkk.......",
        "................",
        "................",
        "................",
    ], {**PAL, "v": "#d36bff", "V": "#f2c2ff", "W": "#9aa4b0"})
    save(refined, "item_refined")
    waste = grid([
        "................",
        "................",
        "................",
        ".....kkkkkk.....",
        "....kgGGGGgk....",
        "....kGkkkkGk....",
        "....kggggggk....",
        "....kgykkygk....",
        "....kgkyykgk....",
        "....kggggggk....",
        "....kGGGGGGk....",
        "....kggggggk....",
        ".....kkkkkk.....",
        "................",
        "................",
        "................",
    ], {**PAL, "g": "#6f9a2a", "G": "#4c6c1c", "y": "#e6d84a"})
    save(waste, "item_waste")


def pickaxe():
    img = grid([
        "................",
        "..kkkkkk........",
        ".kllllllkk......",
        "..kkkkkMMlk.....",
        "......kkMMk.....",
        ".......kwMk.....",
        "......kwwk......",
        ".....kwwk.......",
        "....kwwk........",
        "...kwwk.........",
        "..kwwk..........",
        "..kwk...........",
        "...k............",
        "................",
        "................",
        "................",
    ], {**PAL, "w": "#a0703c"})
    save(img, "designation_mine")


# --- Terrain --------------------------------------------------------------------------

def speckle(img, rng, colors, n):
    for _ in range(n):
        img.putpixel((rng.randrange(16), rng.randrange(16)), rgba(rng.choice(colors)))


def terrain():
    rng = random.Random(1337)
    for v in range(6):
        g = Image.new("RGBA", (16, 16), rgba("#4a3c2c"))
        speckle(g, rng, ["#544531", "#403325", "#57483a"], 40)
        for _ in range(2):  # pebbles
            x, y = rng.randrange(1, 14), rng.randrange(1, 14)
            g.putpixel((x, y), rgba("#7a6a58"))
            g.putpixel((x + 1, y), rgba("#5e5040"))
        if v == 5:  # a rare tuft of dry grass
            x, y = rng.randrange(2, 12), rng.randrange(3, 12)
            for dx, dy in [(0, 0), (1, -1), (2, 0)]:
                g.putpixel((x + dx, y + dy), rgba("#5c5532"))
        save(g, "ground_%d" % v)
    for v in range(4):
        r = Image.new("RGBA", (16, 16), rgba("#6e6a64"))
        speckle(r, rng, ["#7a7670", "#625e58", "#827e78"], 50)
        d = ImageDraw.Draw(r)
        x, y = rng.randrange(2, 12), rng.randrange(2, 12)
        d.line([(x, y), (x + rng.randrange(-3, 4), y + 3), (x + rng.randrange(-2, 3), y + 5)], fill=rgba("#4e4a46"))
        d.line([(0, 0), (15, 0)], fill=rgba("#8c8882"))
        save(r, "rock_%d" % v)
    for v in range(3):
        o = Image.new("RGBA", (16, 16), rgba("#3c3448"))
        speckle(o, rng, ["#463d54", "#342c3e"], 40)
        d = ImageDraw.Draw(o)
        for _ in range(3 + v):
            x, y = rng.randrange(2, 13), rng.randrange(4, 14)
            hgt = rng.randrange(3, 6)
            d.polygon([(x - 2, y), (x, y - hgt), (x + 2, y)], fill=rgba("#9b6cff"), outline=rgba("#5b3fa0"))
            d.line([(x, y - hgt + 1), (x, y - 1)], fill=rgba("#d3a8ff"))
        save(o, "ore_%d" % v)


# region construction
def walls():
    k = rgba(PAL["k"])
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], fill=rgba("#6e665c"), outline=k)
    for y in (4, 8, 12):
        d.line([(1, y), (14, y)], fill=rgba("#4a443d"))
    for x, y0 in ((5, 1), (10, 5), (4, 9), (11, 13)):
        d.line([(x, y0), (x, y0 + 2)], fill=rgba("#4a443d"))
    d.line([(1, 1), (14, 1)], fill=rgba("#9a9184"))
    save(img, "wall")
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 5, 15, 10], fill=rgba("#6e665c"), outline=k)
    d.rectangle([3, 3, 12, 12], fill=rgba("#8a6a40"), outline=k)
    d.line([(7, 4), (7, 11)], fill=rgba("#5a4328"))
    d.point((9, 8), fill=rgba("#e0b030"))
    d.point((5, 8), fill=rgba("#e0b030"))
    save(img, "door")
# region needs
def food_art():
    """Bed, stove, crops and the two food items."""
    pal = {**PAL, "c": "#6a7fb0", "C": "#8fa3d0", "q": "#d9d2c2", "d": "#a0522d", "D": "#6e3a1f",
           "f": "#e8742a", "F": "#ffd23a", "n": "#4c8a2a", "N": "#8fbf4a", "u": "#c9a46a", "U": "#8a6a3a",
           "j": "#d98a4a", "J": "#f2b676"}
    bed = grid([
        "................",
        "................",
        "kkkkkkkkkkkkkkkk",
        "kDDDDDDDDDDDDDDk",
        "kDccccccccccqqDk",
        "kDcCCCccccccqqDk",
        "kDccccccccccqqDk",
        "kDcCCCccccccqqDk",
        "kDccccccccccqqDk",
        "kDccccccccccqqDk",
        "kDDDDDDDDDDDDDDk",
        "kkkkkkkkkkkkkkkk",
        "................",
        "................",
        "................",
        "................",
    ], pal)
    save(bed, "bed")
    stove = grid([
        "................",
        "...kkkkkkkkkk...",
        "..kMMMMMMMMMMk..",
        "..kMllllllllMk..",
        "..kMlkkkkkklMk..",
        "..kMlkffFfklMk..",
        "..kMlkfFFfklMk..",
        "..kMlkkkkkklMk..",
        "..kMllllllllMk..",
        "..kMMMMMMMMMMk..",
        "..kMkMMMMMMkMk..",
        "...kkkkkkkkkk...",
        "................",
        "................",
        "................",
        "................",
    ], pal)
    save(stove, "stove")
    young = grid([
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "......n.n.......",
        ".....nNn.nN.....",
        "......nN.Nn.....",
        "......nnnn......",
        ".......nn.......",
        ".......DD.......",
        "................",
        "................",
        "................",
    ], pal)
    save(young, "plant_young")
    ripe = grid([
        "................",
        "................",
        "....n....n......",
        "...nNn..nNn.....",
        "..nNnnNnnNn.....",
        "...nnNnnnn......",
        "....nnNnn.......",
        "...nuu.nn.uu....",
        "..nuUUu.nuUUu...",
        "..nuuuu.nuuuu...",
        "...nnn.nn.nn....",
        ".......nn.......",
        ".......DD.......",
        "................",
        "................",
        "................",
    ], pal)
    save(ripe, "plant_ripe")
    raw = grid([
        "................",
        "................",
        "................",
        "................",
        ".....kkkk.......",
        "...kkuuuukk.....",
        "..kuuUuuuuuk....",
        "..kuuuuuUuuk.kk.",
        "...kuuuuuuukuuk.",
        "....kkuuUuukuuk.",
        "......kkkkkkkk..",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], pal)
    save(raw, "item_raw_food")
    meal = grid([
        "................",
        "................",
        "................",
        "................",
        "...kkkkkkkkkk...",
        "..kqqqqqqqqqqk..",
        "..kqjJjjjJjjqk..",
        "..kqjjjjjjjjqk..",
        "...kqjjjJjjqk...",
        "....kqqqqqqk....",
        ".....kkkkkk.....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], pal)
    save(meal, "item_meal")
# endregion


# region G1a
# 4-direction creature walk sheets derived from the single front sprite (3x4, 16 px frames,
# rows down/left/right/up like the colonist sheets).
def _shift(img, dx, dy, y0, y1):
    out = img.copy()
    box = (0, y0, 16, y1)
    out.paste((0, 0, 0, 0), box)
    out.paste(img.crop(box), (dx, y0 + dy))
    return out


def creature_sheets():
    from collections import Counter
    for name in ["crawler", "brute", "spitter", "burrower", "drone_scout", "drone_gunner", "drone_enforcer"]:
        front = Image.open(os.path.join(OUT, name + ".png")).convert("RGBA")
        px = front.load()
        cnt = Counter(px[x, y] for x in range(16) for y in range(16)
                      if px[x, y][3] and px[x, y] != rgba(PAL["k"]) and px[x, y] != rgba(PAL["w"]))
        body = cnt.most_common(1)[0][0]
        back = front.copy()
        bp = back.load()
        for x in range(16):
            for y in range(16):
                if bp[x, y] in (rgba(PAL["w"]), rgba(PAL["y"])):
                    bp[x, y] = body
        # side: narrow the body and push the head (upper half) forward as a snout
        side = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        side.paste(front.crop((3, 0, 13, 16)), (3, 0))
        side.paste((0, 0, 0, 0), (0, 0, 16, 8))
        side.paste(front.crop((3, 0, 13, 8)), (5, 0))
        outline = rgba(PAL["k"])
        sp = side.load()
        for y in range(8):  # eye on the facing side only
            for x in range(16):
                if sp[x, y] == rgba(PAL["y"]):
                    sp[x, y] = body
        for y in range(16):  # legs/body tail taper on the rear edge
            if y > 11:
                for x in range(3, 6):
                    sp[x, y] = (0, 0, 0, 0)
        del outline
        frames = {
            0: [front, _shift(front, 0, -1, 12, 16), _shift(front, 0, 1, 12, 16)],
            2: [side, _shift(side, 1, 0, 11, 16), _shift(side, -1, 0, 11, 16)],
            3: [back, _shift(back, 0, 1, 12, 16), _shift(back, 0, -1, 12, 16)],
        }
        frames[1] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames[2]]
        sheet = Image.new("RGBA", (48, 64), (0, 0, 0, 0))
        for row, fl in frames.items():
            for col, im in enumerate(fl):
                sheet.paste(im, (col * 16, row * 16))
        save(sheet, name + "_sheet")
# endregion


# region G1c
def atmosphere_art():
    """Soft ground-contact shadow blob and the selection ring (32 px, alpha only look)."""
    import math
    n = 32
    sh = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ring = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            d = math.hypot((x + 0.5 - n / 2) / (n / 2), (y + 0.5 - n / 2) / (n / 2))
            if d < 1.0:
                a = int(120 * (1.0 - d) ** 0.8)
                sh.putpixel((x, y), (10, 8, 16, a))
            if 0.72 <= d <= 0.92:
                ring.putpixel((x, y), (255, 236, 90, 235))
            elif 0.62 <= d < 0.72 or 0.92 < d <= 0.98:
                ring.putpixel((x, y), (40, 30, 10, 140))
    save(sh, "shadow_blob")
    save(ring, "select_ring")
# endregion


# region A2c
def _arrow(d, x0, y0, col, outline):
    """Right-pointing arrow in a 16 px box at (x0, y0)."""
    pts = [(x0 + 3, y0 + 5), (x0 + 9, y0 + 5), (x0 + 9, y0 + 2), (x0 + 14, y0 + 8), (x0 + 9, y0 + 13),
           (x0 + 9, y0 + 10), (x0 + 3, y0 + 10)]
    d.polygon(pts, fill=col, outline=outline)


def belt_art():
    k = rgba("#14121a")
    # belt tile: art points +x; tiles seamlessly along x (rollers every 4 px)
    img = Image.new("RGBA", (16, 16), rgba("#3a3d46"))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 1], fill=rgba("#e0b030"))
    d.rectangle([0, 14, 15, 15], fill=rgba("#e0b030"))
    for x in range(0, 16, 4):
        d.line([(x, 2), (x, 13)], fill=rgba("#2a2c33"))
        d.line([(x + 1, 2), (x + 1, 13)], fill=rgba("#4e525e"))
    for x in (2, 10):
        d.polygon([(x, 4), (x + 3, 7), (x, 10), (x + 1, 10), (x + 4, 7), (x + 1, 4)], fill=rgba("#ffd23a"))
    save(img, "belt_tile")
    # port arrows (point +x): in = green, out = orange
    # IN = cyan arrow with a notched (chevron) tail; OUT = magenta solid arrow
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 4), (4, 8), (0, 12), (4, 12), (8, 8), (4, 4)], fill=rgba("#3cd8ff"), outline=k)
    d.polygon([(7, 5), (10, 5), (10, 2), (15, 8), (10, 14), (10, 11), (7, 11), (4, 8)], fill=rgba("#3cd8ff"), outline=k)
    save(img, "port_in")
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    _arrow(ImageDraw.Draw(img), 0, 0, rgba("#ff4fb4"), k)
    save(img, "port_out")


def _plate(d, size, base):
    k = rgba("#14121a")
    d.rectangle([0, 0, size - 1, size - 1], fill=rgba(base), outline=k)
    d.rectangle([1, 1, size - 2, 1], fill=rgba("#ffffff", 70))
    for c in ((2, 2), (size - 3, 2), (2, size - 3), (size - 3, size - 3)):
        d.point(c, fill=rgba("#c8d0d8"))


def machine_art():
    k = rgba("#14121a")
    # miner 32x32: drill head on a rock-brown housing
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _plate(d, 32, "#6a5c40")
    d.ellipse([7, 7, 24, 24], fill=rgba("#2a2418"), outline=k)
    d.ellipse([10, 10, 21, 21], fill=rgba("#9a9aa6"), outline=k)
    d.line([(12, 12), (19, 19)], fill=rgba("#d8d8e0"), width=2)
    d.line([(19, 12), (12, 19)], fill=rgba("#d8d8e0"), width=2)
    d.rectangle([27, 12, 31, 19], fill=rgba("#ff9a30"), outline=k)
    save(img, "machine_miner")
    # smelter 32x32: furnace mouth with glow and a chimney
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _plate(d, 32, "#5a4a44")
    d.rectangle([6, 8, 21, 24], fill=rgba("#2a1c18"), outline=k)
    d.rectangle([8, 12, 19, 22], fill=rgba("#e0661c"))
    d.rectangle([10, 14, 17, 20], fill=rgba("#ffc04a"))
    d.rectangle([23, 4, 28, 11], fill=rgba("#555b66"), outline=k)
    d.rectangle([24, 5, 27, 7], fill=rgba("#7fbf3f"))
    d.rectangle([0, 14, 2, 18], fill=rgba("#3cd8ff"))
    d.rectangle([29, 14, 31, 18], fill=rgba("#ff4fb4"))
    save(img, "machine_smelter")
    # assembler 32x32: blue housing with a robot arm
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _plate(d, 32, "#3c5f7a")
    d.rectangle([5, 5, 26, 26], fill=rgba("#2a3e50"), outline=k)
    d.ellipse([12, 12, 19, 19], fill=rgba("#b8c2cc"), outline=k)
    d.line([(15, 15), (24, 8)], fill=rgba("#e0b030"), width=2)
    d.rectangle([23, 6, 26, 9], fill=rgba("#ff4040"))
    d.rectangle([0, 14, 2, 18], fill=rgba("#3cd8ff"))
    d.rectangle([29, 14, 31, 18], fill=rgba("#ff4fb4"))
    save(img, "machine_assembler")
    # storage in / out 16x16: crates with a chute marker
    for name, base, col in (("machine_storage_in", "#6a5a3c", "#4fe08a"), ("machine_storage_out", "#4e6a3c", "#ff9a30")):
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        _plate(d, 16, base)
        d.rectangle([4, 4, 11, 11], fill=rgba("#2a2418"), outline=k)
        d.rectangle([6, 6, 9, 9], fill=rgba(col))
        save(img, name)
# endregion


# region F8 gear icons
GPAL = dict(PAL)
GPAL.update({
    "c": "#6ae6ff", "C": "#2a9ab8", "z": "#e8f4ff",  # plasma glow
    "n": "#8a5a32", "N": "#5a3a20",  # wood / leather handle
    "e": "#6a7a5a", "E": "#46543c",  # olive fabric
    "j": "#4a5a70", "J": "#2e3a4c",  # vest / kevlar
    "u": "#c8a060", "U": "#8a6a3a",  # work glove leather
    "f": "#d8c8a8", "F": "#a89878",  # underlay cloth
})

GEAR_ICONS = {
    "prison_shiv": [
        "................",
        "..............ll",
        ".............lwl",
        "............lwl.",
        "...........lwl..",
        "..........lwl...",
        ".........lwl....",
        "........lwl.....",
        ".......lml......",
        "......mMM.......",
        ".....nmM........",
        "....nN..........",
        "...nN...........",
        "..nN............",
        ".MM.............",
        "................",
    ],
    "rifle": [
        "................",
        "................",
        "................",
        "......mm........",
        "...mmmmmmmmmMMM.",
        "mlmmMMMMMMMMmmMM",
        "mmMMMMMMMMMmmnnN",
        "..MM.mM.MmmnnnnN",
        "......MMMM.nnnN.",
        ".......MM..nnN..",
        ".......MM.......",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    "smg": [
        "................",
        "................",
        "................",
        "................",
        "..mm............",
        ".mmmmmmmmmmmm...",
        "mlmMMMMMMMmmMMM.",
        "mmmmmmmmmMMMMMM.",
        "....MM.mMM.mMM..",
        "....MM.....MM...",
        ".........mmMM...",
        ".........mm.....",
        ".........mm.....",
        "................",
        "................",
        "................",
    ],
    "kevlar_vest": [
        "................",
        "..jjj......jjj..",
        ".jjjjj....jjjjj.",
        ".jjjjjjjjjjjjjj.",
        ".jjjjjjjjjjjjjj.",
        ".jJjjjjjjjjjjJj.",
        "..jjJjjjjjjJjj..",
        "..jjjJjjjjJjjj..",
        "..jjjJJjjJJjjj..",
        "..jmmJJJJJJmmj..",
        "..jmmjjjjjjmmj..",
        "..jjjjjjjjjjjj..",
        "..jJJJJJJJJJJj..",
        "..JJJJJJJJJJJJ..",
        "................",
        "................",
    ],
    "helmet": [
        "................",
        "................",
        "....mmmmmmmm....",
        "...mllmmmmmmM...",
        "..mlmmmmmmmmmM..",
        "..mlmmmmmmmmmM..",
        "..mmmmmmmmmmMM..",
        "..mmmmmmmmmmMM..",
        "..mmkkkkkkkkMM..",
        "..mmMkbbbbkMMM..",
        "..mM.kkkkkk.MM..",
        "..MM........MM..",
        "................",
        "................",
        "................",
        "................",
    ],
    "plasma_blade": [
        "................",
        "............zzc.",
        "...........zcCC.",
        "..........zcCC..",
        ".........zcCC...",
        "........zcCC....",
        ".......zcCC.....",
        "......zcCC......",
        ".....zcC........",
        "...mmmMM........",
        "..mMmnM.........",
        ".nMMn...........",
        "nNnN............",
        "NN..............",
        "................",
        "................",
    ],
    "work_gloves": [
        "................",
        "....u.u.u.......",
        "...uuuuuuu......",
        "...uuuuuuuu.....",
        "...uUuuuuuuu....",
        "...uuuuuuuuu....",
        "..uuuuuuuuuU....",
        "..uuuuuuuuUU....",
        "...uuuuuuUU.....",
        "....uuuuUU......",
        "....UUUUUU......",
        "....UEEEEU......",
        "....EEEEEE......",
        "................",
        "................",
        "................",
    ],
    "greaves": [
        "................",
        "................",
        "...mmmm..mmmm...",
        "...mllM..mllM...",
        "...mlmM..mlmM...",
        "...mmmM..mmmM...",
        "...mlmM..mlmM...",
        "...mmmM..mmmM...",
        "...mmMM..mmMM...",
        "...MMMM..MMMM...",
        "..mmmmm..mmmmm..",
        "..mmmMM..mmmMM..",
        "..MMMMM..MMMMM..",
        "................",
        "................",
        "................",
    ],
    "underlay": [
        "................",
        "................",
        "..ff........ff..",
        ".ffff.ffff.ffff.",
        ".fffffffffffffF.",
        ".fffffffffffffF.",
        "..fffFfffffFfF..",
        "...ffFfffffFf...",
        "....fFfffffF....",
        "....fFfffffF....",
        "....fFfffffF....",
        "....FFffffFF....",
        "................",
        "................",
        "................",
        "................",
    ],
    "socket": [
        "................",
        "................",
        ".....kkkkkk.....",
        "....kttttttk....",
        "...kttzzzzttk...",
        "..kttzllllzttk..",
        "..ktzlkkkklztk..",
        "..ktzlk..klztk..",
        "..ktzlk..klztk..",
        "..ktzlkkkklztk..",
        "..kttzllllzttk..",
        "...kttzzzzttk...",
        "....kttttttk....",
        ".....kkkkkk.....",
        "................",
        "................",
    ],
}
GEAR_FRAME_COLORS = {
    "common": "#c0c0c8", "uncommon": "#5fd36b", "rare": "#4a90ff",
    "epic": "#b35cff", "legendary": "#ffb347",
}


def outline(img, color="#1a1420"):
    """Add a 1px dark outline around opaque pixels that sit next to transparency."""
    w, h = img.size
    src = img.copy()
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] \
                        and src.getpixel((nx, ny)) != rgba(color):
                    img.putpixel((x, y), rgba(color))
                    break
    return img


def gear_art():
    for name, rows in GEAR_ICONS.items():
        img = grid(rows, GPAL)
        if name != "socket":
            img = outline(img)
        save(img, "gear_" + name)
    for rarity, col in GEAR_FRAME_COLORS.items():
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, 15, 15], outline=rgba(col))
        d.rectangle([1, 1, 14, 14], outline=rgba(col, 90))
        for cx, cy in ((0, 0), (15, 0), (0, 15), (15, 15)):  # round the corners
            img.putpixel((cx, cy), (0, 0, 0, 0))
        save(img, "gear_frame_" + rarity)
# endregion

# region passives_v2
# Passive icons (docs/gdd/03-colony/passives-v2): 16x16, frame shape = tier
# (minor: cut-corner box, notable: double square, keystone: diamond), colour = detail,
# glyph = detail motif (minor/notable) or a unique keystone motif, sigil = 4x4 mark per node.
PPAL = dict(PAL)
PPAL.update({
    "x": "#f4f0e8", "X": "#b8b0a0",  # light / shade of the glyph
    "q": "#1a1420",                   # dark fill
})
PASSIVE_DETAIL_COLORS = {
    "pit": "#c8a060", "stacks": "#9a5cff", "shop": "#4fb3a9", "yard": "#e04a3a",
    "infirmary": "#5fd36b", "ledger": "#ffd23a", "key": "#ffb347",
}
PASSIVE_GLYPHS = {
    "pit": [  # pickaxe
        "....xxxx..",
        "...xXxxxx.",
        "..xX...xx.",
        "..x...x.x.",
        ".....x....",
        "....x.....",
        "...x......",
        "..x.......",
        ".x........",
        "x.........",
    ],
    "stacks": [  # flask
        "...xxxx...",
        "....xx....",
        "....xx....",
        "...x..x...",
        "..x....x..",
        ".x......x.",
        ".x.XXXX.x.",
        ".x.XXXX.x.",
        "..xXXXXx..",
        "...xxxx...",
    ],
    "shop": [  # wrench
        ".......xx.",
        "......xxxx",
        "......x.xx",
        ".....xxxx.",
        "....xxx...",
        "...xxx....",
        "..xxx.....",
        ".xxx......",
        "xxx.......",
        "xx........",
    ],
    "yard": [  # fist
        "..........",
        "..xxxxxx..",
        ".xXxxxxxx.",
        ".xxxxxxxx.",
        ".xxxxxxxx.",
        ".xXXXXXxx.",
        "..xxxxxx..",
        "..xxxxxx..",
        "...xxxx...",
        "..........",
    ],
    "infirmary": [  # cross
        "...xxxx...",
        "...xxxx...",
        "...xXXx...",
        "xxxxXXxxxx",
        "xxXXXXXXxx",
        "xxXXXXXXxx",
        "xxxxXXxxxx",
        "...xXXx...",
        "...xxxx...",
        "...xxxx...",
    ],
    "ledger": [  # ledger book
        ".xxxxxxxx.",
        ".xXXXXXXx.",
        ".xXxxxxXx.",
        ".xXXXXXXx.",
        ".xXxxxxXx.",
        ".xXXXXXXx.",
        ".xXxxxxXx.",
        ".xXXXXXXx.",
        ".xxxxxxxx.",
        "..xxxxxx..",
    ],
}
PASSIVE_KEY_GLYPHS = {
    "pit_lifers_back": [  # bent back under a sack
        "..........",
        "....xxxx..",
        "...xxxxxx.",
        "..xxxxxxxx",
        ".xxXXxxxxx",
        ".xxXXxx...",
        "..xxxx....",
        "..x..x....",
        ".xx..xx...",
        "..........",
    ],
    "stacks_essence_lung": [  # lungs
        "....xx....",
        "....xx....",
        ".xx.xx.xx.",
        "xxxxxxxxxx",
        "xXxxxxxxXx",
        "xXxxxxxxXx",
        "xxxx..xxxx",
        "xxxx..xxxx",
        ".xx....xx.",
        "..........",
    ],
    "shop_signature_work": [  # stamped seal
        "..xxxxxx..",
        ".xXXXXXXx.",
        "xXXxxxxXXx",
        "xXx....xXx",
        "xXx.xx.xXx",
        "xXx.xx.xXx",
        "xXx....xXx",
        "xXXxxxxXXx",
        ".xXXXXXXx.",
        "..xxxxxx..",
    ],
    "yard_dead_man_walking": [  # skull
        "..xxxxxx..",
        ".xxxxxxxx.",
        "xxxxxxxxxx",
        "xxqqxxqqxx",
        "xxqqxxqqxx",
        "xxxxxxxxxx",
        ".xxxqqxxx.",
        "..xxxxxx..",
        "..xqxqxq..",
        "..xxxxxx..",
    ],
    "infirmary_field_surgeon": [  # scalpel
        ".......xx.",
        "......xxx.",
        ".....xxx..",
        "....xxx...",
        "...xxx....",
        "..xxx.....",
        ".xXx......",
        "xXX.......",
        "XX........",
        "..........",
    ],
    "ledger_trustee": [  # key
        "..xxxx....",
        ".xx..xx...",
        ".x....x...",
        ".xx..xx...",
        "..xxxx....",
        "...xx.....",
        "...xx.....",
        "...xxxx...",
        "...xx.....",
        "...xxxx...",
    ],
    "clean_hands": [  # open hand
        "...x.x.x..",
        "..xx.x.xx.",
        "x.xxxxxxx.",
        "xx.xxxxxx.",
        ".xxxxxxxx.",
        "..xxxxxxx.",
        "..xxxxxx..",
        "...xxxxx..",
        "...xxxx...",
        "..........",
    ],
    "essence_smith": [  # anvil with glow
        "..........",
        "...xxxxxxx",
        "..xxxxxxx.",
        ".xxxxxxx..",
        "...xxx....",
        "...xxx....",
        "..xxxxx...",
        ".xxxxxxx..",
        ".XXXXXXX..",
        "..........",
    ],
    "armourers_pride": [  # shield
        ".xxxxxxxx.",
        "xxxxxxxxxx",
        "xxXXxxXXxx",
        "xxXXxxXXxx",
        "xxxxxxxxxx",
        ".xxxxxxxx.",
        ".xxxxxxxx.",
        "..xxxxxx..",
        "...xxxx...",
        "....xx....",
    ],
    "walking_wounded": [  # bandaged heart
        "..........",
        ".xx...xx..",
        "xxxx.xxxx.",
        "xxXXXXXxx.",
        "xxxxxxxxx.",
        ".xxXXXxx..",
        "..xxxxx...",
        "...xxx....",
        "....x.....",
        "..........",
    ],
    "chaplain": [  # candle
        "....x.....",
        "...xXx....",
        "...xXx....",
        "....x.....",
        "...xxxx...",
        "...xXXx...",
        "...xXXx...",
        "...xXXx...",
        "..xxxxxx..",
        "..........",
    ],
    "quota_hawk": [  # hawk head
        "..........",
        "...xxxx...",
        "..xxxxxx..",
        ".xxqxxxxx.",
        ".xxxxxxxxx",
        "..xxxxxXX.",
        "...xxxxX..",
        "....xxx...",
        "....xx....",
        "..........",
    ],
}
PASSIVE_SIGILS = [  # 4x4 marks, one per node slot (m1..m8, n1..n3) within a detail
    ["....", ".xx.", ".xx.", "...."],  # dot
    [".x..", "xxx.", ".x..", "...."],  # plus
    [".x..", "xxx.", ".x..", ".x.."],  # arrow up
    ["x...", "xx..", "xxx.", "xxxx"],  # ramp
    ["x.x.", ".x..", "x.x.", "...."],  # cross
    ["xxxx", "x..x", "x..x", "xxxx"],  # box
    [".x..", ".x..", "xxx.", ".x.."],  # drop
    ["..x.", ".x..", "xxx.", ".x.."],  # bolt
    ["xxx.", ".x..", ".x..", "...."],  # tee
    ["xxxx", "....", "xxxx", "...."],  # bars
    ["x..x", ".xx.", ".xx.", "x..x"],  # star
    [".xx.", "x..x", "x..x", ".xx."],  # ring
]
# (sprite name, detail, tier, slot index) — generated with data/passives_v2.json (same order).
PASSIVE_ICONS = [
    ("passive_pit_callouses", "pit", "minor", 0),
    ("passive_pit_yard_shoulders", "pit", "minor", 1),
    ("passive_pit_pick_rhythm", "pit", "minor", 2),
    ("passive_pit_scaffold_eye", "pit", "minor", 3),
    ("passive_pit_the_mule", "pit", "notable", 4),
    ("passive_pit_ore_sense", "pit", "minor", 5),
    ("passive_pit_salvage_habit", "pit", "notable", 6),
    ("passive_pit_long_shift", "pit", "minor", 7),
    ("passive_pit_quiet_pick", "pit", "minor", 8),
    ("passive_pit_braced_walls", "pit", "minor", 9),
    ("passive_pit_vein_reader", "pit", "notable", 10),
    ("passive_pit_lifers_back", "pit", "keystone", "lifers_back"),
    ("passive_stacks_rubber_gloves", "stacks", "minor", 0),
    ("passive_stacks_valve_feel", "stacks", "minor", 1),
    ("passive_stacks_nose_plug", "stacks", "minor", 2),
    ("passive_stacks_scrub_hands", "stacks", "minor", 3),
    ("passive_stacks_slow_pour", "stacks", "notable", 4),
    ("passive_stacks_gauge_eye", "stacks", "minor", 5),
    ("passive_stacks_second_skin", "stacks", "notable", 6),
    ("passive_stacks_still_air", "stacks", "minor", 7),
    ("passive_stacks_fume_tolerance", "stacks", "minor", 8),
    ("passive_stacks_flush_cycle", "stacks", "minor", 9),
    ("passive_stacks_cold_hands", "stacks", "notable", 10),
    ("passive_stacks_essence_lung", "stacks", "keystone", "essence_lung"),
    ("passive_shop_file_and_vice", "shop", "minor", 0),
    ("passive_shop_scrap_eye", "shop", "minor", 1),
    ("passive_shop_true_edge", "shop", "minor", 2),
    ("passive_shop_oil_rag", "shop", "minor", 3),
    ("passive_shop_reloader", "shop", "notable", 4),
    ("passive_shop_steady_file", "shop", "minor", 5),
    ("passive_shop_patch_kit", "shop", "notable", 6),
    ("passive_shop_tinker_hours", "shop", "minor", 7),
    ("passive_shop_tight_tolerance", "shop", "minor", 8),
    ("passive_shop_bench_sense", "shop", "minor", 9),
    ("passive_shop_makers_mark", "shop", "notable", 10),
    ("passive_shop_signature_work", "shop", "keystone", "signature_work"),
    ("passive_yard_yard_stance", "yard", "minor", 0),
    ("passive_yard_shiv_grip", "yard", "minor", 1),
    ("passive_yard_duck_and_cover", "yard", "minor", 2),
    ("passive_yard_flinch_less", "yard", "minor", 3),
    ("passive_yard_brawler", "yard", "notable", 4),
    ("passive_yard_breath_control", "yard", "minor", 5),
    ("passive_yard_thick_skin", "yard", "notable", 6),
    ("passive_yard_fast_hands", "yard", "minor", 7),
    ("passive_yard_count_shots", "yard", "minor", 8),
    ("passive_yard_scar_tissue", "yard", "minor", 9),
    ("passive_yard_killers_eye", "yard", "notable", 10),
    ("passive_yard_dead_man_walking", "yard", "keystone", "dead_man_walking"),
    ("passive_infirmary_clean_rags", "infirmary", "minor", 0),
    ("passive_infirmary_bedside_manner", "infirmary", "minor", 1),
    ("passive_infirmary_light_sleeper", "infirmary", "minor", 2),
    ("passive_infirmary_iron_gut", "infirmary", "minor", 3),
    ("passive_infirmary_triage", "infirmary", "notable", 4),
    ("passive_infirmary_steady_needle", "infirmary", "minor", 5),
    ("passive_infirmary_thick_blood", "infirmary", "notable", 6),
    ("passive_infirmary_calm_voice", "infirmary", "minor", 7),
    ("passive_infirmary_chart_reader", "infirmary", "minor", 8),
    ("passive_infirmary_taint_watch", "infirmary", "minor", 9),
    ("passive_infirmary_even_keel", "infirmary", "notable", 10),
    ("passive_infirmary_field_surgeon", "infirmary", "keystone", "field_surgeon"),
    ("passive_ledger_count_the_coins", "ledger", "minor", 0),
    ("passive_ledger_quiet_mouth", "ledger", "minor", 1),
    ("passive_ledger_block_voice", "ledger", "minor", 2),
    ("passive_ledger_stoic", "ledger", "minor", 3),
    ("passive_ledger_stash_pocket", "ledger", "notable", 4),
    ("passive_ledger_haggler", "ledger", "minor", 5),
    ("passive_ledger_shot_caller", "ledger", "notable", 6),
    ("passive_ledger_long_memory", "ledger", "minor", 7),
    ("passive_ledger_clean_sheet", "ledger", "minor", 8),
    ("passive_ledger_scrip_sense", "ledger", "minor", 9),
    ("passive_ledger_wardens_ear", "ledger", "notable", 10),
    ("passive_ledger_trustee", "ledger", "keystone", "trustee"),
    ("passive_key_clean_hands", "key", "keystone", "clean_hands"),
    ("passive_key_essence_smith", "key", "keystone", "essence_smith"),
    ("passive_key_armourers_pride", "key", "keystone", "armourers_pride"),
    ("passive_key_walking_wounded", "key", "keystone", "walking_wounded"),
    ("passive_key_chaplain", "key", "keystone", "chaplain"),
    ("passive_key_quota_hawk", "key", "keystone", "quota_hawk"),
]


def _passive_frame(d, tier, col):
    base = rgba(col)
    dim = rgba(col, 110)
    if tier == "minor":
        d.rectangle([1, 1, 14, 14], outline=dim)
        for cx, cy in ((1, 1), (14, 1), (1, 14), (14, 14)):
            d.point((cx, cy), (0, 0, 0, 0))
    elif tier == "notable":
        d.rectangle([0, 0, 15, 15], outline=base)
        d.rectangle([2, 2, 13, 13], outline=dim)
    else:  # keystone: diamond
        d.polygon([(7, 0), (8, 0), (15, 7), (15, 8), (8, 15), (7, 15), (0, 8), (0, 7)], outline=base)
        d.polygon([(7, 2), (8, 2), (13, 7), (13, 8), (8, 13), (7, 13), (2, 8), (2, 7)], outline=dim)


def passives_v2_art():
    for name, detail, tier, slot in PASSIVE_ICONS:
        col = PASSIVE_DETAIL_COLORS[detail]
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        _passive_frame(d, tier, col)
        if tier == "keystone":
            rows = PASSIVE_KEY_GLYPHS[slot] if detail == "key" else PASSIVE_KEY_GLYPHS[detail + "_" + slot]
        else:
            rows = PASSIVE_GLYPHS[detail]
        pal = dict(PPAL)
        pal["x"] = col
        pal["X"] = "#f4f0e8"
        glyph = outline(grid(rows, pal))
        img.alpha_composite(glyph, (3, 3))
        if tier != "keystone":
            d.rectangle([10, 10, 15, 15], fill=rgba("#1a1420"))
            img.alpha_composite(grid(PASSIVE_SIGILS[slot], {".": None, "x": "#f4f0e8"}), (11, 11))
        save(img, name)
# endregion


# region traits_v3
# 16x16 trait icons (docs/gdd/03-colony/traits-v3/): a category-coloured badge with an 8x8 glyph.
# Glyph chars: "#" light, "+" accent (gold), "." empty. Ids without the t_ prefix -> trait_<id>.png.
TRAIT_CATEGORY_COLORS = {
    "personality": ("#e0a030", "#8a5a14"),
    "body": ("#c83a2c", "#8a2018"),
    "background": ("#7c8794", "#4f5866"),
    "scar": ("#7a2a4a", "#4e1830"),
    "mutation": ("#9b6cff", "#5a3aa0"),
    "social": ("#4fb3a9", "#2a7a70"),
}

TRAIT_ICONS = {
    # personality
    "stoic": ("personality", [
        "........", "..####..", ".#....#.", ".#.##.#.", ".#....#.", ".######.", "..#..#..", "........"]),
    "volatile": ("personality", [
        "....+...", "...++...", "..+##...", ".+####..", "...##+..", "..##+...", "..#+....", "..+....."]),
    "greedy": ("personality", [
        "..####..", ".#+..+#.", ".#.##.#.", ".#+..+#.", ".######.", "..#..#..", ".+#..#+.", "........"]),
    "compliant": ("personality", [
        ".######.", ".#....#.", ".#.##.#.", ".#....#.", ".#.##.#.", ".#...+#.", ".###+##.", "........"]),
    "defiant": ("personality", [
        "...##...", "..#++#..", "..####..", ".######.", "..####..", "...##...", "..#..#..", ".#....#."]),
    "paranoid": ("personality", [
        "........", ".######.", "#..##..#", "#.#++#.#", "#..##..#", ".######.", "...##...", "........"]),
    "curious": ("personality", [
        "..####..", ".#....#.", "......#.", "....##..", "...#....", "...#....", "........", "...+...."]),
    "morbid": ("personality", [
        "..####..", ".######.", ".#.##.#.", ".######.", "..#..#..", "..####..", "...##...", "..+..+.."]),
    "tunnel_rat": ("personality", [
        "########", "#......#", "#.####.#", "#.#..#.#", "#.#+.#.#", "#.####.#", "#......#", "########"]),
    "gallows_humor": ("personality", [
        "...##...", "..####..", "..#..#..", "..####..", ".#....#.", "..#++#..", "...##...", "........"]),
    "creature_of_habit": ("personality", [
        "..####..", ".#....#.", "#..#...#", "#..##..#", "#..#...#", ".#....#.", "..####..", "...++..."]),
    "dreamer": ("personality", [
        "........", "..+.....", ".######.", ".#.##.#.", ".##..##.", ".######.", "....+...", "........"]),
    "methodical": ("personality", [
        "#..#..#.", "#..#..#.", "#..#..#.", "#..#..#.", "######..", "......+.", ".....+..", "....+..."]),
    "reckless": ("personality", [
        "+.......", ".+..##..", "..+####.", "...####.", "..#####.", ".######.", "..+..+..", "........"]),
    # body
    "hulking": ("body", [
        "..####..", ".######.", "########", "########", ".######.", "..#..#..", "..#..#..", ".##..##."]),
    "wiry": ("body", [
        "...##...", "...##...", "..####..", "...##...", "...##...", "...##...", "..#..#..", "..#..#.."]),
    "tar_lungs": ("body", [
        "...##...", "..####..", ".##..##.", ".#.+.+#.", ".##..##.", ".##..##.", "..#..#..", "........"]),
    "one_eye": ("body", [
        "........", "..####..", ".#....#.", "#..+#..#", ".#....#.", "..####..", "...####.", "........"]),
    "fast_healer": ("body", [
        "...##...", "...##...", ".######.", ".######.", "...##...", "...##...", "....+...", "...+...."]),
    "bleeder": ("body", [
        "...#....", "..###...", ".#####..", ".#####..", "..###...", "....+...", "...+....", "..+....."]),
    "insomniac": ("body", [
        "..###...", ".#......", "#.......", "#....+..", "#.......", ".#......", "..###...", "....+..."]),
    "heavy_sleeper": ("body", [
        "........", "........", ".####...", "....#...", "...#..++", "..#....+", ".####.++", "........"]),
    "sharp_ears": ("body", [
        "..##....", ".#..#...", ".#...#..", ".#...#.+", ".#..#.+.", "..##.+..", "...#....", "........"]),
    "dead_nerves": ("body", [
        "........", ".######.", ".#....#.", ".#.++.#.", ".#....#.", ".######.", "........", "........"]),
    # background (the Charge)
    "charge_murder": ("background", [
        "..#.....", "..#.....", ".###....", "..#..+..", "..#.+.+.", "..#..+..", "..#.....", "........"]),
    "charge_fraud": ("background", [
        ".######.", ".#....#.", ".#+#+.#.", ".#....#.", ".#.+#.#.", ".#....#.", ".######.", "........"]),
    "charge_sedition": ("background", [
        "........", ".######.", ".#....#.", ".#.##.#.", ".#....#.", ".######.", "...++...", "...++..."]),
    "charge_smuggling": ("background", [
        "........", "..####..", ".#.##.#.", ".#....#.", ".##..##.", "..#++#..", "...##...", "........"]),
    "charge_arson": ("background", [
        "...+....", "..+#+...", ".+###+..", ".+####+.", "+######+", ".######.", "..####..", "........"]),
    "charge_desertion": ("background", [
        ".#......", ".###....", ".#####..", ".######.", ".#####..", ".###....", ".#......", ".#......"]),
    "charge_debt": ("background", [
        "...+....", "..####..", ".#.+....", "..####..", "....+.#.", "..####..", "...+....", "........"]),
    "charge_essence_theft": ("background", [
        "...##...", "..#++#..", ".#+##+#.", ".#+##+#.", "..#++#..", "...##...", "...##...", "..####.."]),
    "charge_cult": ("background", [
        "...##...", "..#..#..", ".#.++.#.", "#..++..#", ".#....#.", "..#..#..", "...##...", "...##..."]),
    "charge_mutiny": ("background", [
        "..#.....", "..##....", "..####..", "..######", "..####..", "..##....", "#######.", "........"]),
    "charge_poaching": ("background", [
        "........", "..#..#..", ".#.##.#.", ".#+##+#.", "..####..", "...##...", "..#..#..", "........"]),
    "charge_sealed": ("background", [
        ".######.", ".######.", ".######.", ".##++##.", ".######.", ".######.", ".######.", "........"]),
    "charge_wrongful": ("background", [
        ".#....#.", "..#..#..", "...##...", "...##...", "..#..#..", ".#....#.", "...++...", "........"]),
    # scars
    "hardened": ("scar", [
        "..####..", ".######.", ".######.", ".######.", "..####..", "..####..", "...##...", "....+..."]),
    "resigned": ("scar", [
        "........", ".#....#.", "..#..#..", "........", "........", "..####..", ".#....#.", "........"]),
    "settled": ("scar", [
        "........", "...##...", "..####..", ".######.", ".#.##.#.", ".#.##.#.", ".######.", "........"]),
    "shellshocked": ("scar", [
        "+..##..+", ".+####+.", ".##..##.", "+#....#+", ".##..##.", ".+####+.", "+..##..+", "........"]),
    "marked": ("scar", [
        ".#......", "..#.....", "...#..#.", "....##..", "....##..", "...#..#.", "..#.....", ".#......"]),
    "docked": ("scar", [
        "..####..", ".#....#.", ".#....#.", ".######.", ".#....#.", ".#.++.#.", "..####..", "........"]),
    "last_one": ("scar", [
        "...##...", "...##...", "...##...", "...##...", "...##...", "........", "...+....", "........"]),
    "lean_years": ("scar", [
        "..####..", ".#....#.", ".#....#.", ".#....#.", ".#....#.", "..####..", "...++...", "........"]),
    "reported": ("scar", [
        "........", "..###...", ".#...#..", ".#.+.#..", ".#...#..", "..###...", "...#....", "..#....."]),
    "cell_rot": ("scar", [
        "########", "#.#..#.#", "#.#..#.#", "#.#.+#.#", "#.#..#.#", "#.#..#.#", "#.#..#.#", "########"]),
    "old_timer": ("scar", [
        "........", "..####..", ".#....#.", ".#.++.#.", ".#..+.#.", "..####..", "........", "........"]),
    "runner": ("scar", [
        "....##..", "...##...", "..#####.", ".#.##...", "...##...", "..#..#..", ".#....#.", "........"]),
    # mutation / essence
    "glowtouched": ("mutation", [
        "...+....", ".+.#.+..", "..###...", "+#####+.", "..###...", ".+.#.+..", "...+....", "........"]),
    "second_skin": ("mutation", [
        "########", "#+#..#+#", "########", "#..##..#", "########", "#+#..#+#", "########", "........"]),
    "hollow": ("mutation", [
        "..####..", ".#....#.", "#......#", "#......#", "#......#", ".#....#.", "..####..", "........"]),
    "essence_hum": ("mutation", [
        "........", ".+..+...", "#.##.##.", "........", ".#..#..#", "..##.##.", "...+..+.", "........"]),
    "black_veins": ("mutation", [
        "#....#..", ".#..#...", "..##....", "..##.+..", ".#..#...", "#....#..", ".....#..", "........"]),
    "echo": ("mutation", [
        "...#....", "..#.#...", ".#.+.#..", "#..+..#.", ".#.+.#..", "..#.#...", "...#....", "........"]),
    "waste_kin": ("mutation", [
        "........", "..+..+..", ".######.", ".#.##.#.", ".######.", "..####..", ".#.##.#.", "........"]),
    "clean_blood": ("mutation", [
        "...#....", "..###...", ".#####..", ".##+##..", "..###...", "...#....", "........", "........"]),
    # social
    "cellmate": ("social", [
        "..#..#..", ".###.###", "..#..#..", ".###.###", "..#..#..", "..####..", "........", "........"]),
    "rival": ("social", [
        ".#....#.", ".##..##.", ".#.++.#.", ".#.++.#.", ".##..##.", ".#....#.", "........", "........"]),
    "block_boss": ("social", [
        "+.+..+.+", "########", ".######.", "..####..", "...##...", "..####..", ".######.", "........"]),
    "outcast": ("social", [
        "..#.....", ".###....", "..#.....", ".###....", "......+.", ".....+.+", "......+.", "........"]),
    "wardens_ear": ("social", [
        "..###...", ".#...#..", ".#.+.#..", "..#.#...", "...#....", "...#..++", "..###.++", "........"]),
    "peacemaker": ("social", [
        "...##...", "..####..", ".#.##.#.", ".######.", "..####..", "...##...", "..+..+..", "........"]),
    "agitator": ("social", [
        "...##...", "..#++#..", ".#.##.#.", "...##...", "...##...", "..####..", ".######.", "........"]),
    "quiet_one": ("social", [
        "........", "..####..", ".#....#.", ".#....#.", ".######.", "........", "...++...", "........"]),
    "mentor": ("social", [
        "..##....", ".####...", "..##....", ".####.+.", "#....+#.", "#....##.", "......#.", "........"]),
}


def trait_art():
    for name, (cat, glyph) in TRAIT_ICONS.items():
        fill, dark = TRAIT_CATEGORY_COLORS[cat]
        img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rectangle([1, 1, 14, 14], fill=rgba(dark))
        d.rectangle([2, 2, 13, 13], fill=rgba(fill))
        d.line([(2, 2), (13, 2)], fill=rgba(dark))  # bevel
        d.line([(2, 2), (2, 13)], fill=rgba(dark))
        for cx, cy in ((1, 1), (14, 1), (1, 14), (14, 14)):
            img.putpixel((cx, cy), (0, 0, 0, 0))
        assert len(glyph) == 8, name
        for y, row in enumerate(glyph):
            assert len(row) == 8, "%s row %d" % (name, y)
            for x, ch in enumerate(row):
                if ch == "#":
                    img.putpixel((4 + x, 4 + y), rgba(PAL["w"]))
                elif ch == "+":
                    img.putpixel((4 + x, 4 + y), rgba(PAL["y"]))
        img = outline(img)
        save(img, "trait_" + name)
# endregion


def main():
    os.makedirs(OUT, exist_ok=True)
    colonists()
    colonist_sheets()
    creatures()
    creature_sheets()  # region G1a
    turret()
    refinery()
    capsule()
    walls()  # region construction
    items()
    pickaxe()
    terrain()
    food_art()  # region needs
    atmosphere_art()  # region G1c
    belt_art()  # region A2c
    machine_art()  # region A2c
    gear_art()  # region F8
    passives_v2_art()  # region passives_v2
    trait_art()  # region traits_v3
    print("sprites written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
