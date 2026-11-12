"""生成 1024x1024 App 图标：绿色渐变 + 禁止符号（白圈 + 斜杠）。"""
import os
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4                      # 超采样倍数，抗锯齿
W = SIZE * SS

TOP = (18, 168, 135)
BOTTOM = (5, 74, 58)

# 竖直渐变（用 1px 宽的渐变条拉伸，速度快且平滑）
grad = Image.new("RGB", (1, W))
px = grad.load()
for y in range(W):
    t = y / (W - 1)
    t = t ** 0.92
    px[0, y] = (
        int(TOP[0] + (BOTTOM[0] - TOP[0]) * t),
        int(TOP[1] + (BOTTOM[1] - TOP[1]) * t),
        int(TOP[2] + (BOTTOM[2] - TOP[2]) * t),
    )
img = grad.resize((W, W), Image.BILINEAR).convert("RGBA")

# 左上角柔光（模糊后叠加，避免出现硬边）
glow = Image.new("L", (W, W), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse([-W * 0.35, -W * 0.45, W * 0.75, W * 0.55], fill=40)
glow = glow.filter(ImageFilter.GaussianBlur(W * 0.14))
img = Image.composite(Image.new("RGBA", (W, W), (255, 255, 255, 255)), img, glow)

d = ImageDraw.Draw(img)
cx = cy = W // 2
R = int(W * 0.322)
LW = int(W * 0.063)
WHITE = (255, 255, 255, 255)

# 圆环
d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=WHITE, width=LW)

# 斜杠（端点圆头，收在圆环中线上）
rr = R - LW // 2
x1 = cx - rr * math.cos(math.pi / 4)
y1 = cy + rr * math.sin(math.pi / 4)
x2 = cx + rr * math.cos(math.pi / 4)
y2 = cy - rr * math.sin(math.pi / 4)
d.line([(x1, y1), (x2, y2)], fill=WHITE, width=LW)
for (ex, ey) in ((x1, y1), (x2, y2)):
    d.ellipse([ex - LW / 2, ey - LW / 2, ex + LW / 2, ey + LW / 2], fill=WHITE)

icon = img.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)

here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "..", "ios", "QuitSmoke", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, "icon-1024.png")
icon.save(out, "PNG", optimize=True)
print("saved", os.path.abspath(out), icon.size)
