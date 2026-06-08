import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum BadgeVariant {
  defaultValue,
  outline,
  muted,
  success,
  warning,
  danger,
}

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;

  const StatusBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.defaultValue,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (variant) {
      case BadgeVariant.defaultValue:
        backgroundColor = appColors.surface2;
        textColor = appColors.foreground;
        borderColor = appColors.border;
        break;
      case BadgeVariant.outline:
        backgroundColor = Colors.transparent;
        textColor = appColors.mutedForeground;
        borderColor = appColors.border;
        break;
      case BadgeVariant.muted:
        backgroundColor = appColors.surface1;
        textColor = appColors.mutedForeground;
        borderColor = appColors.border;
        break;
      case BadgeVariant.success:
        backgroundColor = appColors.success.withValues(alpha: 0.1);
        textColor = appColors.success;
        borderColor = appColors.success.withValues(alpha: 0.4);
        break;
      case BadgeVariant.warning:
        backgroundColor = appColors.warning.withValues(alpha: 0.1);
        textColor = appColors.warning;
        borderColor = appColors.warning.withValues(alpha: 0.4);
        break;
      case BadgeVariant.danger:
        backgroundColor = appColors.destructive.withValues(alpha: 0.15);
        textColor = appColors.destructive;
        borderColor = appColors.destructive.withValues(alpha: 0.4);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
