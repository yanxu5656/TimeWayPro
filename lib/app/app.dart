import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
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
        home: const MainScreen(),
      ),
    );
  }
}
