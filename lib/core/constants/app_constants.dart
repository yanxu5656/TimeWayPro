class AppConstants {
  static const String appName = 'TimeWayPro';
  static const String appNameCn = '时途';

  /// 设置页「关于」显示的版本号。
  ///
  /// 必须与 pubspec.yaml 的 `version:` 语义段一致——由
  /// `test/core/constants/app_version_test.dart` 守护。这两处曾经漂移过
  /// （pubspec 到 1.6.0 时这里还停在 1.3.3），改版本号要同时改两处。
  static const String appVersion = '1.13.0';

  // WebDAV默认配置
  static const String defaultWebDavUrl = 'https://dav.jianguoyun.com/dav/';

  // 数据库
  static const String dbName = 'time_way_pro.db';
  static const int dbVersion = 1;

  // 通知
  static const String notificationChannelId = 'time_way_pro_channel';
  static const String notificationChannelName = '时途提醒';

  // 同步
  static const String syncFolderName = 'TimeWayPro';
  static const String syncFileName = 'backup.json';
}
