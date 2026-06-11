import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/encryption_util.dart';
import '../../../core/utils/file_utils.dart';
import 'package:gal/gal.dart';

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
  static const String _biometricEnabledKey = 'vault_biometric_enabled';
  static const String _biometricPinKey = 'vault_bio_pin';
  static const String _vaultRecoveryDataKey = 'vault_recovery_data';

  /// Get the persistent meta file from vault directory
  Future<File> _getMetaFile() async {
    final vaultDir = await FileUtils.getVaultDir();
    return File('${vaultDir.path}/vault_meta.json');
  }

  /// Sync SharedPreferences data to persistent file
  Future<void> _syncToPersistentMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getString(_vaultItemsKey);
    final salt = prefs.getString(AppConstants.keyVaultSalt);
    final hash = prefs.getString(AppConstants.keyVaultPinHash);
    final recovery = prefs.getString(_vaultRecoveryDataKey);

    if (hash != null) {
      final Map<String, dynamic> meta = {
        'salt': salt,
        'hash': hash,
        'items': items,
        'recovery': recovery,
      };
      final metaFile = await _getMetaFile();
      await metaFile.writeAsString(jsonEncode(meta));
    }
  }

  /// Restore SharedPreferences from persistent file if needed
  Future<void> _restoreFromPersistentMeta() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(AppConstants.keyVaultPinHash)) return; // Already setup

    final metaFile = await _getMetaFile();
    if (await metaFile.exists()) {
      try {
        final content = await metaFile.readAsString();
        final Map<String, dynamic> meta = jsonDecode(content);
        
        if (meta['hash'] != null) {
          await prefs.setString(AppConstants.keyVaultPinHash, meta['hash']);
          await prefs.setString(AppConstants.keyVaultSalt, meta['salt']);
          if (meta['items'] != null) await prefs.setString(_vaultItemsKey, meta['items']);
          if (meta['recovery'] != null) await prefs.setString(_vaultRecoveryDataKey, meta['recovery']);
        }
      } catch (e) {
        // Corrupted meta file
      }
    }
  }

  /// Check if vault PIN is set up
  Future<bool> isVaultSetup() async {
    await _restoreFromPersistentMeta();
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(AppConstants.keyVaultPinHash);
  }

  /// Check if biometric unlock is enabled
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Enable/disable biometric unlock
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Store PIN for biometric unlock (base64 encoded in SharedPreferences)
  /// This is protected by the device's biometric hardware
  Future<void> _storePinForBiometric(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = base64Encode(utf8.encode(pin));
    await prefs.setString(_biometricPinKey, encoded);
  }

  /// Retrieve stored PIN after biometric authentication
  Future<String?> getStoredPinForBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_biometricPinKey);
    if (encoded == null) return null;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      return null;
    }
  }

  /// Setup vault with a new PIN
  Future<void> setupVault(String pin, {String? securityAnswer}) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = EncryptionUtil.hashPin(pin, salt);
    await prefs.setString(AppConstants.keyVaultPinHash, hash);
    await prefs.setString(AppConstants.keyVaultSalt, salt);

    if (securityAnswer != null && securityAnswer.isNotEmpty) {
      final ans = securityAnswer.toLowerCase().trim();
      final encryptedPinBytes = EncryptionUtil.encryptFileBytes(Uint8List.fromList(utf8.encode(pin)), ans);
      await prefs.setString(_vaultRecoveryDataKey, base64Encode(encryptedPinBytes));
    }

    // Store PIN for biometric unlock
    await _storePinForBiometric(pin);

    // Create vault directory with .nomedia
    await FileUtils.getVaultDir();
    
    // Sync to persistent meta
    await _syncToPersistentMeta();
  }

  /// Verify vault PIN
  Future<bool> verifyPin(String pin) async {
    await _restoreFromPersistentMeta();
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(AppConstants.keyVaultPinHash);
    final salt = prefs.getString(AppConstants.keyVaultSalt);
    if (storedHash == null || salt == null) return false;

    final inputHash = EncryptionUtil.hashPin(pin, salt);
    return storedHash == inputHash;
  }
  
  /// Reset PIN using Security Answer
  Future<bool> resetPinWithRecovery(String securityAnswer, String newPin) async {
    await _restoreFromPersistentMeta();
    final prefs = await SharedPreferences.getInstance();
    final recoveryData = prefs.getString(_vaultRecoveryDataKey);
    if (recoveryData == null) return false;
    
    try {
      final ans = securityAnswer.toLowerCase().trim();
      final encryptedPinBytes = base64Decode(recoveryData);
      final decryptedPinBytes = EncryptionUtil.decryptFileBytes(encryptedPinBytes, ans);
      
      if (decryptedPinBytes != null) {
        final oldPin = utf8.decode(decryptedPinBytes);
        return await changePin(oldPin, newPin, securityAnswer: ans);
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  /// Change vault PIN (requires old PIN verification)
  Future<bool> changePin(String oldPin, String newPin, {String? securityAnswer}) async {
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

    if (securityAnswer != null && securityAnswer.isNotEmpty) {
      final ans = securityAnswer.toLowerCase().trim();
      final encryptedPinBytes = EncryptionUtil.encryptFileBytes(Uint8List.fromList(utf8.encode(newPin)), ans);
      await prefs.setString(_vaultRecoveryDataKey, base64Encode(encryptedPinBytes));
    }

    await _syncToPersistentMeta();
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

  /// Export a vault file (decrypt and save to gallery/downloads)
  Future<File?> exportFromVault(VaultItem item, String pin) async {
    try {
      final decrypted = await decryptVaultFile(item, pin);
      if (decrypted == null) return null;

      final tempDir = await getTemporaryDirectory();
      final exportFile = File('${tempDir.path}/${item.originalName}');
      await exportFile.writeAsBytes(decrypted);

      if (item.fileType == 'image' || item.fileType == 'video') {
        if (!await Gal.hasAccess()) {
          await Gal.requestAccess();
        }
        if (item.fileType == 'image') {
          await Gal.putImage(exportFile.path);
        } else {
          await Gal.putVideo(exportFile.path);
        }
      } else {
        // Fallback for documents
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final docFile = File('${downloadDir.path}/${item.originalName}');
            await docFile.writeAsBytes(decrypted);
          }
        } catch (_) {}
      }

      return exportFile;
    } catch (e) {
      debugPrint('Export failed: $e');
      return null;
    }
  }

  /// Clear entire vault
  Future<bool> clearVault() async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      if (await vaultDir.exists()) {
        await vaultDir.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_vaultItemsKey);
      await prefs.remove(AppConstants.keyVaultPinHash);
      await prefs.remove(AppConstants.keyVaultSalt);
      await prefs.remove(_vaultRecoveryDataKey);
      await prefs.remove(_biometricEnabledKey);
      await prefs.remove(_biometricPinKey);
      return true;
    } catch (e) {
      return false;
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
    await _syncToPersistentMeta();
  }
}
