#!/usr/bin/env python3
"""Regenerates every Noted. app icon from the bundled Fraunces font.

    pip install pillow && python3 tool/make_icons.py

Outputs (all under assets/icon/):
  app_icon.png / app_icon_foreground.png            light  (flutter_launcher_icons)
  app_icon_dark.png / app_icon_dark_foreground.png  dark
  android_dark/res/...                              dark launcher resources that
                                                    tool/configure_android.sh copies
                                                    into the Android project
  icons_preview.png                                 light + dark, square + circle masks
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, 'assets/fonts/Fraunces.ttf')
OUT = os.path.join(ROOT, 'assets/icon')

THEMES = {
    # same tokens as the app's light / dark themes and splash
    'light': dict(bg=(244, 243, 238), ink=(28, 27, 26), accent=(44, 74, 140)),
    'dark':  dict(bg=(0, 0, 0),       ink=(240, 239, 234), accent=(123, 156, 240)),
}


def load_font(px):
    f = ImageFont.truetype(FONT, px)
    vals = {'SOFT': 0, 'WONK': 0, 'opsz': 96, 'wght': 600}
    axes = f.get_variation_axes()
    f.set_variation_by_axes([
        vals.get(a['name'].decode() if isinstance(a['name'], bytes) else a['name'], a['default'])
        for a in axes])
    return f


def render(t, block_w, with_bg, final=1024, k=2):
    S = final * k
    img = Image.new('RGBA', (S, S), t['bg'] + (255,) if with_bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lo, hi = 100, 3000
    for _ in range(30):                       # size the font so "N." is block_w wide
        mid = (lo + hi) // 2
        f = load_font(mid)
        advN = f.getlength('N')
        l = f.getbbox('N', anchor='ls')[0]
        r = advN + f.getbbox('.', anchor='ls')[2]
        lo, hi = (mid, hi) if (r - l) < block_w * k else (lo, mid)
    f = load_font(lo)
    advN = f.getlength('N')
    bN = f.getbbox('N', anchor='ls'); bD = f.getbbox('.', anchor='ls')
    ink_l = bN[0]; ink_w = advN + bD[2] - ink_l
    cap = -bN[1]
    stroke = int(ink_w * 0.052); gap = int(cap * 0.24); line_gap = int(stroke * 2.3)
    block_h = cap + gap + stroke + line_gap + stroke
    baseline = (S - block_h) / 2 + cap
    x0 = (S - ink_w) / 2 - ink_l
    d.text((x0, baseline), 'N', font=f, fill=t['ink'], anchor='ls')
    d.text((x0 + advN, baseline), '.', font=f, fill=t['accent'], anchor='ls')
    lx = x0 + ink_l; ly = baseline + gap
    d.rounded_rectangle((lx, ly, lx + ink_w, ly + stroke), radius=stroke / 2, fill=t['accent'])
    ly2 = ly + stroke + line_gap
    d.rounded_rectangle((lx, ly2, lx + ink_w * 0.76, ly2 + stroke), radius=stroke / 2, fill=t['accent'])
    img = img.resize((final, final), Image.LANCZOS)
    return img.convert('RGB') if with_bg else img


def rounded(img, frac=0.2237):
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width - 1, img.height - 1),
                                        radius=int(img.width * frac), fill=255)
    o = Image.new('RGBA', img.size, (0, 0, 0, 0)); o.paste(img.convert('RGBA'), (0, 0), m)
    return o


def save(img, *parts):
    p = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


full, fg = {}, {}
for name, t in THEMES.items():
    full[name] = render(t, 500, True)      # full bleed: iOS + legacy Android
    fg[name] = render(t, 400, False)       # adaptive foreground, inside the safe zone
    suffix = '' if name == 'light' else '_dark'
    save(full[name], f'app_icon{suffix}.png')
    save(fg[name], f'app_icon{suffix}_foreground.png')

# ---- Android resources for the dark launcher alias ------------------------
RES = ('android_dark', 'res')
legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
for dpi, px in legacy.items():
    save(rounded(full['dark']).resize((px, px), Image.LANCZOS), *RES, f'mipmap-{dpi}', 'ic_launcher_dark.png')
for dpi, px in adaptive.items():
    save(fg['dark'].resize((px, px), Image.LANCZOS), *RES, f'drawable-{dpi}', 'ic_launcher_dark_foreground.png')


def write(text, *parts):
    p = os.path.join(OUT, *RES, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w').write(text)


write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background_dark"/>
    <foreground android:drawable="@drawable/ic_launcher_dark_foreground"/>
</adaptive-icon>
''', 'mipmap-anydpi-v26', 'ic_launcher_dark.xml')
write('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background_dark">#000000</color>
</resources>
''', 'values', 'ic_launcher_dark_colors.xml')

# ---- preview sheet ---------------------------------------------------------
def mask(img, shape):
    m = Image.new('L', img.size, 0); dd = ImageDraw.Draw(m)
    if shape == 'sq': dd.rounded_rectangle((0, 0, 1023, 1023), radius=230, fill=255)
    else: dd.ellipse((0, 0, 1023, 1023), fill=255)
    o = Image.new('RGBA', img.size, (0, 0, 0, 0)); o.paste(img, (0, 0), m); return o

def adaptive_full(name):
    base = Image.new('RGBA', (1024, 1024), THEMES[name]['bg'] + (255,)); base.alpha_composite(fg[name]); return base

tiles = [mask(full['light'].convert('RGBA'), 'sq'), mask(adaptive_full('light'), 'ci'),
         mask(full['dark'].convert('RGBA'), 'sq'), mask(adaptive_full('dark'), 'ci')]
W = 1024
sheet = Image.new('RGB', (W * 2 + 150, W * 2 + 150), (150, 150, 150))
sheet.paste((214, 210, 200), (0, 0, W * 2 + 150, W + 75))
sheet.paste((44, 44, 46), (0, W + 75, W * 2 + 150, W * 2 + 150))
for i, t in enumerate(tiles):
    x = 50 + (i % 2) * (W + 50); y = 50 + (i // 2) * (W + 50)
    sheet.paste(t, (x, y), t)
sheet.resize((sheet.width // 3, sheet.height // 3), Image.LANCZOS).save(os.path.join(OUT, 'icons_preview.png'))
print('icons generated')
