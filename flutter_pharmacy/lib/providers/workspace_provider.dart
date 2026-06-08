import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../models/models.dart' as model;

class TabItem {
  final String id;
  final String moduleId;
  final String title;
  final bool pinned;
  final Map<String, dynamic>? params;

  TabItem({
    required this.id,
    required this.moduleId,
    required this.title,
    this.pinned = false,
    this.params,
  });

  TabItem copyWith({
    String? id,
    String? moduleId,
    String? title,
    bool? pinned,
    Map<String, dynamic>? params,
  }) {
    return TabItem(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      pinned: pinned ?? this.pinned,
      params: params ?? this.params,
    );
  }
}

class TabGroup {
  final List<TabItem> tabs;
  final String activeTabId;

  TabGroup({required this.tabs, required this.activeTabId});

  TabGroup copyWith({
    List<TabItem>? tabs,
    String? activeTabId,
  }) {
    return TabGroup(
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
    );
  }
}

class WorkspaceProvider with ChangeNotifier {
  Timer? _notificationsTimer;
  final Set<String> _seenNotificationIds = {};
  model.Notification? _currentBannerNotification;
  model.Notification? get currentBannerNotification => _currentBannerNotification;
  final List<model.Notification> _bannerQueue = [];

  model.StaffMember? _currentUser;
  model.StaffMember? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool _isSubscriptionExpired = false;
  bool get isSubscriptionExpired => _isSubscriptionExpired;

  bool _isEmptyTenant = false;
  bool get isEmptyTenant => _isEmptyTenant;

  // POS Cart State
  final List<model.CartItem> _posCart = [];
  List<model.CartItem> get posCart => _posCart;

  model.Customer? _posSelectedCustomer;
  model.Customer? get posSelectedCustomer => _posSelectedCustomer;

  final List<List<model.CartItem>> _posHeldCarts = [];
  List<List<model.CartItem>> get posHeldCarts => _posHeldCarts;

  WorkspaceProvider() {
    checkSession().then((_) {
      if (isLoggedIn) {
        startNotificationPolling();
      }
    });
  }

  // Theme & Locale settings
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  String _locale = 'ar';
  String get locale => _locale;

  Future<void> setLocale(String langCode) async {
    if (_locale != langCode) {
      _locale = langCode;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('system_locale', langCode);
    }
  }

  String _branchLabel = 'Downtown Pharmacy Branch #1';
  String get branchLabel => _branchLabel;

  String _branchAddress = '742 Evergreen Terrace, Springfield';
  String get branchAddress => _branchAddress;

  String _vatTax = '12';
  String get vatTax => _vatTax;

  String _profitMargin = '28';
  String get profitMargin => _profitMargin;

  bool _autoBackup = true;
  bool get autoBackup => _autoBackup;

  bool _lowStockAlerts = true;
  bool get lowStockAlerts => _lowStockAlerts;

  bool _prescChecks = true;
  bool get prescChecks => _prescChecks;

  Future<void> updateSettings({
    required String branchLabel,
    required String branchAddress,
    required String vatTax,
    required String profitMargin,
    required bool autoBackup,
    required bool lowStockAlerts,
    required bool prescChecks,
  }) async {
    _branchLabel = branchLabel;
    _branchAddress = branchAddress;
    _vatTax = vatTax;
    _profitMargin = profitMargin;
    _autoBackup = autoBackup;
    _lowStockAlerts = lowStockAlerts;
    _prescChecks = prescChecks;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_branch_label', branchLabel);
    await prefs.setString('settings_branch_address', branchAddress);
    await prefs.setString('settings_vat_tax', vatTax);
    await prefs.setString('settings_profit_margin', profitMargin);
    await prefs.setBool('settings_cloud_backups', autoBackup);
    await prefs.setBool('settings_low_stock', lowStockAlerts);
    await prefs.setBool('settings_licenses', prescChecks);
  }

  bool _sidebarCollapsed = false;
  bool get sidebarCollapsed => _sidebarCollapsed;

  bool _commandOpen = false;
  bool get commandOpen => _commandOpen;

  bool _notificationsOpen = false;
  bool get notificationsOpen => _notificationsOpen;

  int _activeGroupIndex = 0;
  int get activeGroupIndex => _activeGroupIndex;

