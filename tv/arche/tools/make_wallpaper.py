"""Draw the Arche "Iron Monarch" wallpaper: a hooded iron mask in emerald and gold, drawn in code.

An original drawing (no film or comic art), dark on the left and at the bottom so the clock and the
dock stay readable. 1920x1080 JPEG, kept small for 1 GB TVs.

    python3 tv/arche/tools/make_wallpaper.py out.jpg
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1920, 1080
GOLD = (212, 175, 55)
EMERALD = (18, 92, 52)


def background():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    # Emerald light behind the mask (right third), falling to near black on the left and bottom.
    d = np.sqrt(((x - 1380) / 900) ** 2 + ((y - 430) / 620) ** 2)
    glow = np.clip(1 - d, 0, 1) ** 1.6
    base = np.array([4, 10, 7], np.float32)
    col = base + glow[..., None] * np.array([22, 78, 44], np.float32)
    bottom = np.clip((y - 640) / 440, 0, 1)[..., None]
    col = col * (1 - 0.75 * bottom)
    return Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGB")


def mask_layer():
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = 1380, 470
    # Hood: a tall pointed cowl.
    hood = [(cx - 330, 1080), (cx - 300, cy + 40), (cx - 250, cy - 230), (cx - 120, cy - 360), (cx, cy - 400),
            (cx + 120, cy - 360), (cx + 250, cy - 230), (cx + 300, cy + 40), (cx + 330, 1080)]
    d.polygon(hood, fill=(10, 44, 26, 255))
    d.line(hood, fill=GOLD + (150,), width=3)
    # Faceplate: an iron oval.
    face = (cx - 175, cy - 250, cx + 175, cy + 260)
    d.ellipse(face, fill=(78, 84, 88, 255))
    d.ellipse((cx - 160, cy - 236, cx + 160, cy + 246), fill=(104, 110, 114, 255))
    # Brow ridge and nose bridge.
    d.polygon([(cx - 150, cy - 70), (cx, cy - 110), (cx + 150, cy - 70), (cx + 150, cy - 50), (cx, cy - 88),
               (cx - 150, cy - 50)], fill=(60, 64, 68, 255))
    d.rectangle((cx - 14, cy - 92, cx + 14, cy + 70), fill=(70, 75, 79, 255))
    # Eye slits, glowing emerald.
    for s in (-1, 1):
        x0 = cx + s * 30
        x1 = cx + s * 132
        d.polygon([(x0, cy - 40), (x1, cy - 52), (x1, cy - 28), (x0, cy - 18)], fill=(80, 255, 150, 255))
    # Mouth grille.
    for i in range(-4, 5):
        x = cx + i * 18
        d.rectangle((x - 4, cy + 110, x + 4, cy + 190), fill=(40, 43, 46, 255))
    d.line((cx - 95, cy + 105, cx + 95, cy + 105), fill=(40, 43, 46, 255), width=6)
    # Rivets.
    for x, y in ((cx - 140, cy + 20), (cx + 140, cy + 20), (cx - 120, cy + 170), (cx + 120, cy + 170),
                 (cx - 90, cy - 190), (cx + 90, cy - 190)):
        d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=GOLD + (255,))
    # Gold clasp at the throat.
    d.ellipse((cx - 38, cy + 300, cx + 38, cy + 376), fill=GOLD + (255,))
    d.ellipse((cx - 22, cy + 316, cx + 22, cy + 360), fill=(120, 96, 26, 255))
    return layer


def main(out):
    img = background().convert("RGBA")
    m = mask_layer()
    # Eye glow bloom.
    bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bloom).ellipse((1220, 380, 1540, 460), fill=(60, 255, 140, 120))
    img = Image.alpha_composite(img, bloom.filter(ImageFilter.GaussianBlur(40)))
    img = Image.alpha_composite(img, m.filter(ImageFilter.GaussianBlur(1.2)))
    # Thin gold frame lines, low on the screen, above the dock.
    d = ImageDraw.Draw(img)
    d.line((0, 1030, W, 1030), fill=GOLD + (60,), width=2)
    # Final darkening at the bottom so the dock stays readable.
    y = np.linspace(0, 1, H)[:, None]
    shade = (np.clip((y - 0.62) / 0.38, 0, 1) * 150).astype(np.uint8)
    shade_img = Image.fromarray(np.repeat(shade, W, axis=1), "L")
    black = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    black.putalpha(shade_img)
    img = Image.alpha_composite(img, black).convert("RGB")
    img.save(out, "JPEG", quality=82, optimize=True, progressive=False)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "wallpaper.jpg")
