import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/workspace_provider.dart';
import '../screens/login_screen.dart';
import '../screens/subscription_required_screen.dart';
import 'sidebar.dart';
import 'top_notification_banner.dart';
import 'top_bar.dart';
import 'tab_host.dart';
import 'command_palette.dart';
import 'notification_drawer.dart';

class WorkspaceLayout extends StatelessWidget {
  const WorkspaceLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);

    if (!workspace.isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
        ),
      );
    }

    if (workspace.isSubscriptionExpired) {
      return const Scaffold(
        body: Stack(
          children: [
            SubscriptionRequiredScreen(),
            TopNotificationBanner(),
          ],
        ),
      );
    }

    if (!workspace.isLoggedIn) {
      return const Scaffold(
        body: Stack(
          children: [
            LoginScreen(),
            TopNotificationBanner(),
          ],
        ),
      );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () {
          workspace.openTab('dashboard');
        },
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () {
          workspace.openTab('inventory');
        },
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () {
          workspace.openTab('pos');
        },
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () {
          workspace.openTab('prescriptions');
        },
        const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () {
          workspace.openTab('warehouse');
        },
        // Command palette shortcut (Cmd+K / Ctrl+K)
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          workspace.setCommandOpen(!workspace.commandOpen);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          workspace.setCommandOpen(!workspace.commandOpen);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                // Layout Shell
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Sidebar(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const TopBar(),
                          const Expanded(child: TabHost()),
                        ],
                      ),
                    ),
                  ],
                ),

                // Command Palette dialogue overlay
                const CommandPalette(),

                // Notification Drawer overlay
                const NotificationDrawer(),

                // iOS-Style Top Notification Banner
                const TopNotificationBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
