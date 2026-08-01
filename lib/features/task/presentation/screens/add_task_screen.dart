import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/task.dart';
import '../../providers/task_provider.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  TimerType _timerType = TimerType.countUp;
  RepeatType _repeatType = RepeatType.none;
  int _repeatCount = 1;
  int _durationMinutes = 25;
  int _durationSeconds = 0;
  DateTime? _dueDate;
  int? _reminderMinutes;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final task = widget.task!;
      _titleController.text = task.title;
      _descController.text = task.description ?? '';
      _timerType = task.timerType;
      _repeatType = task.repeatType;
      _repeatCount = task.repeatCount;
      if (task.duration != null) {
        _durationMinutes = task.duration! ~/ 60;
        _durationSeconds = task.duration! % 60;
      }
      _dueDate = task.dueDate;
      _reminderMinutes = task.reminderMinutes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? '编辑任务' : '新建任务'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _deleteTask,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 任务标题
            _buildSection(
              title: '任务名称',
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: '输入任务名称',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入任务名称';
                  }
                  return null;
                },
              ),
            ),

            // 任务描述
            _buildSection(
              title: '任务描述（可选）',
              child: TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  hintText: '输入任务描述',
                ),
                maxLines: 3,
              ),
            ),

            // 计时模式
            _buildSection(
              title: '计时模式',
              child: Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: '正计时',
                      icon: Icons.timer_outlined,
                      selected: _timerType == TimerType.countUp,
                      onSelected: (v) {
                        if (v) setState(() => _timerType = TimerType.countUp);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceChip(
                      label: '倒计时',
                      icon: Icons.hourglass_bottom,
                      selected: _timerType == TimerType.countDown,
                      onSelected: (v) {
                        if (v) setState(() => _timerType = TimerType.countDown);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 倒计时时长
            if (_timerType == TimerType.countDown)
              _buildSection(
                title: '时长设置',
                child: Row(
                  children: [
                    Expanded(
                      child: _buildNumberPicker(
                        label: '分钟',
                        value: _durationMinutes,
                        min: 0,
                        max: 180,
                        onChanged: (v) => setState(() => _durationMinutes = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberPicker(
                        label: '秒',
                        value: _durationSeconds,
                        min: 0,
                        max: 59,
                        onChanged: (v) => setState(() => _durationSeconds = v),
                      ),
                    ),
                  ],
                ),
              ),

            // 重复类型
            _buildSection(
              title: '重复类型',
              child: Column(
                children: [
                  _buildRadioTile(
                    title: '不重复（一次性任务）',
                    value: RepeatType.none,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                  _buildRadioTile(
                    title: '每天',
                    value: RepeatType.daily,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                  _buildRadioTile(
                    title: '每周',
                    value: RepeatType.weekly,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                  _buildRadioTile(
                    title: '每月',
                    value: RepeatType.monthly,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                ],
              ),
            ),

            // 每日重复次数（可重复任务）
            if (_repeatType != RepeatType.none)
              _buildSection(
                title: '每日重复次数',
                child: _buildNumberPicker(
                  label: '次',
                  value: _repeatCount,
                  min: 1,
                  max: 99,
                  onChanged: (v) => setState(() => _repeatCount = v),
                ),
              ),

            // 截止日期
            _buildSection(
              title: '截止日期（可选）',
              child: GestureDetector(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate != null
                            ? DateFormat('yyyy年MM月dd日').format(_dueDate!)
                            : '点击设置截止日期',
                        style: TextStyle(
                          color: _dueDate != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: const Icon(Icons.close, size: 18, color: AppColors.textHint),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 提醒设置
            if (_dueDate != null)
              _buildSection(
                title: '提前提醒',
                child: DropdownButtonFormField<int>(
                  value: _reminderMinutes,
                  decoration: const InputDecoration(
                    hintText: '选择提前提醒时间',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('不提醒')),
                    DropdownMenuItem(value: 5, child: Text('提前5分钟')),
                    DropdownMenuItem(value: 15, child: Text('提前15分钟')),
                    DropdownMenuItem(value: 30, child: Text('提前30分钟')),
                    DropdownMenuItem(value: 60, child: Text('提前1小时')),
                    DropdownMenuItem(value: 1440, child: Text('提前1天')),
                  ],
                  onChanged: (v) => setState(() => _reminderMinutes = v),
                ),
              ),

            const SizedBox(height: 32),

            // 保存按钮
            ElevatedButton(
              onPressed: _saveTask,
              child: Text(isEditing ? '保存修改' : '创建任务'),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required RepeatType value,
    required RepeatType groupValue,
    required ValueChanged<RepeatType?> onChanged,
  }) {
    return RadioListTile<RepeatType>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildNumberPicker({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            color: AppColors.primary,
          ),
          Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final task = Task(
      id: widget.task?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      timerType: _timerType,
      duration: _timerType == TimerType.countDown
          ? _durationMinutes * 60 + _durationSeconds
          : null,
      repeatType: _repeatType,
      repeatCount: _repeatType != RepeatType.none ? _repeatCount : 1,
      dueDate: _dueDate,
      reminderMinutes: _reminderMinutes,
      isCompleted: widget.task?.isCompleted ?? false,
      completedCount: widget.task?.completedCount ?? 0,
      createdAt: widget.task?.createdAt ?? now,
      updatedAt: now,
    );

    final provider = context.read<TaskProvider>();
    if (isEditing) {
      provider.updateTask(task);
    } else {
      provider.addTask(task);
    }

    Navigator.pop(context);
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${widget.task!.title}」吗？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<TaskProvider>().deleteTask(widget.task!.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
