import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_way_pro/core/constants/app_constants.dart';

/// 版本号只有一处真相：pubspec.yaml。
///
/// 设置页「关于」读的是 [AppConstants.appVersion]，两者曾经漂移到
/// pubspec 1.6.0 / 显示 1.3.3——用户看到的版本号是错的。这条守护让
/// 下次只改一处时直接红。
void main() {
  test('AppConstants.appVersion 与 pubspec.yaml 的 version 语义段一致', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml 里找不到 version: 行');
    final String semantic = match!.group(1)!.split('+').first;

    expect(
      AppConstants.appVersion,
      semantic,
      reason: '设置页显示的版本号与 pubspec 漂移了——升版本要同时改这两处',
    );
  });
}