  final List<TabGroup> _groups = [
    TabGroup(
      tabs: [
        TabItem(
          id: 'dashboard',
          moduleId: 'dashboard',
          title: 'Dashboard',
          pinned: true,
        ),
      ],
      activeTabId: 'dashboard',
    )
  ];

  List<TabGroup> get groups => _groups;

  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
  }

  void setCommandOpen(bool open) {
    _commandOpen = open;
    notifyListeners();
  }

  void setNotificationsOpen(bool open) {
    _notificationsOpen = open;
    notifyListeners();
  }

  void setActiveGroup(int index) {
    if (index >= 0 && index < _groups.length) {
      _activeGroupIndex = index;
      notifyListeners();
    }
  }

  void openTab(String moduleId, {String? title, Map<String, dynamic>? params}) {
    final defaultTitles = {
      'dashboard': 'Dashboard',
      'inventory': 'Inventory',
      'medicine-details': 'Medication Profile',
      'pos': 'Checkout POS',
      'prescriptions': 'Rx Validate',
      'purchasing': 'Purchases PO',
      'suppliers': 'Suppliers List',
      'warehouse': 'Rack Layout',
      'finance': 'Revenue OS',
      'reports': 'Reports Center',
      'staff': 'Staff Audit',
      'notifications': 'Inbox Notifications',
      'settings': 'OS Settings',
    };

    final finalTitle = title ?? defaultTitles[moduleId] ?? moduleId;
    final tabId = params != null && params.containsKey('id')
        ? '${moduleId}_${params['id']}'
        : moduleId;

    // Check if the tab already exists in ANY group
    for (int gIdx = 0; gIdx < _groups.length; gIdx++) {
      final grp = _groups[gIdx];
      final existingIndex = grp.tabs.indexWhere((t) => t.id == tabId);
      if (existingIndex != -1) {
        _activeGroupIndex = gIdx;
        _groups[gIdx] = grp.copyWith(activeTabId: tabId);
        notifyListeners();
        return;
      }
    }

    // Add new tab to active group
    final activeGroup = _groups[_activeGroupIndex];
    final updatedTabs = List<TabItem>.from(activeGroup.tabs);
    
    // Non-pinned tabs insert after pinned tabs, or at the end
    int insertIndex = updatedTabs.length;
    final lastPinnedIdx = updatedTabs.lastIndexWhere((t) => t.pinned);
    if (lastPinnedIdx != -1) {
      insertIndex = lastPinnedIdx + 1;
    }

    final newTab = TabItem(
      id: tabId,
      moduleId: moduleId,
      title: finalTitle,
      pinned: false,
      params: params,
    );

    updatedTabs.insert(insertIndex, newTab);
    _groups[_activeGroupIndex] = activeGroup.copyWith(
      tabs: updatedTabs,
      activeTabId: tabId,
    );
    notifyListeners();
  }

  void closeTab(int groupIndex, String tabId) {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;
    final group = _groups[groupIndex];
    final tabIndex = group.tabs.indexWhere((t) => t.id == tabId);
    if (tabIndex == -1) return;

    // Pinned tabs can't be closed
    if (group.tabs[tabIndex].pinned) return;

    final updatedTabs = List<TabItem>.from(group.tabs);
    updatedTabs.removeAt(tabIndex);

    // If active tab was closed, pick another
    String nextActiveId = group.activeTabId;
    if (group.activeTabId == tabId && updatedTabs.isNotEmpty) {
      final prevIndex = tabIndex - 1;
      nextActiveId = prevIndex >= 0 ? updatedTabs[prevIndex].id : updatedTabs[0].id;
    }

    _groups[groupIndex] = group.copyWith(
      tabs: updatedTabs,
      activeTabId: nextActiveId,
    );

    // If group becomes empty, close it (if it's the split panel)
    if (updatedTabs.isEmpty && _groups.length > 1) {
      _groups.removeAt(groupIndex);
      _activeGroupIndex = 0;
    }

    notifyListeners();
  }

  void setActiveTab(int groupIndex, String tabId) {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;
    _activeGroupIndex = groupIndex;
    _groups[groupIndex] = _groups[groupIndex].copyWith(activeTabId: tabId);
    notifyListeners();
  }

  void togglePin(int groupIndex, String tabId) {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;
    final group = _groups[groupIndex];
    final index = group.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final target = group.tabs[index];
    final isPinned = !target.pinned;
    final updatedTab = target.copyWith(pinned: isPinned);

    final updatedTabs = List<TabItem>.from(group.tabs);
    updatedTabs.removeAt(index);

    if (isPinned) {
      // Move to end of pinned group
      int lastPinned = updatedTabs.lastIndexWhere((t) => t.pinned);
      updatedTabs.insert(lastPinned + 1, updatedTab);
    } else {
      // Move to beginning of unpinned group
      int firstUnpinned = updatedTabs.indexWhere((t) => !t.pinned);
      if (firstUnpinned == -1) {
        updatedTabs.add(updatedTab);
      } else {
        updatedTabs.insert(firstUnpinned, updatedTab);
      }
    }

    _groups[groupIndex] = group.copyWith(tabs: updatedTabs);
    notifyListeners();
  }

  void splitTab(TabItem tab) {
    if (_groups.length >= 2) return;

    // Remove from the first group
    final firstGroup = _groups[0];
    final index = firstGroup.tabs.indexWhere((t) => t.id == tab.id);
    if (index != -1 && !firstGroup.tabs[index].pinned) {
      final updatedFirstTabs = List<TabItem>.from(firstGroup.tabs)..removeAt(index);
      String nextActiveId = firstGroup.activeTabId;
      if (firstGroup.activeTabId == tab.id && updatedFirstTabs.isNotEmpty) {
        nextActiveId = updatedFirstTabs[updatedFirstTabs.length - 1].id;
      }
      _groups[0] = firstGroup.copyWith(tabs: updatedFirstTabs, activeTabId: nextActiveId);
    }

    // Add to the second group
    _groups.add(TabGroup(
      tabs: [tab.copyWith(pinned: false)],
      activeTabId: tab.id,
    ));
    _activeGroupIndex = 1;
    notifyListeners();
  }

  void closeSplit(int index) {
    if (_groups.length < 2) return;
    final targetGroup = _groups[index];
    final remainingGroupIndex = index == 0 ? 1 : 0;
    final remainingGroup = _groups[remainingGroupIndex];

    // Merge tabs into remaining group
    final mergedTabs = List<TabItem>.from(remainingGroup.tabs);
    for (final t in targetGroup.tabs) {
      if (!mergedTabs.any((existing) => existing.id == t.id)) {
        mergedTabs.add(t);
      }
    }

    _groups[0] = remainingGroup.copyWith(
      tabs: mergedTabs,
      activeTabId: targetGroup.activeTabId,
    );
    _groups.removeAt(1);
    _activeGroupIndex = 0;
    notifyListeners();
  }

  void reorderTab(int groupIndex, int from, int to) {
    if (groupIndex < 0 || groupIndex >= _groups.length) return;
    final group = _groups[groupIndex];
    if (from < 0 || from >= group.tabs.length || to < 0 || to >= group.tabs.length) return;

    // Check boundaries: do not cross pinned/unpinned boundaries
    final fromTab = group.tabs[from];
    final toTab = group.tabs[to];
    if (fromTab.pinned != toTab.pinned) return;

    final updatedTabs = List<TabItem>.from(group.tabs);
    updatedTabs.removeAt(from);
    updatedTabs.insert(to, fromTab);

    _groups[groupIndex] = group.copyWith(tabs: updatedTabs);
    notifyListeners();
  }

  void showNotification({required String title, required String body, String category = 'system', String priority = 'normal'}) {
    final mockNtf = model.Notification(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      category: category,
      priority: priority,
      read: false,
      at: DateTime.now().toIso8601String(),
    );
    _bannerQueue.add(mockNtf);
    _processBannerQueue();
  }

  void dismissCurrentBanner() {
    _currentBannerNotification = null;
    notifyListeners();
    _processBannerQueue();
  }

  void _processBannerQueue() {
    if (_currentBannerNotification != null) return;
    if (_bannerQueue.isEmpty) return;
    _currentBannerNotification = _bannerQueue.removeAt(0);
    notifyListeners();
    
    // Auto dismiss after 4 seconds
    Timer(const Duration(seconds: 4), () {
      if (_currentBannerNotification != null) {
        dismissCurrentBanner();
      }
    });
  }

  void startNotificationPolling() {
    _notificationsTimer?.cancel();
    
    // Perform initial fetch to populate seen IDs
    _fetchInitialNotifications();
    
    // Poll every 4 seconds
    _notificationsTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _pollNotifications();
    });
  }

  Future<void> _fetchInitialNotifications() async {
    try {
      final api = ApiService();
      final list = await api.request<List<model.Notification>>('notifications');
      for (final n in list) {
        _seenNotificationIds.add(n.id);
      }
    } catch (e) {
      debugPrint('Error fetching initial notifications: $e');
    }
  }

  int _pollCount = 0;

  Future<void> _pollNotifications() async {
    _pollCount++;
    if (_pollCount % 15 == 1) {
      checkMedicineAlerts();
    }
    try {
      final api = ApiService();
      final list = await api.request<List<model.Notification>>('notifications');
      bool hasNew = false;
      for (final n in list) {
        if (!_seenNotificationIds.contains(n.id)) {
          _seenNotificationIds.add(n.id);
          // Queue the notification to show as banner
          _bannerQueue.add(n);
          hasNew = true;
        }
      }
      if (hasNew) {
        _processBannerQueue();
      }
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }

  bool _wasOnline = true;
  bool _syncServiceListening = false;

  void _onSyncStateChanged() {
    final isOnline = SyncService().isOnline;
    if (_wasOnline != isOnline) {
      _wasOnline = isOnline;
      if (isOnline) {
         showNotification(title: 'Connection Restored', body: 'Syncing offline data...', category: 'system');
      } else {
         showNotification(title: 'Connection Lost', body: 'Working offline. Changes will be saved locally.', category: 'alert');
      }
    }
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> _checkTenantStatus() async {
    try {
      final status = await ApiService().request<Map<String, dynamic>>('auth/tenant-status');
      _isEmptyTenant = status['is_empty'] == true;
    } catch (e) {
      debugPrint('Error checking tenant status: $e');
    }
  }

  Future<void> checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = prefs.getString('system_locale') ?? 'ar';
      final savedTheme = prefs.getString('theme_mode');
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      }

      _branchLabel = prefs.getString('settings_branch_label') ?? 'Downtown Pharmacy Branch #1';
      _branchAddress = prefs.getString('settings_branch_address') ?? '742 Evergreen Terrace, Springfield';
      _vatTax = prefs.getString('settings_vat_tax') ?? '12';
      _profitMargin = prefs.getString('settings_profit_margin') ?? '28';
      _autoBackup = prefs.getBool('settings_cloud_backups') ?? true;
      _lowStockAlerts = prefs.getBool('settings_low_stock') ?? true;
      _prescChecks = prefs.getBool('settings_licenses') ?? true;

      _isSubscriptionExpired = false;
      _isEmptyTenant = false;
      await ApiService().initSession();
      await SyncService().init();
      if (!_syncServiceListening) {
        SyncService().addListener(_onSyncStateChanged);
        _syncServiceListening = true;
        // Explicitly evaluate state immediately to catch any lightning-fast synchronous state changes
        _onSyncStateChanged();
      }
      final user = await ApiService().getMe();
      if (user != null) {
        _currentUser = user;
        _setupInitialTabForRole();
        await _checkTenantStatus();
      }
    } catch (e) {
      if (e is SubscriptionExpiredException) {
        _isSubscriptionExpired = true;
      }
      debugPrint('Error checking session: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      _isSubscriptionExpired = false;
      _isEmptyTenant = false;
      
      final user = await ApiService().login(username, password);
      _currentUser = user;
      _setupInitialTabForRole();
      startNotificationPolling();
      
      await _checkTenantStatus();
      notifyListeners();
      
      showNotification(
        title: 'Welcome Back',
        body: 'Successfully authenticated as ${user.name} (${user.role.toUpperCase()})',
        category: 'system',
      );

      if (_isEmptyTenant) {
        showNotification(
          title: 'Empty Tenant Detected',
          body: 'This is the first login. The database has been initialized empty.',
          category: 'system',
        );
      }
      return true;
    } catch (e) {
      showNotification(
        title: 'Authentication Failed',
        body: e.toString().replaceAll('Exception: ', ''),
        category: 'error',
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService().logout();
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
    
    // Clear notifications polling
    _notificationsTimer?.cancel();
    _notificationsTimer = null;
    
    // Clear user
    _currentUser = null;
    _isSubscriptionExpired = false;
    _isEmptyTenant = false;
    
    // Reset tabs to default dashboard tab
    _groups.clear();
    _groups.add(
      TabGroup(
        tabs: [
          TabItem(
            id: 'dashboard',
            moduleId: 'dashboard',
            title: 'Dashboard',
            pinned: true,
          ),
        ],
        activeTabId: 'dashboard',
      ),
    );
    _activeGroupIndex = 0;
    notifyListeners();
  }

  void _setupInitialTabForRole() {
    if (_currentUser == null) return;
    
    _groups.clear();
    final String initialModule = _currentUser!.role == 'cashier' ? 'pos' : 'dashboard';
    final String initialTitle = _currentUser!.role == 'cashier' ? 'Checkout POS' : 'Dashboard';
    
    _groups.add(
      TabGroup(
        tabs: [
          TabItem(
            id: initialModule,
            moduleId: initialModule,
            title: initialTitle,
            pinned: true,
          ),
        ],
        activeTabId: initialModule,
      ),
    );
    _activeGroupIndex = 0;
  }

  void addToPosCart(model.Medicine m, BuildContext context) {
    if (m.quantity <= 0) {
      showNotification(
        title: 'Out of Stock',
        body: '${m.name} is out of stock.',
        category: 'expiry',
      );
      return;
    }

    final idx = _posCart.indexWhere((it) => it.medicineId == m.id);
    if (idx != -1) {
      if (_posCart[idx].quantity < m.quantity) {
        _posCart[idx].quantity++;
        _posCart[idx].controller?.text = _posCart[idx].quantity.toString();
      }
      _focusAndSelectCartItem(idx);
    } else {
      final controller = TextEditingController(text: '1');
      final focusNode = FocusNode();
      final newItem = model.CartItem(
        medicineId: m.id,
        name: m.name,
        quantity: 1,
        unitPrice: m.sellingPrice,
        maxQuantity: m.quantity,
        discount: m.discount,
        taxRate: m.taxRate,
        controller: controller,
        focusNode: focusNode,
      );
      _posCart.add(newItem);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusAndSelectCartItem(_posCart.length - 1);
      });
    }
    notifyListeners();
  }

  void _focusAndSelectCartItem(int idx) {
    if (idx >= 0 && idx < _posCart.length) {
      final it = _posCart[idx];
      it.focusNode?.requestFocus();
      it.controller?.selection = TextSelection(
        baseOffset: 0,
        extentOffset: it.controller?.text.length ?? 0,
      );
    }
  }

  void updatePosCartQty(int index, int delta) {
    final item = _posCart[index];
    final newQty = item.quantity + delta;
    if (newQty <= 0) {
      removeFromPosCart(index);
    } else if (newQty <= item.maxQuantity) {
      item.quantity = newQty;
      item.controller?.text = newQty.toString();
      notifyListeners();
    }
  }

  void updatePosCartQtyDirect(int index, int newQty) {
    final item = _posCart[index];
    if (newQty <= 0) {
      item.quantity = 0;
    } else if (newQty <= item.maxQuantity) {
      item.quantity = newQty;
    } else {
      item.quantity = item.maxQuantity;
      item.controller?.text = item.maxQuantity.toString();
      _focusAndSelectCartItem(index);
    }
    notifyListeners();
  }

  void removeFromPosCart(int index) {
    final item = _posCart[index];
    item.controller?.dispose();
    item.focusNode?.dispose();
    _posCart.removeAt(index);
    notifyListeners();
  }

  void clearPosCart() {
    for (final it in _posCart) {
      it.controller?.dispose();
      it.focusNode?.dispose();
    }
    _posCart.clear();
    _posSelectedCustomer = null;
    notifyListeners();
  }

  void setPosSelectedCustomer(model.Customer? c) {
    _posSelectedCustomer = c;
    notifyListeners();
  }

  void holdPosCart() {
    if (_posCart.isEmpty) return;
    _posHeldCarts.add(List.from(_posCart));
    _posCart.clear();
    notifyListeners();
    showNotification(
      title: 'Cart Suspended',
      body: 'POS cart has been suspended successfully.',
      category: 'system',
    );
  }

  void recallPosCart(int index) {
    clearPosCart();
    _posCart.addAll(_posHeldCarts[index]);
    _posHeldCarts.removeAt(index);
    notifyListeners();
  }

  Future<void> checkMedicineAlerts() async {
    try {
      final api = ApiService();
      final medicines = await api.request<List<model.Medicine>>('medicines');
      final notifications = await api.request<List<model.Notification>>('notifications');
      
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final todayDate = DateTime.parse(todayStr);

      for (final m in medicines) {
        bool isExpired = false;
        try {
          final expDate = DateTime.parse(m.expiryDate);
          if (expDate.isBefore(todayDate) || expDate.isAtSameMomentAs(todayDate)) {
            isExpired = true;
          }
        } catch (_) {}

        if (isExpired) {
          final title = 'Medication Expired';
          final body = '${m.name} has expired (Expiry: ${m.expiryDate.split("T")[0]})';
          if (!notifications.any((n) => n.title == title && n.body == body)) {
            final ntf = model.Notification(
              id: 'ntf_exp_${m.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              body: body,
              category: 'expiry',
              priority: 'critical',
              read: false,
              at: DateTime.now().toIso8601String(),
            );
            await api.request<dynamic>('notifications', body: ntf.toJson());
          }
        }
        
        if (m.quantity == 0) {
          final title = 'Medication Out of Stock';
          final body = '${m.name} is completely out of stock';
          if (!notifications.any((n) => n.title == title && n.body == body)) {
            final ntf = model.Notification(
              id: 'ntf_out_${m.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              body: body,
              category: 'stock',
              priority: 'high',
              read: false,
              at: DateTime.now().toIso8601String(),
            );
            await api.request<dynamic>('notifications', body: ntf.toJson());
          }
        } else if (m.quantity <= m.lowStockThreshold) {
          final title = 'Low Stock Alert';
          final body = '${m.name} is running low (${m.quantity} left)';
          if (!notifications.any((n) => n.title == title && n.body == body)) {
            final ntf = model.Notification(
              id: 'ntf_low_${m.id}_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              body: body,
              category: 'stock',
              priority: 'normal',
              read: false,
              at: DateTime.now().toIso8601String(),
            );
            await api.request<dynamic>('notifications', body: ntf.toJson());
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking medicine alerts: $e');
    }
  }

  bool get hasApiConfig => ApiService().backendUrl.isNotEmpty;

  Future<String?> verifyApiUrl(String newUrl) async {
    final cleanUrl = newUrl.trim();
    final isConnect = await ApiService().testConnection(cleanUrl);
    if (!isConnect) return null;

    final newInfo = await ApiService().fetchSystemInfo(cleanUrl);
    final newSettingsId = newInfo?['settings_id']?.toString() ?? 'default';
    return newSettingsId;
  }

  Future<void> applyApiUrl(String newUrl, String newSettingsId) async {
    final cleanUrl = newUrl.trim();
    final prefs = await SharedPreferences.getInstance();
    final currentSettingsId = prefs.getString('current_pharmacy_settings_id') ?? '';

    // Save new API URL
    await ApiService().updateBackendUrl(cleanUrl);

    // If it's a different database/backend, log out and clear session/cache
    if (currentSettingsId.isNotEmpty && currentSettingsId != newSettingsId) {
      await ApiService().clearSession();
      _currentUser = null;
    }

    // Save new settings ID
    await prefs.setString('current_pharmacy_settings_id', newSettingsId);

    // Re-initialize session to reload backendUrl
    _isInitialized = false;
    notifyListeners();
    
    // Run initialization
    await checkSession();
  }

  Future<bool> setAndTestApiUrl(String newUrl) async {
    final settingsId = await verifyApiUrl(newUrl);
    if (settingsId == null) return false;
    await applyApiUrl(newUrl, settingsId);
    return true;
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    for (final it in _posCart) {
      it.controller?.dispose();
      it.focusNode?.dispose();
    }
    super.dispose();
  }
}
extension LastIndexWhere<E> on List<E> {
  int lastIndexWhere(bool Function(E element) test, [int? start]) {
    if (isEmpty) return -1;
    start ??= length - 1;
    for (int i = start; i >= 0; i--) {
      if (test(this[i])) return i;
    }
    return -1;
  }
}
