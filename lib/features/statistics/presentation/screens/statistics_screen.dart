import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../task/providers/task_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedPeriod = 0; // 0: 日, 1: 周, 2: 月

  // 缓存统计数据，避免频繁刷新
  _StatsData? _cachedStats;
  int _lastPeriod = -1;
  int _lastTaskCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('统计'),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          // 检查是否需要刷新（时间段变化或任务数据变化）
          final currentTaskCount = provider.tasks.length;
          final needRefresh = _lastPeriod != _selectedPeriod ||
              _cachedStats == null ||
              currentTaskCount != _lastTaskCount;

          if (needRefresh) {
            _lastPeriod = _selectedPeriod;
            _lastTaskCount = currentTaskCount;
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
      padding: const EdgeInsets.all(20),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodTab('日', 0),
          _buildPeriodTab('周', 1),
          _buildPeriodTab('月', 2),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String label, int index) {
    final isSelected = _selectedPeriod == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedPeriod != index) {
            setState(() {
              _selectedPeriod = index;
              _cachedStats = null; // 清除缓存，触发重新加载
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(_StatsData stats) {
    return Row(
      children: [
        _buildStatCard(
          '总时长',
          _formatDuration(stats.totalDuration),
          Icons.timer_outlined,
          AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          '完成任务',
          '${stats.completedCount}',
          Icons.check_circle_outline,
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMap(_StatsData stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '热力图',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildHeatMapGrid(stats.dailyMap),
        ],
      ),
    );
  }

  Widget _buildHeatMapGrid(Map<String, int> dailyMap) {
    final now = DateTime.now();
    final startDate = _selectedPeriod == 0
        ? DateTime(now.year, now.month, now.day)
        : _selectedPeriod == 1
            ? now.subtract(Duration(days: now.weekday - 1))
            : DateTime(now.year, now.month, 1);

    final days = _selectedPeriod == 0
        ? 1
        : _selectedPeriod == 1
            ? 7
            : DateTime(now.year, now.month + 1, 0).day;

    // 找到最大值用于计算颜色深度
    int maxDuration = 1;
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final duration = dailyMap[key] ?? 0;
      if (duration > maxDuration) maxDuration = duration;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(days, (i) {
        final date = startDate.add(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final duration = dailyMap[key] ?? 0;
        final intensity = duration / maxDuration;

        return Tooltip(
          message: '${DateFormat('MM/dd').format(date)}\n${_formatDuration(duration)}',
          child: Container(
            width: _selectedPeriod == 2 ? 38 : 42,
            height: _selectedPeriod == 2 ? 38 : 42,
            decoration: BoxDecoration(
              color: _getHeatMapColor(intensity),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: intensity > 0.5 ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _getHeatMapColor(double intensity) {
    if (intensity == 0) return AppColors.surfaceVariant;
    if (intensity < 0.2) return AppColors.heatMapColors[0];
    if (intensity < 0.4) return AppColors.heatMapColors[2];
    if (intensity < 0.6) return AppColors.heatMapColors[4];
    if (intensity < 0.8) return AppColors.heatMapColors[6];
    return AppColors.heatMapColors[8];
  }

  Widget _buildPieChart(_StatsData stats) {
    if (stats.taskDurations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务占比',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
      final shortTitle = title.length > 4 ? '${title.substring(0, 4)}...' : title;

      return PieChartSectionData(
        color: AppColors.chartColors[index % AppColors.chartColors.length],
        value: item['total_duration'].toDouble(),
        title: '$shortTitle\n${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
                color: AppColors.chartColors[index % AppColors.chartColors.length],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${item['title']} (${_formatDuration(item['total_duration'] as int)})',
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务明细',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
                      borderRadius: BorderRadius.circular(2),
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
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: AppColors.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.chartColors[
                                  index % AppColors.chartColors.length],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _formatDuration(item['total_duration'] as int),
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
        range.start, range.end);
    final completedCount = await provider.getCompletedTaskCountByDateRange(
        range.start, range.end);
    final taskDurations =
        await provider.getTaskDurationSummary(range.start, range.end);
    final dailyMap =
        await provider.getDailyDurationMap(range.start, range.end);

    return _StatsData(
      totalDuration: totalDuration,
      completedCount: completedCount,
      taskDurations: taskDurations,
      dailyMap: dailyMap,
    );
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // 日
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 1: // 周
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case 2: // 月
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
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
