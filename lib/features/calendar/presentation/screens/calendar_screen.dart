import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/ui/paper.dart';
import '../../data/models/calendar_note.dart';
import '../../providers/calendar_provider.dart';

/// 月历：整月网格 + 每日简单标注。
///
/// 标注是自由文本（「9-11 高数期末考试」「抢回家的车票」），不做
/// 结构化时间字段——月历的职责是「哪天有什么」，不是排程器。
/// 格子里预览第一条 + 余量计数，点任意一天开 sheet 增 / 改 / 删。
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const List<String> _weekdays = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<CalendarProvider>().loadMonth();
    });
  }

  static String _keyOf(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static String _weekdayCn(DateTime date) =>
      '周${_weekdays[date.weekday - 1]}';

  @override
  Widget build(BuildContext context) {
    return PaperScaffold(
      body: Consumer<CalendarProvider>(
        builder: (context, provider, child) {
          final month = provider.selectedMonth;
          final now = DateTime.now();
          final isCurrentMonth =
              month.year == now.year && month.month == now.month;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH,
                  AppSpacing.xs,
                  AppSpacing.screenH,
                  AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    Masthead(
                      kicker: 'MONTH BOARD',
                      title: '月历',
                      meta: Text.rich(
                        TextSpan(
                          style: AppText.caption.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.4,
                          ),
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${month.year} 年 ${month.month} 月 · 标注 ',
                            ),
                            TextSpan(
                              text: '${provider.notes.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const TextSpan(text: ' 条'),
                          ],
                        ),
                      ),
                      ghost: '${month.month}'.padLeft(2, '0'),
                    ),
                    Row(
                      children: [
                        PaperIconButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: provider.previousMonth,
                          color: AppColors.textSecondary,
                          size: PaperIconButton.sizeChrome,
                          iconSize: 22,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${month.year} 年 ${month.month} 月',
                                style: AppText.titleSerif.copyWith(
                                  color: isCurrentMonth
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (!isCurrentMonth) ...[
                                const SizedBox(width: AppSpacing.xs),
                                PaperTextButton(
                                  compact: true,
                                  onPressed: provider.goToToday,
                                  label: '回今天',
                                ),
                              ],
                            ],
                          ),
                        ),
                        PaperIconButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: provider.nextMonth,
                          color: AppColors.textSecondary,
                          size: PaperIconButton.sizeChrome,
                          iconSize: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH,
                          0,
                          AppSpacing.screenH,
                          AppSpacing.navInset,
                        ),
                        children: [
                          PaperCard(
                            tone: PaperTone.row,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    for (final wd in _weekdays)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: AppSpacing.xs,
                                          ),
                                          child: Text(
                                            wd,
                                            textAlign: TextAlign.center,
                                            style: AppText.labelSm.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                ..._buildWeekRows(provider),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SectionHeader(
                            index: 1,
                            title: '本月标注',
                            trailing: '${provider.notes.length} 条',
                          ),
                          ..._buildAgenda(provider),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildWeekRows(CalendarProvider provider) {
    final month = provider.selectedMonth;
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1; // 周一起
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rowCount = ((leading + daysInMonth) / 7).ceil();
    final todayKey = _keyOf(DateTime.now());

    final rows = <Widget>[];
    for (var r = 0; r < rowCount; r++) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++) {
        final offset = r * 7 + c - leading;
        final date = DateTime(month.year, month.month, 1 + offset);
        final inMonth = offset >= 0 && offset < daysInMonth;
        final key = _keyOf(date);
        cells.add(
          Expanded(
            child: _DayCell(
              key: Key('cal_day_$key'),
              date: date,
              inMonth: inMonth,
              isToday: key == todayKey,
              notes: inMonth ? provider.notesForDay(key) : const [],
              onTap: inMonth ? () => _openDaySheet(key) : null,
            ),
          ),
        );
      }
      rows.add(Row(children: cells));
    }
    return rows;
  }

  List<Widget> _buildAgenda(CalendarProvider provider) {
    if (provider.notes.isEmpty) {
      return [
        PaperCard(
          tone: PaperTone.flat,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 40,
                color: AppColors.textHint,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '这个月还没有标注',
                style: AppText.caption.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '点日历上的任意一天，记一条',
                style: AppText.caption.copyWith(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ];
    }

    // notes 已按 dateKey 排序，连续同天的聚成一行
    final widgets = <Widget>[];
    var i = 0;
    while (i < provider.notes.length) {
      final dayNotes = <CalendarNote>[provider.notes[i]];
      var j = i + 1;
      while (j < provider.notes.length &&
          provider.notes[j].dateKey == provider.notes[i].dateKey) {
        dayNotes.add(provider.notes[j]);
        j++;
      }
      final date = DateTime.parse(dayNotes.first.dateKey);
      widgets.add(
        PaperCard(
          tone: PaperTone.row,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPad,
            vertical: 10,
          ),
          margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
          onTap: () => _openDaySheet(dayNotes.first.dateKey),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${date.day}',
                  style: AppText.serifNum.copyWith(
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayNotes.first.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.month} 月 ${date.day} 日 · ${_weekdayCn(date)}'
                      '${dayNotes.length > 1 ? ' · 等 ${dayNotes.length} 条' : ''}',
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      );
      i = j;
    }
    return widgets;
  }

  void _openDaySheet(String dateKey) {
    showPaperSheet(
      context,
      builder: (context) => _DaySheet(dateKey: dateKey),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.notes,
    this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final List<CalendarNote> notes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            color: isToday ? AppColors.primarySubtle : Colors.transparent,
            borderRadius: AppRadius.brMd,
            border: isToday
                ? Border.all(color: AppColors.primary, width: 1.2)
                : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isToday)
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${date.day}',
                        style: AppText.serifNum.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${date.day}',
                      style: AppText.serifNum.copyWith(
                        fontSize: 13,
                        color: inMonth
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  // 余量计数贴着日期：预览留给两行正文，不被计数挤掉。
                  // Flexible 兜底极窄格：字形宽度随字体变化，不能假设放得下
                  if (notes.length > 1)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          '+${notes.length - 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              if (notes.isNotEmpty)
                Text(
                  notes.first.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.dateKey});

  final String dateKey;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  final _controller = TextEditingController();
  String? _editingId;

  bool get _valid => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit(CalendarNote note) {
    setState(() {
      _editingId = note.id;
      _controller.text = note.text;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _controller.clear();
    });
  }

  void _save() {
    final provider = context.read<CalendarProvider>();
    final text = _controller.text.trim();
    if (_editingId != null) {
      final notes = provider.notesForDay(widget.dateKey);
      final note = notes.where((n) => n.id == _editingId).firstOrNull;
      if (note != null) provider.updateNote(note.copyWith(text: text));
    } else {
      provider.addNote(dateKey: widget.dateKey, text: text);
      AppHaptics.success();
    }
    setState(() {
      _editingId = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.dateKey);
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${date.month} 月 ${date.day} 日 · 周${weekdays[date.weekday - 1]}',
          style: AppText.titleSerif.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        Consumer<CalendarProvider>(
          builder: (context, provider, child) {
            final notes = provider.notesForDay(widget.dateKey);
            if (notes.isEmpty) {
              return Text(
                '这一天还没有标注',
                style: AppText.caption.copyWith(color: AppColors.textHint),
              );
            }
            return Column(
              children: [
                for (final note in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _startEdit(note),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _editingId == note.id
                                    ? AppColors.primarySubtle
                                    : AppColors.surfaceVariant,
                                borderRadius: AppRadius.brMd,
                              ),
                              child: Text(
                                note.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        PaperIconButton(
                          icon: Icons.delete_outline_rounded,
                          size: 32,
                          iconSize: 18,
                          color: AppColors.textSecondary,
                          tooltip: '删除标注',
                          onTap: () {
                            AppHaptics.dismiss();
                            provider.deleteNote(note.id);
                            if (_editingId == note.id) _cancelEdit();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 2,
          minLines: 1,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '如：9-11 高数期末考试 / 抢回家的车票',
          ),
        ),
        if (_editingId != null) ...[
          const SizedBox(height: AppSpacing.xs),
          PaperTextButton(
            compact: true,
            onPressed: _cancelEdit,
            label: '取消编辑',
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: PaperButton(
            onPressed: _valid ? _save : null,
            label: _editingId != null ? '保存修改' : '添加标注',
          ),
        ),
      ],
    );
  }
}