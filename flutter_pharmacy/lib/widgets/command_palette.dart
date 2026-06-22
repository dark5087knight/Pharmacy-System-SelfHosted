import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<Medicine> _meds = [];
  List<Supplier> _sup = [];

  final List<Map<String, dynamic>> _modules = [
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
    {'id': 'activities', 'label': 'System Activities', 'icon': LucideIcons.history},
    {'id': 'settings', 'label': 'OS Settings', 'icon': LucideIcons.settings},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final db = ApiService();
    try {
      final meds = await db.request<List<Medicine>>('medicines');
      final sup = await db.request<List<Supplier>>('suppliers');
      if (mounted) {
        setState(() {
          _meds = meds;
          _sup = sup;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (!workspace.commandOpen) return const SizedBox.shrink();

    // Filter results
    final queryLower = _query.toLowerCase();
    
    final role = workspace.currentUser?.role ?? 'cashier';
    final filteredModules = _modules.where((m) {
      final id = m['id'] as String;
      if (role == 'admin') return true;
      if (role == 'manager') {
        return const ['dashboard', 'inventory', 'pos', 'prescriptions', 'warehouse', 'suppliers', 'reports', 'notifications', 'activities'].contains(id);
      }
      if (role == 'pharmacist') {
        return const ['dashboard', 'inventory', 'pos', 'prescriptions', 'warehouse', 'notifications', 'activities'].contains(id);
      }
      if (role == 'cashier') {
        return const ['pos', 'notifications'].contains(id);
      }
      return false;
    }).where((m) {
      final labelEn = m['label'].toString().toLowerCase();
      final labelTr = context.tr('nav.${m['id']}').toLowerCase();
      return labelEn.contains(queryLower) || labelTr.contains(queryLower);
    }).toList();

    final filteredMeds = _meds.where((m) =>
        m.name.toLowerCase().contains(queryLower) ||
        m.brand.toLowerCase().contains(queryLower) ||
        m.genericName.toLowerCase().contains(queryLower)).take(8).toList();

    final filteredSup = _sup.where((s) =>
        s.company.toLowerCase().contains(queryLower) ||
        s.name.toLowerCase().contains(queryLower)).take(5).toList();

    final hasResults = filteredModules.isNotEmpty ||
        filteredMeds.isNotEmpty ||
        filteredSup.isNotEmpty;

    return Stack(
      children: [
        // Backdrop overlay
        GestureDetector(
          onTap: () => workspace.setCommandOpen(false),
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),

        // Centered Dialogue Box
        Center(
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 480),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: appColors.surface1,
              border: Border.all(color: appColors.borderStrong),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Input Line
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: appColors.border)),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.search, size: 16, color: appColors.mutedForeground),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _query = val),
                          autofocus: true,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: context.tr('palette.search_placeholder'),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: appColors.border),
                          color: appColors.surface2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'ESC',
                          style: AppTheme.mono(fontSize: 9, color: appColors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results list
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      if (!hasResults)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              context.tr('palette.no_results'),
                              style: TextStyle(color: appColors.mutedForeground, fontSize: 12),
                            ),
                          ),
                        ),

                      // Modules
                      if (filteredModules.isNotEmpty) ...[
                        _buildHeader(context, context.tr('palette.header.modules'), appColors),
                        ...filteredModules.map((m) {
                          return _buildItem(
                            context,
                            icon: m['icon'] as IconData,
                            title: context.tr('nav.${m['id']}'),
                            onTap: () {
                              workspace.openTab(m['id'] as String);
                              workspace.setCommandOpen(false);
                            },
                            appColors: appColors,
                          );
                        }),
                      ],

                      // Medicines
                      if (filteredMeds.isNotEmpty) ...[
                        _buildHeader(context, context.tr('palette.header.medicines'), appColors),
                        ...filteredMeds.map((med) {
                          return _buildItem(
                            context,
                            icon: LucideIcons.pill,
                            title: med.name,
                            subtitle: '${med.brand} • ${med.quantity} ${med.unit}s',
                            onTap: () {
                              workspace.openTab(
                                'medicine-details',
                                title: med.name,
                                params: {'id': med.id},
                              );
                              workspace.setCommandOpen(false);
                            },
                            appColors: appColors,
                          );
                        }),
                      ],



                      // Suppliers
                      if (filteredSup.isNotEmpty) ...[
                        _buildHeader(context, context.tr('palette.header.suppliers'), appColors),
                        ...filteredSup.map((s) {
                          return _buildItem(
                            context,
                            icon: LucideIcons.truck,
                            title: s.company,
                            subtitle: s.name,
                            onTap: () {
                              workspace.openTab('suppliers');
                              workspace.setCommandOpen(false);
                            },
                            appColors: appColors,
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String title, AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 12, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: appColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required AppColors appColors,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: appColors.mutedForeground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: appColors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
