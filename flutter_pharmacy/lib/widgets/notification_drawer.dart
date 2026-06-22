import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart' as model;
import '../theme/theme.dart';
import '../i18n/translations.dart';

class NotificationDrawer extends StatefulWidget {
  const NotificationDrawer({super.key});

  @override
  State<NotificationDrawer> createState() => _NotificationDrawerState();
}

class _NotificationDrawerState extends State<NotificationDrawer> {
  List<model.Notification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() async {
    try {
      final list = await ApiService().request<List<model.Notification>>('notifications');
      if (mounted) {
        setState(() {
          _notifications = list;
        });
      }
    } catch (_) {}
  }

  String _formatTime(BuildContext context, String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) {
        return context.tr('time.days_ago', args: {'count': diff.inDays.toString()});
      } else if (diff.inHours > 0) {
        return context.tr('time.hours_ago', args: {'count': diff.inHours.toString()});
      } else if (diff.inMinutes > 0) {
        return context.tr('time.minutes_ago', args: {'count': diff.inMinutes.toString()});
      } else {
        return context.tr('time.just_now');
      }
    } catch (_) {
      return '';
    }
  }

  final Map<String, IconData> _categoryIcons = {
    'expiry': LucideIcons.calendar,
    'stock': LucideIcons.package,
    'payment': LucideIcons.wallet,
    'supplier': LucideIcons.building,
    'system': LucideIcons.settings,
  };

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (!workspace.notificationsOpen) return const SizedBox.shrink();

    final unreadCount = _notifications.where((n) => !n.read).length;

    return Stack(
      children: [
        // Backdrop overlay
        GestureDetector(
          onTap: () => workspace.setNotificationsOpen(false),
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),

        // Slide-out panel from the right
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 420,
            decoration: BoxDecoration(
              color: appColors.background,
              border: Border(left: BorderSide(color: appColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drawer Header
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: appColors.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.bell, size: 16, color: appColors.foreground),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('nav.notifications'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        context.tr('ntf.unread', args: {'count': unreadCount.toString()}),
                        style: TextStyle(fontSize: 12, color: appColors.mutedForeground),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () => workspace.setNotificationsOpen(false),
                      ),
                    ],
                  ),
                ),

                // Notifications List
                Expanded(
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: appColors.border),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final icon = n.priority == 'critical'
                          ? LucideIcons.alertTriangle
                          : (_categoryIcons[n.category] ?? LucideIcons.bell);

                      Color iconColor = appColors.mutedForeground;
                      Color iconBg = appColors.surface1;

                      if (n.priority == 'critical') {
                        iconColor = appColors.destructive;
                        iconBg = appColors.destructive.withValues(alpha: 0.2);
                      } else if (n.priority == 'high') {
                        iconColor = appColors.warning;
                        iconBg = appColors.warning.withValues(alpha: 0.15);
                      }

                      return InkWell(
                        onTap: () {
                          final updated = model.Notification(
                            id: n.id,
                            title: n.title,
                            body: n.body,
                            category: n.category,
                            priority: n.priority,
                            read: true,
                            at: n.at,
                          );
                          ApiService().updateNotification(updated);
                          setState(() {
                            _notifications[index] = updated;
                          });
                        },
                        child: Container(
                          color: n.read ? Colors.transparent : appColors.surface1.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 28,
                                width: 28,
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  border: Border.all(
                                    color: n.priority == 'critical'
                                        ? appColors.destructive.withValues(alpha: 0.5)
                                        : (n.priority == 'high' ? appColors.warning.withValues(alpha: 0.4) : appColors.border),
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(icon, size: 14, color: iconColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!n.read) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            height: 6,
                                            width: 6,
                                            decoration: BoxDecoration(
                                              color: appColors.foreground,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      n.body,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: appColors.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(context, n.at).toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: appColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
