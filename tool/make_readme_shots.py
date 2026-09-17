"""把 golden 出的原始截图缩放成 README 用的 WebP。

用法（在仓库根目录）：

    flutter test test/golden/screenshots.golden.dart --update-goldens
    python tool/make_readme_shots.py

为什么要多这一步：golden 输出的是 3x 原始 PNG（约 1MB/张），
直接把 4MB 的图提交进仓库不值得。缩放后的 WebP 4 张合计约 62KB，
在 GitHub 的 README 里渲染正常。

依赖 Pillow。
"""

import os
import sys

from PIL import Image

SRC_DIR = os.path.join('build', 'readme_screenshots')
DST_DIR = os.path.join('docs', 'screenshots')

# README 里 4 张图并排展示，每张显示宽度约 200px，
# 420px 的源图相当于 2x，够清晰也不至于太重
WIDTH = 420
QUALITY = 88

NAMES = ['daily', 'task', 'stats', 'planning']


def main():
    if not os.path.isdir(SRC_DIR):
        sys.exit(
            f'找不到 {SRC_DIR}/。先跑：\n'
            '  flutter test test/golden/screenshots.golden.dart --update-goldens'
        )

    os.makedirs(DST_DIR, exist_ok=True)
    total = 0

    for name in NAMES:
        src = os.path.join(SRC_DIR, f'{name}.png')
        if not os.path.isfile(src):
            sys.exit(f'缺少 {src}')

        im = Image.open(src).convert('RGB')
        height = round(im.size[1] * WIDTH / im.size[0])
        small = im.resize((WIDTH, height), Image.LANCZOS)

        dst = os.path.join(DST_DIR, f'{name}.webp')
        small.save(dst, 'WEBP', quality=QUALITY, method=6)

        size = os.path.getsize(dst)
        total += size
        print(f'{name:<9} {WIDTH}x{height}  {size // 1024}KB')

    print(f'合计 {total // 1024}KB -> {DST_DIR}/')


if __name__ == '__main__':
    main()