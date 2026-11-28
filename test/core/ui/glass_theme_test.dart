import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/settings/providers/theme_provider.dart';

Future<ThemeProvider> _glassProvider() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString(ThemeProvider.storageKey, 'aurora_glass');
  final ThemeProvider provider = ThemeProvider(preferences: preferences);
  await provider.loadTheme();
  addTearDown(provider.dispose);
  return provider;
}

Widget _glassHarness(
  ThemeProvider provider, {
  bool disableAnimations = false,
  VoidCallback? openSheet,
}) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: provider,
    child: Consumer<ThemeProvider>(
      builder: (BuildContext context, ThemeProvider value, Widget? child) {
        return MaterialApp(
          theme: AppTheme.forDesign(value.option.design),
          builder: (BuildContext context, Widget? child) {
            final Widget app = Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AmbientBackground(design: context.design),
                child ?? const SizedBox.shrink(),
              ],
            );
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: app,
            );
          },
          home: Scaffold(
            backgroundColor: Colors.transparent,
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                const Masthead(
                  kicker: 'TODAY',
                  title: '每日待办',
                  meta: Text('让重要的事慢慢发生'),
                  ghost: '28',
                ),
                const PaperCard(tone: PaperTone.row, child: Text('完成一件小事')),
                const SizedBox(height: AppSpacing.md),
                SegmentedControl<String>(
                  segments: <Segment<String>>[
                    Segment<String>('today', '今天'),
                    Segment<String>('week', '本周'),
                  ],
                  value: 'today',
                  onChanged: (String value) {},
                ),
                const SizedBox(height: AppSpacing.md),
                PaperButton(
                  label: '新建任务',
                  icon: Icons.add_rounded,
                  onPressed: () {},
                ),
                PaperOutlinedButton(label: '打开玻璃弹窗', onPressed: openSheet),
                const PaperFab(onPressed: null, label: '专注'),
              ],
            ),
            bottomNavigationBar: PaperNavBar(index: 0, onChanged: (_) {}),
          ),
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;
  });

  tearDown(UiEffects.resetForTesting);

  testWidgets('玻璃主题使用透明页面、动态背景与真实模糊材质', (WidgetTester tester) async {
    await tester.pumpWidget(_glassHarness(await _glassProvider()));

    expect(find.byType(AmbientBackground), findsOneWidget);
    expect(find.byType(GlassSurface), findsNWidgets(4));
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.transparent,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('玻璃底部弹窗保留内容并使用玻璃表面', (WidgetTester tester) async {
    await tester.pumpWidget(
      _glassHarness(
        await _glassProvider(),
        openSheet: () {
          final BuildContext context = tester.element(find.text('打开玻璃弹窗'));
          showPaperSheet<void>(
            context,
            builder: (BuildContext context) => const Text('弹窗内容'),
          );
        },
      ),
    );

    await tester.tap(find.text('打开玻璃弹窗'));
    await tester.pumpAndSettle();

    expect(find.text('弹窗内容'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PaperSheet),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 窄屏下玻璃组件不溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_glassHarness(await _glassProvider()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('最低效果档位会停止极光动画并关闭模糊', (WidgetTester tester) async {
    UiEffects.tier.value = UiEffectTier.full;
    await tester.pumpWidget(_glassHarness(await _glassProvider()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    UiEffects.tier.value = UiEffectTier.minimal;
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    for (final BackdropFilter filter in tester.widgetList<BackdropFilter>(
      find.byType(BackdropFilter),
    )) {
      expect(filter.filter.toString(), contains('blur(0.0, 0.0'));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('减弱动效与最低档位不会启动连续极光动画', (WidgetTester tester) async {
    UiEffects.tier.value = UiEffectTier.full;
    await tester.pumpWidget(
      _glassHarness(await _glassProvider(), disableAnimations: true),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
