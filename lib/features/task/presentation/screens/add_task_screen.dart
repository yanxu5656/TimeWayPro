import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/ui/paper.dart';
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
  bool _saving = false;

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
    return PaperScaffold(
      // 二级页：平顶栏 + 衬线标题（纸面体系里没有极光可透）
      title: isEditing ? '编辑任务' : '新建任务',
      actions: [
        if (isEditing)
          PaperIconButton(
            icon: Icons.delete_outline,
            color: context.colors.error,
            size: PaperIconButton.sizeChrome,
            onTap: _saving ? null : _deleteTask,
            tooltip: '删除任务',
          ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // 任务标题
            _buildSection(
              title: '任务名称',
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: '输入任务名称'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
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
                decoration: const InputDecoration(hintText: '输入任务描述'),
                maxLines: 3,
              ),
            ),

            // 计时模式
            _buildSection(
              title: '计时模式',
              child: Row(
                children: [
                  Expanded(
                    child: PaperChip(
                      label: '正计时',
                      icon: Icons.timer_outlined,
                      selected: _timerType == TimerType.countUp,
                      onTap: () =>
                          setState(() => _timerType = TimerType.countUp),
                      expanded: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PaperChip(
                      label: '倒计时',
                      icon: Icons.hourglass_bottom,
                      selected: _timerType == TimerType.countDown,
                      onTap: () =>
                          setState(() => _timerType = TimerType.countDown),
                      expanded: false,
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

            if (_timerType == TimerType.countDown &&
                _durationMinutes * 60 + _durationSeconds == 0)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '倒计时时长至少为 1 秒',
                  style: TextStyle(fontSize: 12, color: context.colors.error),
                ),
              ),

            // 重复类型
            _buildSection(
              title: '重复类型',
              child: RadioGroup<RepeatType>(
                groupValue: _repeatType,
                onChanged: (value) {
                  if (value != null) setState(() => _repeatType = value);
                },
                child: Column(
                  children: [
                    _buildRadioTile(
                      title: '不重复（一次性任务）',
                      value: RepeatType.none,
                    ),
                    _buildRadioTile(title: '每天', value: RepeatType.daily),
                    _buildRadioTile(title: '每周', value: RepeatType.weekly),
                    _buildRadioTile(title: '每月', value: RepeatType.monthly),
                  ],
                ),
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
                child: PaperCard(
                  tone: PaperTone.flat,
                  radius: AppRadius.md,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        color: context.colors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate != null
                            ? DateFormat('yyyy年MM月dd日').format(_dueDate!)
                            : '点击设置截止日期',
                        style: TextStyle(
                          color: _dueDate != null
                              ? context.colors.textPrimary
                              : context.colors.textHint,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        PaperIconButton(
                          icon: Icons.close,
                          iconSize: 18,
                          size: 32,
                          color: context.colors.textSecondary,
                          onTap: () => setState(() => _dueDate = null),
                          tooltip: '清除截止日期',
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
                  initialValue: _reminderMinutes,
                  decoration: const InputDecoration(
                    hintText: '选择提前提醒时间',
                    helperText: '提醒时间为截止日当天 09:00',
                    helperMaxLines: 2,
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
            PaperButton(
              onPressed: _saving ? null : _saveTask,
              loading: _saving,
              loadingLabel: '正在保存',
              label: isEditing ? '保存修改' : '创建任务',
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRadioTile({required String title, required RepeatType value}) {
    return RadioListTile<RepeatType>(
      title: Text(title),
      value: value,
      activeColor: context.colors.primary,
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
    return PaperCard(
      tone: PaperTone.flat,
      radius: AppRadius.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PaperIconButton(
            icon: Icons.remove_circle_outline,
            onTap: value > min ? () => onChanged(value - 1) : null,
            enabled: value > min,
            color: context.colors.primary,
            size: 40,
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
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          PaperIconButton(
            icon: Icons.add_circle_outline,
            onTap: value < max ? () => onChanged(value + 1) : null,
            enabled: value < max,
            color: context.colors.primary,
            size: 40,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate != null && !_dueDate!.isBefore(today)
          ? _dueDate!
          : today,
      firstDate: today,
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveTask() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final int duration = _durationMinutes * 60 + _durationSeconds;
    if (_timerType == TimerType.countDown && duration == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('倒计时时长至少为 1 秒')));
      return;
    }
    setState(() => _saving = true);

    final now = DateTime.now();
    final task = Task(
      id: widget.task?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      timerType: _timerType,
      duration: _timerType == TimerType.countDown ? duration : null,
      repeatType: _repeatType,
      repeatCount: _repeatType != RepeatType.none ? _repeatCount : 1,
      dueDate: _dueDate,
      reminderMinutes: _reminderMinutes,
      isCompleted: widget.task?.isCompleted ?? false,
      completedCount: widget.task?.completedCount ?? 0,
      lastCompletedDate: widget.task?.lastCompletedDate,
      createdAt: widget.task?.createdAt ?? now,
      updatedAt: now,
    );

    final provider = context.read<TaskProvider>();
    try {
      if (isEditing) {
        await provider.updateTask(task);
      } else {
        await provider.addTask(task);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTask() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${widget.task!.title}」吗？'),
        actions: [
          PaperTextButton(
            onPressed: () => Navigator.pop(context, false),
            label: '取消',
          ),
          PaperTextButton(
            onPressed: () => Navigator.pop(context, true),
            color: context.colors.error,
            label: '删除',
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    AppHaptics.confirm();
    try {
      await context.read<TaskProvider>().deleteTask(widget.task!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }
}
