/// 供 README 使用的真实截图。
///
/// 与另外两个 golden 的区别：这里把系统字体**应用到了主题上**，所以
/// 文字是真的字，不是 Ahem 占位方块——README 里的图不能用方块字。
///
/// 做法：`Text` 会把自己的 style 与 `DefaultTextStyle`（Material 从
/// `theme.textTheme.bodyMedium` 注入）做 merge，而 merge 时显式 style 里
/// 为 null 的字段不覆盖——`AppText.*` 那些常量都没有 fontFamily，所以
/// 只要给 textTheme 统一 apply 一个 fontFamily，全应用的文字就都换过来了。
///
/// ## 跑法与产物
///
/// 这里输出的是**原始 PNG**（3x，约 1MB/张），写在 `build/` 下（已 gitignore）。
/// README 用的是缩放后的 WebP，体积小一个数量级（5 张合计 ~79KB）。
/// 更新 README 配图要跑两步：
///
///     flutter test test/golden/screenshots.golden.dart --update-goldens
///     python tool/make_readme_shots.py
///
/// 之所以不直接提交 PNG：把 4MB 的图放进仓库不值得，而 WebP 在 GitHub
/// 的 README 里渲染正常。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_way_pro/app/main_screen.dart';
import 'package:time_way_pro/core/theme/app_theme.dart';
import 'package:time_way_pro/core/ui/paper.dart';
import 'package:time_way_pro/features/daily/providers/daily_provider.dart';
import 'package:time_way_pro/features/planning/providers/plan_provider.dart';
import 'package:time_way_pro/features/settings/providers/settings_provider.dart';
import 'package:time_way_pro/features/task/providers/task_provider.dart';
import 'package:time_way_pro/features/weekly/providers/weekly_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../support/app_harness.dart';

/// 加载一个字体文件到指定 family
Future<void> _loadFont(String family, File file) async {
  if (!file.existsSync()) {
    throw StateError('找不到字体 $file，无法生成可用的截图');
  }
  final Uint8List bytes = await file.readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
}

/// 测试环境既没有正文字体也没有图标字体，两者都得手动加载，
/// 否则截图里文字是方块、图标也是方块。
///
/// - **把等线注册成 'Roboto'**：无衬线文本（含组件内部嵌套的
///   AnimatedDefaultTextStyle，fallback 链传不进去的那些）全部经由
///   默认字体名拿到中文，而衬线槽（NotoSerifSC / Playfair）有自己的
///   家族名不受影响。
/// - 图标字体从 Flutter SDK 缓存里取，路径由 FLUTTER_ROOT 推出来
///   （`flutter test` 会设置这个环境变量）。
/// pubspec 声明的字体在 flutter test 里**不会**自动加载（v1.5.0 起
/// README 截图里的衬线一直是占位块，就是这里漏了）——手动按家族装载。
Future<void> _loadPackagedFont(String family, List<String> assets) async {
  final FontLoader loader = FontLoader(family);
  for (final String path in assets) {
    final ByteData bytes = await rootBundle.load(path);
    loader.addFont(Future<ByteData>.value(bytes));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('Roboto', File(r'C:\Windows\Fonts\Deng.ttf'));
  await _loadPackagedFont('Playfair', <String>[
    'assets/fonts/PlayfairDisplay-Medium.ttf',
    'assets/fonts/PlayfairDisplay-Bold.ttf',
  ]);
  await _loadPackagedFont('NotoSerifSC', <String>[
    'assets/fonts/NotoSerifSC-Regular.ttf',
    'assets/fonts/NotoSerifSC-SemiBold.ttf',
  ]);

  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('没有 FLUTTER_ROOT，找不到 MaterialIcons 字体');
  }
  await _loadFont(
    'MaterialIcons',
    File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/'
      'materialicons-regular.otf',
    ),
  );
}

/// 与 `TimeWayProApp` 结构一致（字体由上面的 Roboto 注册解决）
Widget _appWithRealFont() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DailyProvider>(create: (_) => DailyProvider()),
      ChangeNotifierProvider<WeeklyProvider>(
        create: (_) => WeeklyProvider()..loadGoals(),
      ),
      ChangeNotifierProvider<TaskProvider>(
        create: (_) => TaskProvider()..loadTasks(),
      ),
      ChangeNotifierProvider<PlanProvider>(
        create: (_) => PlanProvider()..loadPlans(),
      ),
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider()..loadSyncConfig(),
      ),
    ],
    child: MaterialApp(
      title: 'TimeWayPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('README 截图', (WidgetTester tester) async {
    // 错峰入场要停掉（tier=reduced），否则同一份代码每次出图都不一样
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() => DatabaseHelper().importAll(seedData()));

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(_appWithRealFont());
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    const List<(String tab, String file)> shots = <(String, String)>[
      ('待办', 'daily'),
      ('每周', 'weekly'),
      ('任务', 'task'),
      ('统计', 'stats'),
      ('规划', 'planning'),
    ];

    for (int i = 0; i < shots.length; i++) {
      if (i > 0) {
        await tester.tap(find.text(shots[i].$1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }
      await expectLater(
        find.byType(MaterialApp),
        // 落在 build/ 下（已 gitignore）；README 用的 WebP 由
        // tool/make_readme_shots.py 从这里缩放导出
        matchesGoldenFile('../../build/readme_screenshots/${shots[i].$2}.png'),
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('弹窗截图', (WidgetTester tester) async {
    // 之前这个文件只拍 5 个 Tab 页，导致「添加待办」弹窗里的
    // ParentDataWidget 误用一直没被发现（release 下会变成一块灰色方块）。
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() => DatabaseHelper().importAll(seedData()));

    await tester.pumpWidget(_appWithRealFont());
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // 每日待办页的 FAB 打开「添加待办」
    await tester.tap(find.byType(PaperFab));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/readme_screenshots/sheet_add.png'),
    );
  });

  testWidgets('挪周弹窗截图', (WidgetTester tester) async {
    UiEffects.resetForTesting();
    UiEffects.tier.value = UiEffectTier.reduced;

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() => DatabaseHelper().importAll(seedData()));

    await tester.pumpWidget(_appWithRealFont());
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // 每周页第一条目标的挪周按钮
    await tester.tap(find.text('每周'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byIcon(Icons.event_repeat_outlined).first);
    // 先泵一帧让路由动画开始计时，再给足时长（见 weekly_screen_test 的教训）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/readme_screenshots/sheet_move.png'),
    );
  });
}
