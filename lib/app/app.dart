import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/ui_effects.dart';
import '../features/daily/providers/daily_provider.dart';
import '../features/task/providers/task_provider.dart';
import '../features/planning/providers/plan_provider.dart';
import '../features/settings/providers/settings_provider.dart';
import 'main_screen.dart';

class TimeWayProApp extends StatelessWidget {
  const TimeWayProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DailyProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
        ChangeNotifierProvider(create: (_) => PlanProvider()..loadPlans()),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider()..loadSyncConfig()),
      ],
      child: MaterialApp(
        title: 'TimeWayPro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        // 这里已在 MediaQuery 之下，可读取系统"减弱动效"开关
        builder: (context, child) {
          UiEffects.respectPlatformPreferences(context);
          return child ?? const SizedBox.shrink();
        },
        home: const MainScreen(),
      ),
    );
  }
}
