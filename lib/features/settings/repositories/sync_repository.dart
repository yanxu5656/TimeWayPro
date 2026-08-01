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
    // 坚果云WebDAV地址格式：https://dav.jianguoyun.com/dav/
    // 用户名和密码在认证时提供
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
      // 尝试列出根目录
      await client.readDir('/');
      return true;
    } catch (e) {
      print('Connection test failed: $e');
      // 尝试备用方法
      try {
        final client = await _createClient(config);
        await client.ping();
        return true;
      } catch (e2) {
        print('Backup connection test also failed: $e2');
        return false;
      }
    }
  }

  Future<void> backup() async {
    final config = await getSyncConfig();
    if (config == null) throw Exception('未配置同步信息');

    final client = await _createClient(config);

    final data = await _taskRepository.exportAllData();
    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);

    // 直接写入文件，不创建目录（坚果云会自动创建）
    try {
      await client.write('backup.json', bytes);
    } catch (e) {
      print('Write error: $e');
      // 如果失败，尝试创建目录后再写入
      try {
        await client.mkdir('TimeWayPro');
        await client.write('TimeWayPro/backup.json', bytes);
      } catch (e2) {
        print('Write to subfolder error: $e2');
        rethrow;
      }
    }

    await saveSyncConfig(config.copyWith(lastSyncTime: DateTime.now()));
  }

  Future<void> restore() async {
    final config = await getSyncConfig();
    if (config == null) throw Exception('未配置同步信息');

    final client = await _createClient(config);

    // 尝试从不同路径读取
    try {
      final bytes = await client.read('backup.json');
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      await _taskRepository.importAllData(data);
    } catch (e) {
      print('Read from root failed: $e');
      // 尝试从子目录读取
      final bytes = await client.read('TimeWayPro/backup.json');
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      await _taskRepository.importAllData(data);
    }

    await saveSyncConfig(config.copyWith(lastSyncTime: DateTime.now()));
  }
}
