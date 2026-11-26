import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_way_pro/features/settings/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  test('无偏好时默认使用陶土暖笺', () async {
    final ThemeProvider provider = ThemeProvider(preferences: preferences);
    await provider.loadTheme();
    expect(provider.option.id, 'warm_paper');
    expect(provider.loaded, isTrue);
    provider.dispose();
  });

  test('启动时恢复上次选择', () async {
    await preferences.setString(ThemeProvider.storageKey, 'cute_mint');
    final ThemeProvider provider = ThemeProvider(preferences: preferences);
    await provider.loadTheme();
    expect(provider.option.id, 'cute_mint');
    provider.dispose();
  });

  test('未知或损坏的偏好回退到默认主题', () async {
    await preferences.setInt(ThemeProvider.storageKey, 42);
    final ThemeProvider provider = ThemeProvider(preferences: preferences);
    await provider.loadTheme();
    expect(provider.option.id, 'warm_paper');
    expect(provider.loaded, isTrue);
    provider.dispose();
  });

  test('切换立即通知并持久化，新实例可恢复', () async {
    final ThemeProvider provider = ThemeProvider(preferences: preferences);
    int notifications = 0;
    provider.addListener(() => notifications++);

    await provider.selectTheme('tech_neon');
    expect(provider.option.id, 'tech_neon');
    expect(notifications, 1);
    expect(preferences.getString(ThemeProvider.storageKey), 'tech_neon');

    final ThemeProvider restored = ThemeProvider(preferences: preferences);
    await restored.loadTheme();
    expect(restored.option.id, 'tech_neon');
    provider.dispose();
    restored.dispose();
  });

  test('重复选择不重复通知，未知 ID 不覆盖已存主题', () async {
    final ThemeProvider provider = ThemeProvider(preferences: preferences);
    int notifications = 0;
    provider.addListener(() => notifications++);

    await provider.selectTheme('minimal_forest');
    await provider.selectTheme('minimal_forest');
    await provider.selectTheme('does_not_exist');

    expect(provider.option.id, 'minimal_forest');
    expect(notifications, 1);
    expect(preferences.getString(ThemeProvider.storageKey), 'minimal_forest');
    provider.dispose();
  });

  test('加载期间的新选择不会被旧读取结果覆盖', () async {
    await preferences.setString(ThemeProvider.storageKey, 'warm_paper');
    final ThemeProvider provider = ThemeProvider();
    final Future<void> loading = provider.loadTheme();
    await provider.selectTheme('tech_matrix');
    await loading;
    expect(provider.option.id, 'tech_matrix');
    expect(provider.loaded, isFalse);
    provider.dispose();
  });
}
