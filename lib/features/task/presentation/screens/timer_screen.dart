import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../data/models/task_record.dart';
import '../../data/repositories/task_repository.dart';
import '../../providers/task_provider.dart';

class TimerScreen extends StatefulWidget {
  final Task task;

  const TimerScreen({super.key, required this.task});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  String? _currentRecordId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.task.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 计时器显示
            _buildTimerDisplay(),
            const SizedBox(height: 40),

            // 任务信息
            _buildTaskInfo(),
            const SizedBox(height: 60),

            // 控制按钮
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(_isRunning ? 0.3 : 0.1),
                blurRadius: _isRunning ? 30 : 15,
                spreadRadius: _isRunning ? 5 : 0,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${hours.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskInfo() {
    return Column(
      children: [
        Text(
          widget.task.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (widget.task.description != null &&
            widget.task.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.task.description!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 停止按钮
        if (_isRunning || _elapsedSeconds > 0)
          _buildControlButton(
            icon: Icons.stop_rounded,
            label: '结束',
            color: AppColors.error,
            onTap: _stopTimer,
          ),

        const SizedBox(width: 32),

        // 开始/暂停按钮
        _buildControlButton(
          icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: _isRunning ? '暂停' : '开始',
          color: AppColors.primary,
          onTap: _isRunning ? _pauseTimer : _startTimer,
          isLarge: true,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: isLarge ? 80 : 64,
            height: isLarge ? 80 : 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: isLarge ? 40 : 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() async {
    if (_currentRecordId == null) {
      final record = TaskRecord(
        id: '',
        taskId: widget.task.id,
        startTime: DateTime.now(),
      );
      final repo = TaskRepository();
      _currentRecordId = await repo.insertRecord(record);
    }

    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });

      // 倒计时模式检查
      if (widget.task.timerType == TimerType.countDown &&
          widget.task.duration != null &&
          _elapsedSeconds >= widget.task.duration!) {
        _stopTimer();
        _showCompletionDialog();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _stopTimer() async {
    _timer?.cancel();

    if (_currentRecordId != null && _elapsedSeconds > 0) {
      final repo = TaskRepository();
      final records = await repo.getRecordsByTaskId(widget.task.id);
      final currentRecord = records.firstWhere(
        (r) => r.id == _currentRecordId,
        orElse: () => records.first,
      );

      await repo.updateRecord(currentRecord.copyWith(
        endTime: DateTime.now(),
        duration: _elapsedSeconds,
        completedAt: DateTime.now(),
      ));

      await repo.completeTask(widget.task.id);
    }

    setState(() {
      _isRunning = false;
    });

    if (mounted) {
      context.read<TaskProvider>().loadTasks();
      Navigator.pop(context);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 任务完成！'),
        content: Text('恭喜完成「${widget.task.title}」！'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
