import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final List<Map<String, dynamic>> _navigationItems = [
    // Core group
    {'id': 'dashboard', 'label': 'Dashboard', 'icon': LucideIcons.layoutDashboard, 'group': 'core', 'shortcut': '⌥1'},
    {'id': 'inventory', 'label': 'Inventory', 'icon': LucideIcons.package, 'group': 'core', 'shortcut': '⌥2'},
    {'id': 'pos', 'label': 'Point of Sale', 'icon': LucideIcons.shoppingCart, 'group': 'core', 'shortcut': '⌥3'},
    {'id': 'prescriptions', 'label': 'Prescriptions', 'icon': LucideIcons.fileSpreadsheet, 'group': 'core', 'shortcut': '⌥4'},
    {'id': 'warehouse', 'label': 'Warehouse Heatmap', 'icon': LucideIcons.grid, 'group': 'core', 'shortcut': '⌥5'},
    // People group
    {'id': 'suppliers', 'label': 'Suppliers List', 'icon': LucideIcons.truck, 'group': 'people'},
    {'id': 'staff', 'label': 'Staff & Audit', 'icon': LucideIcons.shieldCheck, 'group': 'people'},
    // Insights group
    {'id': 'finance', 'label': 'Finance OS', 'icon': LucideIcons.wallet, 'group': 'insights'},
    {'id': 'reports', 'label': 'Reports Center', 'icon': LucideIcons.barChart2, 'group': 'insights'},
    // System group
    {'id': 'notifications', 'label': 'Inbox Notifications', 'icon': LucideIcons.bell, 'group': 'system'},
    {'id': 'settings', 'label': 'OS Settings', 'icon': LucideIcons.settings, 'group': 'system'},
  ];


  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final isCollapsed = workspace.sidebarCollapsed || MediaQuery.of(context).size.width < 800;

    final role = workspace.currentUser?.role ?? 'cashier';
    final filteredItems = _navigationItems.where((item) {
      final id = item['id'] as String;
      if (role == 'admin') return true;
      if (role == 'manager') {
        return const ['dashboard', 'inventory', 'pos', 'prescriptions', 'warehouse', 'suppliers', 'reports', 'notifications'].contains(id);
      }
      if (role == 'pharmacist') {
        return const ['dashboard', 'inventory', 'pos', 'prescriptions', 'warehouse', 'notifications'].contains(id);
      }
      if (role == 'cashier') {
        return const ['pos', 'notifications'].contains(id);
      }
      return false;
    }).toList();

    // Group items
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in filteredItems) {
      final g = item['group'] as String;
      grouped.putIfAbsent(g, () => []);
      grouped[g]!.add(item);
    }

    // Determine currently active module (from focused group's active tab)
    String activeModule = '';
    if (workspace.groups.isNotEmpty && workspace.activeGroupIndex < workspace.groups.length) {
      final grp = workspace.groups[workspace.activeGroupIndex];
      final activeTab = grp.tabs.firstWhere((t) => t.id == grp.activeTabId, orElse: () => grp.tabs[0]);
      activeModule = activeTab.moduleId;
    }

    return Container(
      width: isCollapsed ? 60 : 240,
      decoration: BoxDecoration(
        color: appColors.surface1,
        border: Border(right: BorderSide(color: appColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo Header
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: appColors.border)),
            ),
            child: Row(
              children: [
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: appColors.foreground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    LucideIcons.pill,
                    color: appColors.background,
                    size: 16,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('login.title'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: appColors.foreground,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'PHARMACY OS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: appColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),



          // Navigation items list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: grouped.entries.map((entry) {
                final groupKey = entry.key;
                final items = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isCollapsed) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 12, bottom: 4),
                        child: Text(
                          context.tr('nav.group.$groupKey').toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: appColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                    ...items.map((item) {
                      final id = item['id'] as String;
                      final label = context.tr('nav.$id');
                      final icon = item['icon'] as IconData;
                      final shortcut = item['shortcut'] as String?;
                      final isActive = activeModule == id;

                      return Tooltip(
                        message: isCollapsed ? label : '',
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          height: 32,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: isActive ? appColors.surface2 : Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => workspace.openTab(id),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 14,
                                  color: isActive ? appColors.foreground : appColors.mutedForeground,
                                ),
                                if (!isCollapsed) ...[
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isActive ? appColors.foreground : appColors.foreground.withValues(alpha: 0.8),
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (shortcut != null) ...[
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: appColors.border),
                                        color: appColors.surface2,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      child: Text(
                                        shortcut,
                                        style: AppTheme.mono(fontSize: 8, color: appColors.mutedForeground),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),

          // Bottom Collapse Control
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: appColors.border)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: InkWell(
              onTap: workspace.toggleSidebar,
              child: SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 4),
                    Icon(
                      isCollapsed ? LucideIcons.chevronsRight : LucideIcons.chevronsLeft,
                      size: 14,
                      color: appColors.mutedForeground,
                    ),
                    if (!isCollapsed) ...[
                      const SizedBox(width: 8),
                      Text(
                        context.tr('nav.collapse'),
                        style: TextStyle(fontSize: 11, color: appColors.mutedForeground),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
