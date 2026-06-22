import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  List<ActivityEvent> _activities = [];
  List<ActivityEvent> _filteredActivities = [];

  // Filter States
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all';
  String _selectedSeverity = 'all';

  @override
  void initState() {
    super.initState();
    _fetchActivities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await _db.request<List<ActivityEvent>>('activities');
      if (mounted) {
        setState(() {
          _activities = data;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _applyFilters() {
    List<ActivityEvent> temp = _activities;

    // Search query filter
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((a) {
        return a.message.toLowerCase().contains(_searchQuery) ||
            a.actor.toLowerCase().contains(_searchQuery) ||
            a.type.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Type filter
    if (_selectedType != 'all') {
      temp = temp.where((a) => a.type.toLowerCase() == _selectedType).toList();
    }

    // Severity filter
    if (_selectedSeverity != 'all') {
      temp = temp.where((a) => (a.severity ?? 'info').toLowerCase() == _selectedSeverity).toList();
    }

    _filteredActivities = temp;
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

  String _formatFullDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sale':
        return LucideIcons.shoppingCart;
      case 'inventory':
        return LucideIcons.package;
      case 'prescription':
        return LucideIcons.fileSpreadsheet;
      case 'purchase':
        return LucideIcons.truck;
      case 'user':
        return LucideIcons.user;
      case 'system':
        return LucideIcons.settings;
      default:
        return LucideIcons.info;
    }
  }

  BadgeVariant _getSeverityVariant(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
        return BadgeVariant.danger;
      case 'warning':
        return BadgeVariant.warning;
      case 'info':
      default:
        return BadgeVariant.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (_loading && _activities.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.history,
            title: context.tr('nav.activities'),
            subtitle: 'Real-time audit log of database mutations, sales, and system events',
            actions: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.foreground,
                foregroundColor: appColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: _fetchActivities,
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Refresh Logs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appColors.surface1,
              border: Border(bottom: BorderSide(color: appColors.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final filterWidgets = [
                  // Search Input
                  Expanded(
                    flex: isWide ? 2 : 1,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search by message, actor, or type...',
                        prefixIcon: Icon(LucideIcons.search, size: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),

                  // Type Dropdown
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      style: TextStyle(color: appColors.foreground, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Event Type',
                        prefixIcon: Icon(LucideIcons.filter, size: 14),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Types')),
                        DropdownMenuItem(value: 'sale', child: Text('Sales')),
                        DropdownMenuItem(value: 'inventory', child: Text('Inventory')),
                        DropdownMenuItem(value: 'prescription', child: Text('Prescriptions')),
                        DropdownMenuItem(value: 'purchase', child: Text('Purchase Orders')),
                        DropdownMenuItem(value: 'user', child: Text('User Actions')),
                        DropdownMenuItem(value: 'system', child: Text('System Events')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedType = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),

                  // Severity Dropdown
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSeverity,
                      style: TextStyle(color: appColors.foreground, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Severity',
                        prefixIcon: Icon(LucideIcons.shieldAlert, size: 14),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Severities')),
                        DropdownMenuItem(value: 'info', child: Text('Info')),
                        DropdownMenuItem(value: 'warning', child: Text('Warning')),
                        DropdownMenuItem(value: 'critical', child: Text('Critical')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSeverity = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(children: filterWidgets);
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: filterWidgets.map((w) => w is Expanded ? w.child : w).toList(),
                  );
                }
              },
            ),
          ),

          // Logs List Area
          Expanded(
            child: _error
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.alertTriangle, size: 48, color: appColors.destructive),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load activities: $_errorMsg',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchActivities,
                          icon: const Icon(LucideIcons.refreshCw, size: 14),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredActivities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.history, size: 48, color: appColors.mutedForeground),
                            const SizedBox(height: 16),
                            Text(
                              'No activities match the current filters.',
                              style: TextStyle(fontSize: 14, color: appColors.mutedForeground),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredActivities.length,
                        itemBuilder: (context, idx) {
                          final a = _filteredActivities[idx];
                          final severityVariant = _getSeverityVariant(a.severity);
                          final icon = _getTypeIcon(a.type);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: appColors.surface1,
                              border: Border.all(color: appColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  color: appColors.background,
                                  border: Border.all(color: appColors.border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(icon, size: 16, color: appColors.mutedForeground),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: appColors.foreground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(
                                    text: (a.severity ?? 'info').toUpperCase(),
                                    variant: severityVariant,
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(LucideIcons.user, size: 10, color: appColors.mutedForeground),
                                        const SizedBox(width: 4),
                                        Text(
                                          a.actor,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: appColors.mutedForeground,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(LucideIcons.tag, size: 10, color: appColors.mutedForeground),
                                        const SizedBox(width: 4),
                                        Text(
                                          a.type.toUpperCase(),
                                          style: AppTheme.mono(
                                            fontSize: 10,
                                            color: appColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Tooltip(
                                      message: _formatFullDate(a.at),
                                      child: Text(
                                        _formatTime(a.at),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: appColors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
