import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_storage_service.dart';
import 'job_service.dart';
import 'camera_service.dart';
import 'config_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineStorageService _storage = OfflineStorageService();
  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  // Check if device is online
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn ||
          result == ConnectivityResult.other);

      if (!hasConnection) return false;

      // Try to reach the server
      try {
        final baseUrl = await ConfigService.getBaseUrl();
        final response = await http
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 5));
        return response.statusCode == 200;
      } catch (e) {
        // If health endpoint doesn't exist, try base URL
        try {
          final baseUrl = await ConfigService.getBaseUrl();
          final response = await http
              .get(Uri.parse(baseUrl))
              .timeout(const Duration(seconds: 5));
          return response.statusCode < 500;
        } catch (e) {
          // If that fails, try the API base URL
          try {
            final baseUrl = await ConfigService.getBaseUrl();
            final response = await http
                .get(Uri.parse('$baseUrl/api/jobs'))
                .timeout(const Duration(seconds: 5));
            return response.statusCode < 500;
          } catch (e) {
            return false;
          }
        }
      }
    } catch (e) {
      return false;
    }
  }

  // Sync all pending job completions
  Future<void> syncPendingCompletions() async {
    if (_isSyncing) return;
    if (!await isOnline()) return;

    _isSyncing = true;
    try {
      final pending = await _storage.getPendingJobCompletions();
      print('🔄 Syncing ${pending.length} pending job completions...');

      final jobService = JobService();

      for (final item in pending) {
        try {
          // Upload photos first if they exist
          List<String> photoUrls = [];
          if (item['photo_paths'] != null) {
            final photoPaths = item['photo_paths'] as List<String>;
            final cameraService = CameraService();

            for (final photoPath in photoPaths) {
              final file = File(photoPath);
              if (await file.exists()) {
                final url = await cameraService.uploadPhoto(
                  file,
                  item['job_id'] as String,
                  'meter',
                );
                if (url != null) {
                  photoUrls.add(url);
                }
              }
            }
          }

          // Update completion data with uploaded photo URLs
          final completionData = Map<String, dynamic>.from(item['completion_data'] as Map);
          if (photoUrls.isNotEmpty) {
            completionData['photos'] = photoUrls;
          }

          // Submit job completion
          final result = await jobService.completeJob(
            item['job_id'] as String,
            completionData,
          );

          if (result['success']) {
            await _storage.markJobCompletionSynced(item['id'] as int);
            print('✅ Synced job completion: ${item['job_id']}');
          } else {
            // Increment retry count
            await _storage.incrementRetryCount(item['id'] as int);
            final retryCount = (item['retry_count'] as int) + 1;

            // Mark as failed if retry count exceeds 5
            if (retryCount >= 5) {
              await _storage.markJobCompletionFailed(item['id'] as int, retryCount: retryCount);
              print('❌ Failed to sync job completion after 5 retries: ${item['job_id']}');
            } else {
              print('⚠️ Failed to sync job completion, will retry: ${item['job_id']}');
            }
          }
        } catch (e) {
          print('❌ Error syncing job completion ${item['job_id']}: $e');
          await _storage.incrementRetryCount(item['id'] as int);
        }

        // Small delay between syncs to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Cleanup old records
      await _storage.cleanupOldRecords();
    } catch (e) {
      print('❌ Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Auto-sync when connectivity is restored
  Future<void> startAutoSync() async {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final hasConnection = results.any((result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn ||
          result == ConnectivityResult.other);

      if (hasConnection && await isOnline()) {
        print('🌐 Connection restored, starting sync...');
        await syncPendingCompletions();
      }
    });
  }

  // Get pending count
  Future<int> getPendingCount() async {
    return await _storage.getPendingCount();
  }
}

