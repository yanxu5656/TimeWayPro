import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 阴影 token —— 陶土暖笺。
///
/// 卡片回到主表面之后，阴影从「稀缺品」变回**分层的主要工具**：
/// 每张暖白卡都靠 [e1] 从暖纸上托起来。两层是有分工的——贴近的
/// 短影给出接触边，扩散的长影给出体量，单层做不到这件事。
/// 着色用暖陶棕（[AppColors.shadow] 基色）：纯黑在暖纸上会显脏。
///
/// 不用 BackdropFilter：实心卡 + 阴影比玻璃时代的模糊轻一个量级。
class AppShadows {
  AppShadows._();

  /// 账本行卡（PaperTone.row 是唯一默认带阴影的档位）
  static const List<BoxShadow> e1 = <BoxShadow>[
    BoxShadow(color: AppColors.shadow, blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 5)),
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
