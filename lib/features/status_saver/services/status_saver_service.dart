import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';

/// Service to access WhatsApp statuses using SAF (Storage Access Framework)
/// on Android 11+ and direct file access on older versions.
/// NO DATABASE — uses SharedPreferences for SAF URI persistence only.
class StatusSaverService {
  static const _channel = MethodChannel('com.filesharepro/status_saver');

  /// Check if we already have SAF permission (and it's still valid)
  Future<bool> hasPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(AppConstants.keySafUri);
    
    if (uri != null && uri.isNotEmpty) {
      // Verify the persisted SAF URI is still accessible
      final isValid = await _validateSafUri(uri);
      if (isValid) return true;
      
      // URI is no longer valid — clear it so user re-grants
      await prefs.remove(AppConstants.keySafUri);
      return false;
    }
    
    // Also check legacy access
    return await _tryLegacyAccess();
  }

  /// Validate that a persisted SAF URI is still accessible
  Future<bool> _validateSafUri(String uri) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getStatuses',
        {'uri': uri},
      );
      // If we got a response without error, the URI is still valid
      return result != null;
    } on PlatformException catch (e) {
      debugPrint('SAF URI validation failed: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Request SAF permission via platform channel
  /// Opens Android document picker for user to select .Statuses folder
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestSafPermission');
      if (result != null && result.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keySafUri, result);
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('SAF permission error: $e');
      // Fallback: try legacy file access for older Android
      return _tryLegacyAccess();
    } on MissingPluginException {
      debugPrint('Platform channel not available, trying legacy access');
      return _tryLegacyAccess();
    }
  }

  /// Get all status files (images + videos)
  Future<List<File>> getStatuses() async {
    try {
      // Try SAF first (Android 11+)
      final prefs = await SharedPreferences.getInstance();
      final safUri = prefs.getString(AppConstants.keySafUri);

      if (safUri != null && safUri.isNotEmpty) {
        final files = await _getStatusesViaSaf(safUri);
        if (files.isNotEmpty) return files;
        
        // SAF returned empty — might be permission revoked
        // Try to validate
        final isValid = await _validateSafUri(safUri);
        if (!isValid) {
          // Clear invalid URI
          await prefs.remove(AppConstants.keySafUri);
          debugPrint('SAF URI was invalid, cleared. User needs to re-grant.');
        }
      }

      // Fallback: direct file access (Android 10 and below)
      return await _getStatusesLegacy();
    } catch (e) {
      debugPrint('Error getting statuses: $e');
      return [];
    }
  }

  /// Get statuses via SAF platform channel
  Future<List<File>> _getStatusesViaSaf(String safUri) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getStatuses',
        {'uri': safUri},
      );

      if (result != null) {
        // Platform channel copies files to cache and returns paths
        final files = result
            .whereType<String>()
            .map((path) => File(path))
            .where((f) {
              try {
                return f.existsSync() && f.lengthSync() > 0;
              } catch (e) {
                return false;
              }
            })
            .toList();
        
        // Sort by modification time (newest first)
        files.sort((a, b) {
          try {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          } catch (e) {
            return 0;
          }
        });
        
        return files;
      }
      return [];
    } on PlatformException catch (e) {
      debugPrint('SAF getStatuses error: $e');
      return [];
    } on MissingPluginException {
      debugPrint('Platform channel not available');
      return [];
    }
  }

  /// Legacy file access for older Android versions
  Future<List<File>> _getStatusesLegacy() async {
    final List<File> statuses = [];

    // Check all WhatsApp status paths
    final allPaths = [
      ...AppConstants.whatsappStatusPaths,
      ...AppConstants.whatsappBusinessPaths,
    ];

    for (final path in allPaths) {
      final dir = Directory('/storage/emulated/0/$path');
      try {
        if (await dir.exists()) {
          final files = dir.listSync()
              .whereType<File>()
              .where((f) {
                final name = f.path.split('/').last;
                return !name.startsWith('.') &&
                    (FileUtils.isImage(f.path) || FileUtils.isVideo(f.path));
              })
              .toList();
          statuses.addAll(files);
        }
      } catch (e) {
        debugPrint('Error reading status directory $path: $e');
      }
    }

    // Sort by modification time (newest first)
    statuses.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (e) {
        return 0;
      }
    });
    
    return statuses;
  }

  /// Save a status file to the gallery/saved directory
  Future<bool> saveStatus(File statusFile) async {
    try {
      final savedDir = await FileUtils.getSavedStatusDir();
      final fileName = statusFile.path.split(Platform.pathSeparator).last;
      final destPath = '${savedDir.path}/$fileName';

      // Check if already saved
      final destFile = File(destPath);
      if (await destFile.exists()) {
        return true; // Already saved
      }

      await statusFile.copy(destPath);

      // Also try to add to gallery via platform channel
      try {
        await _channel.invokeMethod('addToGallery', {'path': destPath});
      } catch (_) {
        // Gallery notification is optional
      }

      return true;
    } catch (e) {
      debugPrint('Error saving status: $e');
      return false;
    }
  }

  /// Get list of already saved statuses
  Future<List<File>> getSavedStatuses() async {
    try {
      final savedDir = await FileUtils.getSavedStatusDir();
      if (await savedDir.exists()) {
        final files = savedDir.listSync()
            .whereType<File>()
            .where((f) {
              final name = f.path.split('/').last;
              return !name.startsWith('.') &&
                  (FileUtils.isImage(f.path) || FileUtils.isVideo(f.path));
            })
            .toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        return files;
      }
    } catch (e) {
      debugPrint('Error getting saved statuses: $e');
    }
    return [];
  }

  /// Try legacy file access (for older Android)
  Future<bool> _tryLegacyAccess() async {
    final allPaths = [
      ...AppConstants.whatsappStatusPaths,
      ...AppConstants.whatsappBusinessPaths,
    ];
    
    for (final path in allPaths) {
      final dir = Directory('/storage/emulated/0/$path');
      try {
        if (await dir.exists()) {
          return true;
        }
      } catch (e) {
        // continue checking
      }
    }
    return false;
  }
}
