import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../widgets/page_header.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _branchController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxController = TextEditingController();
  final _marginController = TextEditingController();
  final _apiUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    _branchController.text = workspace.branchLabel;
    _addressController.text = workspace.branchAddress;
    _taxController.text = workspace.vatTax;
    _marginController.text = workspace.profitMargin;
    _apiUrlController.text = ApiService().backendUrl;
    _autoBackup = workspace.autoBackup;
    _lowStockAlerts = workspace.lowStockAlerts;
    _prescChecks = workspace.prescChecks;
  }

  @override
  void dispose() {
    _branchController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    _marginController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }
  
  bool _autoBackup = true;
  bool _lowStockAlerts = true;
  bool _prescChecks = true;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final workspace = Provider.of<WorkspaceProvider>(context);

    return Scaffold(
      backgroundColor: appColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: LucideIcons.settings,
            title: context.tr('settings.title'),
            subtitle: context.tr('settings.subtitle'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Branch Profile
                Section(
                  title: context.tr('settings.branch_profile'),
                  children: Column(
                    children: [
                      _buildField(context.tr('settings.branch_label_field'), _branchController),
                      _buildField(context.tr('settings.branch_address_field'), _addressController),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Pricing Rules
                Section(
                  title: context.tr('settings.margin_rules'),
                  children: Row(
                    children: [
                      Expanded(child: _buildField(context.tr('settings.vat_tax'), _taxController, number: true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildField(context.tr('settings.profit_margin'), _marginController, number: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // API Server Configuration
                Section(
                  title: "API Server Configuration",
                  children: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildField("API Server URL", _apiUrlController),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: appColors.surface2,
                            foregroundColor: appColors.foreground,
                          ),
                          onPressed: () async {
                            final newUrl = _apiUrlController.text.trim();
                            if (newUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('API URL cannot be empty')),
                              );
                              return;
                            }
                            
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            final settingsId = await workspace.verifyApiUrl(newUrl);
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Dismiss loading spinner
                              
                              if (settingsId != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('API Connection verified and saved successfully!')),
                                );
                                await workspace.applyApiUrl(newUrl, settingsId);
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Connection Failed'),
                                    content: const Text('Could not establish a connection to the specified API server URL. Changes reverted.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                // Revert input field
                                _apiUrlController.text = ApiService().backendUrl;
                              }
                            }
                          },
                          icon: const Icon(LucideIcons.plug, size: 14),
                          label: const Text("Test & Apply API URL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Database Backup & Restore
                Section(
                  title: "Database Backup & Restore",
                  children: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Export a backup of all system databases to a JSON file, or restore a previous JSON backup. WARNING: Restoring a backup will overwrite all current system data.",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColors.surface2,
                              foregroundColor: appColors.foreground,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(LucideIcons.download, size: 14),
                            label: const Text("Download Backup", style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              try {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                                final bytes = await ApiService().downloadBackup();
                                if (context.mounted) Navigator.pop(context);
                                
                                final dateStr = DateTime.now().toIso8601String().substring(0, 10);
                                final result = await FilePicker.platform.saveFile(
                                  dialogTitle: 'Save Database Backup',
                                  fileName: 'pharmacy_backup_$dateStr.json',
                                  type: FileType.custom,
                                  allowedExtensions: ['json'],
                                );
                                
                                if (result != null) {
                                  final file = File(result);
                                  await file.writeAsBytes(bytes);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Backup downloaded and saved successfully!')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context); // Dismiss loading if showing
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Export Failed'),
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColors.destructive,
                              foregroundColor: appColors.background,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(LucideIcons.upload, size: 14),
                            label: const Text("Restore Backup", style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                dialogTitle: 'Select Backup JSON File',
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                              );
                              
                              if (result == null || result.files.single.path == null) return;
                              final backupFile = File(result.files.single.path!);
                              
                              if (!context.mounted) return;
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Restore Database Backup'),
                                    content: const Text(
                                      'WARNING: Restoring this backup will completely overwrite all existing database records, transactions, products, and settings. This cannot be undone. Are you sure you want to proceed?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Restore & Overwrite'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              
                              if (confirm == true) {
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                                
                                try {
                                  await ApiService().restoreBackup(backupFile);
                                  if (context.mounted) {
                                    Navigator.pop(context); // Dismiss loading spinner
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Database backup restored successfully!')),
                                    );
                                    // Trigger data reload by showing system notification
                                    workspace.showNotification(
                                      title: 'Database Restored',
                                      body: 'The database has been updated from a backup file.',
                                      category: 'system',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.pop(context); // Dismiss loading spinner
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Restore Failed'),
                                        content: Text(e.toString().replaceAll('Exception: ', '')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Language settings
                Section(
                  title: context.tr('settings.language_section'),
                  children: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('settings.select_language'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: workspace.locale,
                          style: TextStyle(color: appColors.foreground, fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ar', child: Text('العربية (Arabic)')),
                            DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              workspace.setLocale(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),


                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.foreground,
                    foregroundColor: appColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
                    await workspace.updateSettings(
                      branchLabel: _branchController.text,
                      branchAddress: _addressController.text,
                      vatTax: _taxController.text,
                      profitMargin: _marginController.text,
                      autoBackup: _autoBackup,
                      lowStockAlerts: _lowStockAlerts,
                      prescChecks: _prescChecks,
                    );
                    if (context.mounted) {
                      workspace.showNotification(
                        title: context.tr('settings.saved_toast'),
                        body: '',
                        category: 'system',
                      );
                    }
                  },
                  child: Text(context.tr('settings.save_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 12),
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
