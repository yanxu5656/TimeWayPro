import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// 广播纸面底部导航的**实测高度**。
///
/// 为什么需要它：各页的 FAB 挂在页面自己的 `PaperScaffold` 上，而底部导航
/// 挂在 `MainScreen` 的 Scaffold 上。`MainScreen` 开了 `extendBody: true`
/// 让内容延伸到屏幕底部，于是**内层 Scaffold 的底边就是屏幕底边**——
/// 它的 FAB 会被摆到 `屏幕高 - 16 - FAB高`，也就是压在导航栏底下。
///
/// 内层拿不到这个高度（外层的 Scaffold 不会把它注入 MediaQuery），所以由
/// [MainScreen] 实测后经这个 InheritedWidget 往下传。
class NavBarInset extends InheritedWidget {
  const NavBarInset({super.key, required this.height, required super.child});

  /// 纸面导航栏的总高度（含设备底部安全区）；未测量到之前为 0
  final double height;

  /// 读取高度。不在 [NavBarInset] 之下（独立路由）时返回 0。
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavBarInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(NavBarInset oldWidget) =>
      (oldWidget.height - height).abs() > 0.5;
}

class _NavItemData {
  const _NavItemData(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// 暖白底部导航，v1.10.0 起**两行 4×2** 共八个入口。
///
/// 一行六格时再加两格会把每格挤到 48dp 以下、标签放不下；两行让每格
/// 保持 ~85dp 宽与 ≥44dp 的触控高度，代价是导航本身高约 35dp——
/// 同期刊头瘦身省下的 ~48dp 补回来还有余。
///
/// 导航是暖白卡面而不是纸面：它要和浮起的列表项区分开，同时比纸底
/// 亮一档，托住整页。选中态不靠底色块，靠**陶土图标文字 + 陶土圆点**
/// ——像目录页上当前条目旁的点标记。两行之间一条发丝线分栏。
///
/// 未选中项用 [AppColors.textSecondary]（5.5:1）而不是 textHint：
/// 导航标签是 10px 的语义文字，hint 档（2.8:1）在这个字号下读不清。
class PaperNavBar extends StatelessWidget {
  const PaperNavBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const List<_NavItemData> _items = <_NavItemData>[
    _NavItemData(Icons.today_outlined, Icons.today_rounded, '待办'),
    _NavItemData(Icons.flag_outlined, Icons.flag_rounded, '每周'),
    _NavItemData(
      Icons.check_circle_outline_rounded,
      Icons.check_circle_rounded,
      '任务',
    ),
    _NavItemData(Icons.bar_chart_rounded, Icons.bar_chart_rounded, '统计'),
    _NavItemData(
      Icons.account_tree_outlined,
      Icons.account_tree_rounded,
      '规划',
    ),
    _NavItemData(
      Icons.sports_esports_outlined,
      Icons.sports_esports_rounded,
      '闲时',
    ),
    _NavItemData(
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      '月历',
    ),
    _NavItemData(Icons.settings_outlined, Icons.settings_rounded, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildRow(0),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.divider,
              ),
              _buildRow(4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int start) {
    return Row(
      children: <Widget>[
        for (int i = start; i < start + 4; i++)
          Expanded(
            child: _NavItem(
              data: _items[i],
              selected: i == index,
              onTap: () => onChanged(i),
            ),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? AppColors.primary : AppColors.textSecondary;

    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 两行导航每行仍要 ≥44dp 触控高度
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(selected ? data.activeIcon : data.icon, size: 20, color: fg),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: (selected ? AppText.navLabelActive : AppText.navLabel)
                    .copyWith(color: fg),
                child: Text(data.label),
              ),
              const SizedBox(height: 2),
              // 当前条目的「点标记」。高度恒定避免切换时导航栏跳动
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}