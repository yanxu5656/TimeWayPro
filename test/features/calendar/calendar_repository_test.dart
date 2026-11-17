import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/features/calendar/data/models/calendar_note.dart';
import 'package:time_way_pro/features/calendar/data/repositories/calendar_repository.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CalendarRepository repo;
  final now = DateTime.now();
  final monthKey =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';
  final today =
      '$monthKey-${now.day.toString().padLeft(2, '0')}';

  setUp(() async {
    installPathProviderMock();
    repo = CalendarRepository();
    await DatabaseHelper().importAll(seedData());
  });

  group('按月 / 按日读取', () {
    test('getByMonth 前缀匹配整月，跨月不串', () async {
      final notes = await repo.getByMonth(monthKey);
      expect(notes, hasLength(3));
      expect(notes.every((n) => n.dateKey.startsWith(monthKey)), isTrue);

      expect(await repo.getByMonth('1999-01'), isEmpty);
    });

    test('getByDate 只取当天且按 sortOrder 排', () async {
      final notes = await repo.getByDate(today);
      expect(notes, hasLength(2));
      expect(notes.first.text, '9-11 高数期末考试');
      expect(notes.last.text, '抢回家的车票');
    });

    test('同一天多条按日期聚组排序', () async {
      final notes = await repo.getByMonth(monthKey);
      final keys = notes.map((n) => n.dateKey).toList();
      expect(keys, orderedEquals(<String>[...keys]..sort()));
    });
  });

  group('增删改', () {
    test('新增自动生成 id', () async {
      final id = await repo.addNote(
        CalendarNote(id: '', dateKey: today, text: '下午取快递', createdAt: now),
      );
      expect(id, isNotEmpty);
      expect(await repo.getByDate(today), hasLength(3));
    });

    test('更新文本', () async {
      final notes = await repo.getByDate(today);
      await repo.updateNote(notes.first.copyWith(text: '9-11 高数期末考试（教三）'));
      final after = await repo.getByDate(today);
      expect(after.first.text, '9-11 高数期末考试（教三）');
    });

    test('删除单条不影响同日其它', () async {
      await repo.deleteNote('c1');
      final notes = await repo.getByDate(today);
      expect(notes, hasLength(1));
      expect(notes.first.id, 'c2');
    });
  });
}