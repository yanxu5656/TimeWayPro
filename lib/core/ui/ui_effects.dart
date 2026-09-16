import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 视觉效果的运行时能力分级。
///
/// 玻璃拟态依赖两类有真实开销的能力：极光的持续重绘、`BackdropFilter` 的
/// GPU 高斯模糊。低端机（本项目 minSdk 24）上两者都可能掉帧，所以按设备
/// 实际表现逐级降级。
enum UiEffectTier {
  /// 全量：极光动画 + 真模糊 + 列表错峰入场 + 数字滚动
  full,

  /// 降级：极光静止为静态帧，其余保留
  reduced,

  /// 最低：极光静止 + 不用真模糊 + 无错峰入场 + 无数字滚动
  minimal,
}

/// 全局视觉能力开关。
///
/// 组件通过这里的 getter 决定是否启用某项能力，而不是各自判断设备型号——
/// 本项目不引入 `device_info_plus`，改为按真实帧数据自适应。
class UiEffects {
  UiEffects._();

  static final ValueNotifier<UiEffectTier> tier =
      ValueNotifier<UiEffectTier>(UiEffectTier.full);

  // ── 组件读取的能力开关 ──

  /// 极光背景是否播放漂移动画（否则画一帧静态极光）
  static bool get auroraAnimated => tier.value == UiEffectTier.full;

  /// 是否使用真 `BackdropFilter`（否则退化为高不透明度填充 + 高光描边）
  static bool get trueBlur => tier.value != UiEffectTier.minimal;

  /// 列表是否错峰入场
  static bool get stagger => tier.value == UiEffectTier.full;

  /// 统计数字是否滚动
  static bool get countUp => tier.value != UiEffectTier.minimal;

  // ─ 自适应降级 ──

  /// 跳过启动阶段的帧（冷启动、字体加载、首屏布局都不代表稳态性能）
  static const Duration _warmup = Duration(seconds: 2);

  /// 采样窗口帧数
  static const int _windowFrames = 60;

  /// p90 光栅化耗时超过此值 → [UiEffectTier.reduced]
  static const double _reducedThresholdMs = 20.0;

  /// p90 光栅化耗时超过此值 → [UiEffectTier.minimal]
  static const double _minimalThresholdMs = 28.0;

  static bool _samplingInstalled = false;
  static bool _settled = false;
  static int? _firstFrameUs;
  static final List<double> _samples = <double>[];

  /// 安装运行时光栅化耗时采样。
  ///
  /// 只在 profile / release 下生效：debug 模式自身的开销会让任何设备都
  /// 越过阈值，采样结果没有意义。
  static void installAutoDowngrade() {
    if (_samplingInstalled) return;
    _samplingInstalled = true;
    if (kDebugMode) return;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// 系统开启"减弱动效"时至少降到 [UiEffectTier.reduced]。
  ///
  /// 需要在 `MediaQuery` 可用的位置调用（如 `MaterialApp.builder`）。
  /// 重复调用安全。
  static void respectPlatformPreferences(BuildContext context) {
    final bool disabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!disabled) return;
    if (tier.value == UiEffectTier.full) {
      tier.value = UiEffectTier.reduced;
    }
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (_settled) return;

    for (final FrameTiming timing in timings) {
      final int ts = timing.timestampInMicroseconds(ui.FramePhase.vsyncStart);
      _firstFrameUs ??= ts;

      // 预热窗口内不计入
      if (ts - _firstFrameUs! < _warmup.inMicroseconds) continue;

      _samples.add(timing.rasterDuration.inMicroseconds / 1000.0);

      if (_samples.length >= _windowFrames) {
        _settle();
        return;
      }
    }
  }

  static void _settle() {
    _settled = true;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);

    final List<double> sorted = List<double>.of(_samples)..sort();
    _samples.clear();
    if (sorted.isEmpty) return;

    final double p90 = sorted[((sorted.length - 1) * 0.9).floor()];

    // 只降不升：一次评估得出结果后不再回弹，避免档位抖动。
    if (p90 > _minimalThresholdMs) {
      tier.value = UiEffectTier.minimal;
      debugPrint('[UiEffects] 光栅化 p90 = ${p90.toStringAsFixed(1)}ms → minimal');
    } else if (p90 > _reducedThresholdMs) {
      tier.value = UiEffectTier.reduced;
      debugPrint('[UiEffects] 光栅化 p90 = ${p90.toStringAsFixed(1)}ms → reduced');
    } else {
      debugPrint('[UiEffects] 光栅化 p90 = ${p90.toStringAsFixed(1)}ms → full');
    }
  }

  /// 仅供测试：把档位与采样状态重置为初始值。
  @visibleForTesting
  static void resetForTesting() {
    tier.value = UiEffectTier.full;
    _settled = false;
    _firstFrameUs = null;
    _samples.clear();
  }
}