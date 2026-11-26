import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({SharedPreferences? preferences}) : this._(preferences);

  ThemeProvider._(this._preferences);

  static const String storageKey = 'selected_theme_id';

  final SharedPreferences? _preferences;
  AppThemeOption _option = AppThemeCatalog.defaultOption;
  bool _loaded = false;
  int _loadGeneration = 0;
  bool _disposed = false;

  AppThemeOption get option => _option;
  bool get loaded => _loaded;

  Future<void> loadTheme() async {
    final int generation = ++_loadGeneration;
    try {
      final SharedPreferences preferences =
          _preferences ?? await SharedPreferences.getInstance();
      if (_disposed || generation != _loadGeneration) return;
      _option = AppThemeCatalog.byId(preferences.getString(storageKey));
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      _option = AppThemeCatalog.defaultOption;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> selectTheme(String id) async {
    if (!AppThemeCatalog.options.any(
      (AppThemeOption option) => option.id == id,
    )) {
      return;
    }
    final AppThemeOption next = AppThemeCatalog.byId(id);
    if (next.id == _option.id) return;
    _loadGeneration++;
    _option = next;
    notifyListeners();

    try {
      final SharedPreferences preferences =
          _preferences ?? await SharedPreferences.getInstance();
      await preferences.setString(storageKey, next.id);
    } catch (_) {
      // 本地偏好写入失败时仍保留本次会话内的选择。
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
