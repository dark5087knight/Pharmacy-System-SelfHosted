import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/models.dart' as model;
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _db = ApiService();
  List<model.Notification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() async {
    final list = await _db.request<List<model.Notification>>('notifications');
    if (mounted) {
      setState(() {
        _notifications = list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.bell,
            title: context.tr('ntf.title'),
            subtitle: context.tr('ntf.subtitle'),
            actions: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    for (int i = 0; i < _notifications.length; i++) {
                      if (!_notifications[i].read) {
                        final updated = _notifications[i].copyWith(read: true);
                        await _db.updateNotification(updated);
                      }
                    }
                    _loadNotifications();
                  },
                  child: Text(context.tr('ntf.mark_all'), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(LucideIcons.trash2, color: appColors.destructive, size: 16),
                  onPressed: () {
                    setState(() {
                      _notifications.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _notifications.isEmpty
                ? Center(
                    child: Text(context.tr('ntf.empty')),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, idx) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      Color bg = appColors.surface1;
                      Color border = appColors.border;

                      if (!n.read) {
                        bg = appColors.surface2;
                        border = appColors.borderStrong;
                      }

                      return InkWell(
                        onTap: () async {
                          if (!n.read) {
                            final updated = n.copyWith(read: true);
                            await _db.updateNotification(updated);
                            _loadNotifications();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                height: 32,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: appColors.background,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  n.priority == 'critical' ? LucideIcons.alertTriangle : LucideIcons.info,
                                  size: 16,
                                  color: n.priority == 'critical' ? appColors.destructive : appColors.foreground,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        StatusBadge(text: n.priority == 'critical' ? context.tr('ntf.priority.critical') : context.tr('ntf.priority.info'), variant: n.priority == 'critical' ? BadgeVariant.danger : BadgeVariant.muted),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n.body, style: TextStyle(fontSize: 12, color: appColors.mutedForeground)),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat('yyyy-MM-dd').format(DateTime.parse(n.at)),
                                style: AppTheme.mono(fontSize: 11, color: appColors.mutedForeground),
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
    );
  }
}
