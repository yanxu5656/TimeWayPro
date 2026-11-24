import 'package:flutter/material.dart';

Future<bool> runPaperAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await action();
    return true;
  } catch (e) {
    debugPrint('Paper action failed: $e');
    if (messenger?.mounted ?? false) {
      messenger!.showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
    return false;
  }
}
