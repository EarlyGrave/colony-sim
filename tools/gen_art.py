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


def main():
    os.makedirs(OUT, exist_ok=True)
    colonists()
    colonist_sheets()
    creatures()
    turret()
    refinery()
    capsule()
    walls()  # region construction
    items()
    pickaxe()
    terrain()
    food_art()  # region needs
    atmosphere_art()  # region G1c
    print("sprites written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
