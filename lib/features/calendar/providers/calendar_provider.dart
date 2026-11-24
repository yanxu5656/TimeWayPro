import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/calendar_note.dart';
import '../data/repositories/calendar_repository.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarRepository _repository;

  CalendarProvider({CalendarRepository? repository})
    : _repository = repository ?? CalendarRepository();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarNote> _notes = [];
  bool _isLoading = false;
  int _loadGeneration = 0;

  DateTime get selectedMonth => _selectedMonth;
  List<CalendarNote> get notes => _notes;
  bool get isLoading => _isLoading;

  String get monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  List<CalendarNote> notesForDay(String dateKey) =>
      _notes.where((n) => n.dateKey == dateKey).toList();

  /// 有标注的日子 → 条数，供月网格与议程列表共用
  Map<String, int> get countByDay {
    final map = <String, int>{};
    for (final note in _notes) {
      map[note.dateKey] = (map[note.dateKey] ?? 0) + 1;
    }
    return map;
  }

  void previousMonth() =>
      _setMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void nextMonth() =>
      _setMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  void goToToday() =>
      _setMonth(DateTime(DateTime.now().year, DateTime.now().month));

  void _setMonth(DateTime month) {
    _selectedMonth = month;
    loadMonth();
  }

  Future<void> loadMonth() async {
    final generation = ++_loadGeneration;
    final key = monthKey;
    _isLoading = true;
    notifyListeners();
    try {
      final notes = await _repository.getByMonth(key);
      if (generation != _loadGeneration) return;
      _notes = notes;
    } catch (e) {
      if (generation != _loadGeneration) return;
      debugPrint('Error loading calendar notes: $e');
    } finally {
      if (generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> addNote({required String dateKey, required String text}) async {
    await _repository.addNote(
      CalendarNote(
        id: '',
        dateKey: dateKey,
        text: text,
        sortOrder:
            notesForDay(dateKey).fold<int>(
              -1,
              (max, note) => note.sortOrder > max ? note.sortOrder : max,
            ) +
            1,
        createdAt: DateTime.now(),
      ),
    );
    await loadMonth();
  }

  Future<void> updateNote(CalendarNote note) async {
    await _repository.updateNote(note);
    await loadMonth();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await loadMonth();
  }
}
