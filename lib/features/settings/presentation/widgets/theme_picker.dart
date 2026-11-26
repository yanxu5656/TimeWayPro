import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/paper.dart';
import '../../providers/theme_provider.dart';

class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  static const Map<ThemeFamily, String> familyLabels = <ThemeFamily, String>{
    ThemeFamily.warm: '经典文雅',
    ThemeFamily.minimal: '简洁',
    ThemeFamily.cute: '可爱',
    ThemeFamily.tech: '科技',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ThemeFamily family in ThemeFamily.values) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppThemeCatalog.byFamily(
                      family,
                    ).first.design.palette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  familyLabels[family]!,
                  style: AppText.titleSm.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${AppThemeCatalog.byFamily(family).length} 款',
                  style: AppText.caption.copyWith(
                    color: context.colors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double spacing = AppSpacing.xs;
                final double width = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: <Widget>[
                    for (final AppThemeOption option
                        in AppThemeCatalog.byFamily(family))
                      SizedBox(
                        width: width,
                        child: _ThemeOptionCard(option: option),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({required this.option});

  final AppThemeOption option;

  @override
  Widget build(BuildContext context) {
    final ThemeProvider provider = context.watch<ThemeProvider>();
    final bool selected = provider.option.id == option.id;
    final AppPalette palette = option.design.palette;

    return Semantics(
      key: Key('theme_option_${option.id}'),
      button: true,
      selected: selected,
      label: '${option.name}，${option.tagline}',
      child: ExcludeSemantics(
        child: PressableScale(
          scale: 0.98,
          pressOffset: 1,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.selectTheme(option.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: selected
                    ? Color.alphaBlend(
                        context.colors.primary.withValues(alpha: 0.08),
                        context.colors.surface,
                      )
                    : context.colors.surface,
                borderRadius: BorderRadius.circular(context.shape.cardRadius),
                border: Border.all(
                  color: selected
                      ? context.colors.primary
                      : context.colors.divider,
                  width: selected ? 1.8 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ThemePreview(option: option),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          option.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleSm.copyWith(
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: context.colors.primary,
                        )
                      else
                        Icon(
                          Icons.circle_outlined,
                          size: 18,
                          color: palette.dividerStrong,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      fontSize: 11,
                      height: 1.35,
                      color: context.colors.textSecondary,
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

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.option});

  final AppThemeOption option;

  @override
  Widget build(BuildContext context) {
    final AppDesign design = option.design;
    final AppPalette c = design.palette;
    final AppTypography t = design.typography;
    final double radius = design.shape.cardRadius;

    return ExcludeSemantics(
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.circular(radius - 4),
          border: Border.all(color: c.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(radius * 0.55),
              ),
              child: Text(
                '今日待办',
                style: t.masthead.copyWith(
                  fontSize: 10,
                  color: c.textOnPrimary,
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(radius * 0.65),
                border: Border.all(color: c.divider),
                boxShadow: design.shape.rowShadows,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, size: 13, color: c.success),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '完成一件小事',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySerif.copyWith(
                        fontSize: 8,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: 0.65,
                      minHeight: 4,
                      backgroundColor: c.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(c.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '65%',
                  style: t.serifNum.copyWith(fontSize: 8, color: c.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
