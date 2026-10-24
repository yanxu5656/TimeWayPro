import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/app/app.dart';
import 'package:time_way_pro/core/ui/glass.dart';

/// 玻璃设计系统的视觉探针。
///
/// 这个项目的改动价值几乎全在视觉上，而**文字对比度这类问题静态分析
/// 查不出来**——`glassFill` 78% 白之下 textSecondary 只有约 4.7:1，
/// 余量很窄。这个 golden 把各档玻璃 + 各档文字真实渲染成 PNG，用来
/// 用眼睛确认，而不是靠算。
///
/// ## 为什么要单独加载字体
///
/// `flutter test` 默认用 Ahem 占位字体，**所有文字会渲染成实心方块**，
/// 拿来判断字号与行高没有意义。这里加载系统的等线（Deng.ttf）。
/// 注意不能用 msyh.ttc —— 那是字体集合，FontLoader 不认。
///
/// ## 为什么不进默认 test run
///
/// 文件名不以 `_test.dart` 结尾，所以 `flutter test` 默认不会收集它——
/// golden 在不同 Flutter 版本 / 平台上像素级结果会漂移，放进默认 test run
/// 会让别人的机器变红。需要时显式按路径跑：
///
///     flutter test test/golden/glass_gallery.golden.dart --update-goldens
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

TextStyle _t(TextStyle base, Color color) =>
    base.copyWith(color: color, fontFamily: _CjkFont.family);

Widget _label(String text) =>
    Text(text, style: _t(AppText.label, AppColors.textSecondary));

/// 一档玻璃上的三档文字对比度
Widget _contrastCard(GlassTone tone) {
  const List<(String, TextStyle, Color)> rows = <(String, TextStyle, Color)>[
    ('textPrimary 16.8:1', AppText.title, AppColors.textPrimary),
    ('textSecondary 4.7:1 正文', AppText.body, AppColors.textSecondary),
    ('textHint 3.1:1 仅限大号', AppText.h2, AppColors.textHint),
  ];

  return GlassCard(
    tone: tone,
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('tone: ${tone.name}', style: _t(AppText.label, AppColors.primary)),
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

Widget _periodChip(String label, IconData icon, Color tint, bool selected) =>
    GlassChip(
      label: label,
      icon: icon,
      tint: tint,
      selected: selected,
      onTap: () {},
      expanded: false,
      vertical: true,
    );

Widget _gallery() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      // 让内容伸到顶栏之下，才能看出玻璃顶栏的磨砂
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
        title: '时途',
        titleIcon: Icons.access_time_rounded,
      ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AuroraBackground(forceAnimated: false)),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              kToolbarHeight + AppSpacing.xxl,
              AppSpacing.md,
              AppSpacing.navInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final GlassTone tone in GlassTone.values)
                  _contrastCard(tone),

                const SizedBox(height: AppSpacing.md),
                _label('强调态（计时进行中）'),
                const SizedBox(height: AppSpacing.xs),
                GlassCard(
                  tint: AppColors.success,
                  edgeWidth: 2,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      const GlassIconButton(
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
                          style: _t(AppText.taskTitle, AppColors.textPrimary),
                        ),
                      ),
                      const GlassIconButton(
                        icon: Icons.stop_rounded,
                        onTap: null,
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                _label('GlassChip 未选 / 已选'),
                const SizedBox(height: AppSpacing.xs),
                // 在 Row 里必须给宽度：GlassChip 用 expanded:false 时
                // 会按内容收缩，不包 Expanded 就会缩成细条
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _periodChip(
                        '上午',
                        Icons.wb_sunny_outlined,
                        AppColors.warning,
                        false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _periodChip(
                        '下午',
                        Icons.wb_cloudy_outlined,
                        AppColors.info,
                        true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _periodChip(
                        '晚上',
                        Icons.nights_stay_outlined,
                        AppColors.primary,
                        false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),
                _label('SegmentedControl'),
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
                _label('图表配色 / 热力图色阶'),
                const SizedBox(height: AppSpacing.xs),
                GlassCard(
                  tone: GlassTone.strong,
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
                          for (
                            int i = 0;
                            i < AppColors.heatMapColors.length;
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.xxs,
                              ),
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
                                      i >= 3
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
        ],
      ),
      bottomNavigationBar: GlassNavBar(index: 1, onChanged: (int _) {}),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _CjkFont.ensureLoaded();
  });

  testWidgets('玻璃设计系统视觉探针', (WidgetTester tester) async {
    // 用 reduced 而不是 minimal：minimal 会关掉 trueBlur，
    // 那样顶栏/底栏的磨砂效果根本不会被渲染，这个探针就失去意义了。
    // reduced 停掉极光动画（配合 forceAnimated: false）但保留真模糊。
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_gallery());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/glass_gallery.png'),
    );
  });

  testWidgets('真实 App 首屏（空数据下的 chrome 与空态）', (WidgetTester tester) async {
    // 这条走的是真实 TimeWayProApp：provider 会因为拿不到平台通道（
    // path_provider / shared_preferences 在测试环境不可用）而落回空数据，
    // 所以看到的是**空态 + 玻璃 chrome**。
    // 它的价值不是看数据，而是抓布局回归——顶栏、极光、底部导航、
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

  testWidgets('5 个 Tab 逐个出图', (WidgetTester tester) async {
    // FAB 被导航栏遮挡那个回归就是在"没看过的页面"里藏着的，
    // 所以每个 Tab 都出图过一遍。
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const TimeWayProApp());
    await tester.pump();
    await tester.pump(); // 等 MainScreen 回填导航栏高度

    const List<String> labels = <String>['待办', '任务', '统计', '规划', '设置'];
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
