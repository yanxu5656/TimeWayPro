import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';
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

/// 单行横向导航：八项按固定宽度排列，分隔线明确，选中项用陶土浅底标记。
class PaperNavBar extends StatefulWidget {
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
    _NavItemData(Icons.account_tree_outlined, Icons.account_tree_rounded, '规划'),
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
    _NavItemData(Icons.storefront_outlined, Icons.storefront_rounded, '商店'),
    _NavItemData(Icons.settings_outlined, Icons.settings_rounded, '设置'),
  ];

  @override
  State<PaperNavBar> createState() => _PaperNavBarState();
}

class _PaperNavBarState extends State<PaperNavBar> {
  final ScrollController _controller = ScrollController();
  double _itemExtent = 0;

  @override
  void didUpdateWidget(covariant PaperNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _revealSelected();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || _itemExtent <= 0) return;
      final ScrollPosition position = _controller.position;
      final double target = context.isGlass
          ? (widget.index * 52 + 48 - (position.viewportDimension - 100) / 2)
                .clamp(position.minScrollExtent, position.maxScrollExtent)
          : (widget.index * _itemExtent -
                    (position.viewportDimension - _itemExtent) / 2)
                .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((target - position.pixels).abs() < 0.5) return;
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (context.isGlass) {
      _itemExtent = 48;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(34),
            shadow: true,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: SizedBox(
              height: 58,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < PaperNavBar._items.length; i++)
                      _GlassNavItem(
                        data: PaperNavBar._items[i],
                        selected: i == widget.index,
                        onTap: () => widget.onChanged(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final Widget bar = Container(
      height: 54,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(context.shape.controlRadius),
        border: Border.all(color: context.colors.dividerStrong),
        boxShadow: context.shape.rowShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double itemExtent = (constraints.maxWidth / 4 + 8).clamp(
            88.0,
            120.0,
          );
          if ((itemExtent - _itemExtent).abs() > 0.5) {
            _itemExtent = itemExtent;
            _revealSelected();
          }
          return SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: <Widget>[
                for (int i = 0; i < PaperNavBar._items.length; i++)
                  SizedBox(
                    width: itemExtent,
                    child: _NavItem(
                      data: PaperNavBar._items[i],
                      selected: i == widget.index,
                      showDivider: i != PaperNavBar._items.length - 1,
                      onTap: () => widget.onChanged(i),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: bar,
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? context.colors.textOnPrimary
        : context.colors.textSecondary;
    return Semantics(
      label: data.label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: PressableScale(
          haptic: false,
          scale: 0.94,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: selected ? 96 : 48,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color.lerp(
                            context.colors.primary,
                            Colors.black,
                            0.24,
                          )!,
                          context.colors.primary,
                          Color.lerp(
                            context.colors.primary,
                            context.colors.accent,
                            0.76,
                          )!,
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(27),
                border: selected
                    ? Border.all(color: Colors.white.withValues(alpha: 0.2))
                    : null,
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: context.atmosphere.glow.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (selected)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: AnimatedScale(
                        scale: 1.06,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          data.activeIcon,
                          size: 20,
                          color: foreground,
                        ),
                      ),
                    )
                  else
                    AnimatedScale(
                      scale: 1,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Icon(data.icon, size: 20, color: foreground),
                    ),
                  if (selected)
                    Positioned(
                      left: 38,
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.label,
                          maxLines: 1,
                          style: AppText.navLabelActive.copyWith(
                            color: foreground,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0,
                        child: Center(
                          child: Text(
                            data.label,
                            maxLines: 1,
                            style: AppText.navLabelActive.copyWith(
                              color: foreground,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = selected
        ? context.colors.primary
        : context.colors.textSecondary;

    return Semantics(
      label: data.label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(right: BorderSide(color: context.colors.dividerStrong))
                : const Border(),
          ),
          child: PressableScale(
            haptic: false,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: selected
                      ? (context.isGlass
                            ? context.colors.primary.withValues(alpha: 0.06)
                            : context.colors.primary.withValues(alpha: 0.12))
                      : Colors.transparent,
                  gradient: selected && context.isGlass
                      ? LinearGradient(
                          colors: <Color>[
                            context.colors.primary.withValues(alpha: 0.24),
                            context.colors.accent.withValues(alpha: 0.14),
                          ],
                        )
                      : null,
                  borderRadius: context.isGlass
                      ? BorderRadius.circular(24)
                      : AppRadius.brMd,
                  border: selected && context.isGlass
                      ? Border.all(
                          color: context.colors.primary.withValues(alpha: 0.18),
                        )
                      : null,
                  boxShadow: selected && context.isGlass
                      ? <BoxShadow>[
                          BoxShadow(
                            color: context.atmosphere.glow,
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedScale(
                      scale: selected ? 1.08 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        selected ? data.activeIcon : data.icon,
                        size: 21,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      style:
                          (selected ? AppText.navLabelActive : AppText.navLabel)
                              .copyWith(color: fg),
                      child: Text(data.label),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
