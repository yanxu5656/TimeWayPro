import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/features/leisure/data/models/leisure_item.dart';
import 'package:time_way_pro/features/leisure/data/repositories/leisure_repository.dart';
import 'package:time_way_pro/shared/database/database_helper.dart';

import '../../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LeisureRepository repo;

  setUp(() async {
    installPathProviderMock();
    repo = LeisureRepository();
    await DatabaseHelper().importAll(seedData());
  });

  group('读取与排序', () {
    test('没试过的排前面，试过的沉底', () async {
      final items = await repo.getAll();

      expect(items, hasLength(3));
      expect(items.last.id, 'l3');
      expect(items.last.isDone, isTrue);
      expect(items.take(2).every((i) => !i.isDone), isTrue);
    });

    test('空表返回空列表', () async {
      await DatabaseHelper().importAll(<String, dynamic>{
        'tasks': <Map<String, dynamic>>[],
        'task_records': <Map<String, dynamic>>[],
        'plans': <Map<String, dynamic>>[],
      });
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('增删改', () {
    test('新增自动生成 id 并落库', () async {
      final id = await repo.addItem(
        LeisureItem(id: '', title: '去 livehouse', createdAt: DateTime.now()),
      );

      expect(id, isNotEmpty);
      final items = await repo.getAll();
      expect(items.any((i) => i.id == id && i.title == '去 livehouse'), isTrue);
    });

    test('toggleDone 翻转完成态', () async {
      await repo.toggleDone('l1');
      var items = await repo.getAll();
      expect(items.firstWhere((i) => i.id == 'l1').isDone, isTrue);

      await repo.toggleDone('l1');
      items = await repo.getAll();
      expect(items.firstWhere((i) => i.id == 'l1').isDone, isFalse);
    });

    test('更新备注与标题', () async {
      final items = await repo.getAll();
      final l1 = items.firstWhere((i) => i.id == 'l1');
      await repo.updateItem(l1.copyWith(title: '打两款新游戏', note: '改了备注'));

      final after = (await repo.getAll()).firstWhere((i) => i.id == 'l1');
      expect(after.title, '打两款新游戏');
      expect(after.note, '改了备注');
    });

    test('删除后不再出现', () async {
      await repo.deleteItem('l2');
      final items = await repo.getAll();
      expect(items, hasLength(2));
      expect(items.any((i) => i.id == 'l2'), isFalse);
    });
  });
}