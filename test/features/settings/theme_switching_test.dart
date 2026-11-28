import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/settings/presentation/widgets/theme_picker.dart';
import 'package:time_way_pro/features/settings/providers/theme_provider.dart';

import '../../support/app_harness.dart';

Widget _themeHarness(ThemeProvider provider) {
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: provider,
    child: Consumer<ThemeProvider>(
      builder: (BuildContext context, ThemeProvider value, Widget? child) {
        final bool isDark = value.option.design.palette.isDark;
        return MaterialApp(
          theme: AppTheme.forDesign(value.option.design),
          builder: (BuildContext context, Widget? child) =>
              AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                Masthead(kicker: 'THEME', title: '主题预览', ghost: '26'),
                PaperCard(tone: PaperTone.row, child: Text('示例卡片')),
                ThemePicker(),
              ],
            ),
            bottomNavigationBar: PaperNavBar(index: 0, onChanged: (_) {}),
          ),
        );
      },
    ),
  );
}

Color _containerColor(WidgetTester tester, Finder container) {
  final Container widget = tester.widget<Container>(container);
  return (widget.decoration! as BoxDecoration).color!;
}

Future<void> _scrollTop(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('点击方案实时更新刊头、卡片、导航与状态栏', (WidgetTester tester) async {
    final ThemeProvider provider = ThemeProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(_themeHarness(provider));
    await tester.pumpAndSettle();

    Color mastheadColor() => _containerColor(
      tester,
      find
          .descendant(
            of: find.byType(Masthead, skipOffstage: false),
            matching: find.byType(Container),
            skipOffstage: false,
          )
          .first,
    );
    Color cardColor() => _containerColor(
      tester,
      find
          .descendant(
            of: find.byType(PaperCard, skipOffstage: false),
            matching: find.byType(Container),
            skipOffstage: false,
          )
          .first,
    );
    Color navColor() => _containerColor(
      tester,
      find
          .descendant(
            of: find.byType(PaperNavBar),
            matching: find.byType(Container),
          )
          .first,
    );

    expect(mastheadColor(), AppColors.primary);
    expect(cardColor(), AppColors.surface);
    expect(navColor(), AppColors.surface);

    await tester.ensureVisible(
      find.byKey(const Key('theme_option_tech_deepspace')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme_option_tech_deepspace')));
    await tester.pumpAndSettle();
    await _scrollTop(tester);

    final AppPalette c = AppThemeCatalog.byId('tech_deepspace').design.palette;
    expect(provider.option.id, 'tech_deepspace');
    expect(mastheadColor(), c.primary);
    expect(cardColor(), c.surface);
    expect(navColor(), c.surface);
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .scaffoldBackgroundColor,
      c.background,
    );
    final AnnotatedRegion<SystemUiOverlayStyle> region = tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        );
    expect(region.value.statusBarIconBrightness, Brightness.light);

    await tester.ensureVisible(
      find.byKey(const Key('theme_option_cute_peach')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme_option_cute_peach')));
    await tester.pumpAndSettle();
    await _scrollTop(tester);
    expect(provider.option.id, 'cute_peach');
    expect(
      mastheadColor(),
      AppThemeCatalog.byId('cute_peach').design.palette.primary,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 窄屏与两列方案卡片不溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ThemeProvider provider = ThemeProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(_themeHarness(provider));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('theme_option_tech_matrix')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('科技深色主题的日期选择器保持深色表面', (WidgetTester tester) async {
    await pumpSeededApp(tester);
    final BuildContext navContext = tester.element(find.byType(PaperNavBar));
    final ThemeProvider provider = navContext.read<ThemeProvider>();
    await provider.selectTheme('tech_deepspace');
    await tester.pumpAndSettle();

    await revealNavItem(tester, '任务');
    await tester.tap(
      find.descendant(of: find.byType(PaperNavBar), matching: find.text('任务')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    final ColorScheme scheme = Theme.of(
      tester.element(find.byType(DatePickerDialog)),
    ).colorScheme;
    final AppPalette palette = provider.option.design.palette;
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, palette.primary);
    expect(scheme.onPrimary, palette.textOnPrimary);
    expect(scheme.surface, palette.surface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('完整应用切换到流光璃境不重置当前 Tab', (WidgetTester tester) async {
    await pumpSeededApp(tester);
    await revealNavItem(tester, '设置');
    await tester.tap(
      find.descendant(of: find.byType(PaperNavBar), matching: find.text('设置')),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(PaperNavBar));
    final ThemeProvider provider = context.read<ThemeProvider>();
    await provider.selectTheme('aurora_glass');
    await tester.pumpAndSettle();

    expect(provider.option.id, 'aurora_glass');
    expect(find.byType(GlassSurface), findsWidgets);
    expect(find.text('外观主题'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      Colors.transparent,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('完整应用内切换不重置当前 Tab', (WidgetTester tester) async {
    await pumpSeededApp(tester);
    await revealNavItem(tester, '设置');
    await tester.tap(
      find.descendant(of: find.byType(PaperNavBar), matching: find.text('设置')),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(PaperNavBar));
    final ThemeProvider provider = context.read<ThemeProvider>();
    await provider.selectTheme('tech_matrix');
    await tester.pumpAndSettle();
    expect(provider.option.id, 'tech_matrix');

    await revealNavItem(tester, '待办');
    await tester.tap(
      find.descendant(of: find.byType(PaperNavBar), matching: find.text('待办')),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日待办'), findsOneWidget);
    expect(provider.option.id, 'tech_matrix');
    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.theme!.brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
