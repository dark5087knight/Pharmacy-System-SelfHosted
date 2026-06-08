import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class WorkspaceTabBar extends StatelessWidget {
  final int groupIndex;

  const WorkspaceTabBar({super.key, required this.groupIndex});

  void _showContextMenu(BuildContext context, TabItem tab, WorkspaceProvider workspace, Offset globalPosition) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(tab.pinned ? LucideIcons.pinOff : LucideIcons.pin, size: 14),
              const SizedBox(width: 8),
              Text(tab.pinned ? context.tr('tab.unpin') : context.tr('tab.pin')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'split',
          enabled: workspace.groups.length < 2,
          child: Row(
            children: [
              const Icon(LucideIcons.splitSquareHorizontal, size: 14),
              const SizedBox(width: 8),
              Text(context.tr('tab.split')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'close',
          enabled: !tab.pinned,
          child: Row(
            children: [
              const Icon(LucideIcons.x, size: 14),
              const SizedBox(width: 8),
              Text(context.tr('tab.close')),
            ],
          ),
        ),
      ],
      elevation: 8,
    );

    if (result == 'pin') {
      workspace.togglePin(groupIndex, tab.id);
    } else if (result == 'split') {
      workspace.splitTab(tab);
    } else if (result == 'close') {
      workspace.closeTab(groupIndex, tab.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final group = workspace.groups[groupIndex];

    final List<Map<String, dynamic>> addableModules = [
      {'id': 'dashboard', 'label': 'Dashboard', 'icon': LucideIcons.layoutDashboard},
      {'id': 'inventory', 'label': 'Inventory', 'icon': LucideIcons.package},
      {'id': 'pos', 'label': 'Point of Sale', 'icon': LucideIcons.shoppingCart},
      {'id': 'prescriptions', 'label': 'Prescriptions', 'icon': LucideIcons.fileSpreadsheet},
      {'id': 'warehouse', 'label': 'Warehouse Heatmap', 'icon': LucideIcons.grid},
      {'id': 'suppliers', 'label': 'Suppliers List', 'icon': LucideIcons.truck},
      {'id': 'staff', 'label': 'Staff & Audit', 'icon': LucideIcons.shieldCheck},
      {'id': 'finance', 'label': 'Finance OS', 'icon': LucideIcons.wallet},
      {'id': 'reports', 'label': 'Reports Center', 'icon': LucideIcons.barChart2},
      {'id': 'notifications', 'label': 'Inbox Notifications', 'icon': LucideIcons.bell},
      {'id': 'settings', 'label': 'OS Settings', 'icon': LucideIcons.settings},
    ];

    final moduleIcons = {
      'dashboard': LucideIcons.layoutDashboard,
      'inventory': LucideIcons.package,
      'medicine-details': LucideIcons.pill,
      'pos': LucideIcons.shoppingCart,
      'prescriptions': LucideIcons.fileSpreadsheet,
      'warehouse': LucideIcons.grid,
      'suppliers': LucideIcons.truck,
      'staff': LucideIcons.shieldCheck,
      'finance': LucideIcons.wallet,
      'reports': LucideIcons.barChart2,
      'notifications': LucideIcons.bell,
      'settings': LucideIcons.settings,
    };

    return Listener(
      onPointerDown: (e) {
        workspace.setActiveGroup(groupIndex);
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: appColors.surface1,
          border: Border(bottom: BorderSide(color: appColors.border)),
        ),
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Row(
          children: [
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: group.tabs.length,
                itemBuilder: (context, index) {
                  final tab = group.tabs[index];
                  final isActive = group.activeTabId == tab.id;
                  final icon = tab.pinned ? LucideIcons.pin : (moduleIcons[tab.moduleId] ?? LucideIcons.file);

                  return GestureDetector(
                    onTap: () => workspace.setActiveTab(groupIndex, tab.id),
                    onSecondaryTapDown: (details) {
                      _showContextMenu(context, tab, workspace, details.globalPosition);
                    },
                    // Middle click / wheel click closure support
                    onTertiaryTapDown: (details) {
                      workspace.closeTab(groupIndex, tab.id);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? appColors.background : Colors.transparent,
                        border: Border.all(
                          color: isActive ? appColors.border : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 13,
                            color: isActive ? appColors.foreground : appColors.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (tab.title == 'Dashboard' || 
                             tab.title == 'Inventory' || 
                             tab.title == 'Checkout POS' || 
                             tab.title == 'Rx Validate' || 
                             tab.title == 'Purchases PO' || 
                             tab.title == 'Suppliers List' || 
                             tab.title == 'Patients CRM' || 
                             tab.title == 'Rack Layout' || 
                             tab.title == 'Revenue OS' || 
                             tab.title == 'Reports Center' || 
                             tab.title == 'Staff Audit' || 
                             tab.title == 'Inbox Notifications' || 
                             tab.title == 'OS Settings') ? context.tr('nav.${tab.moduleId}') : tab.title,
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? appColors.foreground : appColors.mutedForeground,
                              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          if (!tab.pinned) ...[
                            const SizedBox(width: 6),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => workspace.closeTab(groupIndex, tab.id),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 11,
                                  color: appColors.mutedForeground.withValues(alpha: isActive ? 1.0 : 0.5),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dropdown menu for adding tabs
            PopupMenuButton<String>(
              icon: Icon(LucideIcons.plus, size: 14, color: appColors.mutedForeground),
              tooltip: context.tr('tab.new'),
              offset: const Offset(0, 30),
              itemBuilder: (context) {
                return addableModules.map((m) {
                  return PopupMenuItem(
                    value: m['id'] as String,
                    child: Row(
                      children: [
                        Icon(m['icon'] as IconData, size: 14),
                        const SizedBox(width: 8),
                        Text(context.tr('nav.${m['id']}'), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList();
              },
              onSelected: (moduleId) {
                workspace.openTab(moduleId);
              },
            ),

            if (workspace.groups.length > 1) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => workspace.closeSplit(groupIndex),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(60, 24),
                ),
                child: Text(
                  context.tr('tab.close_split'),
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                    color: appColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
