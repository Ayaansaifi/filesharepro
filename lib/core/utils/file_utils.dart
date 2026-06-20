import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class FileUtils {
  FileUtils._();

  /// Get human-readable file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get file extension from path
  static String getExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return path.substring(dotIndex).toLowerCase();
  }

  /// Get file name from path
  static String getFileName(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  /// Sanitize a received file name — blocks path traversal and unsafe chars.
  static String sanitizeFileName(String rawName) {
    var name = rawName.replaceAll(RegExp(r'[/\\]'), '_');
    name = name.replaceAll('..', '_');
    name = name.replaceAll(RegExp(r'[\x00-\x1f]'), '');
    name = name.trim();
    if (name.isEmpty || name == '.' || name == '..') {
      name = 'received_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (name.length > 200) {
      final ext = getExtension(name);
      name = '${name.substring(0, 180)}$ext';
    }
    return name;
  }

  /// Unique path if file already exists (ShareIt-style auto-rename).
  static Future<String> uniqueFilePath(String directory, String fileName) async {
    final safeName = sanitizeFileName(fileName);
    var target = '$directory/$safeName';
    if (!await File(target).exists()) return target;

    final ext = getExtension(safeName);
    final base = ext.isEmpty
        ? safeName
        : safeName.substring(0, safeName.length - ext.length);

    for (var i = 1; i < 1000; i++) {
      final candidate = '$directory/${base}_$i$ext';
      if (!await File(candidate).exists()) return candidate;
    }
    return '$directory/${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  /// Get MIME type
  static String getMimeType(String path) {
    return lookupMimeType(path) ?? 'application/octet-stream';
  }

  /// Check if file is image
  static bool isImage(String path) {
    final ext = getExtension(path);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }

  /// Check if file is video
  static bool isVideo(String path) {
    final ext = getExtension(path);
    return ['.mp4', '.mkv', '.avi', '.mov', '.webm', '.3gp'].contains(ext);
  }

  /// Get app's private storage directory
  static Future<Directory> getAppStorageDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir;
  }

  /// Get temp directory for transfers
  static Future<Directory> getTransferTempDir() async {
    final dir = await getTemporaryDirectory();
    final transferDir = Directory('${dir.path}/transfers');
    if (!await transferDir.exists()) {
      await transferDir.create(recursive: true);
    }
    return transferDir;
  }

  /// Public vault root — survives app uninstall (Documents folder).
  static const String publicVaultRoot =
      '/storage/emulated/0/Documents/FileShareProVault';
  static const String legacyVaultRoot =
      '/storage/emulated/0/Documents/.FileShareVault';

  static bool isUsingPublicVaultStorage = false;

  /// Get vault directory (public Documents — persists after uninstall).
  static Future<Directory> getVaultDir() async {
    if (kIsWeb || !Platform.isAndroid) {
      final dir = await getApplicationDocumentsDirectory();
      final finalDir = Directory('${dir.path}/.secure_vault');
      if (!await finalDir.exists()) await finalDir.create(recursive: true);
      isUsingPublicVaultStorage = false;
      return finalDir;
    }

    Directory? rootDir;
    for (final rootPath in [publicVaultRoot, legacyVaultRoot]) {
      final candidate = Directory(rootPath);
      try {
        if (!await candidate.exists()) {
          await candidate.create(recursive: true);
        }
        rootDir = candidate;
        isUsingPublicVaultStorage = true;
        break;
      } catch (_) {}
    }

    rootDir ??= await getExternalStorageDirectory();
    isUsingPublicVaultStorage = rootDir?.path.contains('/Documents/') ?? false;

    final vaultDir = Directory('${rootDir!.path}/.secure_vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
      await File('${vaultDir.path}/${AppConstants.nomediaFile}').create();
      await File('${rootDir.path}/${AppConstants.nomediaFile}').create();
    }
    return vaultDir;
  }

  /// Public downloads folder for document export.
  static Future<Directory> getPublicDownloadsDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/FileSharePro');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Saved WhatsApp statuses — public Pictures folder (survives uninstall).
  static Future<Directory> getSavedStatusDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Pictures/FileSharePro/Statuses');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final dir = await getApplicationDocumentsDirectory();
    final statusDir = Directory('${dir.path}/saved_statuses');
    if (!await statusDir.exists()) await statusDir.create(recursive: true);
    return statusDir;
  }

  /// Get received files directory (public Downloads — survives uninstall)
  static Future<Directory> getReceivedDir() async {
    if (!kIsWeb && Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/FileSharePro/Received');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final dir = await getApplicationDocumentsDirectory();
    final receivedDir = Directory('${dir.path}/received_files');
    if (!await receivedDir.exists()) await receivedDir.create(recursive: true);
    return receivedDir;
  }

  /// Delete a file safely
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Copy file to destination
  static Future<File?> copyFile(String sourcePath, String destPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;
      return await sourceFile.copy(destPath);
    } catch (e) {
      return null;
    }
  }

  /// Get icon for file type
  static String getFileTypeIcon(String path) {
    if (isImage(path)) return '🖼️';
    if (isVideo(path)) return '🎬';
    final ext = getExtension(path);
    switch (ext) {
      case '.pdf': return '📄';
      case '.doc': case '.docx': return '📝';
      case '.xls': case '.xlsx': return '📊';
      case '.mp3': case '.wav': case '.aac': return '🎵';
      case '.zip': case '.rar': case '.7z': return '📦';
      case '.apk': return '📱';
      default: return '📎';
    }
  }
}
