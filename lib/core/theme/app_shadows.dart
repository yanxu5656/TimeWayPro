import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 阴影 token —— 静白志。
///
/// 阴影在这个体系里是稀缺品：绝大多数表面长在纸面上、靠发丝线分层，
/// 只有真正「浮起」的东西（弹窗、FAB、墨色按钮）才带一点微影。
/// 着色用暖墨（[AppColors.shadow] 基色）——纯黑在纸面上会显脏。
class AppShadows {
  AppShadows._();

  /// 浮起块（白底卡、输入焦点框）
  static const List<BoxShadow> e1 = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  /// 高浮表面（弹窗、FAB）
  static const List<BoxShadow> e2 = <BoxShadow>[
    BoxShadow(
      color: AppColors.shadowMedium,
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
  ];
}
