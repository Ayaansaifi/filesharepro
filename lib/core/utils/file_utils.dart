import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';

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
    return path.split(Platform.pathSeparator).last;
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

  /// Get vault directory (hidden with .nomedia)
  static Future<Directory> getVaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${dir.path}/.secure_vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
      // Create .nomedia to hide from gallery
      final nomedia = File('${vaultDir.path}/.nomedia');
      await nomedia.create();
    }
    return vaultDir;
  }

  /// Get saved statuses directory
  static Future<Directory> getSavedStatusDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final statusDir = Directory('${dir.path}/saved_statuses');
    if (!await statusDir.exists()) {
      await statusDir.create(recursive: true);
    }
    return statusDir;
  }

  /// Get received files directory
  static Future<Directory> getReceivedDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final receivedDir = Directory('${dir.path}/received_files');
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
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
