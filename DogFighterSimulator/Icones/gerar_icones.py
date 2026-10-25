"""Gera os ícones 512x512 dos gamepasses/produtos (Icones/*.png)."""
import math, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024  # desenha em 2x e reduz (bordas suaves)
OUT = os.path.dirname(os.path.abspath(__file__))
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def font(size): return ImageFont.truetype(FONT, size)

def bg(top, bottom):
    img = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        k = y / S
        c = tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3))
        d.line([(0, y), (S, y)], fill=c + (255,))
    # brilho radial
    glow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(glow).ellipse([S*0.1, S*0.05, S*0.9, S*0.75], fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(Image.new("RGBA", (S, S), (255, 255, 255, 255)), img, glow.point(lambda v: v // 2))
    # raios
    rays = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rays)
    cx, cy = S / 2, S * 0.44
    for i in range(16):
        a0 = i * math.tau / 16
        a1 = a0 + math.tau / 40
        rd.polygon([(cx, cy), (cx + 1500 * math.cos(a0), cy + 1500 * math.sin(a0)), (cx + 1500 * math.cos(a1), cy + 1500 * math.sin(a1))], fill=(255, 255, 255, 28))
    img.alpha_composite(rays)
    return img

def outline_text(d, xy, text, size, fill=(255, 255, 255), stroke=(20, 15, 30), sw=None, anchor="mm"):
    d.text(xy, text, font=font(size), fill=fill, stroke_width=sw or max(6, size // 9), stroke_fill=stroke, anchor=anchor)

def label(img, text, color=(255, 255, 255)):
    d = ImageDraw.Draw(img)
    size = 150 if len(text) <= 6 else (120 if len(text) <= 9 else 96)
    outline_text(d, (S / 2, S * 0.86), text, size, fill=color, sw=16)

INK = (20, 15, 30)

def coin(d, cx, cy, r, sym="$"):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 205, 50), outline=INK, width=14)
    d.ellipse([cx - r * 0.75, cy - r * 0.75, cx + r * 0.75, cy + r * 0.75], outline=(225, 160, 20), width=10)
    outline_text(d, (cx, cy + 4), sym, int(r * 1.1), fill=(255, 245, 190), sw=8)

def egg(d, cx, cy, w, h, fill, spots=None):
    d.ellipse([cx - w, cy - h, cx + w, cy + h * 0.85], fill=fill, outline=INK, width=16)
    d.ellipse([cx - w * 0.55, cy - h * 0.75, cx - w * 0.15, cy - h * 0.3], fill=(255, 255, 255, 160))
    for (sx, sy, sr, sc) in (spots or []):
        d.ellipse([cx + sx - sr, cy + sy - sr, cx + sx + sr, cy + sy + sr], fill=sc)

def paw(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r * 0.6, cx + r, cy + r * 0.9], fill=fill, outline=INK, width=14)
    for dx, dy in [(-0.95, -0.95), (-0.35, -1.35), (0.35, -1.35), (0.95, -0.95)]:
        tr = r * 0.38
        x, y = cx + dx * r, cy + dy * r
        d.ellipse([x - tr, y - tr * 1.15, x + tr, y + tr * 1.15], fill=fill, outline=INK, width=12)

def star(d, cx, cy, r, fill):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=fill, outline=INK, width=10)

def sparkle(d, cx, cy, r, fill=(255, 255, 255)):
    d.polygon([(cx, cy - r), (cx + r * 0.25, cy - r * 0.25), (cx + r, cy), (cx + r * 0.25, cy + r * 0.25), (cx, cy + r), (cx - r * 0.25, cy + r * 0.25), (cx - r, cy), (cx - r * 0.25, cy - r * 0.25)], fill=fill)

def save(img, name):
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=150, fill=255)
    img.putalpha(mask)
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))

