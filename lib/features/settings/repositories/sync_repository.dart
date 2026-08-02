import 'dart:convert';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../shared/database/database_helper.dart';
import '../../../features/task/data/repositories/task_repository.dart';
import '../models/sync_config.dart';

class SyncRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TaskRepository _taskRepository = TaskRepository();

  Future<SyncConfig?> getSyncConfig() async {
    final configs = await _dbHelper.query('sync_config');
    if (configs.isEmpty) return null;
    return SyncConfig.fromMap(configs.first);
  }

  Future<void> saveSyncConfig(SyncConfig config) async {
    final existing = await getSyncConfig();
    if (existing != null) {
      await _dbHelper.update(
        'sync_config',
        config.copyWith(id: existing.id).toMap(),
        'id',
      );
    } else {
      await _dbHelper.insert('sync_config', config.toMap());
    }
  }

  Future<void> clearSyncConfig() async {
    await _dbHelper.deleteWhere('sync_config', (map) => true);
  }

  Future<webdav.Client> _createClient(SyncConfig config) async {
    String url = config.webdavUrl;
    if (!url.endsWith('/')) {
      url = '$url/';
    }

    final client = webdav.newClient(
      url,
      user: config.username,
      password: config.password,
      debug: false,
    );
    return client;
  }

  Future<bool> testConnection(SyncConfig config) async {
    try {
      final client = await _createClient(config);
      await client.ping();
      return true;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<void> backup() async {
    final config = await getSyncConfig();
    if (config == null) throw Exception('未配置同步信息');

    final client = await _createClient(config);

    final data = await _taskRepository.exportAllData();
    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);

    // 尝试写入根目录
    try {
      await client.write('backup.json', bytes);
    } catch (e) {
      print('Write to root failed: $e');
      // 尝试创建目录后写入
      try {
        await client.mkdir('TimeWayPro');
        await client.write('TimeWayPro/backup.json', bytes);
      } catch (e2) {
        print('Write to subfolder failed: $e2');
        throw Exception('备份失败，请检查网络连接和坚果云配置');
      }
    }

    await saveSyncConfig(config.copyWith(lastSyncTime: DateTime.now()));
  }

  Future<void> restore() async {
    final config = await getSyncConfig();
    if (config == null) throw Exception('未配置同步信息');

    final client = await _createClient(config);

    // 尝试从不同路径读取
    List<int>? bytes;

    try {
      bytes = await client.read('backup.json');
    } catch (e) {
      print('Read from root failed: $e');
    }

    if (bytes == null) {
      try {
        bytes = await client.read('TimeWayPro/backup.json');
      } catch (e) {
        print('Read from subfolder failed: $e');
      }
    }

    if (bytes == null) {
      throw Exception('未找到备份文件，请先在电脑端备份数据');
    }

    try {
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      await _taskRepository.importAllData(data);
    } catch (e) {
      print('Parse or import failed: $e');
      throw Exception('备份文件格式错误或数据损坏');
    }

    await saveSyncConfig(config.copyWith(lastSyncTime: DateTime.now()));
  }
}
