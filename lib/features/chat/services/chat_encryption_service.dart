import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

/// Handles End-to-End Encryption (E2E) for chat messages.
/// Uses a per-session symmetric key (AES-256-CBC).
/// The session key is exchanged over the already DTLS-secured WebRTC DataChannel
/// during the initial handshake, adding a second layer of security.
class ChatEncryptionService {
  encrypt.Key? _sessionKey;
  encrypt.Encrypter? _encrypter;

  bool get isReady => _sessionKey != null && _encrypter != null;

  /// Generate a random 256-bit session key
  String generateSessionKey() {
    final key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }

  /// Set the session key (either generated locally or received from peer)
  void setSessionKey(String base64Key) {
    _sessionKey = encrypt.Key.fromBase64(base64Key);
    _encrypter = encrypt.Encrypter(encrypt.AES(_sessionKey!, mode: encrypt.AESMode.cbc));
  }

  /// Encrypt a string message (JSON)
  String encryptMessage(String plaintext) {
    if (!isReady) throw Exception('ChatEncryptionService not initialized with session key');
    
    // Generate a random IV for each message
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plaintext, iv: iv);
    
    // Prepend the IV to the ciphertext so the receiver can decrypt it
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypt a string message (JSON)
  String decryptMessage(String encryptedData) {
    if (!isReady) throw Exception('ChatEncryptionService not initialized with session key');
    
    final parts = encryptedData.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted message format');
    
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    
    return _encrypter!.decrypt(encrypted, iv: iv);
  }

  /// Hash a phone number for privacy-preserving contact matching
  static String hashPhoneNumber(String phone) {
    // Remove all non-numeric characters except +
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void dispose() {
    _sessionKey = null;
    _encrypter = null;
  }
}
