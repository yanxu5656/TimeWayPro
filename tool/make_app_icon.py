"""生成「时途」的应用图标与各平台资源。

用法（在仓库根目录）：

    python tool/make_app_icon.py

设计：青绿径向渐变底（光源在左上）+ 不闭合的白色粗圆环，缺口端点是实心圆点——
环表示已走过的进度，圆点表示「当下」。纯几何、无文字，48px 下不糊。

为什么要程序化生成而不是手工导图：改一个参数（环粗、缺口角度）就能整体
重出，且**零新依赖**（不引 flutter_launcher_icons）。母版是 1024×1024，
其余尺寸全部由它缩放，保证各处一致。

产物：
- build/app_icon/            母版与自检图（已 gitignore）
- android/app/src/main/res/  mipmap 位图 + 自适应图标（vector）
- ios / macos / web / windows 的既有图标位图

依赖 Pillow 与 numpy。
"""

import os

import numpy as np
from PIL import Image, ImageDraw

# ── 设计参数 ──────────────────────────────────────────────

SIZE = 1024  # 母版边长
SS = 4  # 超采样倍数，避免圆环边缘锯齿

# 径向渐变，光从左上打来——与 app 里玻璃卡的「光从左上打来」是同一套语言。
# 直接对比过：线性左上→右下几乎看不出渐变，整体读起来是一块平色。
GRAD_LIGHT = (0x14, 0xD0, 0xB2)  # 光源中心
GRAD_DARK = (0x00, 0x69, 0x5C)  # 边缘
GRAD_CENTER = (0.28, 0.22)  # 光源位置（画布归一化坐标）
GRAD_RADIUS = 1.15  # 渐变半径 / 画布边长

RING_RADIUS_FRAC = 0.28  # 环中心线半径 / 画布边长
RING_WIDTH_FRAC = 0.24  # 环粗 / 环半径
GAP_DEG = 70  # 缺口角度
GAP_CENTER_DEG = 315  # 缺口中心方向：右上（0°=右，顺时针为正）
DOT_SCALE = 1.4  # 圆点直径 / 环粗

CORNER_FRAC = 0.20  # 圆角矩形的圆角半径 / 边长

# 自适应图标：108dp 视口，launcher 只显示中间 66dp（safe zone），
# 圆形遮罩下可显示半径是 33dp。环的外沿必须落在这个圆内。
ADAPTIVE_VIEWPORT = 108
ADAPTIVE_RING_RADIUS = 22  # 比 0.28*66=18.5 略大，为了更醒目，仍在安全区内


def _gradient(size: int) -> Image.Image:
    """径向渐变：光源在左上，向边缘压暗"""
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1.0)
    dist = np.sqrt((xx - GRAD_CENTER[0]) ** 2 + (yy - GRAD_CENTER[1]) ** 2)
    t = np.clip(dist / GRAD_RADIUS, 0.0, 1.0)
    out = np.zeros((size, size, 3), dtype=np.uint8)
    for i in range(3):
        out[:, :, i] = (
            GRAD_LIGHT[i] + (GRAD_DARK[i] - GRAD_LIGHT[i]) * t
        ).astype(np.uint8)
    return Image.fromarray(out, 'RGB')


def _ring_angles() -> tuple[float, float]:
    """返回 (arc_start, arc_end)，缺口居中于 GAP_CENTER_DEG。

    角度约定与 PIL 一致：0° 指向右，顺时针为正（屏幕坐标）。
    """
    half = GAP_DEG / 2.0
    return GAP_CENTER_DEG + half, GAP_CENTER_DEG - half + 360.0


