import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/workspace_provider.dart';
import '../theme/theme.dart';
import '../models/models.dart' as model;

class TopNotificationBanner extends StatefulWidget {
  const TopNotificationBanner({super.key});

  @override
  State<TopNotificationBanner> createState() => _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<TopNotificationBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;
  model.Notification? _shownNotification;
  WorkspaceProvider? _provider;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<WorkspaceProvider>(context);
    if (_provider != newProvider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = newProvider;
      _provider?.addListener(_onProviderChanged);
      _onProviderChanged();
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final current = _provider?.currentBannerNotification;
    if (current != null && _shownNotification?.id != current.id) {
      setState(() {
        _shownNotification = current;
      });
      _controller.forward();
    } else if (current == null && _shownNotification != null) {
      _controller.reverse().then((_) {
        if (mounted && _provider?.currentBannerNotification == null) {
          setState(() {
            _shownNotification = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = Provider.of<WorkspaceProvider>(context);
    final appColors = Theme.of(context).extension<AppColors>()!;

    if (_shownNotification == null) {
      return const SizedBox.shrink();
    }

    // Determine category icon and color
    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (_shownNotification!.category) {
      case 'expiry':
        icon = LucideIcons.alertOctagon;
        iconColor = appColors.destructive;
        iconBg = appColors.destructive.withValues(alpha: 0.12);
        break;
      case 'stock':
        icon = LucideIcons.package;
        iconColor = Colors.orange;
        iconBg = Colors.orange.withValues(alpha: 0.12);
        break;
      case 'payment':
        icon = LucideIcons.creditCard;
        iconColor = appColors.success;
        iconBg = appColors.success.withValues(alpha: 0.12);
        break;
      case 'supplier':
        icon = LucideIcons.truck;
        iconColor = Colors.purple;
        iconBg = Colors.purple.withValues(alpha: 0.12);
        break;
      default:
        icon = LucideIcons.bell;
        iconColor = appColors.foreground;
        iconBg = appColors.surface2;
    }

    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  workspace.openTab('notifications');
                  workspace.dismissCurrentBanner();
                },
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy < -4) {
                    Future.microtask(() {
                      workspace.dismissCurrentBanner();
                    });
                  }
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: workspace.themeMode == ThemeMode.dark
                        ? Colors.black.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.8),
                    border: Border.all(
                      color: appColors.border,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                color: iconColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _shownNotification!.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'now',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: appColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _shownNotification!.body,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: appColors.mutedForeground,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 14),
                              onPressed: () {
                                workspace.dismissCurrentBanner();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                              color: appColors.mutedForeground,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
