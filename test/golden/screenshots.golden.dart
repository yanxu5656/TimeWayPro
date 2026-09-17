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
/// README 用的是缩放后的 WebP，体积小一个数量级（4 张合计 ~62KB）。
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
import 'package:time_way_pro/core/ui/glass.dart';
import 'package:time_way_pro/features/daily/providers/daily_provider.dart';
import 'package:time_way_pro/features/planning/providers/plan_provider.dart';
import 'package:time_way_pro/features/settings/providers/settings_provider.dart';
import 'package:time_way_pro/features/task/providers/task_provider.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../support/app_harness.dart';

const String _fontFamily = 'CJK';

/// 加载一个字体文件到指定 family
Future<void> _loadFont(String family, File file) async {
  if (!file.existsSync()) {
    throw StateError('找不到字体 $file，无法生成可用的截图');
  }
  final Uint8List bytes = await file.readAsBytes();
  await (FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes))))
      .load();
}

/// 测试环境既没有正文字体也没有图标字体，两者都得手动加载，
/// 否则截图里文字是方块、图标也是方块。
///
/// - 正文用系统等线。`.ttc` 是字体集合，FontLoader 不认，必须用纯 TTF。
/// - 图标字体从 Flutter SDK 缓存里取，路径由 FLUTTER_ROOT 推出来
///   （`flutter test` 会设置这个环境变量）。
Future<void> _loadFonts() async {
  await _loadFont(_fontFamily, File(r'C:\Windows\Fonts\Deng.ttf'));

  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('没有 FLUTTER_ROOT，找不到 MaterialIcons 字体');
  }
  await _loadFont(
    'MaterialIcons',
    File('$flutterRoot/bin/cache/artifacts/material_fonts/'
        'materialicons-regular.otf'),
  );
}

/// 与 `TimeWayProApp` 结构一致，只是主题套了 CJK 字体
Widget _appWithRealFont() {
  final ThemeData theme = AppTheme.lightTheme;
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DailyProvider>(create: (_) => DailyProvider()),
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
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: _fontFamily),
      ),
      builder: (BuildContext context, Widget? child) {
        // 兜底：把 DefaultTextStyle 也钉上，覆盖没有 Material 祖先的位置
        return DefaultTextStyle(
          style: TextStyle(fontFamily: _fontFamily),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
    // 真模糊要留着（截图得体现磨砂），但极光动画要停，
    // 否则同一份代码每次出图都不一样
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
}