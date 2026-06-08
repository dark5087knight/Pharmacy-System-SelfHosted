import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  late Directory _cacheDir;
  bool _initialized = false;
  bool _isSyncing = false;

  Future<void> init() async {
    if (_initialized) return;
    _cacheDir = await getApplicationDocumentsDirectory();
    _initialized = true;

    // Ping every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (_) => _checkConnection());
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    bool isNowOnline = false;
    
    if (ApiService().backendUrl.isNotEmpty) {
      isNowOnline = await ApiService().testConnection(ApiService().backendUrl);
    }
    
    if (_isOnline != isNowOnline) {
      _isOnline = isNowOnline;
      notifyListeners(); // Tells WorkspaceProvider to show banner
    }

    if (_isOnline && !_isSyncing) {
      _syncOfflineQueue();
    }
  }

  File _getCacheFile(String endpoint) {
    final safeName = endpoint.replaceAll('/', '_');
    return File('${_cacheDir.path}/cache_$safeName.json');
  }

  File get _queueFile => File('${_cacheDir.path}/offline_queue.json');

  Future<void> saveCache(String endpoint, dynamic data) async {
    if (!_initialized) return;
    final file = _getCacheFile(endpoint);
    await file.writeAsString(jsonEncode(data));
  }

  Future<dynamic> loadCache(String endpoint) async {
    if (!_initialized) return null;
    final file = _getCacheFile(endpoint);
    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content);
    }
    return null;
  }

  Future<void> clearAllCache() async {
    if (!_initialized) return;
    if (await _cacheDir.exists()) {
      final files = _cacheDir.listSync();
      for (var file in files) {
        if (file is File && file.path.contains('cache_')) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('Failed to delete cache file: $e');
          }
        }
      }
    }
  }

  Future<void> enqueueMutation(String method, String endpoint, dynamic body) async {
    if (!_initialized) return;
    final file = _queueFile;
    List<dynamic> queue = [];
    if (await file.exists()) {
      final content = await file.readAsString();
      queue = jsonDecode(content) as List<dynamic>;
    }
    
    queue.add({
      'method': method,
      'endpoint': endpoint,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    await file.writeAsString(jsonEncode(queue));
    debugPrint('Queued offline action: $method $endpoint');
  }

  Future<void> _syncOfflineQueue() async {
    if (!_initialized) return;
    _isSyncing = true;
    final file = _queueFile;
    if (await file.exists()) {
      final content = await file.readAsString();
      final queue = jsonDecode(content) as List<dynamic>;
      
      if (queue.isNotEmpty) {
        debugPrint('Syncing ${queue.length} offline actions...');
        List<dynamic> remaining = [];
        
        for (var action in queue) {
          try {
             final method = action['method'] as String;
             final endpoint = action['endpoint'] as String;
             final body = action['body'];
             
             final response = await ApiService().rawMutation(method, endpoint, body: body);
             if (response.statusCode >= 300) {
                // If it's a 4xx error, there's a logic error, we might want to drop it to unblock the queue.
                if (response.statusCode >= 400 && response.statusCode < 500) {
                    debugPrint('Dropping invalid offline action: ${response.body}');
                } else {
                    throw Exception('Server error: ${response.statusCode}');
                }
             }
          } catch (e) {
             debugPrint('Failed to sync action, keeping in queue: $e');
             remaining.add(action);
          }
        }
        
        if (remaining.isEmpty) {
          await file.delete();
          debugPrint('Sync complete. Queue empty.');
        } else {
          await file.writeAsString(jsonEncode(remaining));
        }
      }
    }
    _isSyncing = false;
  }
}