# ---------------------------------------------------------------- ícones
def starter():
    img = bg((255, 170, 60), (220, 70, 40)); d = ImageDraw.Draw(img)
    d.rounded_rectangle([250, 380, 774, 720], 30, fill=(235, 60, 90), outline=INK, width=16)
    d.rounded_rectangle([220, 300, 804, 400], 26, fill=(255, 90, 120), outline=INK, width=16)
    d.rectangle([472, 300, 552, 720], fill=(255, 210, 60), outline=INK, width=12)
    d.ellipse([380, 190, 510, 310], fill=(255, 210, 60), outline=INK, width=14)
    d.ellipse([514, 190, 644, 310], fill=(255, 210, 60), outline=INK, width=14)
    sparkle(d, 200, 220, 60); sparkle(d, 830, 260, 45)
    label(img, "STARTER", (255, 240, 120)); save(img, "01_StarterPack")

def double(name, file, top, bottom, sym, symfill):
    img = bg(top, bottom); d = ImageDraw.Draw(img)
    if sym == "$":
        coin(d, 640, 420, 190)
    else:
        d.ellipse([450, 230, 830, 610], fill=(90, 210, 255), outline=INK, width=14)
        outline_text(d, (640, 425), "XP", 170, fill=(255, 255, 255), sw=12)
    outline_text(d, (330, 430), "2x", 300, fill=symfill, sw=22)
    label(img, name); save(img, file)

def fast_eggs():
    img = bg((120, 220, 255), (40, 110, 220)); d = ImageDraw.Draw(img)
    for i, y in enumerate([330, 430, 530]):
        d.rounded_rectangle([140 + i * 30, y, 420, y + 36], 18, fill=(255, 255, 255, 220))
    egg(d, 600, 440, 190, 250, (255, 240, 200), [(-60, 40, 30, (255, 170, 80)), (70, -40, 24, (255, 170, 80))])
    label(img, "FAST EGGS"); save(img, "04_FastEggs")

def auto_collect():
    img = bg((150, 230, 120), (40, 150, 70)); d = ImageDraw.Draw(img)
    # mochila
    d.rounded_rectangle([300, 330, 724, 740], 70, fill=(200, 120, 60), outline=INK, width=16)
    d.rounded_rectangle([370, 520, 654, 680], 30, fill=(225, 150, 80), outline=INK, width=12)
    d.arc([400, 230, 624, 430], 180, 360, fill=INK, width=30)
    egg(d, 512, 250, 90, 120, (255, 240, 200))
    d.polygon([(470, 400), (554, 400), (512, 470)], fill=(255, 255, 255), outline=INK)
    label(img, "AUTO COLLECT"); save(img, "05_AutoCollect")

def auto_hatch():
    img = bg((255, 220, 90), (240, 140, 40)); d = ImageDraw.Draw(img)
    egg(d, 512, 470, 210, 270, (255, 245, 220))
    zig = [(300, 430), (360, 380), (420, 440), (480, 370), (540, 440), (600, 370), (660, 440), (725, 390)]
    d.line(zig, fill=INK, width=18, joint="curve")
    paw(d, 512, 560, 70, (255, 200, 120))
    sparkle(d, 220, 260, 55); sparkle(d, 810, 300, 50)
    label(img, "AUTO HATCH"); save(img, "06_AutoHatch")

def vip():
    img = bg((190, 120, 255), (90, 40, 180)); d = ImageDraw.Draw(img)
    pts = [(260, 640), (260, 330), (390, 470), (512, 270), (634, 470), (764, 330), (764, 640)]
    d.polygon(pts, fill=(255, 205, 50), outline=INK, width=18)
    d.rectangle([260, 600, 764, 680], fill=(255, 185, 30), outline=INK, width=16)
    for x, c in [(390, (255, 80, 120)), (512, (80, 200, 255)), (634, (90, 230, 120))]:
        d.ellipse([x - 34, 520, x + 34, 588], fill=c, outline=INK, width=10)
    sparkle(d, 200, 230, 55); sparkle(d, 840, 230, 55)
    label(img, "VIP", (255, 230, 90)); save(img, "07_VIP")

