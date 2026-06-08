import 'package:flutter/material.dart';
import '../theme/theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? actions;
  final IconData? icon;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: appColors.background.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: appColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: appColors.surface1,
                border: Border.all(color: appColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: appColors.foreground),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: appColors.foreground,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: appColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ignore: use_null_aware_elements
          if (actions != null) actions!,
        ],
      ),
    );
  }
}

class Section extends StatelessWidget {
  final String title;
  final Widget children;
  final Widget? actions;

  const Section({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: appColors.surface1,
        border: Border.all(color: appColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: appColors.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: appColors.mutedForeground,
                  ),
                ),
                // ignore: use_null_aware_elements
                if (actions != null) actions!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: children,
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final Map<String, dynamic>? trend; // e.g. {'value': '12%', 'up': true}
  final IconData? icon;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.trend,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: appColors.surface1,
          border: Border.all(color: appColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: appColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: AppTheme.mono(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: appColors.foreground,
                    ),
                  ),
                  if (hint != null || trend != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (trend != null) ...[
                          Text(
                            '${trend!['up'] == true ? "▲" : "▼"} ${trend!['value']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: trend!['up'] == true ? appColors.success : appColors.destructive,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (hint != null)
                          Expanded(
                            child: Text(
                              hint!,
                              style: TextStyle(
                                fontSize: 11,
                                color: appColors.mutedForeground,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 12),
              Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: appColors.background,
                  border: Border.all(color: appColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: appColors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? description;

  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: appColors.surface1,
                  border: Border.all(color: appColors.border),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 20, color: appColors.mutedForeground),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: appColors.foreground,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: appColors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
