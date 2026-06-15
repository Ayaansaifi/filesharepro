import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  PermissionUtils._();

  /// Cached SDK version to avoid repeated platform channel calls
  static int? _cachedSdkVersion;

  /// Request storage permissions based on Android version
  static Future<bool> requestStoragePermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      final sdkVersion = await _getAndroidSdkVersion();
      if (sdkVersion >= 33) {
        // Android 13+ uses granular media permissions
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        return photos.isGranted && videos.isGranted;
      } else if (sdkVersion >= 30) {
        // Android 11-12
        final storage = await Permission.storage.request();
        return storage.isGranted;
      } else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }
    return true;
  }

  /// Request Wi-Fi/location permissions for nearby discovery
  static Future<bool> requestNearbyPermissions(BuildContext context) async {
    if (!kIsWeb && Platform.isAndroid) {
      // Check if location is already granted
      final status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        // Show Prominent Disclosure before requesting location
        if (context.mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Location Permission Needed'),
              content: const Text(
                'FileShare Pro collects location data to enable the discovery of nearby devices for Wi-Fi Direct file transfers.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('I Understand'),
                ),
              ],
            ),
          );

          if (proceed != true) return false;
        }
      }

      final sdkVersion = await _getAndroidSdkVersion();
      
      if (sdkVersion >= 33) {
        final nearby = await Permission.nearbyWifiDevices.request();
        final location = await Permission.locationWhenInUse.request();
        return nearby.isGranted && location.isGranted;
      } else {
        final location = await Permission.locationWhenInUse.request();
        return location.isGranted;
      }
    }
    return true;
  }

  /// Request camera permission for QR scanning
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Check if all necessary permissions are granted
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'storage': await Permission.storage.isGranted,
      'camera': await Permission.camera.isGranted,
      'location': await Permission.locationWhenInUse.isGranted,
    };
  }

  /// Show permission denied dialog
  static void showPermissionDeniedDialog(BuildContext context, String permission) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          '$permission permission is needed for this feature. '
          'Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Get actual Android SDK version via platform channel
  static Future<int> _getAndroidSdkVersion() async {
    if (_cachedSdkVersion != null) return _cachedSdkVersion!;
    
    if (kIsWeb || !Platform.isAndroid) {
      _cachedSdkVersion = 0;
      return 0;
    }
    
    try {
      // Use MethodChannel to query Android's Build.VERSION.SDK_INT
      const channel = MethodChannel('com.filesharepro/device_info');
      final sdkInt = await channel.invokeMethod<int>('getSdkVersion');
      _cachedSdkVersion = sdkInt ?? 33;
      return _cachedSdkVersion!;
    } on MissingPluginException {
      // Platform channel not available — fallback to safe default
      // Android 13 (API 33) behavior is the safest default
      _cachedSdkVersion = 33;
      return 33;
    } catch (e) {
      _cachedSdkVersion = 33;
      return 33;
    }
  }
}