def cash(file, name, n, top, bottom):
    img = bg(top, bottom); d = ImageDraw.Draw(img)
    if n == 1:  # saquinho
        d.ellipse([300, 330, 724, 740], fill=(200, 160, 90), outline=INK, width=16)
        d.polygon([(420, 340), (604, 340), (650, 250), (374, 250)], fill=(200, 160, 90), outline=INK)
        d.rectangle([400, 320, 624, 360], fill=(150, 100, 50), outline=INK, width=10)
        outline_text(d, (512, 560), "$", 230, fill=(120, 235, 110), sw=16)
    elif n == 2:  # maleta
        d.rounded_rectangle([230, 360, 794, 720], 40, fill=(120, 80, 50), outline=INK, width=16)
        d.rounded_rectangle([420, 280, 604, 370], 20, outline=INK, width=26)
        d.rectangle([230, 480, 794, 520], fill=(90, 60, 35))
        for i in range(5):
            coin(d, 300 + i * 105, 330 - (i % 2) * 40, 62)
        outline_text(d, (512, 610), "$$", 150, fill=(120, 235, 110), sw=12)
    else:  # cofre
        d.rounded_rectangle([220, 220, 804, 740], 60, fill=(150, 160, 180), outline=INK, width=18)
        d.ellipse([340, 300, 684, 644], fill=(110, 120, 140), outline=INK, width=16)
        for k in range(6):
            a = k * math.pi / 3
            d.line([(512, 472), (512 + 130 * math.cos(a), 472 + 130 * math.sin(a))], fill=INK, width=20)
        d.ellipse([462, 422, 562, 522], fill=(255, 205, 50), outline=INK, width=12)
        for i in range(3):
            coin(d, 250 + i * 70, 760 - i * 40, 70)
    label(img, name); save(img, file)

def crystal():
    img = bg((140, 240, 255), (60, 90, 220)); d = ImageDraw.Draw(img)
    egg(d, 512, 450, 200, 260, (170, 240, 255))
    d.polygon([(400, 330), (470, 250), (520, 360)], fill=(230, 255, 255))
    d.polygon([(560, 480), (640, 420), (620, 560)], fill=(120, 200, 255))
    d.polygon([(420, 520), (500, 600), (400, 640)], fill=(200, 160, 255))
    for x, y, r in [(220, 240, 60), (820, 300, 50), (780, 640, 45), (240, 620, 40)]:
        sparkle(d, x, y, r)
    label(img, "CRYSTAL EGG"); save(img, "11_CrystalEgg")

def mythic():
    img = bg((80, 30, 140), (20, 10, 60)); d = ImageDraw.Draw(img)
    for i in range(70):
        x, y = (i * 137) % S, (i * 271) % (S - 200)
        r = 4 + (i % 4) * 3
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, 200))
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([230, 170, 794, 734], fill=(255, 90, 220, 150))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(50)))
    d = ImageDraw.Draw(img)
    paw(d, 512, 520, 150, (255, 120, 220))
    star(d, 512, 250, 70, (255, 230, 90))
    sparkle(d, 220, 300, 60); sparkle(d, 800, 330, 60)
    label(img, "MYTHIC DOG", (255, 140, 230)); save(img, "12_RandomMythicDog")

starter()
double("2x CASH", "02_Cash2x", (130, 240, 110), (30, 150, 60), "$", (255, 255, 255))
double("2x XP", "03_XP2x", (110, 200, 255), (40, 80, 210), "XP", (255, 255, 255))
fast_eggs(); auto_collect(); auto_hatch(); vip()
cash("08_PouchOfCash", "POUCH", 1, (170, 240, 140), (60, 160, 80))
cash("09_BriefcaseOfCash", "BRIEFCASE", 2, (150, 230, 130), (40, 140, 70))
cash("10_VaultOfCash", "VAULT", 3, (120, 220, 120), (20, 110, 60))
crystal(); mythic()
print("ok")
