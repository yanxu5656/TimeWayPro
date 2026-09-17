import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 阴影 token。
///
/// 纯黑阴影（`Colors.black.withOpacity(0.04)`）叠在青绿色调的极光背景上
/// 会显脏，统一改用 slate（[AppColors.glassShadow] = #0F172A）着色。
///
/// 收敛自原代码的 6 档 blurRadius {8,10,12,15,20,30}。性能约定：
/// **列表里的卡片一律用 [e1]（blur 12 封顶）**，[e2] 只给底部导航 /
/// 弹窗 / FAB 这类同时存在不超过 2 个的表面——`BoxShadow.blur` 是每张
/// 卡片一次独立的模糊 pass。
class AppShadows {
  AppShadows._();

  /// 静置卡片
  static const List<BoxShadow> e1 = <BoxShadow>[
    BoxShadow(
      color: AppColors.glassShadow,
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  /// 浮起表面：底部导航 / 弹窗 / FAB
  static const List<BoxShadow> e2 = <BoxShadow>[
    BoxShadow(
      color: AppColors.glassShadowStrong,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// 强调态（计时进行中 / 选中）。替代原先硬编码的
  /// `primary.withOpacity(0.3)`、`success.withValues(alpha: 0.15)` 等。
  static List<BoxShadow> tint(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.16),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}

/// 渐变 token。
class AppGradients {
  AppGradients._();

  /// 玻璃的 1px 内高光描边。
  ///
  /// 用它而不是 `Border.all(color: Colors.white)`：均匀白环在白底区域
  /// 完全不可见、在青绿区域才可见，看起来像"缺了一块"。渐变色描边模拟
  /// "光从左上打来、上缘被照亮"，这才是玻璃质感的来源。
  static const LinearGradient glassEdge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.glassEdgeTop, AppColors.glassEdgeBottom],
  );

  /// 同色系低透明度双向渐变（计时条背景、圆形按钮底）。
  /// 收敛自 task_card 里 3 处同构的 LinearGradient。
  static LinearGradient softFill(Color color) => LinearGradient(
    colors: <Color>[
      color.withValues(alpha: 0.15),
      color.withValues(alpha: 0.05),
    ],
  );

  /// 极光层的实底基色（极光本身是部分透明的，必须有底）
  static const LinearGradient auroraBase = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFF8FAFB), Color(0xFFEFF6F4)],
  );
}
