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


def main():
    os.makedirs(OUT, exist_ok=True)
    colonists()
    creatures()
    turret()
    refinery()
    capsule()
    items()
    pickaxe()
    terrain()
    print("sprites written to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
