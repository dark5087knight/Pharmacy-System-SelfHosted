import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'sync_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  String backendUrl = '';
  String? _apiKey;

  File get _configFile {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return File('$exeDir/config.yaml');
  }

  Uri _apiUri(String path) {
    if (backendUrl.isEmpty) {
      throw Exception('Backend URL is not configured.');
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$backendUrl$cleanPath');
  }

  ApiService._internal();

  String? _sessionCookie;

  Future<void> initSession() async {
    final file = _configFile;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final RegExp urlExp = RegExp(r'backend_url:\s*(.+)');
        final match = urlExp.firstMatch(content);
        if (match != null) {
          backendUrl = match
              .group(1)!
              .trim()
              .replaceAll('"', '')
              .replaceAll("'", "");
        }

        final RegExp keyExp = RegExp(r'api_key:\s*(.+)');
        final keyMatch = keyExp.firstMatch(content);
        if (keyMatch != null) {
          _apiKey = keyMatch
              .group(1)!
              .trim()
              .replaceAll('"', '')
              .replaceAll("'", "");
        } else {
          _apiKey = _generateApiKey();
          final updatedContent = '${content.trim()}\napi_key: "$_apiKey"\n';
          await file.writeAsString(updatedContent);
        }
      } catch (e) {
        // Ignore, leave as empty
      }
    } else {
      _apiKey = _generateApiKey();
      await file.writeAsString('backend_url: ""\napi_key: "$_apiKey"\n');
    }

    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
  }

  String _generateApiKey() {
    final random = Random();
    final parts = List.generate(4, (_) => random.nextInt(0xffffffff).toRadixString(16).padLeft(8, '0'));
    return parts.join('-');
  }

  Future<bool> testConnection(String url) async {
    if (url.isEmpty) return false;
    try {
      final cleanUrl = url.endsWith('/')
          ? url.substring(0, url.length - 1)
          : url;
      // Hit the health endpoint to verify server is alive without triggering 401 errors
      await http
          .get(Uri.parse('$cleanUrl/health'))
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchSystemInfo(String url) async {
    if (url.isEmpty) return null;
    try {
      final cleanUrl = url.endsWith('/')
          ? url.substring(0, url.length - 1)
          : url;
      final response = await http
          .get(Uri.parse('$cleanUrl/auth/info'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateBackendUrl(String url) async {
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    backendUrl = cleanUrl;

    String content = '';
    final file = _configFile;
    if (await file.exists()) {
      content = await file.readAsString();
    }

    final RegExp urlExp = RegExp(r'backend_url:\s*(.+)');
    if (urlExp.hasMatch(content)) {
      content = content.replaceAll(urlExp, 'backend_url: "$cleanUrl"');
    } else {
      content += '\nbackend_url: "$cleanUrl"\n';
    }
    await file.writeAsString('${content.trim()}\n');
  }

  Future<void> _saveSession(String cookie) async {
    _sessionCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', cookie);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    _sessionCookie = null;
    await SyncService().clearAllCache();
  }

  Future<http.Response> rawMutation(
    String method,
    String route, {
    dynamic body,
  }) async {
    try {
      final url = _apiUri(route);
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'cookie': ?_sessionCookie,
        if (_sessionCookie != null)
          'authorization':
              'Bearer ${_sessionCookie!.replaceFirst('session_id=', '')}',
        'X-API-Key': ?_apiKey,
      };

      if (method == 'POST') {
        return http.post(url, headers: headers, body: jsonEncode(body));
      }
      if (method == 'PUT') {
        return http.put(url, headers: headers, body: jsonEncode(body));
      }
      if (method == 'DELETE') {
        return http.delete(url, headers: headers);
      }
      throw Exception('Invalid method');
    } catch (e) {
      rethrow;
    }
  }

  // Execute API requests directly against the FastAPI database backend
  Future<T> request<T>(String route, {dynamic body}) async {
    if (!SyncService().isOnline) {
      if (body == null && route != '/auth/me' && route != '/users') {
        final cachedData = await SyncService().loadCache(route);
        if (cachedData != null) {
          return _parseResponse<T>(route, cachedData);
        }
      }
      throw Exception('Offline: No cached data available for $route');
    }

    try {
      final url = _apiUri(route);
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'cookie': ?_sessionCookie,
        if (_sessionCookie != null)
          'authorization':
              'Bearer ${_sessionCookie!.replaceFirst('session_id=', '')}',
        'X-API-Key': ?_apiKey,
      };

      final http.Response response;
      if (body != null) {
        response = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 30));
      } else {
        response = await http
            .get(url, headers: headers)
            .timeout(const Duration(seconds: 30));
      }

      // Capture cookie from response headers
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final parts = setCookie.split(';');
        if (parts.isNotEmpty) {
          await _saveSession(parts[0]);
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Cache read-only GET requests for offline fallback
        if (body == null && route != '/auth/me' && route != '/users') {
          await SyncService().saveCache(route, data);
        }
        return _parseResponse<T>(route, data);
      } else {
        throw Exception(
          'Failed to load data from $route. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (body == null && route != '/auth/me' && route != '/users') {
        final cachedData = await SyncService().loadCache(route);
        if (cachedData != null) {
          return _parseResponse<T>(route, cachedData);
        }
      }
      throw Exception('Network Error: $e');
    }
  }

  T _parseResponse<T>(String route, dynamic decoded) {
    if (decoded == null) return decoded as T;
    final parts = route.split('/');
    final resource = parts[0];

    if (resource == 'dashboard') {
      final map = decoded as Map<String, dynamic>;
      return {
            'stats': map['stats'],
            'revenueSeries': map['revenueSeries'],
            'categoryBreakdown': map['categoryBreakdown'],
            'topSold': map['topSold'],
            'leastSold': map['leastSold'],
            'recentActivity': (map['recentActivity'] as List)
                .map((x) => ActivityEvent.fromJson(x))
                .toList(),
            'pendingOrders': map['pendingOrders'],
          }
          as T;
    }

    if (resource == 'categories') {
      return (decoded as List).cast<String>() as T;
    }

    if (resource == 'medicines') {
      if (decoded is Map) {
        return Medicine.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => Medicine.fromJson(x)).toList() as T;
    }
    if (resource == 'suppliers') {
      if (decoded is Map) {
        return Supplier.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => Supplier.fromJson(x)).toList() as T;
    }
    if (resource == 'customers') {
      if (decoded is Map) {
        return Customer.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => Customer.fromJson(x)).toList() as T;
    }
    if (resource == 'prescriptions') {
      if (decoded is Map) {
        return Prescription.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => Prescription.fromJson(x)).toList()
          as T;
    }
    if (resource == 'sales') {
      if (decoded is Map) {
        return Sale.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => Sale.fromJson(x)).toList() as T;
    }
    if (resource == 'purchase-orders') {
      if (decoded is Map) {
        return PurchaseOrder.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => PurchaseOrder.fromJson(x)).toList()
          as T;
    }
    if (resource == 'staff') {
      if (decoded is Map) {
        return StaffMember.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => StaffMember.fromJson(x)).toList()
          as T;
    }
    if (resource == 'activities') {
      if (decoded is Map) {
        return ActivityEvent.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => ActivityEvent.fromJson(x)).toList()
          as T;
    }
    if (resource == 'notifications') {
      if (decoded is Map) {
        return Notification.fromJson(decoded as Map<String, dynamic>) as T;
      }
      return (decoded as List).map((x) => Notification.fromJson(x)).toList()
          as T;
    }

    return decoded as T;
  }

  Future<void> _performMutation(
    String method,
    String endpoint,
    dynamic body, {
    String? cacheKey,
    dynamic Function(dynamic cache)? updateCache,
  }) async {
    if (!SyncService().isOnline) {
      await SyncService().enqueueMutation(method, endpoint, body);
      if (cacheKey != null && updateCache != null) {
        final cache = await SyncService().loadCache(cacheKey);
        if (cache != null) {
          final updated = updateCache(cache);
          await SyncService().saveCache(cacheKey, updated);
        }
      }
      return;
    }

    try {
      final response = await rawMutation(
        method,
        endpoint,
        body: body,
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode >= 300) {
        throw Exception('Mutation failed: ${response.statusCode}');
      }
    } catch (e) {
      if (!SyncService().isOnline ||
          e is SocketException ||
          e is TimeoutException) {
        await SyncService().enqueueMutation(method, endpoint, body);
        if (cacheKey != null && updateCache != null) {
          final cache = await SyncService().loadCache(cacheKey);
          if (cache != null) {
            final updated = updateCache(cache);
            await SyncService().saveCache(cacheKey, updated);
          }
        }
      } else {
        rethrow;
      }
    }
  }

  Future<Medicine?> lookupByBarcode(String code) async {
    try {
      final data = await request<Medicine>('medicines/barcode/$code');
      return data;
    } catch (_) {
      return null;
    }
  }

  // --- CRUD API Mutation Wrappers ---

  Future<void> createMedicine(Medicine m) async {
    await _performMutation(
      'POST',
      'medicines',
      m.toJson(),
      cacheKey: 'medicines',
      updateCache: (cache) {
        final list = cache as List;
        list.add(m.toJson());
        return list;
      },
    );
  }

  Future<void> updateMedicine(Medicine m) async {
    await _performMutation(
      'PUT',
      'medicines/${m.id}',
      m.toJson(),
      cacheKey: 'medicines',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == m.id);
        if (idx != -1) list[idx] = m.toJson();
        return list;
      },
    );
  }

  Future<void> deleteMedicine(String id) async {
    await _performMutation(
      'DELETE',
      'medicines/$id',
      null,
      cacheKey: 'medicines',
      updateCache: (cache) {
        final list = cache as List;
        list.removeWhere((x) => x['id'] == id);
        return list;
      },
    );
  }

  Future<void> createCustomer(Customer c) async {
    await _performMutation(
      'POST',
      'customers',
      c.toJson(),
      cacheKey: 'customers',
      updateCache: (cache) {
        final list = cache as List;
        list.add(c.toJson());
        return list;
      },
    );
  }

  Future<void> updateCustomer(Customer c) async {
    await _performMutation(
      'PUT',
      'customers/${c.id}',
      c.toJson(),
      cacheKey: 'customers',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == c.id);
        if (idx != -1) list[idx] = c.toJson();
        return list;
      },
    );
  }

  Future<void> createSupplier(Supplier s) async {
    await _performMutation(
      'POST',
      'suppliers',
      s.toJson(),
      cacheKey: 'suppliers',
      updateCache: (cache) {
        final list = cache as List;
        list.add(s.toJson());
        return list;
      },
    );
  }

  Future<void> updateSupplier(Supplier s) async {
    await _performMutation(
      'PUT',
      'suppliers/${s.id}',
      s.toJson(),
      cacheKey: 'suppliers',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == s.id);
        if (idx != -1) list[idx] = s.toJson();
        return list;
      },
    );
  }

  Future<void> addSale(Sale s) async {
    await _performMutation(
      'POST',
      'sales',
      s.toJson(),
      cacheKey: 'sales',
      updateCache: (cache) {
        final list = cache as List;
        list.add(s.toJson());
        return list;
      },
    );
  }

  Future<void> createPrescription(Prescription p) async {
    await _performMutation(
      'POST',
      'prescriptions',
      p.toJson(),
      cacheKey: 'prescriptions',
      updateCache: (cache) {
        final list = cache as List;
        list.add(p.toJson());
        return list;
      },
    );
  }

  Future<void> updatePrescription(Prescription p) async {
    await _performMutation(
      'PUT',
      'prescriptions/${p.id}',
      {'status': p.status},
      cacheKey: 'prescriptions',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == p.id);
        if (idx != -1) {
          list[idx]['status'] = p.status;
        }
        return list;
      },
    );
  }

  Future<void> updateNotification(Notification n) async {
    await _performMutation(
      'PUT',
      'notifications/${n.id}',
      {'read': n.read},
      cacheKey: 'notifications',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == n.id);
        if (idx != -1) {
          list[idx]['read'] = n.read;
        }
        return list;
      },
    );
  }

  Future<void> addActivity(ActivityEvent a) async {
    await _performMutation(
      'POST',
      'activities',
      a.toJson(),
      cacheKey: 'activities',
      updateCache: (cache) {
        final list = cache as List;
        list.insert(0, a.toJson());
        return list;
      },
    );
  }

  Future<void> createStaff(StaffMember s, String password) async {
    final body = s.toJson();
    body['password'] = password;
    await _performMutation(
      'POST',
      'staff',
      body,
      cacheKey: 'staff',
      updateCache: (cache) {
        final list = cache as List;
        list.add(s.toJson());
        return list;
      },
    );
  }

  Future<void> updateStaff(StaffMember s, {String? password}) async {
    final body = s.toJson();
    if (password != null) {
      body['password'] = password;
    }
    await _performMutation(
      'PUT',
      'staff/${s.id}',
      body,
      cacheKey: 'staff',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == s.id);
        if (idx != -1) list[idx] = s.toJson();
        return list;
      },
    );
  }

  Future<void> deleteStaff(String id) async {
    await _performMutation(
      'DELETE',
      'staff/$id',
      null,
      cacheKey: 'staff',
      updateCache: (cache) {
        final list = cache as List;
        list.removeWhere((x) => x['id'] == id);
        return list;
      },
    );
  }

  Future<void> deleteSupplier(String id) async {
    await _performMutation(
      'DELETE',
      'suppliers/$id',
      null,
      cacheKey: 'suppliers',
      updateCache: (cache) {
        final list = cache as List;
        list.removeWhere((x) => x['id'] == id);
        return list;
      },
    );
  }

  Future<void> processReturn(String medicineId, String customerName, int quantity) async {
    await _performMutation(
      'POST',
      'sales/return',
      {
        'medicineId': medicineId,
        'customerName': customerName,
        'quantity': quantity,
      },
      cacheKey: 'medicines',
      updateCache: (cache) {
        final list = cache as List;
        final idx = list.indexWhere((x) => x['id'] == medicineId);
        if (idx != -1) {
          final currentQty = list[idx]['quantity'] as int;
          list[idx]['quantity'] = currentQty + quantity;
        }
        return list;
      },
    );
  }

  Future<StaffMember> login(String username, String password) async {
    final url = _apiUri('/auth/login');
    final http.Response response;

    try {
      response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': ?_apiKey,
            },
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Network Error: Could not reach the backend.');
    }

    if (response.statusCode == 200) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final parts = setCookie.split(';');
        if (parts.isNotEmpty) {
          await _saveSession(parts[0]);
        }
      }

      final data = jsonDecode(response.body);
      if (_sessionCookie == null && data['session_token'] != null) {
        await _saveSession('session_id=${data['session_token']}');
      }

      // Save cache instantly so offline login works even if they close app immediately
      await SyncService().saveCache('/auth/me', data['user']);

      final settingsId = data['user']['pharmacySettingsId']?.toString() ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_pharmacy_settings_id', settingsId);

      return StaffMember.fromJson(data['user']);
    } else {
      final decoded = jsonDecode(response.body);
      final errorMsg = decoded is Map && decoded.containsKey('detail')
          ? decoded['detail']
          : 'Invalid username or password.';

      throw Exception(errorMsg);
    }
  }

  Future<void> logout() async {
    try {
      final url = _apiUri('/auth/logout');
      final Map<String, String> headers = {'Content-Type': 'application/json'};
      if (_sessionCookie != null) {
        headers['cookie'] = _sessionCookie!;
        headers['authorization'] =
            'Bearer ${_sessionCookie!.replaceFirst('session_id=', '')}';
      }
      if (_apiKey != null) {
        headers['X-API-Key'] = _apiKey!;
      }
      await http
          .post(url, headers: headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Logout network call failed: $e');
    } finally {
      await clearSession();
    }
  }

  Future<StaffMember?> getMe() async {
    if (_sessionCookie == null) return null;

    try {
      if (!SyncService().isOnline) {
        final cachedData = await SyncService().loadCache('/auth/me');
        if (cachedData != null) {
          return StaffMember.fromJson(cachedData);
        }
        return null;
      }

      final url = _apiUri('/auth/me');
      final Map<String, String> headers = {'Content-Type': 'application/json'};
      headers['cookie'] = _sessionCookie!;
      headers['authorization'] =
          'Bearer ${_sessionCookie!.replaceFirst('session_id=', '')}';
      if (_apiKey != null) {
        headers['X-API-Key'] = _apiKey!;
      }

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await SyncService().saveCache('/auth/me', data);

        final settingsId = data['pharmacySettingsId']?.toString() ?? 'default';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_pharmacy_settings_id', settingsId);

        return StaffMember.fromJson(data);
      } else {
        await clearSession();
        return null;
      }
    } catch (e) {
      final cachedData = await SyncService().loadCache('/auth/me');
      if (cachedData != null) {
        return StaffMember.fromJson(cachedData);
      }
      return null;
    }
  }

  /// Downloads the backup JSON file and returns the raw bytes
  Future<List<int>> downloadBackup() async {
    final url = _apiUri('backup/export');
    final Map<String, String> headers = {
      'cookie': ?_sessionCookie,
      if (_sessionCookie != null)
        'authorization': 'Bearer ${_sessionCookie!.replaceFirst('session_id=', '')}',
      'X-API-Key': ?_apiKey,
    };
    
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to download backup: ${response.statusCode} - ${response.body}');
    }
  }

  /// Uploads a backup JSON file to restore the database
  Future<void> restoreBackup(File backupFile) async {
    final url = _apiUri('backup/import');
    
    final request = http.MultipartRequest('POST', url);
    
    // Add headers
    if (_sessionCookie != null) {
      request.headers['cookie'] = _sessionCookie!;
      request.headers['authorization'] = 'Bearer ${_sessionCookie!.replaceFirst('session_id=', '')}';
    }
    if (_apiKey != null) {
      request.headers['X-API-Key'] = _apiKey!;
    }
    
    // Add file
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        backupFile.path,
      ),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      final msg = decoded is Map && decoded.containsKey('detail')
          ? decoded['detail']
          : 'Failed to restore backup.';
      throw Exception(msg);
    }
  }
}

class SubscriptionExpiredException implements Exception {
  final String message;
  SubscriptionExpiredException([this.message = 'Subscription has expired']);

  @override
  String toString() => message;
}

class NoAdminUserException implements Exception {
  final String tenantId;
  NoAdminUserException(this.tenantId);

  @override
  String toString() => 'NoAdminUserException: tenantId=$tenantId';
}
