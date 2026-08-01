class SyncConfig {
  final int? id;
  final String webdavUrl;
  final String username;
  final String password;
  final DateTime? lastSyncTime;

  SyncConfig({
    this.id,
    required this.webdavUrl,
    required this.username,
    required this.password,
    this.lastSyncTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'webdav_url': webdavUrl,
      'username': username,
      'password': password,
      'last_sync_time': lastSyncTime?.toIso8601String(),
    };
  }

  factory SyncConfig.fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      id: map['id'],
      webdavUrl: map['webdav_url'],
      username: map['username'],
      password: map['password'],
      lastSyncTime: map['last_sync_time'] != null
          ? DateTime.parse(map['last_sync_time'])
          : null,
    );
  }

  SyncConfig copyWith({
    int? id,
    String? webdavUrl,
    String? username,
    String? password,
    DateTime? lastSyncTime,
  }) {
    return SyncConfig(
      id: id ?? this.id,
      webdavUrl: webdavUrl ?? this.webdavUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}
