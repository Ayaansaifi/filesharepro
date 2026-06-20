import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/encryption_util.dart';
import '../../../core/utils/file_utils.dart';

/// Vault item metadata — persisted in vault_meta.json on device storage.
class VaultItem {
  final String id;
  final String originalName;
  final String encryptedFileName;
  final String fileType;
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

  VaultItem copyWith({String? originalName}) => VaultItem(
        id: id,
        originalName: originalName ?? this.originalName,
        encryptedFileName: encryptedFileName,
        fileType: fileType,
        originalSize: originalSize,
        addedAt: addedAt,
      );
}

/// Encrypted vault — files on public Documents storage + vault_meta.json.
/// Survives app uninstall; restore with same PIN after reinstall.
/// Files are NEVER auto-deleted — only when user explicitly deletes.
class VaultService {
  static const String _vaultItemsKey = 'vault_items';
  static const String _biometricEnabledKey = 'vault_biometric_enabled';
  static const String _biometricPinKey = 'vault_bio_pin';
  static const String _vaultRecoveryDataKey = 'vault_recovery_data';
  static const int _metaVersion = 2;
  static const _uuid = Uuid();
  bool _initialized = false;

  Future<File> _getMetaFile() async {
    final vaultDir = await FileUtils.getVaultDir();
    return File('${vaultDir.path}/${AppConstants.vaultMetaFile}');
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await FileUtils.getVaultDir();
    await _restoreFromPersistentMeta();
    await _reconcileVaultFromDisk();
    _initialized = true;
  }

