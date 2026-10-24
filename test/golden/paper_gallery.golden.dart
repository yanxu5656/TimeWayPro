import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/app/app.dart';
import 'package:time_way_pro/core/ui/paper.dart';

/// 纸面设计系统（静白志）的视觉探针。
///
/// 这个项目的改动价值几乎全在视觉上，而**文字对比度、衬线混排、
/// 发丝线密度这类问题静态分析查不出来**。这个 golden 把各档表面 +
/// 各档文字 + 衬线槽位真实渲染成 PNG，用来用眼睛确认，而不是靠算。
///
/// ## 为什么要单独加载字体
///
/// `flutter test` 默认用 Ahem 占位字体，无衬线中文会渲染成实心方块。
/// 这里加载系统的等线（Deng.ttf）作为无衬线中文的兜底。
/// 注意：衬线槽位（NotoSerifSC / Playfair）是 pubspec 打包字体，
/// 测试环境天然可用，**不要**用 textTheme.apply 覆盖它们。
///
/// ## 为什么不进默认 test run
///
/// 文件名不以 `_test.dart` 结尾，所以 `flutter test` 默认不会收集它——
/// golden 在不同 Flutter 版本 / 平台上像素级结果会漂移，放进默认 test run
/// 会让别人的机器变红。需要时显式按路径跑：
///
///     flutter test test/golden/paper_gallery.golden.dart --update-goldens
class _CjkFont {
  static const String family = 'CJK';
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final File file = File(r'C:\Windows\Fonts\Deng.ttf');
    if (!file.existsSync()) return;
    final Uint8List bytes = await file.readAsBytes();
    final FontLoader loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loaded = true;
  }
}

/// 颜色 + 无衬线中文兜底。注意用 fontFamilyFallback 而不是 fontFamily：
/// serif 槽位（NotoSerifSC/Playfair）自己的字形优先，只有缺字才落到 CJK
TextStyle _t(TextStyle base, Color color) =>
    base.copyWith(color: color, fontFamilyFallback: <String>['CJK']);

Widget _label(String text) =>
    Text(text, style: _t(AppText.label, AppColors.textSecondary));

/// 一档表面上的三档文字对比度
Widget _contrastCard(PaperTone tone) {
  const List<(String, TextStyle, Color)> rows = <(String, TextStyle, Color)>[
    ('textPrimary 16.1:1 正文', AppText.body, AppColors.textPrimary),
    ('textSecondary 5.3:1 说明', AppText.body, AppColors.textSecondary),
    ('textHint 2.7:1 仅限大号', AppText.h2, AppColors.textHint),
    ('朱砂 4.8:1 强调', AppText.body, AppColors.primary),
  ];

  return PaperCard(
    tone: tone,
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'tone: ${tone.name}',
          style: _t(AppText.label, AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final (String text, TextStyle style, Color color) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(text, style: _t(style, color)),
          ),
      ],
    ),
  );
}

Widget _periodChip(String label, IconData icon, bool selected) => PaperChip(
  label: label,
  icon: icon,
  selected: selected,
  onTap: () {},
  expanded: false,
  vertical: true,
);

