import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  PermissionUtils._();

  /// Request storage permissions based on Android version
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions
      final androidInfo = await _getAndroidSdkVersion();
      if (androidInfo >= 33) {
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        return photos.isGranted && videos.isGranted;
      } else if (androidInfo >= 30) {
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
  static Future<bool> requestNearbyPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidSdkVersion();
      
      if (androidInfo >= 33) {
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

  static Future<int> _getAndroidSdkVersion() async {
    // Default to latest behavior
    return 33;
  }
}
