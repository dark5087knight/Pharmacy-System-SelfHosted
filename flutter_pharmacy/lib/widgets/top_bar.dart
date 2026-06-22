import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';
import 'profile_dialog.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isDark = workspace.themeMode == ThemeMode.dark;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: appColors.background.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: appColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final showFullSearch = width >= 700;
          final showCompactSearch = width >= 500 && width < 700;
          final showExtraButtons = width >= 650;
          final showProfileText = width >= 550;

          return Row(
            children: [
              // Global Search bar button
              if (showFullSearch || showCompactSearch)
                InkWell(
                  onTap: () => workspace.setCommandOpen(true),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: showFullSearch ? 300 : 180,
                    height: 36,
                    decoration: BoxDecoration(
                      color: appColors.surface1,
                      border: Border.all(color: appColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.search, size: 14, color: appColors.mutedForeground),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            showFullSearch
                                ? context.tr('top.search_placeholder')
                                : context.tr('top.search_compact'),
                            style: TextStyle(fontSize: 12, color: appColors.mutedForeground),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showFullSearch)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: appColors.border),
                              color: appColors.surface2,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            child: Text(
                              '⌘K',
                              style: AppTheme.mono(fontSize: 9, color: appColors.mutedForeground),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(LucideIcons.search, size: 16, color: appColors.mutedForeground),
                  tooltip: context.tr('top.search_tooltip'),
                  onPressed: () => workspace.setCommandOpen(true),
                ),

              const Spacer(),

              // Actions
              if (showExtraButtons) ...[
                IconButton(
                  icon: Icon(LucideIcons.command, size: 16, color: appColors.mutedForeground),
                  tooltip: context.tr('top.command_tooltip'),
                  onPressed: () => workspace.setCommandOpen(true),
                ),
                IconButton(
                  icon: Icon(LucideIcons.helpCircle, size: 16, color: appColors.mutedForeground),
                  tooltip: context.tr('top.help_tooltip'),
                  onPressed: () {},
                ),
              ],
              IconButton(
                icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 16, color: appColors.mutedForeground),
                tooltip: context.tr('top.theme_tooltip'),
                onPressed: workspace.toggleTheme,
              ),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.bell, size: 16, color: appColors.mutedForeground),
                    tooltip: context.tr('top.notifications_tooltip'),
                    onPressed: () => workspace.setNotificationsOpen(true),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IgnorePointer(
                      child: Container(
                        height: 6,
                        width: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Container(
                width: 1,
                height: 20,
                color: appColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),

              // User Profile Info
              InkWell(
                onTap: () => ProfileDialog.show(context, workspace),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: appColors.surface3,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.user,
                          size: 14,
                          color: appColors.foreground,
                        ),
                      ),
                      if (showProfileText) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              workspace.currentUser?.name ?? context.tr('top.guest_user'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              workspace.currentUser != null
                                  ? context.tr('role.${workspace.currentUser!.role.toLowerCase()}')
                                  : context.tr('top.guest_role'),
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
