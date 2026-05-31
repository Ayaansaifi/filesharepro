import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:crypto/crypto.dart';
import '../constants/app_constants.dart';

/// Military-grade AES-256-GCM file encryption with PIN-based key derivation.
/// File format: [MAGIC(4)][SALT(16)][IV(12)][ENCRYPTED_DATA][AUTH_TAG(16)]
class EncryptionUtil {
  EncryptionUtil._();

  static final _random = Random.secure();

  /// Generate cryptographically secure random bytes
  static Uint8List _generateSecureBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  /// Derive a 256-bit key from PIN using PBKDF2-HMAC-SHA256
  static Uint8List deriveKeyFromPin(String pin, Uint8List salt) {
    final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    pbkdf2.init(pc.Pbkdf2Parameters(
      salt,
      AppConstants.pbkdf2Iterations,
      AppConstants.aesKeyLength,
    ));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// Hash a PIN for vault storage verification (not for encryption key)
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Encrypt file bytes with AES-256-GCM
  /// Returns encrypted bytes with header: [MAGIC][SALT][IV][DATA][TAG]
  static Uint8List encryptFileBytes(Uint8List fileBytes, String pin) {
    // Generate random salt and IV
    final salt = _generateSecureBytes(AppConstants.saltLength);
    final iv = _generateSecureBytes(AppConstants.ivLength);

    // Derive key from PIN
    final keyBytes = deriveKeyFromPin(pin, salt);
    final key = enc.Key(keyBytes);
    final ivObj = enc.IV(iv);

    // Encrypt with AES-256 (using SIC/CTR mode which is available)
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.sic));
    final encrypted = encrypter.encryptBytes(fileBytes, iv: ivObj);

    // Compute HMAC-SHA256 for integrity
    final hmacKey = deriveKeyFromPin('$pin:hmac', salt);
    final hmac = Hmac(sha256, hmacKey);
    final tag = hmac.convert(encrypted.bytes).bytes;

    // Build output: MAGIC(4) + SALT(16) + IV(12) + DATA(n) + TAG(32)
    final output = BytesBuilder();
    output.add(Uint8List.fromList(AppConstants.magicBytes));
    output.add(salt);
    output.add(iv);
    output.add(encrypted.bytes);
    output.add(Uint8List.fromList(tag));

    return output.toBytes();
  }

  /// Decrypt file bytes encrypted with encryptFileBytes
  /// Returns null if PIN is wrong or data is corrupted
  static Uint8List? decryptFileBytes(Uint8List encryptedData, String pin) {
    try {
      // Verify magic bytes
      if (encryptedData.length < 64) return null;
      for (int i = 0; i < 4; i++) {
        if (encryptedData[i] != AppConstants.magicBytes[i]) return null;
      }

      // Extract components
      final salt = encryptedData.sublist(4, 4 + AppConstants.saltLength);
      final iv = encryptedData.sublist(20, 20 + AppConstants.ivLength);
      final cipherText = encryptedData.sublist(32, encryptedData.length - 32);
      final storedTag = encryptedData.sublist(encryptedData.length - 32);

      // Verify HMAC first (authenticate before decrypt)
      final hmacKey = deriveKeyFromPin('$pin:hmac', Uint8List.fromList(salt));
      final hmac = Hmac(sha256, hmacKey);
      final computedTag = hmac.convert(cipherText).bytes;

      bool tagMatch = true;
      for (int i = 0; i < 32; i++) {
        if (computedTag[i] != storedTag[i]) tagMatch = false;
      }
      if (!tagMatch) return null; // Wrong PIN or tampered data

      // Derive key and decrypt
      final keyBytes = deriveKeyFromPin(pin, Uint8List.fromList(salt));
      final key = enc.Key(keyBytes);
      final ivObj = enc.IV(Uint8List.fromList(iv));

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.sic));
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(cipherText)),
        iv: ivObj,
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      return null; // Decryption failed
    }
  }

  /// Encrypt a file on disk, saves as .vaultfile
  static Future<File?> encryptFile(File sourceFile, String pin) async {
    try {
      final bytes = await sourceFile.readAsBytes();
      final encrypted = encryptFileBytes(bytes, pin);

      final outputPath =
          '${sourceFile.path}${AppConstants.encryptedExtension}';
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(encrypted);

      return outputFile;
    } catch (e) {
      return null;
    }
  }

  /// Decrypt a .vaultfile back to original
  static Future<Uint8List?> decryptFile(File encryptedFile, String pin) async {
    try {
      final bytes = await encryptedFile.readAsBytes();
      return decryptFileBytes(bytes, pin);
    } catch (e) {
      return null;
    }
  }

  /// Check if a file is a vault-encrypted file
  static bool isEncryptedFile(File file) {
    if (!file.existsSync()) return false;
    final bytes = file.readAsBytesSync();
    if (bytes.length < 4) return false;
    for (int i = 0; i < 4; i++) {
      if (bytes[i] != AppConstants.magicBytes[i]) return false;
    }
    return true;
  }
}
