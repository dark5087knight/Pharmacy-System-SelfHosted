import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../services/api_service.dart';
import '../theme/theme.dart';
import '../i18n/translations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final workspace = Provider.of<WorkspaceProvider>(context, listen: false);
    try {
      await workspace.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    } catch (_) {
      // workspace.login already shows error notification
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _fillCredentials(String username, String password) {
    _usernameController.text = username;
    _passwordController.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final workspace = Provider.of<WorkspaceProvider>(context);

    return Scaffold(
      backgroundColor: appColors.background,
      body: Stack(
        children: [
          // 1. Dynamic background gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appColors.destructive.withValues(alpha: 0.08),
              ),
            ),
          ),

          // Settings button in top left corner (only if API URL is configured)
          if (workspace.hasApiConfig)
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: Icon(
                  LucideIcons.settings,
                  color: appColors.mutedForeground,
                  size: 20,
                ),
                onPressed: () => _showApiConfigDialog(context, workspace),
                tooltip: "Change API Server",
              ),
            ),

          // 2. Centered glassmorphic card container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: appColors.surface1.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: appColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Icon & Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    LucideIcons.pill,
                                    color: appColors.background,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  context.tr('login.title'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: appColors.foreground,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('login.subtitle'),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: appColors.mutedForeground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 32),

                            if (!workspace.hasApiConfig) ...[
                              Text(
                                "An API connection is required to authenticate and use Caduceus Pharmacy OS.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: appColors.mutedForeground,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => _showApiConfigDialog(context, workspace),
                                icon: const Icon(LucideIcons.plug, size: 16),
                                label: const Text(
                                  "Register API Connection",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Username input field
                              Text(
                                context.tr('login.email'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: appColors.mutedForeground,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _usernameController,
                                style: TextStyle(color: appColors.foreground, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: context.tr('login.email_hint'),
                                  hintStyle: TextStyle(color: appColors.mutedForeground.withValues(alpha: 0.6)),
                                  prefixIcon: Icon(LucideIcons.user, size: 16, color: appColors.mutedForeground),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: appColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: appColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return context.tr('login.email_required');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password input field
                              Text(
                                context.tr('login.password'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: appColors.mutedForeground,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: appColors.foreground, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: TextStyle(color: appColors.mutedForeground.withValues(alpha: 0.6)),
                                  prefixIcon: Icon(LucideIcons.lock, size: 16, color: appColors.mutedForeground),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                      size: 16,
                                      color: appColors.mutedForeground,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: appColors.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: appColors.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return context.tr('login.password_required');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Log In Button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        context.tr('login.login_btn'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 28),

                              // Testing convenience accounts selector
                              Divider(color: appColors.border, height: 1),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('login.quick_accounts'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: appColors.mutedForeground,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              _buildQuickAccountButton(
                                context,
                                name: 'Avery Stone',
                                role: 'Admin',
                                username: 'admin',
                                password: 'admin',
                                icon: LucideIcons.shieldAlert,
                                appColors: appColors,
                                primaryColor: primaryColor,
                              ),
                              const SizedBox(height: 8),
                              _buildQuickAccountButton(
                                context,
                                name: 'Jordan Lee',
                                role: 'Pharmacist',
                                username: 'jordan',
                                password: 'password123',
                                icon: LucideIcons.pill,
                                appColors: appColors,
                                primaryColor: primaryColor,
                              ),
                              const SizedBox(height: 8),
                              _buildQuickAccountButton(
                                context,
                                name: 'Marcus Cole',
                                role: 'Cashier',
                                username: 'marcus',
                                password: 'password123',
                                icon: LucideIcons.shoppingBag,
                                appColors: appColors,
                                primaryColor: primaryColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccountButton(
    BuildContext context, {
    required String name,
    required String role,
    required String username,
    required String password,
    required IconData icon,
    required AppColors appColors,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () => _fillCredentials(username, password),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: appColors.surface2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: appColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: appColors.foreground,
                    ),
                  ),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 10,
                      color: appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                role,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApiConfigDialog(BuildContext context, WorkspaceProvider workspace) {
    final apiController = TextEditingController(text: ApiService().backendUrl);
    bool isVerifying = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final appColors = Theme.of(context).extension<AppColors>()!;
            final primaryColor = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              backgroundColor: appColors.surface1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(LucideIcons.globe, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "API Server Configuration",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Enter your self-hosted API backend server URL below (e.g. http://localhost:8000).",
                      style: TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (errorMsg != null) ...[
                      Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: apiController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: "API Server URL",
                        prefixIcon: Icon(LucideIcons.link2, size: 14),
                        hintText: "http://localhost:8000",
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: Text("Cancel", style: TextStyle(color: appColors.mutedForeground)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final newUrl = apiController.text.trim();
                          if (newUrl.isEmpty) {
                            setState(() => errorMsg = "URL cannot be empty.");
                            return;
                          }

                          setState(() {
                            isVerifying = true;
                            errorMsg = null;
                          });

                          final settingsId = await workspace.verifyApiUrl(newUrl);

                          if (settingsId != null) {
                            if (context.mounted) {
                              Navigator.pop(context); // Dismiss dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Connected to API successfully!')),
                              );
                            }
                            await workspace.applyApiUrl(newUrl, settingsId);
                          } else {
                            if (context.mounted) {
                              setState(() {
                                isVerifying = false;
                                errorMsg = "Connection failed. Make sure the backend server is running and accessible.";
                              });
                            }
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Connect", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
