import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import 'dart:io';

import '../widgets/page_header.dart';
import '../widgets/charts.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Weekly sales activity matrix data
    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<String> hours = ['09:00', '12:00', '15:00', '18:00', '21:00'];
    final Map<String, double> matrix = {
      'Mon_12:00': 0.8, 'Mon_15:00': 0.5, 'Mon_18:00': 0.9,
      'Tue_12:00': 0.6, 'Tue_15:00': 0.7, 'Tue_18:00': 0.8,
      'Wed_12:00': 0.7, 'Wed_15:00': 0.9, 'Wed_18:00': 0.6,
      'Thu_12:00': 0.5, 'Thu_15:00': 0.6, 'Thu_18:00': 0.8,
      'Fri_12:00': 0.9, 'Fri_15:00': 1.0, 'Fri_18:00': 0.9,
      'Sat_12:00': 1.0, 'Sat_15:00': 0.9, 'Sat_18:00': 0.8,
      'Sun_12:00': 0.3, 'Sun_15:00': 0.4, 'Sun_18:00': 0.2,
    };

    final barData = [
      {'label': context.tr('months.jan'), 'revenue': 12000.0},
      {'label': context.tr('months.feb'), 'revenue': 14200.0},
      {'label': context.tr('months.mar'), 'revenue': 11800.0},
      {'label': context.tr('months.apr'), 'revenue': 16100.0},
      {'label': context.tr('months.may'), 'revenue': 18500.0},
      {'label': context.tr('months.jun'), 'revenue': 21000.0},
    ];

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.barChart2,
            title: context.tr('rep.title'),
            subtitle: context.tr('rep.subtitle'),
            actions: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.foreground,
                foregroundColor: appColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ReportGenerationDialog(),
                );
              },
              icon: const Icon(LucideIcons.fileSpreadsheet, size: 14),
              label: Text(
                context.tr('rep.export_btn'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // AI insights block
                Row(
                  children: [
                    Expanded(
                      child: _aiCard(
                        context.tr('rep.ai.amox_title'),
                        context.tr('rep.ai.amox_desc'),
                        appColors,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _aiCard(
                        context.tr('rep.ai.exp_title'),
                        context.tr('rep.ai.exp_desc'),
                        appColors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Charts
                Section(
                  title: context.tr('rep.chart.sales_title'),
                  children: MonoBar(
                    data: barData,
                    xKey: 'label',
                    yKey: 'revenue',
                  ),
                ),
                const SizedBox(height: 20),

                // Heatmap matrix
                Section(
                  title: context.tr('rep.chart.peak_title'),
                  children: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 60),
                          ...hours.map((h) => Expanded(
                                child: Text(
                                  h,
                                  style: TextStyle(fontSize: 10, color: appColors.mutedForeground, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...days.map((d) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 60,
                                child: Text(
                                  context.tr('days.${d.toLowerCase()}'),
                                  style: TextStyle(fontSize: 11, color: appColors.mutedForeground, fontWeight: FontWeight.w600),
                                ),
                              ),
                              ...hours.map((h) {
                                final val = matrix['${d}_$h'] ?? 0.05;
                                return Expanded(
                                  child: Container(
                                    height: 24,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: appColors.foreground.withValues(alpha: val),
                                      border: Border.all(color: appColors.border, width: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        val > 0.6 ? '${(val * 100).toStringAsFixed(0)}%' : '',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: val > 0.7 ? appColors.background : appColors.foreground,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiCard(String title, String desc, AppColors appColors) {
    return Container(
      decoration: BoxDecoration(
        color: appColors.surface1,
        border: Border.all(color: appColors.borderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 14, color: appColors.foreground),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(fontSize: 12, color: appColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class ReportGenerationDialog extends StatefulWidget {
  const ReportGenerationDialog({super.key});

  @override
  State<ReportGenerationDialog> createState() => _ReportGenerationDialogState();
}

class _ReportGenerationDialogState extends State<ReportGenerationDialog> {
  String _format = 'PDF';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  bool _includeIncome = true;
  bool _includeOutcome = true;
  bool _includeInventory = true;
  bool _includeSummary = true;

  String? _saveDirectory;
  bool _generating = false;

  Future<void> _pickDirectory() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        setState(() {
          _saveDirectory = path;
        });
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _generate() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (_saveDirectory == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please select a folder to save the report.')),
      );
      return;
    }
    setState(() {
      _generating = true;
    });

    try {
      List<Sale> sales = [];
      List<PurchaseOrder> pos = [];
      List<Medicine> medicines = [];

      final api = ApiService();
      if (_includeIncome || _includeSummary) {
        sales = await api.request<List<Sale>>('sales');
      }
      if (_includeOutcome || _includeSummary) {
        pos = await api.request<List<PurchaseOrder>>('purchase-orders');
      }
      if (_includeInventory || _includeSummary) {
        medicines = await api.request<List<Medicine>>('medicines');
      }

      final filteredSales = sales.where((s) {
        try {
          final dt = DateTime.parse(s.createdAt);
          return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(_endDate.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();

      final filteredPOs = pos.where((p) {
        try {
          final dt = DateTime.parse(p.createdAt);
          return dt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(_endDate.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();

      final dateStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final ext = _format.toLowerCase() == 'pdf' ? 'pdf' : 'xlsx';
      final fileName = 'pharmacy_report_$dateStr.$ext';
      final fullPath = '$_saveDirectory\\$fileName';

      if (_format == 'PDF') {
        await _compilePdf(fullPath, filteredSales, filteredPOs, medicines);
      } else {
        await _compileExcel(fullPath, filteredSales, filteredPOs, medicines);
      }

      if (mounted) {
        nav.pop(true);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Report generated successfully: $fileName'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  Future<void> _compilePdf(
    String path,
    List<Sale> sales,
    List<PurchaseOrder> pos,
    List<Medicine> medicines,
  ) async {
    final pdf = pw.Document();
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final dfShort = DateFormat('yyyy-MM-dd');

    final baseFont = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    final double totalRevenue = sales.fold(0.0, (sum, s) => sum + s.total);
    final double totalExpenses = pos.fold(0.0, (sum, p) => sum + p.total);
    final double stockValue = medicines.fold(0.0, (sum, m) => sum + (m.quantity * m.purchasePrice));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text('Caduceus Pharmacy OS - Operational Report', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Caduceus Pharmacy OS', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                pw.SizedBox(height: 4),
                pw.Text('OPERATIONAL PERFORMANCE REPORT', style: pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey800, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('Range: ${dfShort.format(_startDate)} to ${dfShort.format(_endDate)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Generated: ${df.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                pw.Divider(thickness: 1.5),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          if (_includeSummary) ...[
            pw.Text('Financial Performance Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
              data: [
                ['Metric Indicator', 'Amount Value (IQD)'],
                ['Total Revenue (Sales)', totalRevenue.toIQD()],
                ['Total Operational Costs (POs)', totalExpenses.toIQD()],
                ['Net Operating Income', (totalRevenue - totalExpenses).toIQD()],
                ['Estimated Wholesale Inventory Value', stockValue.toIQD()],
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          if (_includeIncome && sales.isNotEmpty) ...[
            pw.Text('Sales Ledger (Revenues)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              data: [
                ['Invoice #', 'Date', 'Payment Method', 'Status', 'Revenue (IQD)'],
                ...sales.map((s) => [
                  s.invoiceNumber,
                  s.createdAt.length >= 10 ? s.createdAt.substring(0, 10) : s.createdAt,
                  s.paymentMethod.toUpperCase(),
                  s.status.toUpperCase(),
                  s.total.toIQD(),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          if (_includeOutcome && pos.isNotEmpty) ...[
            pw.Text('Purchase Ledger (Procurements)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              data: [
                ['PO Code', 'Date', 'Status', 'Wholesale Cost (IQD)'],
                ...pos.map((p) => [
                  p.poNumber,
                  p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt,
                  p.status.toUpperCase(),
                  p.total.toIQD(),
                ]),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          if (_includeInventory && medicines.isNotEmpty) ...[
            pw.Text('Stock & Inventory Deposition', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              data: [
                ['SKU', 'Medication / Formula', 'Qty Stock', 'Buy Price', 'Sell Price', 'Expiry'],
                ...medicines.map((m) => [
                  m.sku,
                  m.name,
                  '${m.quantity} ${m.unit}s',
                  m.purchasePrice.toIQD(),
                  m.sellingPrice.toIQD(),
                  m.expiryDate.length >= 10 ? m.expiryDate.substring(0, 10) : m.expiryDate,
                ]),
              ],
            ),
          ],
        ],
      ),
    );

    final file = File(path);
    await file.writeAsBytes(await pdf.save());
  }

  Future<void> _compileExcel(
    String path,
    List<Sale> sales,
    List<PurchaseOrder> pos,
    List<Medicine> medicines,
  ) async {
    final excel = Excel.createExcel();

    if (_includeSummary) {
      final sheet = excel['Financial Summary'];
      sheet.appendRow([TextCellValue('Caduceus Pharmacy OS - Financial Summary')]);
      sheet.appendRow([TextCellValue('Period: ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}')]);
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue('Financial Metric'), TextCellValue('Value (IQD)')]);

      final double totalRevenue = sales.fold(0.0, (sum, s) => sum + s.total);
      final double totalExpenses = pos.fold(0.0, (sum, p) => sum + p.total);
      final double stockValue = medicines.fold(0.0, (sum, m) => sum + (m.quantity * m.purchasePrice));

      sheet.appendRow([TextCellValue('Total Revenue'), DoubleCellValue(totalRevenue)]);
      sheet.appendRow([TextCellValue('Total Expenses'), DoubleCellValue(totalExpenses)]);
      sheet.appendRow([TextCellValue('Net Operating Profit'), DoubleCellValue(totalRevenue - totalExpenses)]);
      sheet.appendRow([TextCellValue('Total Stock Valuation'), DoubleCellValue(stockValue)]);
    }

    if (_includeIncome && sales.isNotEmpty) {
      final sheet = excel['Revenues (Sales)'];
      sheet.appendRow([
        TextCellValue('Invoice Number'),
        TextCellValue('Date'),
        TextCellValue('Payment Method'),
        TextCellValue('Status'),
        TextCellValue('Total (IQD)'),
      ]);
      for (final s in sales) {
        sheet.appendRow([
          TextCellValue(s.invoiceNumber),
          TextCellValue(s.createdAt.length >= 10 ? s.createdAt.substring(0, 10) : s.createdAt),
          TextCellValue(s.paymentMethod.toUpperCase()),
          TextCellValue(s.status.toUpperCase()),
          DoubleCellValue(s.total),
        ]);
      }
    }

    if (_includeOutcome && pos.isNotEmpty) {
      final sheet = excel['Procurements (POs)'];
      sheet.appendRow([
        TextCellValue('PO Number'),
        TextCellValue('Date'),
        TextCellValue('Status'),
        TextCellValue('Total Cost (IQD)'),
      ]);
      for (final p in pos) {
        sheet.appendRow([
          TextCellValue(p.poNumber),
          TextCellValue(p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt),
          TextCellValue(p.status.toUpperCase()),
          DoubleCellValue(p.total),
        ]);
      }
    }

    if (_includeInventory && medicines.isNotEmpty) {
      final sheet = excel['Inventory Status'];
      sheet.appendRow([
        TextCellValue('SKU'),
        TextCellValue('Medication Name'),
        TextCellValue('Quantity'),
        TextCellValue('Purchase Price (IQD)'),
        TextCellValue('Selling Price (IQD)'),
        TextCellValue('Stock Value (IQD)'),
        TextCellValue('Expiry Date'),
      ]);
      for (final m in medicines) {
        sheet.appendRow([
          TextCellValue(m.sku),
          TextCellValue(m.name),
          IntCellValue(m.quantity),
          DoubleCellValue(m.purchasePrice),
          DoubleCellValue(m.sellingPrice),
          DoubleCellValue(m.quantity * m.purchasePrice),
          TextCellValue(m.expiryDate.length >= 10 ? m.expiryDate.substring(0, 10) : m.expiryDate),
        ]);
      }
    }

    if (excel.tables.containsKey('Sheet1') && excel.tables.length > 1) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final file = File(path);
      await file.writeAsBytes(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final df = DateFormat('yyyy-MM-dd');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: appColors.surface1,
          border: Border.all(color: appColors.borderStrong),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: appColors.border)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.fileSpreadsheet, size: 20, color: appColors.foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('rep.dialog.title'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: appColors.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // File format selector
                    Text(
                      context.tr('rep.dialog.format'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: appColors.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _format = 'PDF'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _format == 'PDF' ? appColors.foreground : appColors.surface2,
                                border: Border.all(color: _format == 'PDF' ? appColors.foreground : appColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'PDF DOCUMENT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _format == 'PDF' ? appColors.background : appColors.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _format = 'Excel'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _format == 'Excel' ? appColors.foreground : appColors.surface2,
                                border: Border.all(color: _format == 'Excel' ? appColors.foreground : appColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'EXCEL SPREADSHEET',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _format == 'Excel' ? appColors.background : appColors.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Date range pickers
                    Text(
                      context.tr('rep.dialog.range'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: appColors.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: appColors.surface2,
                                border: Border.all(color: appColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    df.format(_startDate),
                                    style: TextStyle(fontSize: 11, color: appColors.foreground),
                                  ),
                                  Icon(LucideIcons.calendar, size: 14, color: appColors.mutedForeground),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _endDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: appColors.surface2,
                                border: Border.all(color: appColors.border),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    df.format(_endDate),
                                    style: TextStyle(fontSize: 11, color: appColors.foreground),
                                  ),
                                  Icon(LucideIcons.calendar, size: 14, color: appColors.mutedForeground),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Options Checkboxes
                    Text(
                      context.tr('rep.dialog.options'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: appColors.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: appColors.surface2,
                        border: Border.all(color: appColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: Text(context.tr('rep.dialog.summary'), style: TextStyle(fontSize: 12, color: appColors.foreground)),
                            value: _includeSummary,
                            onChanged: (v) => setState(() => _includeSummary = v ?? true),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: appColors.foreground,
                            checkColor: appColors.background,
                          ),
                          CheckboxListTile(
                            title: Text(context.tr('rep.dialog.income'), style: TextStyle(fontSize: 12, color: appColors.foreground)),
                            value: _includeIncome,
                            onChanged: (v) => setState(() => _includeIncome = v ?? true),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: appColors.foreground,
                            checkColor: appColors.background,
                          ),
                          CheckboxListTile(
                            title: Text(context.tr('rep.dialog.outcome'), style: TextStyle(fontSize: 12, color: appColors.foreground)),
                            value: _includeOutcome,
                            onChanged: (v) => setState(() => _includeOutcome = v ?? true),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: appColors.foreground,
                            checkColor: appColors.background,
                          ),
                          CheckboxListTile(
                            title: Text(context.tr('rep.dialog.inventory'), style: TextStyle(fontSize: 12, color: appColors.foreground)),
                            value: _includeInventory,
                            onChanged: (v) => setState(() => _includeInventory = v ?? true),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: appColors.foreground,
                            checkColor: appColors.background,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Destination Directory Selector
                    Text(
                      context.tr('rep.dialog.folder'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: appColors.mutedForeground),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: appColors.surface2,
                              border: Border.all(color: appColors.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _saveDirectory ?? 'No folder selected',
                              style: TextStyle(
                                fontSize: 11,
                                color: _saveDirectory == null ? appColors.mutedForeground : appColors.foreground,
                                fontFamily: AppTheme.mono().fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickDirectory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appColors.foreground,
                            foregroundColor: appColors.background,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(LucideIcons.folder, size: 14),
                          label: Text(context.tr('rep.dialog.select_folder'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _generating ? null : () => Navigator.of(context).pop(),
                          child: Text(context.tr('rep.dialog.cancel'), style: TextStyle(color: appColors.mutedForeground, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _generating ? null : _generate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appColors.foreground,
                            foregroundColor: appColors.background,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: _generating
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(context.tr('rep.dialog.generate'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
