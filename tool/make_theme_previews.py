"""导出十款主题的 WebP 预览与四组方案联系表。"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / 'build' / 'theme_previews'
DST_DIR = ROOT / 'docs' / 'themes'
PREVIEW_WIDTH = 420
CARD_WIDTH = 360
QUALITY = 88

GROUPS = [
    (
        'minimal',
        '简洁风格',
        '克制留白 · 清晰边界 · 专注内容',
        [
            ('minimal_cloud', '01  云白', '雾蓝点睛，轻盈留白'),
            ('minimal_forest', '02  青野', '低饱和绿，清爽呼吸'),
            ('minimal_graphite', '03  石墨', '中性灰阶，理性有序'),
        ],
    ),
    (
        'cute',
        '可爱风格',
        '柔和色彩 · 圆润卡片 · 轻快氛围',
        [
            ('cute_peach', '01  蜜桃汽水', '蜜桃与奶油，温暖圆润'),
            ('cute_mint', '02  薄荷糖', '清透薄荷，轻松治愈'),
            ('cute_lavender', '03  莓莓云朵', '柔紫莓果，轻盈甜美'),
        ],
    ),
    (
        'tech',
        '科技风格',
        '深色界面 · 等宽字体 · 荧光强调',
        [
            ('tech_deepspace', '01  深空蓝', '深夜蓝底，冰蓝光感'),
            ('tech_neon', '02  霓虹脉冲', '黑紫碰撞，双荧光节奏'),
            ('tech_matrix', '03  矩阵夜航', '碳黑矩阵，终端绿光'),
        ],
    ),
    (
        'aurora',
        '液态玻璃',
        '动态极光 · 半透明材质 · 弹性动效',
        [
            ('aurora_glass', '01  流光璃境', 'Gemini 灵感的液态玻璃体验'),
        ],
    ),
]


def load_font(size, bold=False):
    name = 'Dengb.ttf' if bold else 'Deng.ttf'
    path = Path('C:/Windows/Fonts') / name
    if path.exists():
        return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def export_contact_sheet(key, title, subtitle, options):
    margin = 24
    header_height = 108
    label_height = 76
    gap = 20
    image_height = round(CARD_WIDTH * 844 / 390)
    width = margin * 2 + CARD_WIDTH * len(options) + gap * (len(options) - 1)
    height = header_height + label_height + image_height + margin
    sheet = Image.new('RGB', (width, height), '#F3F1ED')
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (margin, 20),
        title,
        font=load_font(34, True),
        fill='#262A29',
    )
    draw.text(
        (margin, 66),
        subtitle,
        font=load_font(18),
        fill='#626966',
    )

    for index, (theme_id, name, description) in enumerate(options):
        source = Image.open(SRC_DIR / f'{theme_id}.png').convert('RGB')
        source.thumbnail((PREVIEW_WIDTH, 2000), Image.LANCZOS)
        source.save(DST_DIR / f'{theme_id}.webp', 'WEBP', quality=QUALITY, method=6)
        preview = source.resize((CARD_WIDTH, image_height), Image.LANCZOS)
        x = margin + index * (CARD_WIDTH + gap)
        y = header_height
        draw.rounded_rectangle(
            (x - 1, y - 1, x + CARD_WIDTH, y + image_height + 1),
            radius=15,
            outline='#D5D8D4',
            width=2,
        )
        sheet.paste(preview, (x, y))
        label_y = y + image_height + 14
        draw.text((x, label_y), name, font=load_font(24, True), fill='#262A29')
        draw.text(
            (x, label_y + 36),
            description,
            font=load_font(16),
            fill='#626966',
        )

    sheet.save(DST_DIR / f'{key}-options.webp', 'WEBP', quality=QUALITY, method=6)


def main():
    if not SRC_DIR.is_dir():
        raise SystemExit(f'找不到 {SRC_DIR}，请先生成主题截图')
    DST_DIR.mkdir(parents=True, exist_ok=True)
    for group in GROUPS:
        export_contact_sheet(*group)
        print(group[0])


if __name__ == '__main__':
    main()
