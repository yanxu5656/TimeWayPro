import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/ui/glass.dart';
import '../../../task/providers/task_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedPeriod = 0; // 0: 日, 1: 周, 2: 月
  DateTime _selectedDate = DateTime.now();

  // 缓存统计数据，避免频繁刷新
  _StatsData? _cachedStats;
  int _lastPeriod = -1;
  int _lastTaskCount = 0;
  String _lastDateKey = '';

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '统计',
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          // 检查是否需要刷新
          final currentTaskCount = provider.tasks.length;
          final currentDateKey =
              '$_selectedPeriod-${_selectedDate.toIso8601String().substring(0, 10)}';
          final needRefresh =
              _lastPeriod != _selectedPeriod ||
              _cachedStats == null ||
              currentTaskCount != _lastTaskCount ||
              _lastDateKey != currentDateKey;

          if (needRefresh) {
            _lastPeriod = _selectedPeriod;
            _lastTaskCount = currentTaskCount;
            _lastDateKey = currentDateKey;
            return FutureBuilder<_StatsData>(
              future: _loadStats(provider),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  );
                }

                _cachedStats = snapshot.data ?? _StatsData.empty();
                return _buildContent(_cachedStats!);
              },
            );
          }

          // 使用缓存的数据
          return _buildContent(_cachedStats!);
        },
      ),
    );
  }

  Widget _buildContent(_StatsData stats) {
    return ListView(
      // 底部要避让玻璃导航栏（MainScreen 开了 extendBody），
      // 否则滚到底时最后一张卡会被压在导航栏下面
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.navInset,
      ),
      children: [
        // 时间段选择器
        _buildDateSelector(),
        const SizedBox(height: 20),

        // 概览卡片
        _buildOverviewCards(stats),
        const SizedBox(height: 20),

        // 热力图
        _buildHeatMap(stats),
        const SizedBox(height: 20),

        // 饼图
        _buildPieChart(stats),
        const SizedBox(height: 20),

        // 任务明细
        _buildTaskDetail(stats),
      ],
    );
  }

  Widget _buildDateSelector() {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          // 时间段切换。换成带滑动指示块的分段控件——
          // 原来的实现只有背景色在变，看不出"从哪滑到哪"
          SegmentedControl<int>(
            segments: const [
              Segment<int>(0, '日'),
              Segment<int>(1, '周'),
              Segment<int>(2, '月'),
            ],
            value: _selectedPeriod,
            onChanged: (index) {
              if (_selectedPeriod != index) {
                setState(() {
                  _selectedPeriod = index;
                  _cachedStats = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // 日期导航
          Row(
            children: [
              _buildNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: _previousPeriod,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDate,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    tone: GlassTone.subtle,
                    radius: AppRadius.md,
                    tint: AppColors.primary,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isCurrentPeriod()
                              ? Icons.today_rounded
                              : Icons.calendar_month_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getPeriodText(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _nextPeriod,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GlassIconButton(
      icon: icon,
      onTap: onTap,
      color: AppColors.textSecondary,
      size: 40,
      iconSize: 22,
    );
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // 日
        return _selectedDate.year == now.year &&
            _selectedDate.month == now.month &&
            _selectedDate.day == now.day;
      case 1: // 周
        final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final selectedWeekStart = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        return currentWeekStart.year == selectedWeekStart.year &&
            currentWeekStart.month == selectedWeekStart.month &&
            currentWeekStart.day == selectedWeekStart.day;
      case 2: // 月
        return _selectedDate.year == now.year &&
            _selectedDate.month == now.month;
      default:
        return false;
    }
  }

  String _getPeriodText() {
    switch (_selectedPeriod) {
      case 0: // 日
        if (_isCurrentPeriod()) return '今天';
        return DateFormat('yyyy年MM月dd日').format(_selectedDate);
      case 1: // 周
        final weekStart = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        final weekEnd = weekStart.add(const Duration(days: 6));
        if (_isCurrentPeriod()) return '本周';
        return '${DateFormat('MM/dd').format(weekStart)} - ${DateFormat('MM/dd').format(weekEnd)}';
      case 2: // 月
        if (_isCurrentPeriod()) return '本月';
        return DateFormat('yyyy年MM月').format(_selectedDate);
      default:
        return '';
    }
  }

  void _previousPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 0: // 日
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case 1: // 周
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          break;
        case 2: // 月
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month - 1,
            1,
          );
          break;
      }
      _cachedStats = null;
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_selectedPeriod) {
        case 0: // 日
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case 1: // 周
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          break;
        case 2: // 月
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + 1,
            1,
          );
          break;
      }
      _cachedStats = null;
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textOnPrimary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _cachedStats = null;
      });
    }
  }

  Widget _buildOverviewCards(_StatsData stats) {
    return Row(
      children: [
        _buildStatCard(
          '总时长',
          stats.totalDuration,
          formatDurationShort,
          Icons.timer_outlined,
          AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildStatCard(
          '完成任务',
          stats.completedCount,
          (v) => '$v',
          Icons.check_circle_outline,
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    int value,
    String Function(int) format,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: GlassCard(
        // 数字密集，走 strong 档保对比度
        tone: GlassTone.strong,
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppSpacing.md),
            CountUpText(
              value: value,
              format: format,
              style: AppText.numXl.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMap(_StatsData stats) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '热力图',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (_selectedPeriod == 0)
                Text(
                  DateFormat('yyyy年MM月dd日').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatMapGrid(stats.dailyMap),
        ],
      ),
    );
  }

  Widget _buildHeatMapGrid(Map<String, int> dailyMap) {
    DateTime startDate;
    int days;

    switch (_selectedPeriod) {
      case 0: // 日 - 显示当月
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        days = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
        break;
      case 1: // 周 - 显示当周
        startDate = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        days = 7;
        break;
      case 2: // 月 - 显示当月
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        days = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
        break;
      default:
        startDate = DateTime.now();
        days = 7;
    }

    // 找到最大值用于计算颜色深度
    int maxDuration = 1;
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final duration = dailyMap[key] ?? 0;
      if (duration > maxDuration) maxDuration = duration;
    }

    // 日模式显示当月热力图，周模式显示7天，月模式显示当月
    if (_selectedPeriod == 1) {
      // 周模式 - 7天横排
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final date = startDate.add(Duration(days: i));
          final key = DateFormat('yyyy-MM-dd').format(date);
          final duration = dailyMap[key] ?? 0;
          final level = _heatLevel(duration, maxDuration);
          final isSelected =
              date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          return Column(
            children: [
              Text(
                ['一', '二', '三', '四', '五', '六', '日'][i],
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
              const SizedBox(height: 6),
              Tooltip(
                message:
                    '${DateFormat('MM/dd').format(date)}\n${formatDurationShort(duration)}',
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _heatCellColor(level),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _heatTextColor(level),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      );
    }

    // 日/月模式 - 网格布局
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(days, (i) {
        final date = startDate.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final duration = dailyMap[key] ?? 0;
        final level = _heatLevel(duration, maxDuration);
        final isSelected =
            _selectedPeriod == 0 &&
            date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;

        return Tooltip(
          message:
              '${DateFormat('MM/dd').format(date)}\n${formatDurationShort(duration)}',
          child: Container(
            width: _selectedPeriod == 2 ? 36 : 40,
            height: _selectedPeriod == 2 ? 36 : 40,
            decoration: BoxDecoration(
              color: _heatCellColor(level),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 11,
                  color: _heatTextColor(level),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 热力图档位：0 = 无数据，1..N 对应 AppColors.heatMapColors 的下标 + 1。
  ///
  /// 用离散档位而不是连续强度，是为了让**格子颜色与文字颜色成对切换**——
  /// 原先文字阈值写死 `intensity > 0.5`，与色阶档位并不对齐，实测下来
  /// 会出现"中等底色配白字"这种读不出的组合。
  int _heatLevel(int duration, int maxDuration) {
    if (duration <= 0) return 0;
    final ratio = duration / maxDuration;
    return (ratio * AppColors.heatMapColors.length).ceil().clamp(
      1,
      AppColors.heatMapColors.length,
    );
  }

  Color _heatCellColor(int level) =>
      level == 0 ? AppColors.heatEmpty : AppColors.heatMapColors[level - 1];

  /// 1-3 档底色还够浅，用深色字；4-5 档才用白字
  Color _heatTextColor(int level) =>
      level >= 4 ? AppColors.textOnPrimary : AppColors.textPrimary;

  Widget _buildPieChart(_StatsData stats) {
    if (stats.taskDurations.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无数据',
              style: TextStyle(color: AppColors.textHint, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务占比',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _buildPieSections(stats),
                centerSpaceRadius: 50,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(stats),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(_StatsData stats) {
    return stats.taskDurations.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final percentage = stats.totalDuration > 0
          ? (item['total_duration'] as int) / stats.totalDuration * 100
          : 0.0;
      final title = item['title'] as String;
      final shortTitle = title.length > 4
          ? '${title.substring(0, 4)}...'
          : title;

      final Color sliceColor =
          AppColors.chartColors[index % AppColors.chartColors.length];
      // 浅色切片用深色字，否则白字读不出
      final bool lightSlice =
          ThemeData.estimateBrightnessForColor(sliceColor) == Brightness.light;

      return PieChartSectionData(
        color: sliceColor,
        value: item['total_duration'].toDouble(),
        title: '$shortTitle\n${percentage.toStringAsFixed(0)}%',
        titleStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: lightSlice ? AppColors.textPrimary : AppColors.textOnPrimary,
        ),
        radius: 70,
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
  }

  Widget _buildLegend(_StatsData stats) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: stats.taskDurations.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:
                    AppColors.chartColors[index % AppColors.chartColors.length],
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${item['title']} (${formatDurationShort(item['total_duration'] as int)})',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTaskDetail(_StatsData stats) {
    if (stats.taskDurations.isEmpty) return const SizedBox();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务明细',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...stats.taskDurations.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = stats.totalDuration > 0
                ? (item['total_duration'] as int) / stats.totalDuration * 100
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors
                          .chartColors[index % AppColors.chartColors.length],
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.chartColors[index %
                                  AppColors.chartColors.length],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    formatDurationShort(item['total_duration'] as int),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<_StatsData> _loadStats(TaskProvider provider) async {
    final range = _getDateRange();
    final totalDuration = await provider.getTotalDurationByDateRange(
      range.start,
      range.end,
    );
    final completedCount = await provider.getCompletedTaskCountByDateRange(
      range.start,
      range.end,
    );
    final taskDurations = await provider.getTaskDurationSummary(
      range.start,
      range.end,
    );
    final dailyMap = await provider.getDailyDurationMap(range.start, range.end);

    return _StatsData(
      totalDuration: totalDuration,
      completedCount: completedCount,
      taskDurations: taskDurations,
      dailyMap: dailyMap,
    );
  }

  DateTimeRange _getDateRange() {
    switch (_selectedPeriod) {
      case 0: // 日
        return DateTimeRange(
          start: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
          ),
          end: DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            23,
            59,
            59,
          ),
        );
      case 1: // 周
        final weekStart = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        return DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + 6,
            23,
            59,
            59,
          ),
        );
      case 2: // 月
        return DateTimeRange(
          start: DateTime(_selectedDate.year, _selectedDate.month, 1),
          end: DateTime(
            _selectedDate.year,
            _selectedDate.month + 1,
            0,
            23,
            59,
            59,
          ),
        );
      default:
        final now = DateTime.now();
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
    }
  }
}

class _StatsData {
  final int totalDuration;
  final int completedCount;
  final List<Map<String, dynamic>> taskDurations;
  final Map<String, int> dailyMap;

  _StatsData({
    required this.totalDuration,
    required this.completedCount,
    required this.taskDurations,
    required this.dailyMap,
  });

  factory _StatsData.empty() {
    return _StatsData(
      totalDuration: 0,
      completedCount: 0,
      taskDurations: [],
      dailyMap: {},
    );
  }
}

/// 时长的紧凑展示（`3h 20m` / `45m` / `12s`）。
///
/// 提到文件级是为了让 [CountUpText] 能直接把它当 `format:` 传进去——
/// 数字滚动的动画作用在整数秒上，渲染时才格式化。
String formatDurationShort(int seconds) {
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}
