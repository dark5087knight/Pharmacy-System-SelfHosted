import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
