import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/encryption_util.dart';
import '../../../core/utils/file_utils.dart';

/// Vault item metadata — stored as JSON in SharedPreferences (NO DB)
class VaultItem {
  final String id;
  final String originalName;
  final String encryptedFileName;
  final String fileType; // 'image', 'video', 'document'
  final int originalSize;
  final DateTime addedAt;

  VaultItem({
    required this.id,
    required this.originalName,
    required this.encryptedFileName,
    required this.fileType,
    required this.originalSize,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalName': originalName,
        'encryptedFileName': encryptedFileName,
        'fileType': fileType,
        'originalSize': originalSize,
        'addedAt': addedAt.toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
        id: json['id'] as String,
        originalName: json['originalName'] as String,
        encryptedFileName: json['encryptedFileName'] as String,
        fileType: json['fileType'] as String,
        originalSize: json['originalSize'] as int,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}

/// Encrypted vault service — files stored in .nomedia hidden folder
/// Metadata stored in SharedPreferences as JSON. ZERO DATABASE.
class VaultService {
  static const String _vaultItemsKey = 'vault_items';

  /// Check if vault PIN is set up
  Future<bool> isVaultSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(AppConstants.keyVaultPinHash);
  }

  /// Setup vault with a new PIN
  Future<void> setupVault(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = EncryptionUtil.hashPin(pin, salt);
    await prefs.setString(AppConstants.keyVaultPinHash, hash);
    await prefs.setString(AppConstants.keyVaultSalt, salt);

    // Create vault directory with .nomedia
    await FileUtils.getVaultDir();
  }

  /// Verify vault PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(AppConstants.keyVaultPinHash);
    final salt = prefs.getString(AppConstants.keyVaultSalt);
    if (storedHash == null || salt == null) return false;

    final inputHash = EncryptionUtil.hashPin(pin, salt);
    return storedHash == inputHash;
  }

  /// Change vault PIN (requires old PIN verification)
  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) return false;

    // Re-encrypt all vault files with new PIN
    final items = await getVaultItems();
    final vaultDir = await FileUtils.getVaultDir();

    for (final item in items) {
      final file = File('${vaultDir.path}/${item.encryptedFileName}');
      if (await file.exists()) {
        // Decrypt with old PIN
        final decrypted = await EncryptionUtil.decryptFile(file, oldPin);
        if (decrypted != null) {
          // Re-encrypt with new PIN
          final reEncrypted = EncryptionUtil.encryptFileBytes(decrypted, newPin);
          await file.writeAsBytes(reEncrypted);
        }
      }
    }

    // Update PIN hash
    final prefs = await SharedPreferences.getInstance();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = EncryptionUtil.hashPin(newPin, salt);
    await prefs.setString(AppConstants.keyVaultPinHash, hash);
    await prefs.setString(AppConstants.keyVaultSalt, salt);

    return true;
  }

  /// Add a file to the vault (encrypts and stores)
  Future<VaultItem?> addToVault(File sourceFile, String pin) async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final fileName = FileUtils.getFileName(sourceFile.path);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final encFileName = '$id${AppConstants.encryptedExtension}';

      // Read and encrypt
      final bytes = await sourceFile.readAsBytes();
      final encrypted = EncryptionUtil.encryptFileBytes(bytes, pin);

      // Save encrypted file
      final encFile = File('${vaultDir.path}/$encFileName');
      await encFile.writeAsBytes(encrypted);

      // Determine file type
      String fileType = 'document';
      if (FileUtils.isImage(fileName)) fileType = 'image';
      if (FileUtils.isVideo(fileName)) fileType = 'video';

      // Create vault item
      final item = VaultItem(
        id: id,
        originalName: fileName,
        encryptedFileName: encFileName,
        fileType: fileType,
        originalSize: bytes.length,
        addedAt: DateTime.now(),
      );

      // Save metadata to SharedPreferences
      await _addVaultItemMeta(item);

      return item;
    } catch (e) {
      return null;
    }
  }

  /// Get all vault items metadata
  Future<List<VaultItem>> getVaultItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_vaultItemsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (e) {
      return [];
    }
  }

  /// Decrypt a vault file for viewing
  Future<Uint8List?> decryptVaultFile(VaultItem item, String pin) async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final file = File('${vaultDir.path}/${item.encryptedFileName}');
      if (!await file.exists()) return null;

      return await EncryptionUtil.decryptFile(file, pin);
    } catch (e) {
      return null;
    }
  }

  /// Remove a file from vault
  Future<bool> removeFromVault(VaultItem item) async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final file = File('${vaultDir.path}/${item.encryptedFileName}');
      if (await file.exists()) {
        await file.delete();
      }
      await _removeVaultItemMeta(item.id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Export a vault file (decrypt and save to downloads)
  Future<File?> exportFromVault(VaultItem item, String pin) async {
    try {
      final decrypted = await decryptVaultFile(item, pin);
      if (decrypted == null) return null;

      final downloadsDir = await getApplicationDocumentsDirectory();
      final exportFile = File('${downloadsDir.path}/${item.originalName}');
      await exportFile.writeAsBytes(decrypted);
      return exportFile;
    } catch (e) {
      return null;
    }
  }

  /// Get vault storage stats
  Future<Map<String, dynamic>> getVaultStats() async {
    final items = await getVaultItems();
    int totalSize = 0;
    int images = 0, videos = 0, docs = 0;

    for (final item in items) {
      totalSize += item.originalSize;
      switch (item.fileType) {
        case 'image': images++; break;
        case 'video': videos++; break;
        default: docs++; break;
      }
    }

    return {
      'totalFiles': items.length,
      'totalSize': totalSize,
      'images': images,
      'videos': videos,
      'documents': docs,
    };
  }

  // ─── Private Helpers ─────────────────────────────────────

  Future<void> _addVaultItemMeta(VaultItem item) async {
    final items = await getVaultItems();
    items.add(item);
    await _saveVaultItemsMeta(items);
  }

  Future<void> _removeVaultItemMeta(String id) async {
    final items = await getVaultItems();
    items.removeWhere((i) => i.id == id);
    await _saveVaultItemsMeta(items);
  }

  Future<void> _saveVaultItemsMeta(List<VaultItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_vaultItemsKey, jsonStr);
  }
}
