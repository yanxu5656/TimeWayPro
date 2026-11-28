import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/ambient_background.dart';
import '../core/ui/ui_effects.dart';
import '../features/daily/providers/daily_provider.dart';
import '../features/focus/providers/focus_timer_provider.dart';
import '../features/leisure/providers/leisure_provider.dart';
import '../features/calendar/providers/calendar_provider.dart';
import '../features/rewards/data/repositories/reward_repository.dart';
import '../features/rewards/providers/reward_provider.dart';
import '../features/settings/providers/theme_provider.dart';
import '../features/task/providers/task_provider.dart';
import '../features/planning/providers/plan_provider.dart';
import '../features/settings/providers/settings_provider.dart';
import '../features/weekly/providers/weekly_provider.dart';
import 'main_screen.dart';

class TimeWayProApp extends StatelessWidget {
  const TimeWayProApp({super.key});

  @override
  Widget build(BuildContext context) {
    final RewardRepository rewards = RewardRepository();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DailyProvider()),
        ChangeNotifierProvider(
          create: (_) => WeeklyProvider(rewards: rewards)..loadGoals(),
        ),
        ChangeNotifierProvider(
          create: (_) => RewardProvider(repository: rewards)..load(),
        ),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
        ChangeNotifierProvider(create: (_) => PlanProvider()..loadPlans()),
        ChangeNotifierProvider(create: (_) => LeisureProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()..loadMonth()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..loadSyncConfig(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(
          create: (_) => FocusTimerProvider()..restoreState(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder:
            (BuildContext context, ThemeProvider themeProvider, Widget? child) {
              return MaterialApp(
                title: 'TimeWayPro',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.forDesign(themeProvider.option.design),
                builder: (BuildContext context, Widget? child) {
                  UiEffects.respectPlatformPreferences(context);
                  final bool isDark = context.colors.isDark;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: isDark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarIconBrightness: isDark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarColor: Colors.transparent,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        AmbientBackground(design: context.design),
                        child ?? const SizedBox.shrink(),
                      ],
                    ),
                  );
                },
                home: const MainScreen(),
              );
            },
      ),
    );
  }
}
