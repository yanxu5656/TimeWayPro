import 'package:flutter/services.dart';

/// 触觉词汇表 —— 陶土暖笺。
///
/// 全应用的震动反馈统一从这里取，不再各处散写 `HapticFeedback.*`：
/// 不同语义的动作应该有不同「重量」，一律 selectionClick 会让完成、
/// 确认这类重要时刻和普通轻点没有区别。
///
/// | 语义 | 方法 | 平台反馈 |
/// |---|---|---|
/// | 轻点 / 切换（按钮按下、分段、chip） | [tap] / [select] | selectionClick |
/// | 完成（勾选任务 / 目标） | [success] | mediumImpact |
/// | 破坏性确认（删除、断开、覆盖恢复） | [confirm] | heavyImpact |
/// | 关闭闹铃 | [dismiss] | mediumImpact |
class AppHaptics {
  AppHaptics._();

  /// 普通轻点：按钮按下、图标钮。
  static void tap() => HapticFeedback.selectionClick();

  /// 选项切换：分段控件、chip、开关。
  static void select() => HapticFeedback.selectionClick();

  /// 完成时刻：勾选任务 / 每周目标。比轻点重一档，
  /// 让「完成」在手感上也是全应用最有回报感的一瞬。
  static void success() => HapticFeedback.mediumImpact();

  /// 破坏性操作的最终确认：删除、断开连接、覆盖恢复。
  static void confirm() => HapticFeedback.heavyImpact();

  /// 关闭闹铃：与完成同档，但语义独立，便于日后分别调整。
  static void dismiss() => HapticFeedback.mediumImpact();
}