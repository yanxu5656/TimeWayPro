import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/row_parse.dart';
import '../../../../shared/database/database_helper.dart';
import '../models/calendar_note.dart';

class CalendarRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  /// [monthKey] 形如 `2026-11`，前缀匹配整月
  Future<List<CalendarNote>> getByMonth(String monthKey) async {
    try {
      final maps = await _dbHelper.queryWhere(
        'calendar_notes',
        (map) => (map['date_key'] as String? ?? '').startsWith(monthKey),
      );
      final notes = parseRows(maps, CalendarNote.fromMap);
      notes.sort((a, b) {
        if (a.dateKey != b.dateKey) return a.dateKey.compareTo(b.dateKey);
        return a.sortOrder.compareTo(b.sortOrder);
      });
      return notes;
    } catch (e) {
      debugPrint('Error getting calendar notes: $e');
      return [];
    }
  }

  Future<List<CalendarNote>> getByDate(String dateKey) async {
    final maps = await _dbHelper.queryWhere(
      'calendar_notes',
      (map) => map['date_key'] == dateKey,
    );
    final notes = parseRows(maps, CalendarNote.fromMap);
    notes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return notes;
  }

  Future<String> addNote(CalendarNote note) async {
    final id = note.id.isEmpty ? _uuid.v4() : note.id;
    await _dbHelper.insert('calendar_notes', note.copyWith(id: id).toMap());
    return id;
  }

  Future<void> updateNote(CalendarNote note) async {
    await _dbHelper.update('calendar_notes', note.toMap(), 'id');
  }

  Future<void> deleteNote(String id) async {
    await _dbHelper.delete('calendar_notes', 'id', id);
  }
}