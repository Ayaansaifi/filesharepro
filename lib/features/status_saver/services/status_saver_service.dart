import 'dart:io';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/file_utils.dart';

/// Service to access WhatsApp statuses using SAF (Storage Access Framework)
/// on Android 11+ and direct file access on older versions.
/// NO DATABASE — uses SharedPreferences for SAF URI persistence only.
class StatusSaverService {
  static const _channel = MethodChannel('com.filesharepro/status_saver');

  /// Check if we already have SAF permission
  Future<bool> hasPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(AppConstants.keySafUri);
    return uri != null && uri.isNotEmpty;
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
    } on PlatformException {
      // Fallback: try legacy file access for older Android
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
        return await _getStatusesViaSaf(safUri);
      }

      // Fallback: direct file access (Android 10 and below)
      return await _getStatusesLegacy();
    } catch (e) {
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
        return result
            .whereType<String>()
            .map((path) => File(path))
            .where((f) => f.existsSync())
            .toList()
          ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Legacy file access for older Android versions
  Future<List<File>> _getStatusesLegacy() async {
    final List<File> statuses = [];

    for (final path in AppConstants.whatsappStatusPaths) {
      final dir = Directory('/storage/emulated/0/$path');
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
    }

    // Also check WhatsApp Business
    for (final path in AppConstants.whatsappBusinessPaths) {
      final dir = Directory('/storage/emulated/0/$path');
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
    }

    statuses.sort((a, b) =>
        b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return statuses;
  }

  /// Save a status file to the gallery/saved directory
  Future<bool> saveStatus(File statusFile) async {
    try {
      final savedDir = await FileUtils.getSavedStatusDir();
      final fileName = statusFile.path.split(Platform.pathSeparator).last;
      final destPath = '${savedDir.path}/$fileName';

      await statusFile.copy(destPath);

      // Also try to add to gallery via platform channel
      try {
        await _channel.invokeMethod('addToGallery', {'path': destPath});
      } catch (_) {
        // Gallery notification is optional
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Try legacy file access (for older Android)
  Future<bool> _tryLegacyAccess() async {
    for (final path in AppConstants.whatsappStatusPaths) {
      final dir = Directory('/storage/emulated/0/$path');
      if (await dir.exists()) {
        return true;
      }
    }
    return false;
  }
}
