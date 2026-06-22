import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class ProfileDialog extends StatelessWidget {
  final WorkspaceProvider workspace;

  const ProfileDialog({super.key, required this.workspace});

  static void show(BuildContext context, WorkspaceProvider workspace) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => ProfileDialog(workspace: workspace),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isDark = workspace.themeMode == ThemeMode.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final name = workspace.currentUser?.name ?? 'Guest User';
    final displayName = workspace.currentUser?.name ?? context.tr('top.guest_user');
    final email = workspace.currentUser?.email ?? 'guest@pharm.co';
    final role = workspace.currentUser?.role ?? 'guest';
    final shift = workspace.currentUser?.shift ?? 'morning';
    final status = workspace.currentUser?.status ?? 'active';

    String initials = 'GU';
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        initials = name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
      }
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: appColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                        color: appColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Avatar
                    Container(
                      height: 72,
                      width: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor,
                            primaryColor.withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name and Role Title
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: appColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        workspace.currentUser != null
                            ? context.tr('role.${role.toLowerCase()}').toUpperCase()
                            : context.tr('top.guest_role'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info Rows
                    _buildInfoRow(
                      icon: LucideIcons.mail,
                      label: context.tr('profile.email'),
                      value: email,
                      appColors: appColors,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: LucideIcons.shieldCheck,
                      label: context.tr('profile.status'),
                      value: status == 'active' ? context.tr('status.active').toUpperCase() : status.toUpperCase(),
                      appColors: appColors,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      icon: LucideIcons.clock,
                      label: context.tr('profile.current_shift'),
                      value: context.tr('profile.shift_format', args: {
                        'shift': context.tr('shift.${shift.toLowerCase()}'),
                      }),
                      appColors: appColors,
                    ),
                    const SizedBox(height: 24),

                    Divider(color: appColors.border, height: 1),
                    const SizedBox(height: 16),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: appColors.mutedForeground,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              context.tr('staff.cancel'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColors.destructive,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              // Trigger logout simulation
                              _handleLogout(context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.logOut, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  context.tr('nav.logout'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required AppColors appColors,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: appColors.mutedForeground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: appColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: appColors.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleLogout(BuildContext context) {
    workspace.logout();
  }
}
