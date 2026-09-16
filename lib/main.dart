import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'core/ui/ui_effects.dart';
import 'shared/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 按真实光栅化耗时自适应决定视觉效果档位（profile/release 下生效）
  UiEffects.installAutoDowngrade();

  // 初始化通知服务
  await NotificationService().initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const TimeWayProApp());
}
