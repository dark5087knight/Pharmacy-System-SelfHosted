import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/page_header.dart';
import '../widgets/status_badge.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class PointOfSaleScreen extends StatefulWidget {
  const PointOfSaleScreen({super.key});

  @override
  State<PointOfSaleScreen> createState() => _PointOfSaleScreenState();
}

class _PointOfSaleScreenState extends State<PointOfSaleScreen> {
  final ApiService _db = ApiService();
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  List<Medicine> _medicines = [];
  
  // Search query
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  
  // Active tab on narrow screens
  int _activePosTab = 0;

  // Cart width in wide screens
  double _cartWidth = 380.0;

  @override
  void initState() {
    super.initState();
    _loadCartWidth();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final meds = await _db.request<List<Medicine>>('medicines?q=${Uri.encodeComponent(query)}');
        if (mounted) {
          setState(() {
            _medicines = meds;
          });
        }
      } catch (_) {}
    });
  }

  void _loadCartWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final w = prefs.getDouble('pos_cart_width');
    if (w != null && mounted) {
      setState(() {
        _cartWidth = w;
      });
    }
  }

  void _saveCartWidth(double w) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pos_cart_width', w);
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final meds = await _db.request<List<Medicine>>('medicines');
      if (mounted) {
        setState(() {
          _medicines = meds;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (showLoading) {
            _error = true;
            _errorMsg = e.toString().replaceAll('Exception: ', '');
          }
        });
      }
    }
  }

  double getSubtotal(WorkspaceProvider workspace) => workspace.posCart.fold(0.0, (s, x) => s + x.unitPrice * x.quantity);
  double getDiscount(WorkspaceProvider workspace) => workspace.posCart.fold(0.0, (s, x) => s + (x.unitPrice * x.quantity * x.discount) / 100);
  double getTax(WorkspaceProvider workspace) => workspace.posCart.fold(0.0, (s, x) => s + (x.unitPrice * x.quantity * x.taxRate) / 100);
  double getTotal(WorkspaceProvider workspace) => getSubtotal(workspace) - getDiscount(workspace) + getTax(workspace);

  void _onCartQtyChanged(int index, String val, WorkspaceProvider workspace) {
    final parsed = int.tryParse(val);
    if (parsed == null) return;
    workspace.updatePosCartQtyDirect(index, parsed);
  }

  void _showReturnDialog() {
    final appColors = Theme.of(context).extension<AppColors>()!;
    Medicine? selectedReturnMed;

    final qtyController = TextEditingController(text: '1');
    bool isSaving = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: appColors.surface1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Icon(LucideIcons.undo, color: appColors.destructive, size: 20),
                const SizedBox(width: 8),
                const Text('Process Product Return', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorMsg != null) ...[
                    Text(errorMsg!, style: TextStyle(color: appColors.destructive, fontSize: 12)),
                    const SizedBox(height: 12),
                  ],
                  const Text('Select Medicine', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Autocomplete<Medicine>(
                    displayStringForOption: (Medicine m) => '${m.name} (${m.brand})',
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Medicine>.empty();
                      }
                      return _medicines.where((m) =>
                          m.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                          m.brand.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (Medicine selection) {
                      setDialogState(() {
                        selectedReturnMed = selection;
                      });
                    },
                    fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Type medicine name...',
                          isDense: true,
                          contentPadding: EdgeInsets.all(10),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  const Text('Returned Quantity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text(context.tr('pos.dialog.cancel'), style: TextStyle(color: appColors.mutedForeground)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.destructive,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final qty = int.tryParse(qtyController.text) ?? 0;
                        final custName = 'Walk-in Customer';
                        if (selectedReturnMed == null) {
                          setDialogState(() => errorMsg = 'Please select a medicine.');
                          return;
                        }
                        if (qty <= 0) {
                          setDialogState(() => errorMsg = 'Returned quantity must be greater than 0.');
                          return;
                        }
                        setDialogState(() {
                          isSaving = true;
                          errorMsg = null;
                        });

                        final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
                        final currentUser = workspace.currentUser;
                        final nav = Navigator.of(context);

                        try {
                          await _db.processReturn(selectedReturnMed!.id, custName, qty);
                          
                          final act = ActivityEvent(
                            id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
                            type: 'sale',
                            message: 'Product return processed: ${selectedReturnMed!.name} (Qty: $qty) from $custName',
                            actor: currentUser?.name ?? 'System',
                            at: DateTime.now().toIso8601String(),
                            severity: 'info',
                          );
                          await _db.addActivity(act);

                          if (nav.context.mounted) {
                            nav.pop();
                            _loadData(showLoading: false);
                            workspace.showNotification(
                              title: 'Return Processed',
                              body: 'Successfully returned $qty x ${selectedReturnMed!.name}',
                              category: 'payment',
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMsg = e.toString().replaceAll('Exception: ', '');
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Confirm Return', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  void _checkout(WorkspaceProvider workspace) async {
    if (workspace.posCart.isEmpty) return;

    final toastTitle = context.tr('pos.toast.success_title');
    final toastBody = context.tr('pos.toast.success_body');

    final appColors = Theme.of(context).extension<AppColors>()!;
    final totalVal = getTotal(workspace);
    final subtotalVal = getSubtotal(workspace);
    final discountVal = getDiscount(workspace);
    final taxVal = getTax(workspace);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String method = 'card';
        final controller = TextEditingController(text: totalVal.toStringAsFixed(2));
        
        return StatefulBuilder(builder: (context, setDialogState) {
          final amt = double.tryParse(controller.text) ?? 0.0;
          final change = amt - totalVal;
          return AlertDialog(
            title: Text(context.tr('pos.dialog.title'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.tr('pos.dialog.payment_method'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['cash', 'card', 'insurance'].map((m) {
                      final isSel = method == m;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 36,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isSel ? appColors.foreground : Colors.transparent,
                              side: BorderSide(color: isSel ? appColors.foreground : appColors.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () => setDialogState(() => method = m),
                            child: Text(
                              m.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSel ? appColors.background : appColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('pos.dialog.amount_received'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(isDense: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('pos.dialog.total'), style: const TextStyle(fontSize: 12)),
                      Text(totalVal.toIQD(), style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.tr('pos.dialog.change'), style: const TextStyle(fontSize: 12)),
                      Text(
                        change >= 0 ? change.toIQD() : '0 IQD',
                        style: AppTheme.mono(fontSize: 12, color: change >= 0 ? appColors.success : appColors.destructive, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('pos.dialog.cancel'), style: TextStyle(color: appColors.mutedForeground)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.foreground,
                  foregroundColor: appColors.background,
                ),
                onPressed: () => Navigator.pop(context, {'method': method, 'paid': amt}),
                child: Text(context.tr('pos.dialog.confirm'), style: const TextStyle(fontSize: 12)),
              ),
            ],
          );
        });
      },
    );

    if (result != null) {
      final currentUser = workspace.currentUser;
      final invNum = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final sale = Sale(
        id: 'sale_${DateTime.now().millisecondsSinceEpoch}',
        invoiceNumber: invNum,
        customerId: workspace.posSelectedCustomer?.id,
        cashierId: currentUser?.id ?? 'stf_0001',
        items: workspace.posCart.map((it) => SaleItem(
          medicineId: it.medicineId,
          name: it.name,
          quantity: it.quantity,
          unitPrice: it.unitPrice,
          discount: it.discount,
          taxRate: it.taxRate,
        )).toList(),
        subtotal: double.parse(subtotalVal.toStringAsFixed(2)),
        discount: double.parse(discountVal.toStringAsFixed(2)),
        tax: double.parse(taxVal.toStringAsFixed(2)),
        total: double.parse(totalVal.toStringAsFixed(2)),
        paymentMethod: result['method'] as String,
        status: 'completed',
        createdAt: DateTime.now().toIso8601String(),
      );

      final event = ActivityEvent(
        id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
        type: 'sale',
        message: 'POS checkout sale completed ($invNum)',
        actor: currentUser?.name ?? 'System',
        at: DateTime.now().toIso8601String(),
        severity: 'info',
      );

      workspace.clearPosCart();
      setState(() {});

      try {
        await _db.addSale(sale);
        await _db.addActivity(event);
        await _loadData(showLoading: false);
        
        if (mounted) {
          final printReceipt = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              final ac = Theme.of(context).extension<AppColors>()!;
              return AlertDialog(
                backgroundColor: ac.surface1,
                title: const Text('Sale Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                content: const Text('Would you like to generate and save the PDF receipt/bill for this sale?', style: TextStyle(fontSize: 12)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Skip', style: TextStyle(color: ac.mutedForeground)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ac.foreground,
                      foregroundColor: ac.background,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Generate PDF', style: TextStyle(fontSize: 12)),
                  ),
                ],
              );
            }
          );
          if (printReceipt == true && mounted) {
            await _generateReceiptPdf(context, sale);
          }
        }
      } catch (e) {
        debugPrint(e.toString());
      }

      if (!mounted) return;
      workspace.showNotification(
        title: toastTitle,
        body: toastBody,
        category: 'payment',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load POS: $_errorMsg',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredProducts = _medicines.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.brand.toLowerCase().contains(q) ||
          m.barcode.contains(q);
    }).toList();

    filteredProducts.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    final subtotal = getSubtotal(workspace);
    final discount = getDiscount(workspace);
    final tax = getTax(workspace);
    final total = getTotal(workspace);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 950;

          final catalogWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                icon: LucideIcons.shoppingCart,
                title: context.tr('pos.title'),
                subtitle: context.tr('pos.subtitle'),
                actions: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: appColors.destructive,
                      ),
                      onPressed: _showReturnDialog,
                      icon: const Icon(LucideIcons.undo, size: 14),
                      label: const Text('Process Return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    if (workspace.posHeldCarts.isNotEmpty) ...[
                      PopupMenuButton<int>(
                        icon: Badge(
                          label: Text(workspace.posHeldCarts.length.toString()),
                          child: Icon(LucideIcons.history, color: appColors.mutedForeground, size: 18),
                        ),
                        tooltip: context.tr('pos.suspend'),
                        onSelected: workspace.recallPosCart,
                        itemBuilder: (context) {
                          return List.generate(workspace.posHeldCarts.length, (idx) {
                            final heldTotal = workspace.posHeldCarts[idx].fold<double>(0, (s, x) => s + x.unitPrice * x.quantity);
                            return PopupMenuItem(
                              value: idx,
                              child: Text('${context.tr('pos.suspend')} #${idx + 1} (${workspace.posHeldCarts[idx].length} - ${heldTotal.toIQD()})'),
                            );
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _onSearchChanged(val);
                  },
                  onSubmitted: (val) async {
                    final code = val.trim();
                    if (code.isEmpty) return;

                    Medicine? matchedMed;
                    try {
                      matchedMed = _medicines.firstWhere((m) => m.barcode == code);
                    } catch (_) {
                      matchedMed = await ApiService().lookupByBarcode(code);
                    }

                    if (!context.mounted) return;

                    if (matchedMed != null) {
                      workspace.addToPosCart(matchedMed, context);
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _searchFocusNode.requestFocus();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No medicine found for barcode: $code'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.tr('pos.search_hint'),
                    prefixIcon: const Icon(LucideIcons.search, size: 14),
                    fillColor: appColors.surface1,
                  ),
                ),
              ),

              // Grid Catalog
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final m = filteredProducts[index];
                    final isLow = m.quantity <= m.lowStockThreshold;
                    final isOut = m.quantity == 0;

                    return InkWell(
                      onTap: () => workspace.addToPosCart(m, context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: appColors.surface1,
                          border: Border.all(color: appColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    m.name,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (m.prescriptionRequired) ...[
                                  const StatusBadge(text: 'Rx', variant: BadgeVariant.warning),
                                  const SizedBox(width: 4),
                                ],
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () async {
                                      setState(() {
                                        final idx = _medicines.indexWhere((x) => x.id == m.id);
                                        if (idx != -1) {
                                          _medicines[idx] = m.copyWith(isPinned: !m.isPinned);
                                        }
                                      });
                                      try {
                                        final updated = m.copyWith(isPinned: !m.isPinned);
                                        await _db.updateMedicine(updated);
                                        _loadData(showLoading: false);
                                      } catch (_) {
                                        _loadData(showLoading: false);
                                      }
                                    },
                                    child: Icon(
                                      m.isPinned ? LucideIcons.pin : LucideIcons.pinOff,
                                      size: 11,
                                      color: m.isPinned ? appColors.foreground : appColors.mutedForeground.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              m.brand,
                              style: TextStyle(fontSize: 10, color: appColors.mutedForeground),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  m.sellingPrice.toIQD(),
                                  style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  isOut ? context.tr('inventory.filter.out').toUpperCase() : '${m.quantity} ${context.tr('wh.total_qty').replaceAll('إجمالي القطع: {count}', '').replaceAll('Total Quantity: {count}', '').trim()}',
                                  style: AppTheme.mono(
                                    fontSize: 10,
                                    color: isOut ? appColors.destructive : (isLow ? appColors.warning : appColors.mutedForeground),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );

          final cartWidget = Container(
            width: double.infinity,
            height: double.infinity,
            color: appColors.surface1,
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
                      const Icon(LucideIcons.shoppingBag, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('pos.cart_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      if (workspace.posCart.isNotEmpty)
                        TextButton(
                          onPressed: workspace.clearPosCart,
                          child: Text(context.tr('pos.reset'), style: TextStyle(fontSize: 10, color: appColors.destructive)),
                        ),
                    ],
                  ),
                ),

                // Cart item list
                Expanded(
                  child: workspace.posCart.isEmpty
                      ? Center(
                          child: Text(
                            context.tr('pos.empty_cart'),
                            style: TextStyle(color: appColors.mutedForeground, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: workspace.posCart.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: appColors.border),
                          itemBuilder: (context, index) {
                            final it = workspace.posCart[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.name,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${it.unitPrice.toIQD()} ${context.tr('pos.each')}',
                                          style: TextStyle(fontSize: 11, color: appColors.mutedForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(LucideIcons.minus, size: 12),
                                        onPressed: () => workspace.updatePosCartQty(index, -1),
                                      ),
                                      SizedBox(
                                        width: 38,
                                        child: TextField(
                                          controller: it.controller ??= TextEditingController(text: it.quantity.toString()),
                                          focusNode: it.focusNode ??= FocusNode(),
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.bold),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) => _onCartQtyChanged(index, val, workspace),
                                        ),
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(LucideIcons.plus, size: 12),
                                        onPressed: () => workspace.updatePosCartQty(index, 1),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (it.unitPrice * it.quantity).toIQD(),
                                    style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(LucideIcons.trash2, size: 12, color: appColors.destructive),
                                    onPressed: () => workspace.removeFromPosCart(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Financial sums and checkout buttons
                Container(
                  decoration: BoxDecoration(
                    color: appColors.background,
                    border: Border(top: BorderSide(color: appColors.border)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sumRow(context.tr('pos.subtotal'), subtotal.toIQD(), appColors),
                      _sumRow(context.tr('pos.discount'), '-${discount.toIQD()}', appColors),
                      _sumRow(context.tr('pos.tax'), '+${tax.toIQD()}', appColors),
                      const Divider(),
                      _sumRow(context.tr('pos.total'), total.toIQD(), appColors, isBold: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: workspace.holdPosCart,
                              child: Text(context.tr('pos.suspend').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appColors.foreground,
                                foregroundColor: appColors.background,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () => _checkout(workspace),
                              child: Text(context.tr('pos.checkout').toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (isWide) {
            final maxCartWidth = constraints.maxWidth * 0.6;
            final minCartWidth = 280.0;
            final clampedCartWidth = _cartWidth.clamp(minCartWidth, maxCartWidth);
            if (_cartWidth != clampedCartWidth) {
              _cartWidth = clampedCartWidth;
            }

            return Row(
              children: [
                Expanded(child: catalogWidget),
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
                    final delta = details.delta.dx;
                    Future.microtask(() {
                      if (mounted) {
                        setState(() {
                          if (isRtl) {
                            _cartWidth = (_cartWidth + delta).clamp(minCartWidth, maxCartWidth);
                          } else {
                            _cartWidth = (_cartWidth - delta).clamp(minCartWidth, maxCartWidth);
                          }
                        });
                        _saveCartWidth(_cartWidth);
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
                  width: clampedCartWidth,
                  child: cartWidget,
                ),
              ],
            );
          } else {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: appColors.surface1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: appColors.border),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activePosTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activePosTab == 0 ? appColors.background : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _activePosTab == 0 ? [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                              ] : null,
                            ),
                            child: Center(
                                child: Text(
                                context.tr('pos.tab.grid'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activePosTab == 0 ? appColors.foreground : appColors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _activePosTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activePosTab == 1 ? appColors.background : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _activePosTab == 1 ? [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                              ] : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.tr('pos.tab.cart'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _activePosTab == 1 ? appColors.foreground : appColors.mutedForeground,
                                    ),
                                  ),
                                  if (workspace.posCart.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: appColors.foreground,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${workspace.posCart.length}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: appColors.background,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _activePosTab == 0 ? catalogWidget : cartWidget,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _sumRow(String label, String value, AppColors appColors, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isBold ? appColors.foreground : appColors.mutedForeground,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: AppTheme.mono(
              fontSize: 12,
              color: appColors.foreground,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReceiptPdf(BuildContext context, Sale sale) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;
      
      final pdf = pw.Document();
      final df = DateFormat('yyyy-MM-dd HH:mm');
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text('Caduceus Pharmacy', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Invoice: ${sale.invoiceNumber}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Date: ${df.format(DateTime.parse(sale.createdAt))}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Cashier: ${sale.cashierId}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Divider(thickness: 0.5),
                  
                  // Items Table
                  pw.TableHelper.fromTextArray(
                    border: null,
                    headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                    cellStyle: const pw.TextStyle(fontSize: 7),
                    headers: ['Item', 'Qty', 'Price', 'Total'],
                    data: sale.items.map((it) => [
                      it.name,
                      it.quantity.toString(),
                      it.unitPrice.toIQD(),
                      (it.quantity * it.unitPrice).toIQD(),
                    ]).toList(),
                  ),
                  pw.Divider(thickness: 0.5),
                  
                  // Totals
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Subtotal: ${sale.subtotal.toIQD()}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Tax: ${sale.tax.toIQD()}', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Total: ${sale.total.toIQD()}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  
                  // Barcode containing invoice number!
                  pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      children: [
                        pw.BarcodeWidget(
                          data: sale.invoiceNumber,
                          barcode: pw.Barcode.code128(),
                          width: 140,
                          height: 40,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(sale.invoiceNumber, style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      
      final fullPath = '$path\\receipt_${sale.invoiceNumber}.pdf';
      final file = File(fullPath);
      await file.writeAsBytes(await pdf.save());
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Receipt saved: receipt_${sale.invoiceNumber}.pdf'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generating receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
