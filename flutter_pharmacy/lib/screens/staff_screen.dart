import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/data_table.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  List<StaffMember> _staff = [];
  List<ActivityEvent> _activities = [];
  double _auditLogWidth = 320.0;
  bool _showAuditLog = false;

  @override
  void initState() {
    super.initState();
    _loadAuditLogPrefs();
    _fetchStaff();
  }

  void _loadAuditLogPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble('staff_audit_log_width');
    final show = prefs.getBool('staff_show_audit_log');
    if (mounted) {
      setState(() {
        if (width != null) _auditLogWidth = width;
        if (show != null) _showAuditLog = show;
      });
    }
  }

  void _saveAuditLogWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('staff_audit_log_width', width);
  }

  void _saveShowAuditLog(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('staff_show_audit_log', show);
  }

  void _fetchStaff() async {
    try {
      final s = await _db.request<List<StaffMember>>('staff');
      final act = await _db.request<List<ActivityEvent>>('activities');
      if (mounted) {
        setState(() {
          _staff = s;
          _activities = act;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Enforce role-based access control inside client view layer
    final isAdmin = workspace.currentUser?.role == 'admin';
    if (!isAdmin) {
      return Scaffold(
        backgroundColor: appColors.background,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: appColors.destructive.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.shieldAlert,
                    color: appColors.destructive,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('staff.access_denied'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: appColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('staff.access_denied_desc'),
                  style: TextStyle(
                    fontSize: 13,
                    color: appColors.mutedForeground,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: appColors.background,
      body: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  icon: LucideIcons.shieldCheck,
                  title: context.tr('staff.title'),
                  subtitle: context.tr('staff.subtitle'),
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: appColors.foreground,
                        ),
                        onPressed: () {
                          setState(() {
                            _showAuditLog = !_showAuditLog;
                          });
                          _saveShowAuditLog(_showAuditLog);
                        },
                        icon: Icon(_showAuditLog ? LucideIcons.eyeOff : LucideIcons.eye, size: 14),
                        label: Text(_showAuditLog ? 'Hide Audit Log' : 'Show Audit Log', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appColors.foreground,
                          foregroundColor: appColors.background,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => _showStaffFormDialog(),
                        icon: const Icon(LucideIcons.userPlus, size: 14),
                        label: Text(context.tr('staff.add_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DataTableWidget<StaffMember>(
                      data: _staff,
                      getRowId: (s) => s.id,
                      searchKeys: (s) => [s.name, s.username, s.email, s.role, s.status, s.shift],
                      onRowClick: (s) => _showStaffDetailsDialog(s),
                      onBulkDelete: _onBulkDeleteStaff,
                      columns: [
                        DataTableColumn(
                          key: 'name',
                          header: context.tr('staff.col_name'),
                          cellBuilder: (s) => Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        DataTableColumn(
                          key: 'username',
                          header: context.tr('staff.col_username'),
                          cellBuilder: (s) => Text(s.username, style: AppTheme.mono(fontSize: 12)),
                        ),
                        DataTableColumn(
                          key: 'email',
                          header: context.tr('staff.col_email'),
                          cellBuilder: (s) => Text(s.email.isNotEmpty ? s.email : '-', style: const TextStyle(fontSize: 12)),
                        ),
                        DataTableColumn(
                          key: 'role',
                          header: context.tr('staff.col_role'),
                          cellBuilder: (s) => StatusBadge(
                            text: context.tr('role.${s.role}'),
                            variant: s.role == 'admin'
                                ? BadgeVariant.danger
                                : (s.role == 'pharmacist' ? BadgeVariant.warning : BadgeVariant.muted),
                          ),
                        ),
                        DataTableColumn(
                          key: 'shift',
                          header: context.tr('staff.col_shift'),
                          cellBuilder: (s) => Text(context.tr('shift.${s.shift}'), style: AppTheme.mono(fontSize: 11)),
                        ),
                        DataTableColumn(
                          key: 'status',
                          header: context.tr('staff.col_status'),
                          cellBuilder: (s) => StatusBadge(
                            text: context.tr('status.${s.status.replaceAll('-', '_')}'),
                            variant: s.status == 'active' ? BadgeVariant.success : BadgeVariant.outline,
                          ),
                        ),
                      ],
                      rowActionBuilder: (s) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(LucideIcons.edit3, size: 14, color: appColors.mutedForeground),
                              tooltip: context.tr('staff.tooltip_edit'),
                              onPressed: () => _showStaffFormDialog(staff: s),
                            ),
                             if (s.role != 'owner' && s.name != 'Owner')
                              IconButton(
                                icon: Icon(LucideIcons.trash2, size: 14, color: appColors.destructive),
                                tooltip: context.tr('staff.tooltip_delete'),
                                onPressed: () => _confirmDelete(s),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showAuditLog) ...[
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                final isRtl = Directionality.of(context) == TextDirection.rtl;
                final delta = details.delta.dx;
                Future.microtask(() {
                  if (mounted) {
                    setState(() {
                      final maxAuditWidth = MediaQuery.of(context).size.width * 0.5;
                      final minAuditWidth = 240.0;
                      if (isRtl) {
                        _auditLogWidth = (_auditLogWidth + delta).clamp(minAuditWidth, maxAuditWidth);
                      } else {
                        _auditLogWidth = (_auditLogWidth - delta).clamp(minAuditWidth, maxAuditWidth);
                      }
                    });
                    _saveAuditLogWidth(_auditLogWidth);
                  }
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: Container(
                  width: 12,
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 1,
                      color: appColors.border,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _auditLogWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: appColors.border)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.history, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('staff.audit_log'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activities.length,
                      separatorBuilder: (context, idx) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final a = _activities[idx];
                        BadgeVariant v = BadgeVariant.muted;
                        if (a.severity == 'critical') {
                          v = BadgeVariant.danger;
                        } else if (a.severity == 'warning') {
                          v = BadgeVariant.warning;
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: appColors.surface1,
                            border: Border.all(color: appColors.border),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  StatusBadge(text: a.type, variant: v),
                                  Text(
                                    _formatTime(a.at),
                                    style: TextStyle(fontSize: 10, color: appColors.mutedForeground),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(a.message, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('Actor: ${a.actor}', style: TextStyle(fontSize: 10, color: appColors.mutedForeground)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStaffFormDialog({StaffMember? staff}) {
    final isEdit = staff != null;
    final nameController = TextEditingController(text: staff?.name);
    final usernameController = TextEditingController(text: staff?.username);
    final emailController = TextEditingController(text: staff?.email);
    final passwordController = TextEditingController();

    String selectedRole = staff?.role ?? 'cashier';
    String selectedShift = staff?.shift ?? 'morning';
    String selectedStatus = staff?.status ?? 'active';

    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final appColors = Theme.of(context).extension<AppColors>()!;
            final primaryColor = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              backgroundColor: appColors.surface1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Icon(isEdit ? LucideIcons.edit : LucideIcons.userPlus, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? context.tr('staff.edit_title') : context.tr('staff.add_title'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorText != null) ...[
                      Text(errorText!, style: TextStyle(color: appColors.destructive, fontSize: 12)),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: nameController,
                      enabled: staff?.role != 'owner' && staff?.name != 'Owner',
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: context.tr('staff.field_name'),
                        prefixIcon: const Icon(LucideIcons.user, size: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      enabled: !isEdit && staff?.role != 'owner' && staff?.name != 'Owner',
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: context.tr('staff.field_username'),
                        prefixIcon: const Icon(LucideIcons.fingerprint, size: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      enabled: staff?.role != 'owner' && staff?.name != 'Owner',
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: context.tr('staff.field_email'),
                        prefixIcon: const Icon(LucideIcons.mail, size: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: isEdit ? context.tr('staff.field_password_edit') : context.tr('staff.field_password'),
                        prefixIcon: const Icon(LucideIcons.lock, size: 14),
                        helperText: isEdit ? context.tr('staff.field_password_helper') : null,
                        helperStyle: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      style: TextStyle(color: appColors.foreground, fontSize: 13),
                      decoration: InputDecoration(labelText: context.tr('staff.field_role'), prefixIcon: const Icon(LucideIcons.shield, size: 14)),
                      items: ['admin', 'manager', 'pharmacist', 'cashier', if (selectedRole == 'owner') 'owner'].map((role) {
                        return DropdownMenuItem(value: role, child: Text(role == 'owner' ? 'Owner' : context.tr('role.$role')));
                      }).toList(),
                      onChanged: (staff?.role == 'owner' || staff?.name == 'Owner') ? null : (val) {
                        if (val != null) setState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedShift,
                      style: TextStyle(color: appColors.foreground, fontSize: 13),
                      decoration: InputDecoration(labelText: context.tr('staff.field_shift'), prefixIcon: const Icon(LucideIcons.clock, size: 14)),
                      items: ['morning', 'evening', 'night'].map((shift) {
                        return DropdownMenuItem(value: shift, child: Text(context.tr('shift.$shift')));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedShift = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      style: TextStyle(color: appColors.foreground, fontSize: 13),
                      decoration: InputDecoration(labelText: context.tr('staff.field_status'), prefixIcon: const Icon(LucideIcons.activity, size: 14)),
                      items: ['active', 'off-shift', 'suspended'].map((status) {
                        return DropdownMenuItem(value: status, child: Text(context.tr('status.${status.replaceAll('-', '_')}')));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedStatus = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(context.tr('staff.cancel'), style: TextStyle(color: appColors.mutedForeground)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              usernameController.text.trim().isEmpty ||
                              (!isEdit && passwordController.text.isEmpty)) {
                            setState(() => errorText = context.tr('staff.validation_required'));
                            return;
                          }
                          setState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          try {
                            final targetStaff = StaffMember(
                              id: isEdit ? staff.id : 'staff_${DateTime.now().millisecondsSinceEpoch}',
                              name: nameController.text.trim(),
                              username: usernameController.text.trim(),
                              email: emailController.text.trim(),
                              role: selectedRole,
                              status: selectedStatus,
                              shift: selectedShift,
                              joinedAt: isEdit ? staff.joinedAt : DateTime.now().toIso8601String(),
                              lastSeen: isEdit ? staff.lastSeen : '',
                            );

                            final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
                            final nav = Navigator.of(context);
                            final dialogTitle = isEdit ? context.tr('staff.edit_title') : context.tr('staff.add_title');
                            final dialogBody = isEdit ? context.tr('staff.toast_updated') : context.tr('staff.toast_added');

                            if (isEdit) {
                              await _db.updateStaff(
                                targetStaff,
                                password: passwordController.text.isNotEmpty ? passwordController.text : null,
                              );
                            } else {
                              await _db.createStaff(
                                targetStaff,
                                passwordController.text,
                              );
                            }

                            if (nav.context.mounted) {
                              nav.pop();
                              _fetchStaff();
                              workspace.showNotification(
                                title: dialogTitle,
                                body: dialogBody,
                                category: 'system',
                              );
                            }
                          } catch (err) {
                            setState(() {
                              isSaving = false;
                              errorText = err.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? context.tr('staff.save') : context.tr('staff.create'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStaffDetailsDialog(StaffMember staff) {
    showDialog(
      context: context,
      builder: (context) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        final primaryColor = Theme.of(context).colorScheme.primary;
        return AlertDialog(
          backgroundColor: appColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(LucideIcons.user, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Staff Member Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _infoRow('Name', staff.name, appColors),
              _infoRow('Username', staff.username, appColors),
              _infoRow('Email', staff.email.isNotEmpty ? staff.email : 'None', appColors),
              _infoRow('Role', context.tr('role.${staff.role}'), appColors),
              _infoRow('Shift', context.tr('shift.${staff.shift}'), appColors),
              _infoRow('Status', context.tr('status.${staff.status.replaceAll('-', '_')}'), appColors),
              _infoRow('Joined At', _formatDateTime(staff.joinedAt), appColors),
              _infoRow('Last Seen', staff.lastSeen.isNotEmpty ? _formatDateTime(staff.lastSeen) : 'Never', appColors),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('staff.cancel'), style: TextStyle(color: appColors.mutedForeground)),
            ),
            if (staff.role != 'owner' && staff.name != 'Owner')
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(staff);
                },
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: Text(context.tr('staff.delete')),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showStaffFormDialog(staff: staff);
              },
              icon: const Icon(LucideIcons.edit, size: 14),
              label: Text(context.tr('staff.tooltip_edit')),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value, AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 12, color: appColors.mutedForeground, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, color: appColors.foreground)),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  void _onBulkDeleteStaff(List<StaffMember> selected) {
    final deletable = selected.where((s) => s.role != 'owner' && s.name != 'Owner').toList();
    if (deletable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No deletable staff members selected (Owners cannot be deleted).')),
      );
      return;
    }

    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    showDialog<bool>(
      context: context,
      builder: (context) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        return AlertDialog(
          backgroundColor: appColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text('Bulk Delete Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to delete ${deletable.length} staff members?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('staff.cancel'), style: TextStyle(color: appColors.mutedForeground)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('staff.delete')),
            ),
          ],
        );
      },
    ).then((confirm) async {
      if (confirm == true) {
        try {
          for (final s in deletable) {
            await _db.deleteStaff(s.id);
          }
          _fetchStaff();
          workspace.showNotification(
            title: 'Bulk Deletion',
            body: 'Deleted ${deletable.length} staff members successfully.',
            category: 'system',
          );
        } catch (e) {
          workspace.showNotification(
            title: 'Error',
            body: e.toString().replaceAll('Exception: ', ''),
            category: 'error',
          );
        }
      }
    });
  }

  void _confirmDelete(StaffMember staff) {
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final appColors = Theme.of(context).extension<AppColors>()!;

            return AlertDialog(
              backgroundColor: appColors.surface1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(context.tr('staff.delete_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorText != null) ...[
                    Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    context.tr('staff.delete_confirm', args: {'name': staff.name}),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(context.tr('staff.cancel'), style: TextStyle(color: appColors.mutedForeground)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
                          final nav = Navigator.of(context);
                          final deleteTitle = context.tr('staff.delete_title');
                          final deleteBody = context.tr('staff.toast_deleted');

                          try {
                            await _db.deleteStaff(staff.id);
                            if (nav.context.mounted) {
                              nav.pop();
                              _fetchStaff();
                              workspace.showNotification(
                                title: deleteTitle,
                                body: deleteBody,
                                category: 'system',
                              );
                            }
                          } catch (err) {
                            setState(() {
                              isSaving = false;
                              errorText = err.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(context.tr('staff.delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return context.tr('time.days_ago', args: {'count': diff.inDays.toString()});
      if (diff.inHours > 0) return context.tr('time.hours_ago', args: {'count': diff.inHours.toString()});
      if (diff.inMinutes > 0) return context.tr('time.minutes_ago', args: {'count': diff.inMinutes.toString()});
      return context.tr('time.just_now');
    } catch (_) {
      return '';
    }
  }

}
