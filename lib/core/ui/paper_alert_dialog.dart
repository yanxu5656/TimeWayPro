import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

class PaperAlertDialog extends StatelessWidget {
  const PaperAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.semanticLabel,
    this.scrollable = false,
    this.insetPadding,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;
  final EdgeInsets? insetPadding;

  @override
  Widget build(BuildContext context) {
    if (!context.isGlass) {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
        semanticLabel: semanticLabel,
        scrollable: scrollable,
        insetPadding: insetPadding,
      );
    }

    return Semantics(
      label: semanticLabel,
      child: Dialog(
        insetPadding:
            insetPadding ??
            const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.shape.sheetRadius),
        ),
        child: GlassSurface(
          gradient: <Color>[
            context.atmosphere.glassFill.withValues(alpha: 0.78),
            context.atmosphere.dialogFill.withValues(alpha: 0.68),
          ],
          rimColor: context.colors.primary,
          borderRadius: BorderRadius.circular(context.shape.sheetRadius),
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: context.colors.primary,
                        size: 28,
                      ),
                      child: icon!,
                    ),
                  )
                else
                  const SizedBox(height: 4),
                if (title != null)
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    child: title!,
                  ),
                if (title != null && content != null)
                  const SizedBox(height: 12),
                if (content != null)
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                      height: 1.55,
                    ),
                    child: content!,
                  ),
                if (actions != null && actions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8,
                      overflowSpacing: 4,
                      children: actions!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
