import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../theme/theme.dart';
import 'tab_bar.dart';

// Screens imports
import '../screens/dashboard_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/medicine_details_screen.dart';
import '../screens/pos_screen.dart';
import '../screens/prescriptions_screen.dart';
import '../screens/warehouse_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/staff_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';

class TabHost extends StatelessWidget {
  const TabHost({super.key});

  Widget _buildScreen(String moduleId, Map<String, dynamic>? params) {
    switch (moduleId) {
      case 'dashboard':
        return const DashboardScreen();
      case 'inventory':
        return const InventoryScreen();
      case 'medicine-details':
        final id = params?['id'] as String? ?? '';
        return MedicineDetailsScreen(medicineId: id);
      case 'pos':
        return const PointOfSaleScreen();
      case 'prescriptions':
        return const PrescriptionsScreen();
      case 'warehouse':
        return const WarehouseScreen();
      case 'suppliers':
        return const SuppliersScreen();
      case 'staff':
        return const StaffScreen();
      case 'finance':
        return const FinanceScreen();
      case 'reports':
        return const ReportsScreen();
      case 'notifications':
        return const NotificationsScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return Center(
          child: Text('Module "$moduleId" is not implemented yet.'),
        );
    }
  }

  Widget _buildGroupView(BuildContext context, int groupIndex, AppColors appColors) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final group = workspace.groups[groupIndex];
    final activeTab = group.tabs.firstWhere(
      (t) => t.id == group.activeTabId,
      orElse: () => group.tabs[0],
    );

    return Container(
      color: appColors.background,
      child: Column(
        children: [
          WorkspaceTabBar(groupIndex: groupIndex),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(activeTab.id),
              child: _buildScreen(activeTab.moduleId, activeTab.params),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (workspace.groups.isEmpty) {
      return const Center(child: Text('Workspace empty. Open a tab to start.'));
    }

    if (workspace.groups.length == 1) {
      return _buildGroupView(context, 0, appColors);
    }

    // Split screen side-by-side layout
    return Row(
      children: [
        Expanded(
          child: _buildGroupView(context, 0, appColors),
        ),
        Container(
          width: 1,
          color: appColors.border,
        ),
        Expanded(
          child: _buildGroupView(context, 1, appColors),
        ),
      ],
    );
  }
}
