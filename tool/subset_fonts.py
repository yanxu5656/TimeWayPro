"""把可变字体实例化为静态字重，并子集化到应用实际用到的字符集。

用法（在仓库根目录）：

    python tool/subset_fonts.py

输入：tool/fonts/ 下的可变字体（脚本不负责下载，见文件头注释）
输出：assets/fonts/ 下的静态 TTF（pubspec 已声明）

## 为什么要子集化

思源宋体 SC 的可变字体全量约 25MB，两个字重直接打包会让 APK 膨胀
50MB。应用实际用到的字符非常有限——GB2312 一级常用字（3755 个，
覆盖现代中文的绝对主体）+ 源码里的中文文案 + ASCII + 常用标点，
子集后每个字重约 2~3MB。

## 缺字怎么办

界面出现「口」方块说明用到了子集外的字（多半是生僻字或新造词）。
把字加进下面的 EXTRA_CHARS，或确认它出现在 lib/ 的文案里，重跑
本脚本即可。

依赖：fonttools（pip install fonttools）
"""

import re
from pathlib import Path

from fontTools import subset
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'tool' / 'fonts'
DST = ROOT / 'assets' / 'fonts'

# 字体清单：(源文件, 家族, [(字重, 输出名)])
JOBS = [
    ('PlayfairDisplay-VF.ttf', 'Playfair', [(500, 'PlayfairDisplay-Medium.ttf'),
                                            (700, 'PlayfairDisplay-Bold.ttf')]),
    ('NotoSerifSC-VF.ttf', 'NotoSerifSC', [(400, 'NotoSerifSC-Regular.ttf'),
                                           (600, 'NotoSerifSC-SemiBold.ttf')]),
]

# 应用文案之外手动补充的字符（生僻字、符号按需加在这里）
EXTRA_CHARS = ''

# GB2312 一级常用字之外的常用补充（二级字库里挑高频的）
COMMON_EXTRA = (
    '的一是在了我不和他有这大们上到为地中也子道说出而要于就下得可你年生'
    '自会那后能对着事其里所去行过家十用发天如然作方成者多日都三小军二'
    '无同么经法当起与好看学进种将还分此心前面又定见只主没公从'
)


def gb2312_level1():
    """枚举 GB2312 一级常用字（区位 16-55 区，按拼音排列的 3755 个汉字）。"""
    chars = []
    for hi in range(0xB0, 0xD8):  # 16..55 区
        for lo in range(0xA1, 0xFF):
            try:
                chars.append(bytes([hi, lo]).decode('gb2312'))
            except UnicodeDecodeError:
                pass
    return ''.join(chars)


def source_chars():
    """扫描 lib/ 与 test/ 里的 Dart 源码，收集出现过的全部中文字符。"""
    chars = set()
    for pattern in ('lib/**/*.dart', 'test/**/*.dart'):
        for path in ROOT.glob(pattern):
            text = path.read_text(encoding='utf-8', errors='ignore')
            chars.update(re.findall(r'[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]', text))
    return ''.join(sorted(chars))


def build_charset():
    parts = [
        EXTRA_CHARS,
        COMMON_EXTRA,
        gb2312_level1(),
        source_chars(),
        # ASCII 可打印区 + 常用中英文标点
        ''.join(chr(c) for c in range(0x20, 0x7F)),
        '，。、；：？！「」『』（）《》〈〉【】…—·～￥％＋－×÷°′″←→↑↓'
        '☀☁☾☽✓✕·■□▲△▼◆○●◎☆★①②③④⑤⑥⑦⑧⑨⑩',
    ]
    return ''.join(sorted(set(''.join(parts))))


def latin_charset():
    """Playfair 只承担拉丁字母与数字，给它单独的字符集（没有 CJK 字形）。"""
    return ''.join(sorted(set(
        ''.join(chr(c) for c in range(0x20, 0x7F))
        + '·—–’‘“”…′″°'
    )))


def subset_font(src: Path, weight: int, dst: Path, charset: str):
    from fontTools.ttLib import TTFont

    font = TTFont(str(src))
    instantiateVariableFont(font, {'wght': weight}, inplace=True)

    options = subset.Options()
    options.layout_features = ['*']       # 保留 kerning / liga 等排版特性
    options.name_IDs = [1, 2, 3, 4, 6]    # 保留基本名称记录
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables += ['DSIG']

    thinner = subset.Subsetter(options=options)
    # populate 的位置参数不是「字符串里的字符」：传 str 会被当成十六进制
    # 码点串解析。必须显式传 int 码点集合。
    thinner.populate(unicodes=sorted({ord(c) for c in charset}))
    thinner.subset(font)
    font.save(str(dst))


def main():
    DST.mkdir(parents=True, exist_ok=True)
    full = build_charset()
    latin = latin_charset()
    print(f'字符集：中文 {len(full)} 字 / 拉丁 {len(latin)} 字')

    # Playfair 只有拉丁字形，塞中文字符集会直接报缺字形
    for src_name, family, weights in JOBS:
        src = SRC / src_name
        if not src.exists():
            raise SystemExit(f'缺少 {src}，请先下载可变字体放到 tool/fonts/')
        charset = latin if family == 'Playfair' else full
        for weight, out_name in weights:
            dst = DST / out_name
            subset_font(src, weight, dst, charset)
            size = dst.stat().st_size
            print(f'{out_name:<32} wght={weight}  {size / 1024 / 1024:.2f} MB')


if __name__ == '__main__':
    main()
