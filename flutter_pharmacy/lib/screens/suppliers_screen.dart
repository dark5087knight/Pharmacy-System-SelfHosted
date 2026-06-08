import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../widgets/data_table.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';


class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;
  bool _sheetOpen = false;

  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  void _fetchSuppliers() async {
    final res = await _db.request<List<Supplier>>('suppliers');
    if (mounted) {
      setState(() {
        _suppliers = res;
        _loading = false;
      });
    }
  }

  void _openCreateSheet() {
    setState(() {
      _selectedSupplier = null;
      _companyController.clear();
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
      _balanceController.text = '0.00';
      _sheetOpen = true;
    });
  }

  void _openEditSheet(Supplier s) {
    setState(() {
      _selectedSupplier = s;
      _companyController.text = s.company;
      _nameController.text = s.name;
      _phoneController.text = s.phone;
      _emailController.text = s.email;
      _addressController.text = s.address;
      _balanceController.text = s.outstandingBalance.toString();
      _sheetOpen = true;
    });
  }

  void _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final bal = double.tryParse(_balanceController.text) ?? 0.0;
      final db = ApiService();
      if (_selectedSupplier == null) {
        final s = Supplier(
          id: 'sup_${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text,
          company: _companyController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          rating: 5.0,
          outstandingBalance: bal,
          totalPurchased: 0.0,
          status: 'active',
        );
        await db.createSupplier(s);
      } else {
        final updatedSupplier = _selectedSupplier!.copyWith(
          company: _companyController.text,
          name: _nameController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          address: _addressController.text,
          outstandingBalance: bal,
        );
        await db.updateSupplier(updatedSupplier);
      }
      _fetchSuppliers();
      setState(() {
        _sheetOpen = false;
      });
    }
  }

  void _onBulkDeleteSuppliers(List<Supplier> selected) {
    if (selected.isEmpty) return;
    showDialog<bool>(
      context: context,
      builder: (context) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        return AlertDialog(
          title: const Text('Bulk Delete Suppliers'),
          content: Text('Are you sure you want to delete ${selected.length} suppliers?'),
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
        final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
        try {
          for (final s in selected) {
            await _db.deleteSupplier(s.id);
          }
          _fetchSuppliers();
          workspace.showNotification(
            title: 'Bulk Deletion',
            body: 'Successfully deleted ${selected.length} suppliers.',
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

  void _deleteSupplier() async {
    if (_selectedSupplier == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final appColors = Theme.of(context).extension<AppColors>()!;
        return AlertDialog(
          title: Text(context.tr('staff.delete_title')),
          content: Text(context.tr('staff.delete_confirm', args: {'name': _selectedSupplier!.name})),
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
    );

    if (confirm == true) {
      try {
        await _db.deleteSupplier(_selectedSupplier!.id);
        setState(() {
          _sheetOpen = false;
          _selectedSupplier = null;
        });
        _fetchSuppliers();
        if (mounted) {
          Provider.of<WorkspaceProvider>(context, listen: false).showNotification(
            title: 'Supplier Deleted',
            body: 'Supplier removed successfully.',
            category: 'system',
          );
        }
      } catch (e) {
        if (mounted) {
          Provider.of<WorkspaceProvider>(context, listen: false).showNotification(
            title: 'Error',
            body: e.toString().replaceAll('Exception: ', ''),
            category: 'error',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  icon: LucideIcons.truck,
                  title: context.tr('sup.title'),
                  subtitle: context.tr('sup.subtitle'),
                  actions: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColors.foreground,
                      foregroundColor: appColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _openCreateSheet,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: Text(context.tr('sup.add_btn'), style: const TextStyle(fontSize: 12)),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: DataTableWidget<Supplier>(
                      data: _suppliers,
                      getRowId: (s) => s.id,
                      searchKeys: (s) => [s.company, s.name, s.phone, s.email],
                      onRowClick: (s) => _openEditSheet(s),
                      onBulkDelete: _onBulkDeleteSuppliers,
                      columns: [

                        DataTableColumn(
                          key: 'company',
                          header: context.tr('sup.col.company'),
                          sortValue: (s) => s.company,
                          cellBuilder: (s) => Text(s.company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        DataTableColumn(
                          key: 'contact',
                          header: context.tr('sup.col.contact'),
                          cellBuilder: (s) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.name, style: const TextStyle(fontSize: 12)),
                              Text(s.email, style: TextStyle(fontSize: 10, color: appColors.mutedForeground)),
                            ],
                          ),
                        ),
                        DataTableColumn(
                          key: 'balance',
                          header: context.tr('sup.col.balance'),
                          sortValue: (s) => s.outstandingBalance,
                          cellBuilder: (s) => Text(
                            '\$${s.outstandingBalance.toStringAsFixed(2)}',
                            style: AppTheme.mono(
                              fontSize: 12,
                              color: s.outstandingBalance > 0 ? appColors.destructive : appColors.foreground,
                              fontWeight: s.outstandingBalance > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        DataTableColumn(
                          key: 'volume',
                          header: context.tr('sup.col.volume'),
                          sortValue: (s) => s.totalPurchased,
                          cellBuilder: (s) => Text('\$${s.totalPurchased.toStringAsFixed(2)}', style: AppTheme.mono(fontSize: 12)),
                        ),
                        DataTableColumn(
                          key: 'rating',
                          header: context.tr('sup.col.score'),
                          sortValue: (s) => s.rating,
                          cellBuilder: (s) => Row(
                            children: [
                              Icon(Icons.star, size: 12, color: appColors.warning),
                              const SizedBox(width: 4),
                              Text(s.rating.toString(), style: AppTheme.mono(fontSize: 12)),
                            ],
                          ),
                        ),
                        DataTableColumn(
                          key: 'status',
                          header: context.tr('sup.col.status'),
                          cellBuilder: (s) => StatusBadge(
                            text: s.status == 'active' ? context.tr('status.active') : s.status,
                            variant: s.status == 'active' ? BadgeVariant.success : BadgeVariant.outline,
                          ),
                        ),
                      ],
                      rowActionBuilder: (s) {
                        return IconButton(
                          icon: const Icon(LucideIcons.edit, size: 14),
                          onPressed: () => _openEditSheet(s),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_sheetOpen) ...[
            Container(width: 1, color: appColors.border),
            Container(
              width: 380,
              color: appColors.surface1,
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedSupplier == null ? context.tr('sup.form.add') : context.tr('sup.form.edit'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () => setState(() => _sheetOpen = false),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: [
                          if (_selectedSupplier != null) ...[
                            Text(
                              'ID: ${_selectedSupplier!.id}',
                              style: TextStyle(
                                fontSize: 10,
                                color: appColors.mutedForeground,
                                fontFamily: AppTheme.mono().fontFamily,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildField(context.tr('sup.form.company'), _companyController, required: true),
                          _buildField(context.tr('sup.form.agent'), _nameController, required: true),
                          _buildField(context.tr('sup.form.phone'), _phoneController, required: true),
                          _buildField(context.tr('sup.form.email'), _emailController, required: true),
                          _buildField(context.tr('sup.form.address'), _addressController),
                          _buildField(context.tr('sup.form.balance'), _balanceController, number: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.foreground,
                        foregroundColor: appColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _saveForm,
                      child: Text(context.tr('sup.form.save'), style: const TextStyle(fontSize: 12)),
                    ),
                    if (_selectedSupplier != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: appColors.destructive,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _deleteSupplier,
                        icon: const Icon(LucideIcons.trash2, size: 14),
                        label: Text(context.tr('staff.delete'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool required = false, bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: const TextStyle(fontSize: 12),
            validator: required
                ? (val) => val == null || val.trim().isEmpty ? context.tr('inventory.required_field') : null
                : null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}
