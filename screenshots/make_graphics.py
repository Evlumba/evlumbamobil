#!/usr/bin/env python3
"""Play Store graphics for Evlumba — feature graphic + 3 screenshots."""

from PIL import Image, ImageDraw, ImageFont
import os

RAW  = os.path.join(os.path.dirname(__file__), "raw")
OUT  = os.path.join(os.path.dirname(__file__), "final")
os.makedirs(OUT, exist_ok=True)

# ── Brand colours ────────────────────────────────────────────────────────────
GREEN      = (0, 112, 74)
GREEN_DARK = (0, 75, 50)
GREEN_LITE = (0, 160, 100)
WHITE      = (255, 255, 255)
OFFWHITE   = (248, 250, 252)
GRAY       = (100, 116, 139)
DARK       = (15, 23, 42)

# ── Canvas sizes ─────────────────────────────────────────────────────────────
FW, FH = 1024, 500   # Feature graphic
SW, SH = 1080, 1920  # Screenshots

# ── Screenshot phone frame ────────────────────────────────────────────────────
SCR_W = 440
SCR_H = int(SCR_W * 2400 / 1080)
BEZ   = 12
PH_W  = SCR_W + BEZ * 2
PH_H  = SCR_H + BEZ * 2 + 36 + 28
PH_X  = (SW - PH_W) // 2
PH_Y  = 100

def lerp(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))

def vgrad(draw, w, h, c1, c2):
    for y in range(h):
        draw.line([(0, y), (w, y)], fill=lerp(c1, c2, y / h))

def hgrad(draw, x0, y0, x1, y1, c1, c2):
    for x in range(x0, x1):
        t = (x - x0) / max(1, x1 - x0)
        draw.line([(x, y0), (x, y1)], fill=lerp(c1, c2, t))

def glow(base, cx, cy, r, color, alpha=50):
    lay = Image.new("RGBA", base.size, (0,0,0,0))
    d = ImageDraw.Draw(lay)
    for i in range(8, 0, -1):
        ri = int(r * i / 8)
        a  = int(alpha * (1 - i/8) * 2.5)
        d.ellipse([cx-ri, cy-ri, cx+ri, cy+ri], fill=(*color, min(a, alpha)))
    base.paste(lay, mask=lay)