Widget _gallery() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // 给主题文字统一挂 CJK 兜底：组件内部不带样式的 Text（如
    // SegmentedControl 的标签）经由 DefaultTextStyle 继承到它
    theme: AppTheme.lightTheme.copyWith(
      textTheme: AppTheme.lightTheme.textTheme.apply(
        fontFamilyFallback: <String>[_CjkFont.family],
      ),
    ),
    home: Scaffold(
      backgroundColor: AppColors.background,
      appBar: const PaperAppBar(title: '时途'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.navInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 刊头与衬线槽位（编辑风的核心视觉）
            const Masthead(kicker: 'WEEKLY LEDGER', title: '每周目标'),
            const SizedBox(height: AppSpacing.md),

            for (final PaperTone tone in PaperTone.values) _contrastCard(tone),

            const SizedBox(height: AppSpacing.md),
            _label('衬线数字（Playfair）与衬线正文（思源宋）'),
            const SizedBox(height: AppSpacing.xs),
            PaperCard(
              tone: PaperTone.row,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 26,
                    child: Text(
                      '01',
                      style: _t(
                        AppText.serifNum.copyWith(fontSize: 13),
                        AppColors.textHint,
                      ),
                    ),
                  ),
                  InkCheckCircle(isChecked: false, onTap: () {}, size: 21),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Text(
                      '读完《纳瓦尔宝典》前三章',
                      style: _t(AppText.bodySerif, AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '1/3',
                    style: _t(AppText.serifNum.copyWith(fontSize: 28), AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            _label('强调态（计时进行中，左缘着重线）'),
            const SizedBox(height: AppSpacing.xs),
            PaperCard(
              tone: PaperTone.row,
              padding: const EdgeInsets.symmetric(vertical: 14),
              tint: AppColors.success,
              child: Row(
                children: <Widget>[
                  const PaperIconButton(
                    icon: Icons.check,
                    onTap: null,
                    color: AppColors.success,
                    size: 28,
                    iconSize: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '写周报',
                      style: _t(
                        AppText.bodySerif.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const PaperIconButton(
                    icon: Icons.stop_rounded,
                    onTap: null,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            _label('PaperChip 未选 / 已选'),
            const SizedBox(height: AppSpacing.xs),
            // 在 Row 里必须给宽度：PaperChip 用 expanded:false 时
            // 会按内容收缩，不包 Expanded 就会缩成细条
            Row(
              children: <Widget>[
                Expanded(
                  child: _periodChip('上午', Icons.wb_sunny_outlined, false),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _periodChip('下午', Icons.wb_cloudy_outlined, true)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _periodChip('晚上', Icons.nights_stay_outlined, false)),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            _label('SegmentedControl（下划线页签）'),
            const SizedBox(height: AppSpacing.xs),
            SegmentedControl<int>(
              segments: const <Segment<int>>[
                Segment<int>(0, '日'),
                Segment<int>(1, '周'),
                Segment<int>(2, '月'),
              ],
              value: 1,
              onChanged: (int _) {},
            ),

            const SizedBox(height: AppSpacing.md),
            _label('图表配色（墨色系编辑色板）/ 热力图色阶（墨阶）'),
            const SizedBox(height: AppSpacing.xs),
            PaperCard(
              tone: PaperTone.raised,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final Color c in AppColors.chartColors)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: AppRadius.brSm,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.heatEmpty,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Center(
                          child: Text(
                            '空',
                            style: _t(
                              AppText.labelSm,
                              AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      for (int i = 0; i < AppColors.heatMapColors.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xxs),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.heatMapColors[i],
                              borderRadius: AppRadius.brSm,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: _t(
                                  AppText.labelSm,
                                  i >= 4
                                      ? AppColors.textOnPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PaperNavBar(index: 1, onChanged: (int _) {}),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _CjkFont.ensureLoaded();
  });

  testWidgets('纸面设计系统视觉探针', (WidgetTester tester) async {
    // 静白志没有极光与真模糊，tier 只影响错峰入场——探针固定 reduced
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/paper_gallery.png'),
    );
  });

  testWidgets('真实 App 首屏（空数据下的 chrome 与空态）', (WidgetTester tester) async {
    // 这条走的是真实 TimeWayProApp：provider 会因为拿不到平台通道（
    // path_provider / shared_preferences 在测试环境不可用）而落回空数据，
    // 所以看到的是**空态 + 纸面 chrome**。
    // 它的价值不是看数据，而是抓布局回归——刊头、底部导航、
    // extendBody 之后的避让有没有把内容遮住。
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const TimeWayProApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await expectLater(
      find.byType(TimeWayProApp),
      matchesGoldenFile('goldens/app_daily.png'),
    );
  });

  testWidgets('6 个 Tab 逐个出图', (WidgetTester tester) async {
    // FAB 被导航栏遮挡那个回归就是在"没看过的页面"里藏着的，
    // 所以每个 Tab 都出图过一遍。
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const TimeWayProApp());
    await tester.pump();
    await tester.pump(); // 等 MainScreen 回填导航栏高度

    const List<String> labels = <String>[
      '待办',
      '每周',
      '任务',
      '统计',
      '规划',
      '设置',
    ];
    for (int i = 0; i < labels.length; i++) {
      if (i > 0) {
        await tester.tap(find.text(labels[i]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }
      await expectLater(
        find.byType(TimeWayProApp),
        matchesGoldenFile('goldens/tab_$i.png'),
      );
    }
  });
}
