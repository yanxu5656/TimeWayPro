import 'package:flutter/material.dart';
import '../../task/providers/task_provider.dart';
import '../models/sync_config.dart';
import '../repositories/sync_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  final SyncRepository _syncRepository;
  int _loadGeneration = 0;
  bool _disposed = false;

  SyncConfig? _syncConfig;
  bool _isSyncing = false;
  String? _syncError;

  SyncConfig? get syncConfig => _syncConfig;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  bool get isConfigured => _syncConfig != null;

  bool _beginSync() {
    if (_disposed || _isSyncing) return false;
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    return true;
  }

  void _endSync({String? error}) {
    if (_disposed) return;
    _isSyncing = false;
    _syncError = error;
    notifyListeners();
  }

  Future<void> loadSyncConfig() async {
    final int generation = ++_loadGeneration;
    try {
      final SyncConfig? config = await _syncRepository.getSyncConfig();
      if (_disposed || generation != _loadGeneration) return;
      _syncConfig = config;
      notifyListeners();
    } catch (e) {
      if (!_disposed && generation == _loadGeneration) {
        debugPrint('Error loading sync config: $e');
      }
    }
  }

  Future<bool> saveSyncConfig(SyncConfig config) async {
    if (!_beginSync()) return false;
    try {
      final success = await _syncRepository.testConnection(config);
      if (success) await _syncRepository.saveSyncConfig(config);
      if (!_disposed) _syncConfig = success ? config : _syncConfig;
      _endSync(error: success ? null : '连接失败，请检查配置');
      return success;
    } catch (e) {
      _endSync(error: '连接失败: $e');
      return false;
    }
  }

  Future<void> clearSyncConfig() async {
    if (_isSyncing) return;
    await _syncRepository.clearSyncConfig();
    if (_disposed) return;
    _syncConfig = null;
    notifyListeners();
  }

  Future<bool> backup() async {
    if (_syncConfig == null || !_beginSync()) return false;
    try {
      await _syncRepository.backup();
      _endSync();
      return true;
    } catch (e) {
      _endSync(error: '备份失败: $e');
      return false;
    }
  }

  Future<bool> restore({
    Future<List<TimerState>> Function()? beforeImport,
  }) async {
    if (_syncConfig == null || !_beginSync()) return false;
    try {
      await _syncRepository.restore(beforeImport: beforeImport);
      _endSync();
      return true;
    } catch (e) {
      _endSync(error: '恢复失败: $e');
      return false;
    }
  }

  void clearError() {
    _syncError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