def try_font(size, bold=False):
    for p in [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

def cx_text(draw, y, text, font, fill, w=SW):
    bb = draw.textbbox((0,0), text, font=font)
    draw.text(((w - (bb[2]-bb[0])) // 2, y), text, font=font, fill=fill)

def phone_frame(canvas, raw_path):
    raw = Image.open(raw_path).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    scr_x = PH_X + BEZ
    scr_y = PH_Y + BEZ + 28

    # Body
    draw.rounded_rectangle(
        [PH_X, PH_Y, PH_X+PH_W, PH_Y+PH_H],
        radius=36, fill=(240,245,240), outline=(180,210,190), width=3)
    draw.rounded_rectangle(
        [PH_X+2, PH_Y+2, PH_X+PH_W-2, PH_Y+PH_H-2],
        radius=34, outline=(*GREEN_LITE, 120), width=1)

    # Notch
    ncx = PH_X + PH_W // 2
    draw.rounded_rectangle(
        [ncx-30, PH_Y+16, ncx+30, PH_Y+30],
        radius=7, fill=(200,220,210))

    # Screen
    scr = raw.resize((SCR_W, SCR_H), Image.LANCZOS)
    mask = Image.new("L", (SCR_W, SCR_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,SCR_W,SCR_H], radius=24, fill=255)
    canvas.paste(scr, (scr_x, scr_y), mask)
    draw.rounded_rectangle(
        [scr_x, scr_y, scr_x+SCR_W, scr_y+SCR_H],
        radius=24, outline=(*GREEN, 80), width=2)

    # Home bar
    bcx = PH_X + PH_W // 2
    bar_y = PH_Y + PH_H - 18
    draw.rounded_rectangle([bcx-44, bar_y, bcx+44, bar_y+8], radius=4, fill=(150,180,165))

# ── 1. FEATURE GRAPHIC (1024 × 500) ─────────────────────────────────────────
def make_feature_graphic():
    img  = Image.new("RGBA", (FW, FH))
    draw = ImageDraw.Draw(img)

    # BG gradient — dark green to slightly lighter
    vgrad(draw, FW, FH, GREEN_DARK, (0, 90, 60))

    # Decorative circles
    glow(img, 80,  80,  180, GREEN_LITE, 60)
    glow(img, FW-80, FH-60, 200, (0, 50, 30), 80)
    glow(img, FW//2, FH//2, 300, GREEN, 30)

    # Right side: faint grid pattern
    for x in range(600, FW, 60):
        draw.line([(x, 0), (x, FH)], fill=(255,255,255,15))
    for y in range(0, FH, 60):
        draw.line([(600, y), (FW, y)], fill=(255,255,255,15))

    # App logo area (left)
    logo_x, logo_y = 70, FH//2 - 36
    draw.rounded_rectangle(
        [logo_x, logo_y, logo_x+72, logo_y+72],
        radius=18, fill=WHITE)
    draw.text((logo_x+14, logo_y+10), "E", font=try_font(52, bold=True), fill=GREEN_DARK)

    # App name
    f_app  = try_font(72, bold=True)
    f_tag  = try_font(28)
    f_feat = try_font(24, bold=True)
    draw.text((logo_x+88, logo_y+4),  "evlumba", font=f_app, fill=WHITE)
    draw.text((logo_x+88, logo_y+72+8), "Tasarımcıyla Ev Hayalini Gerçekleştir", font=f_tag, fill=(200, 235, 220))

    # Feature bullets
    features = [
        "🏠  Binlerce iç mimar projesi",
        "💬  Doğrudan tasarımcıyla iletişim",
        "✨  AI destekli tasarım önerileri",
        "📋  İlan ver, teklif al",
    ]
    fy = 310
    for feat in features:
        draw.text((logo_x, fy), feat, font=f_feat, fill=(220, 245, 235))
        fy += 38

    # Right side: small phone mockup (minimal)
    mock_x, mock_y, mock_w, mock_h = 680, 30, 200, 440
    draw.rounded_rectangle(
        [mock_x, mock_y, mock_x+mock_w, mock_y+mock_h],
        radius=24, fill=(0,50,35), outline=(0,160,100), width=2)
    # Screen preview (green-ish placeholder)
    sx, sy = mock_x+8, mock_y+30
    draw.rounded_rectangle([sx, sy, sx+mock_w-16, sy+mock_h-50],
        radius=18, fill=(10,80,55))
    draw.text((sx+20, sy+20), "evlumba", font=try_font(18, bold=True), fill=WHITE)
    # fake cards
    for i in range(3):
        cy2 = sy + 60 + i*100
        draw.rounded_rectangle([sx+10, cy2, sx+mock_w-26, cy2+80],
            radius=10, fill=(0,100,70))
    # Home bar
    draw.rounded_rectangle(
        [mock_x+mock_w//2-30, mock_y+mock_h-18,
         mock_x+mock_w//2+30, mock_y+mock_h-10],
        radius=4, fill=(0,140,90))

    path = os.path.join(OUT, "feature_graphic.png")
    img.convert("RGB").save(path)
    print(f"✓  {path}")

# ── 2. SCREENSHOTS ───────────────────────────────────────────────────────────
slides = [
    ("screen1.png", "İlham Al",          "Binlerce iç mimar projesini keşfet",      "🏠  Ana Sayfa"),
    ("screen2.png", "Projeleri Keşfet",  "Oturma odası, mutfak, banyo ve daha fazlası","🔍  Keşfet"),
    ("screen3.png", "Profesyoneller",    "Türkiye'nin en iyi tasarımcılarıyla tanış", "👤  Uzmanlar"),
]

def make_screenshot(idx, raw_file, title, subtitle, tag):
    canvas = Image.new("RGBA", (SW, SH))
    draw   = ImageDraw.Draw(canvas)

    # BG — very light warm white
    vgrad(draw, SW, SH, OFFWHITE, (230, 240, 235))

    # Top green band
    for y in range(280):
        t = y / 280
        c = lerp(GREEN_DARK, GREEN, t)
        draw.line([(0, y), (SW, y)], fill=c)

    # Subtle glow on green band
    glow(canvas, SW//2, 140, 400, GREEN_LITE, 40)
    glow(canvas, 60, 60, 150, WHITE, 20)

    # App name on green band
    f_app = try_font(52, bold=True)
    f_tag_s = try_font(26)
    bb = draw.textbbox((0,0), "evlumba", font=f_app)
    draw.text(((SW - (bb[2]-bb[0]))//2, 44), "evlumba", font=f_app, fill=WHITE)

    # Phone frame
    phone_frame(canvas, os.path.join(RAW, raw_file))

    # Bottom text area
    text_y = PH_Y + PH_H + 36
    f_title = try_font(70, bold=True)
    f_sub   = try_font(36)
    f_pill  = try_font(28, bold=True)

    cx_text(draw, text_y, title, f_title, DARK)
    text_y += 84
    cx_text(draw, text_y, subtitle, f_sub, GRAY)
    text_y += 52

    # Green pill tag
    bb2 = draw.textbbox((0,0), tag, font=f_pill)
    tw = bb2[2]-bb2[0]; th = bb2[3]-bb2[1]
    px, py2 = 24, 10
    x0 = SW//2 - tw//2 - px; y0 = text_y+10
    x1 = SW//2 + tw//2 + px; y1 = y0 + th + py2*2
    hgrad(draw, x0, y0, x1, y1, GREEN, GREEN_LITE)
    draw.rounded_rectangle([x0,y0,x1,y1], radius=(y1-y0)//2, outline=WHITE, width=0)
    pill_mask = Image.new("L", (SW,SH), 0)
    ImageDraw.Draw(pill_mask).rounded_rectangle([x0,y0,x1,y1], radius=(y1-y0)//2, fill=255)
    canvas_rgb = canvas.convert("RGB")
    pill_layer = canvas_rgb.copy()
    pd = ImageDraw.Draw(pill_layer)
    hgrad(pd, x0, y0, x1, y1, GREEN, GREEN_LITE)
    canvas_rgb.paste(pill_layer, mask=pill_mask)
    ImageDraw.Draw(canvas_rgb).text((SW//2 - tw//2, y0+py2), tag, font=f_pill, fill=WHITE)

    # Dots
    dot_y = SH - 52
    for i in range(3):
        dx = SW//2 + (i-1)*28
        col = GREEN if i == idx-1 else (200, 215, 208)
        r   = 8 if i == idx-1 else 5
        ImageDraw.Draw(canvas_rgb).ellipse([dx-r,dot_y-r,dx+r,dot_y+r], fill=col)

    path = os.path.join(OUT, f"screenshot_{idx}.png")
    canvas_rgb.save(path)
    print(f"✓  {path}")

# ── Run ───────────────────────────────────────────────────────────────────────
make_feature_graphic()
for i, args in enumerate(slides, 1):
    make_screenshot(i, *args)

print(f"\nDone → {OUT}")