def _draw_mark(draw: ImageDraw.ImageDraw, size: int, radius: float,
               width: float, color: tuple[int, int, int, int],
               dot_at_start: bool) -> None:
    """画圆环 + 缺口端点的实心圆点。

    坐标以 size 为画布边长、中心为圆心。
    """
    c = size / 2.0
    start, end = _ring_angles()

    box = [c - radius, c - radius, c + radius, c + radius]
    draw.arc(box, start=start, end=end, fill=color, width=round(width))

    # 圆点落在缺口的一个端点上。放在 arc 的末端 = 进度"走到这里"。
    angle = end if not dot_at_start else start
    rad = np.deg2rad(angle)
    dot_c = (c + radius * np.cos(rad), c + radius * np.sin(rad))
    dot_r = width * DOT_SCALE / 2.0
    draw.ellipse(
        [dot_c[0] - dot_r, dot_c[1] - dot_r, dot_c[0] + dot_r, dot_c[1] + dot_r],
        fill=color,
    )


def make_icon(size: int, *, rounded: bool, ring_radius_frac: float,
              dot_at_start: bool = False) -> Image.Image:
    """生成一张图标位图。

    [rounded] 为真时四角切圆角、角外透明（Android 旧版位图 / web /
    Windows 用）；为假时是满幅方形（iOS / macOS 由系统自己套遮罩）。
    """
    big = size * SS
    img = _gradient(big).convert('RGBA')

    overlay = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    _draw_mark(
        ImageDraw.Draw(overlay),
        big,
        radius=ring_radius_frac * big,
        width=ring_radius_frac * big * RING_WIDTH_FRAC,
        color=(255, 255, 255, 255),
        dot_at_start=dot_at_start,
    )
    img = Image.alpha_composite(img, overlay)

    if rounded:
        mask = Image.new('L', (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=CORNER_FRAC * big, fill=255
        )
        img.putalpha(mask)

    return img.resize((size, size), Image.LANCZOS)


def make_named(path: str, size: int, **kw) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    make_icon(size, **kw).save(path)
    print('  %-58s %dx%d' % (path, size, size))


# ── 自适应图标的 vector drawable ────────────────────────────

def _vec(v: float) -> str:
    """去掉多余小数位"""
    return ('%.3f' % v).rstrip('0').rstrip('.')


def _foreground_xml() -> str:
    c = ADAPTIVE_VIEWPORT / 2.0
    r = ADAPTIVE_RING_RADIUS
    w = r * RING_WIDTH_FRAC
    start, end = _ring_angles()

    def pt(angle: float):
        rad = np.deg2rad(angle)
        return c + r * np.cos(rad), c + r * np.sin(rad)

    x1, y1 = pt(start)
    x2, y2 = pt(end)
    large = 1 if (end - start) % 360 > 180 else 0

    dot_cx, dot_cy = pt(end)
    dot_r = w * DOT_SCALE / 2.0

    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tool/make_app_icon.py 生成，勿手改 -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{ADAPTIVE_VIEWPORT}dp"
    android:height="{ADAPTIVE_VIEWPORT}dp"
    android:viewportWidth="{ADAPTIVE_VIEWPORT}"
    android:viewportHeight="{ADAPTIVE_VIEWPORT}">

    <!-- 不闭合的圆环：缺口 {GAP_DEG}° 居中于右上 -->
    <path
        android:pathData="M{_vec(x1)},{_vec(y1)} A{_vec(r)},{_vec(r)} 0 {large} 1 {_vec(x2)},{_vec(y2)}"
        android:strokeColor="#FFFFFFFF"
        android:strokeWidth="{_vec(w)}"
        android:strokeLineCap="butt" />

    <!-- 缺口端点的实心圆点：当下 -->
    <path
        android:pathData="M{_vec(dot_cx)},{_vec(dot_cy)} m{_vec(-dot_r)},0 a{_vec(dot_r)},{_vec(dot_r)} 0 1,0 {_vec(dot_r * 2)},0 a{_vec(dot_r)},{_vec(dot_r)} 0 1,0 {_vec(-dot_r * 2)},0"
        android:fillColor="#FFFFFFFF" />
</vector>
'''


def _background_xml() -> str:
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tool/make_app_icon.py 生成，勿手改 -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="{ADAPTIVE_VIEWPORT}dp"
    android:height="{ADAPTIVE_VIEWPORT}dp"
    android:viewportWidth="{ADAPTIVE_VIEWPORT}"
    android:viewportHeight="{ADAPTIVE_VIEWPORT}">

    <path android:pathData="M0,0h{ADAPTIVE_VIEWPORT}v{ADAPTIVE_VIEWPORT}h-{ADAPTIVE_VIEWPORT}z">
        <aapt:attr name="android:fillColor">
            <!-- 径向渐变，光源在左上，与位图母版一致 -->
            <gradient
                android:type="radial"
                android:centerX="{_vec(GRAD_CENTER[0] * ADAPTIVE_VIEWPORT)}"
                android:centerY="{_vec(GRAD_CENTER[1] * ADAPTIVE_VIEWPORT)}"
                android:gradientRadius="{_vec(GRAD_RADIUS * ADAPTIVE_VIEWPORT)}">
                <item android:offset="0" android:color="#FF14D0B2" />
                <item android:offset="1" android:color="#FF00695C" />
            </gradient>
        </aapt:attr>
    </path>
</vector>
'''


def _monochrome_xml() -> str:
    """Android 13+ 主题图标：只保留形状，颜色由系统填。"""
    body = _foreground_xml()
    body = body.replace('android:strokeColor="#FFFFFFFF"', 'android:strokeColor="#FF000000"')
    body = body.replace('android:fillColor="#FFFFFFFF"', 'android:fillColor="#FF000000"')
    body = body.replace(
        '<!-- 由 tool/make_app_icon.py 生成，勿手改 -->',
        '<!-- 由 tool/make_app_icon.py 生成，勿手改 -->\n<!-- Android 13+ 主题图标：只保留形状 -->',
    )
    return body


def _adaptive_xml() -> str:
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- 由 tool/make_app_icon.py 生成，勿手改 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
'''


def write_text(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print('  %-58s (vector/xml)' % path)


# ── 自检图 ────────────────────────────────────────────────

def make_selfcheck(out_path: str) -> None:
    """把不同尺寸与遮罩叠在一起，用来确认前景不会被裁。

    这是这个脚本最重要的产物：自适应图标的前景只占 108dp 视口中间的
    66dp，且启动器遮罩形状各异，环画大了会在圆形遮罩下被切掉缺口。
    """
    tiles = []
    for size in (192, 48):
        for mask in ('none', 'circle', 'squircle'):
            icon = make_icon(size, rounded=False, ring_radius_frac=RING_RADIUS_FRAC)
            if mask != 'none':
                m = Image.new('L', (size * 4, size * 4), 0)
                d = ImageDraw.Draw(m)
                if mask == 'circle':
                    d.ellipse([0, 0, size * 4 - 1, size * 4 - 1], fill=255)
                else:
                    d.rounded_rectangle(
                        [0, 0, size * 4 - 1, size * 4 - 1],
                        radius=0.42 * size * 4, fill=255,
                    )
                m = m.resize((size, size), Image.LANCZOS)
                masked = Image.new('RGBA', (size, size), (240, 240, 240, 255))
                masked.paste(icon, (0, 0), m)
                icon = masked
            tiles.append((icon, '%d/%s' % (size, mask)))

    pad = 24
    big = max(t[0].width for t in tiles) * 2
    cols = 3
    rows = (len(tiles) + cols - 1) // cols
    cell = big + pad
    sheet = Image.new('RGB', (cell * cols + pad, cell * rows + pad),
                      (245, 247, 249))
    for i, (icon, _) in enumerate(tiles):
        r, c = divmod(i, cols)
        scaled = icon.resize((big, big), Image.LANCZOS)
        sheet.paste(scaled, (pad + c * cell, pad + r * cell),
                    scaled if scaled.mode == 'RGBA' else None)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    sheet.save(out_path)
    print('  %-58s 自检图' % out_path)


# ── 主流程 ────────────────────────────────────────────────

def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    print('母版与自检图（build/ 已 gitignore）：')
    master_dir = os.path.join('build', 'app_icon')
    make_named(os.path.join(master_dir, 'master_1024.png'), 1024,
               rounded=False, ring_radius_frac=RING_RADIUS_FRAC)
    make_selfcheck(os.path.join(master_dir, 'selfcheck.png'))

    print('\nAndroid 传统位图（圆角方形）：')
    for folder, size in (
        ('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
        ('xxhdpi', 144), ('xxxhdpi', 192),
    ):
        make_named(
            os.path.join('android/app/src/main/res', 'mipmap-' + folder,
                         'ic_launcher.png'),
            size, rounded=True, ring_radius_frac=RING_RADIUS_FRAC,
        )

    print('\nAndroid 自适应图标（vector，API 26+）：')
    res = 'android/app/src/main/res'
    write_text(os.path.join(res, 'drawable', 'ic_launcher_background.xml'),
               _background_xml())
    write_text(os.path.join(res, 'drawable', 'ic_launcher_foreground.xml'),
               _foreground_xml())
    write_text(os.path.join(res, 'drawable', 'ic_launcher_monochrome.xml'),
               _monochrome_xml())
    write_text(os.path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
               _adaptive_xml())

    print('\niOS（满幅方形，系统自己套遮罩）：')
    ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for name, size in (
        ('Icon-App-20x20@1x', 20), ('Icon-App-20x20@2x', 40),
        ('Icon-App-20x20@3x', 60), ('Icon-App-29x29@1x', 29),
        ('Icon-App-29x29@2x', 58), ('Icon-App-29x29@3x', 87),
        ('Icon-App-40x40@1x', 40), ('Icon-App-40x40@2x', 80),
        ('Icon-App-40x40@3x', 120), ('Icon-App-60x60@2x', 120),
        ('Icon-App-60x60@3x', 180), ('Icon-App-76x76@1x', 76),
        ('Icon-App-76x76@2x', 152), ('Icon-App-83.5x83.5@2x', 167),
        ('Icon-App-1024x1024@1x', 1024),
    ):
        make_named(os.path.join(ios, name + '.png'), size,
                   rounded=False, ring_radius_frac=RING_RADIUS_FRAC)

    print('\nmacOS：')
    mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for size in (16, 32, 64, 128, 256, 512, 1024):
        make_named(os.path.join(mac, 'app_icon_%d.png' % size), size,
                   rounded=False, ring_radius_frac=RING_RADIUS_FRAC)

    print('\nWeb（maskable 要缩到安全区内）：')
    web = 'web/icons'
    for name, size in (('Icon-192', 192), ('Icon-512', 512)):
        make_named(os.path.join(web, name + '.png'), size,
                   rounded=True, ring_radius_frac=RING_RADIUS_FRAC)
    for name, size in (('Icon-maskable-192', 192), ('Icon-maskable-512', 512)):
        # maskable 的图形要落在中间 80% 的圆内
        make_named(os.path.join(web, name + '.png'), size,
                   rounded=False, ring_radius_frac=RING_RADIUS_FRAC * 0.62)
    make_named('web/favicon.png', 64,
               rounded=True, ring_radius_frac=RING_RADIUS_FRAC)

    print('\nWindows (.ico, 多尺寸)：')
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    frames = [
        make_icon(s, rounded=True, ring_radius_frac=RING_RADIUS_FRAC)
        for s, _ in ico_sizes
    ]
    ico_path = 'windows/runner/resources/app_icon.ico'
    frames[-1].save(ico_path, format='ICO',
                    sizes=ico_sizes,
                    append_images=frames[:-1])
    print('  %-58s %s' % (ico_path, ' / '.join(str(s) for s, _ in ico_sizes)))

    # README 标题区用的小图
    print('\nREADME 用图：')
    make_named('docs/icon.png', 128,
               rounded=True, ring_radius_frac=RING_RADIUS_FRAC)

    print('\n完成。请务必先看 build/app_icon/selfcheck.png，'
          '确认圆形遮罩下缺口与圆点没被裁掉。')


if __name__ == '__main__':
    main()