  Future<List<VaultItem>> _loadItemsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_vaultItemsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (_) {
      return [];
    }
  }

  /// True if encrypted vault data exists on disk (e.g. after reinstall).
  Future<bool> hasExistingVaultOnDisk() async {
    final metaFile = await _getMetaFile();
    if (await metaFile.exists()) {
      try {
        final meta = jsonDecode(await metaFile.readAsString()) as Map;
        return meta['hash'] != null;
      } catch (_) {}
    }
    final vaultDir = await FileUtils.getVaultDir();
    if (await vaultDir.exists()) {
      return vaultDir
          .listSync()
          .any((e) => e.path.endsWith(AppConstants.encryptedExtension));
    }
    return false;
  }

  Future<void> _syncToPersistentMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getString(_vaultItemsKey);
    final salt = prefs.getString(AppConstants.keyVaultSalt);
    final hash = prefs.getString(AppConstants.keyVaultPinHash);
    final recovery = prefs.getString(_vaultRecoveryDataKey);
    final bioEnabled = prefs.getBool(_biometricEnabledKey);

    if (hash == null) return;

    final meta = {
      'version': _metaVersion,
      'salt': salt,
      'hash': hash,
      'items': items,
      'recovery': recovery,
      'biometricEnabled': bioEnabled ?? false,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final metaFile = await _getMetaFile();
    await metaFile.writeAsString(jsonEncode(meta));
    // Mirror meta at vault root parent for reinstall discovery
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final rootMeta = File('${vaultDir.parent.path}/${AppConstants.vaultMetaFile}');
      await rootMeta.writeAsString(jsonEncode(meta));
    } catch (_) {}
  }

  Future<void> _restoreFromPersistentMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final metaFile = await _getMetaFile();
    if (!await metaFile.exists()) return;

    try {
      final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      if (meta['hash'] == null) return;

      if (!prefs.containsKey(AppConstants.keyVaultPinHash)) {
        await prefs.setString(AppConstants.keyVaultPinHash, meta['hash'] as String);
        if (meta['salt'] != null) {
          await prefs.setString(AppConstants.keyVaultSalt, meta['salt'] as String);
        }
        if (meta['items'] != null) {
          await prefs.setString(_vaultItemsKey, meta['items'] as String);
        }
        if (meta['recovery'] != null) {
          await prefs.setString(_vaultRecoveryDataKey, meta['recovery'] as String);
        }
      } else if (meta['items'] != null) {
        final diskItems = meta['items'] as String;
        final localItems = prefs.getString(_vaultItemsKey);
        if (localItems == null || localItems.isEmpty) {
          await prefs.setString(_vaultItemsKey, diskItems);
        }
      }
    } catch (e) {
      debugPrint('Vault meta restore error: $e');
    }
  }

  /// Sync metadata with actual .vaultfile files on disk.
  Future<void> _reconcileVaultFromDisk() async {
    final vaultDir = await FileUtils.getVaultDir();
    if (!await vaultDir.exists()) return;

    final items = await _loadItemsFromPrefs();
    final onDisk = vaultDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith(AppConstants.encryptedExtension))
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toSet();

    var changed = false;
    final kept = <VaultItem>[];
    for (final item in items) {
      if (onDisk.contains(item.encryptedFileName)) {
        kept.add(item);
      } else {
        changed = true;
      }
    }

    final knownEnc = kept.map((i) => i.encryptedFileName).toSet();
    for (final encName in onDisk) {
      if (!knownEnc.contains(encName)) {
        kept.add(VaultItem(
          id: encName.replaceAll(AppConstants.encryptedExtension, ''),
          originalName: 'Recovered_${encName.substring(0, 8)}',
          encryptedFileName: encName,
          fileType: 'document',
          originalSize: 0,
          addedAt: DateTime.now(),
        ));
        changed = true;
      }
    }

    if (changed) await _saveVaultItemsMeta(kept);
  }

  Future<bool> isVaultSetup() async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(AppConstants.keyVaultPinHash);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  Future<void> _storePinForBiometric(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_biometricPinKey, base64Encode(utf8.encode(pin)));
  }

  Future<String?> getStoredPinForBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_biometricPinKey);
    if (encoded == null) return null;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> setupVault(String pin, {String? securityAnswer}) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = EncryptionUtil.hashPin(pin, salt);
    await prefs.setString(AppConstants.keyVaultPinHash, hash);
    await prefs.setString(AppConstants.keyVaultSalt, salt);

    if (securityAnswer != null && securityAnswer.isNotEmpty) {
      final ans = securityAnswer.toLowerCase().trim();
      final encryptedPinBytes = EncryptionUtil.encryptFileBytes(
        Uint8List.fromList(utf8.encode(pin)),
        ans,
      );
      await prefs.setString(
        _vaultRecoveryDataKey,
        base64Encode(encryptedPinBytes),
      );
    }

    await _storePinForBiometric(pin);
    await FileUtils.getVaultDir();
    await prefs.setString(_vaultItemsKey, '[]');
    await _syncToPersistentMeta();
  }

  Future<bool> verifyPin(String pin) async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(AppConstants.keyVaultPinHash);
    final salt = prefs.getString(AppConstants.keyVaultSalt);
    if (storedHash == null || salt == null) return false;
    return storedHash == EncryptionUtil.hashPin(pin, salt);
  }

  Future<bool> resetPinWithRecovery(String securityAnswer, String newPin) async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final recoveryData = prefs.getString(_vaultRecoveryDataKey);
    if (recoveryData == null) return false;

    try {
      final ans = securityAnswer.toLowerCase().trim();
      final decryptedPinBytes =
          EncryptionUtil.decryptFileBytes(base64Decode(recoveryData), ans);
      if (decryptedPinBytes != null) {
        final oldPin = utf8.decode(decryptedPinBytes);
        return changePin(oldPin, newPin, securityAnswer: ans);
      }
    } catch (_) {}
    return false;
  }

  Future<bool> changePin(String oldPin, String newPin, {String? securityAnswer}) async {
    if (!await verifyPin(oldPin)) return false;

    final items = await getVaultItems();
    final vaultDir = await FileUtils.getVaultDir();

    for (final item in items) {
      final file = File('${vaultDir.path}/${item.encryptedFileName}');
      if (await file.exists()) {
        final decrypted = await EncryptionUtil.decryptFile(file, oldPin);
        if (decrypted != null) {
          final reEncrypted = EncryptionUtil.encryptFileBytes(decrypted, newPin);
          await file.writeAsBytes(reEncrypted);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString(AppConstants.keyVaultPinHash, EncryptionUtil.hashPin(newPin, salt));
    await prefs.setString(AppConstants.keyVaultSalt, salt);

    if (securityAnswer != null && securityAnswer.isNotEmpty) {
      final ans = securityAnswer.toLowerCase().trim();
      final encryptedPinBytes = EncryptionUtil.encryptFileBytes(
        Uint8List.fromList(utf8.encode(newPin)),
        ans,
      );
      await prefs.setString(
        _vaultRecoveryDataKey,
        base64Encode(encryptedPinBytes),
      );
    }

    if (await isBiometricEnabled()) {
      await _storePinForBiometric(newPin);
    }
    await _syncToPersistentMeta();
    return true;
  }

  Future<VaultItem?> addToVault(File sourceFile, String pin) async {
    try {
      await _ensureInitialized();
      final vaultDir = await FileUtils.getVaultDir();
      final fileName = FileUtils.getFileName(sourceFile.path);
      final id = _uuid.v4();
      final encFileName = '$id${AppConstants.encryptedExtension}';

      final bytes = await sourceFile.readAsBytes();
      final encrypted = EncryptionUtil.encryptFileBytes(bytes, pin);
      await File('${vaultDir.path}/$encFileName').writeAsBytes(encrypted);

      String fileType = 'document';
      if (FileUtils.isImage(fileName)) fileType = 'image';
      if (FileUtils.isVideo(fileName)) fileType = 'video';

      final item = VaultItem(
        id: id,
        originalName: fileName,
        encryptedFileName: encFileName,
        fileType: fileType,
        originalSize: bytes.length,
        addedAt: DateTime.now(),
      );
      await _addVaultItemMeta(item);
      return item;
    } catch (e) {
      debugPrint('addToVault error: $e');
      return null;
    }
  }

  Future<List<VaultItem>> getVaultItems() async {
    await _ensureInitialized();
    return _loadItemsFromPrefs();
  }

  Future<bool> renameVaultItem(String id, String newName) async {
    final safeName = FileUtils.sanitizeFileName(newName);
    if (safeName.isEmpty) return false;
    final items = await getVaultItems();
    final idx = items.indexWhere((i) => i.id == id);
    if (idx == -1) return false;
    items[idx] = items[idx].copyWith(originalName: safeName);
    await _saveVaultItemsMeta(items);
    return true;
  }

  Future<Uint8List?> decryptVaultFile(VaultItem item, String pin) async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final file = File('${vaultDir.path}/${item.encryptedFileName}');
      if (!await file.exists()) return null;
      return EncryptionUtil.decryptFile(file, pin);
    } catch (_) {
      return null;
    }
  }

  Future<bool> removeFromVault(VaultItem item) async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final file = File('${vaultDir.path}/${item.encryptedFileName}');
      if (await file.exists()) await file.delete();
      await _removeVaultItemMeta(item.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Export decrypted file to phone gallery / downloads. Vault copy stays unless [removeFromVaultAfter].
  Future<File?> exportFromVault(
    VaultItem item,
    String pin, {
    bool removeFromVaultAfter = false,
  }) async {
    try {
      final decrypted = await decryptVaultFile(item, pin);
      if (decrypted == null) return null;

      final tempDir = await getTemporaryDirectory();
      final safeName = FileUtils.sanitizeFileName(item.originalName);
      final exportFile = File('${tempDir.path}/$safeName');
      await exportFile.writeAsBytes(decrypted);

      if (item.fileType == 'image' || item.fileType == 'video') {
        if (!await Gal.hasAccess()) await Gal.requestAccess();
        if (item.fileType == 'image') {
          await Gal.putImage(exportFile.path);
        } else {
          await Gal.putVideo(exportFile.path);
        }
      } else {
        final downloadDir = await FileUtils.getPublicDownloadsDir();
        final dest = await FileUtils.uniqueFilePath(downloadDir.path, safeName);
        await exportFile.copy(dest);
      }

      if (removeFromVaultAfter) {
        await removeFromVault(item);
      }
      return exportFile;
    } catch (e) {
      debugPrint('Export failed: $e');
      return null;
    }
  }

  Future<bool> clearVault() async {
    try {
      final vaultDir = await FileUtils.getVaultDir();
      final metaFile = await _getMetaFile();
      if (await metaFile.exists()) await metaFile.delete();
      if (await vaultDir.exists()) await vaultDir.delete(recursive: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_vaultItemsKey);
      await prefs.remove(AppConstants.keyVaultPinHash);
      await prefs.remove(AppConstants.keyVaultSalt);
      await prefs.remove(_vaultRecoveryDataKey);
      await prefs.remove(_biometricEnabledKey);
      await prefs.remove(_biometricPinKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getVaultStats() async {
    final items = await getVaultItems();
    final vaultDir = await FileUtils.getVaultDir();
    int diskSize = 0;
    int images = 0, videos = 0, docs = 0;

    for (final item in items) {
      switch (item.fileType) {
        case 'image':
          images++;
          break;
        case 'video':
          videos++;
          break;
        default:
          docs++;
      }
      final f = File('${vaultDir.path}/${item.encryptedFileName}');
      if (await f.exists()) diskSize += await f.length();
    }

    return {
      'totalFiles': items.length,
      'totalSize': diskSize,
      'images': images,
      'videos': videos,
      'documents': docs,
      'storagePath': vaultDir.path,
      'isPublicStorage': FileUtils.isUsingPublicVaultStorage,
    };
  }

  Future<void> _addVaultItemMeta(VaultItem item) async {
    final items = await _loadItemsFromPrefs();
    items.add(item);
    await _saveVaultItemsMeta(items);
  }

  Future<void> _removeVaultItemMeta(String id) async {
    final items = await _loadItemsFromPrefs();
    items.removeWhere((i) => i.id == id);
    await _saveVaultItemsMeta(items);
  }

  Future<void> _saveVaultItemsMeta(List<VaultItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vaultItemsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    await _syncToPersistentMeta();
  }
}
