import 'package:flutter/material.dart';
import '../models/sync_config.dart';
import '../repositories/sync_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SyncRepository _syncRepository = SyncRepository();

  SyncConfig? _syncConfig;
  bool _isSyncing = false;
  String? _syncError;
  bool _autoSync = true;

  SyncConfig? get syncConfig => _syncConfig;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  bool get isConfigured => _syncConfig != null;
  bool get autoSync => _autoSync;

  Future<void> loadSyncConfig() async {
    _syncConfig = await _syncRepository.getSyncConfig();
    notifyListeners();
  }

  Future<bool> saveSyncConfig(SyncConfig config) async {
    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final success = await _syncRepository.testConnection(config);
      if (success) {
        await _syncRepository.saveSyncConfig(config);
        _syncConfig = config;
        _isSyncing = false;
        notifyListeners();
        return true;
      } else {
        _syncError = '连接失败，请检查配置';
        _isSyncing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _syncError = '连接失败: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> clearSyncConfig() async {
    await _syncRepository.clearSyncConfig();
    _syncConfig = null;
    notifyListeners();
  }

  Future<bool> backup() async {
    if (_syncConfig == null) return false;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _syncRepository.backup();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _syncError = '备份失败: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restore() async {
    if (_syncConfig == null) return false;

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      await _syncRepository.restore();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _syncError = '恢复失败: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  void setAutoSync(bool value) {
    _autoSync = value;
    notifyListeners();
  }

  void clearError() {
    _syncError = null;
    notifyListeners();
  }
}
