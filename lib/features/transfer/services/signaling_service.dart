import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serverless signaling service for WebRTC.
/// Uses room codes and copy-paste / QR code to exchange
/// SDP offers/answers and ICE candidates between peers.
/// 
/// NO Firebase, NO WebSocket server — fully offline signaling via:
/// 1. QR Code (sender shows QR, receiver scans)
/// 2. Room code copy-paste (share via WhatsApp/SMS)
/// 3. Clipboard exchange
class SignalingService {
  static const _keyPrefix = 'signaling_';
  
  // ─── Room Code Generation ────────────────────────────────
  
  /// Generate a unique 6-character room code
  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // ─── Signal Data Packaging ───────────────────────────────
  
  /// Package WebRTC offer/answer + ICE candidates into a compact
  /// transferable string for QR code or clipboard exchange.
  /// 
  /// Format: Base64-encoded JSON containing:
  /// - type: 'offer' or 'answer'
  /// - sdp: Session Description Protocol string
  /// - candidates: List of ICE candidates
  String packageSignalData({
    required String type,
    required String sdp,
    List<Map<String, dynamic>>? candidates,
  }) {
    final data = {
      'v': 1, // Protocol version
      't': type,
      's': _compressSdp(sdp),
      'c': candidates ?? [],
    };
    
    final jsonStr = json.encode(data);
    final compressed = base64Url.encode(utf8.encode(jsonStr));
    return compressed;
  }

  /// Unpackage the signal data from QR code or clipboard
  Map<String, dynamic>? unpackageSignalData(String encoded) {
    try {
      final jsonStr = utf8.decode(base64Url.decode(encoded));
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      
      if (data['v'] != 1) {
        debugPrint('Unsupported signaling version: ${data['v']}');
        return null;
      }
      
      return {
        'type': data['t'],
        'sdp': _decompressSdp(data['s'] as String),
        'candidates': (data['c'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      };
    } catch (e) {
      debugPrint('Failed to unpackage signal data: $e');
      return null;
    }
  }

  // ─── SDP Compression ─────────────────────────────────────
  // Simple SDP compression to make QR codes smaller
  
  String _compressSdp(String sdp) {
    // Remove unnecessary whitespace and common patterns
    return sdp
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  String _decompressSdp(String compressed) {
    return compressed.replaceAll('\n', '\r\n');
  }

  // ─── Room Code Based Exchange ────────────────────────────
  // For scenarios where QR code isn't possible (phone call, etc.)
  // Both devices share a room code and use SharedPreferences
  // to store/retrieve their signal data locally.
  // A manual copy-paste is used as the transport layer.

  /// Store signal data locally associated with a room code
  Future<void> storeSignalData(String roomCode, String data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$roomCode', data);
    await prefs.setInt('$_keyPrefix${roomCode}_time', 
        DateTime.now().millisecondsSinceEpoch);
  }

  /// Retrieve stored signal data for a room code
  Future<String?> getSignalData(String roomCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix$roomCode');
  }

  /// Clear signal data for a room code (cleanup)
  Future<void> clearSignalData(String roomCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$roomCode');
    await prefs.remove('$_keyPrefix${roomCode}_time');
  }

  /// Clean up all expired signal data (older than 1 hour)
  Future<void> cleanupExpiredSignals() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    const oneHour = 3600000;
    
    final keys = prefs.getKeys()
        .where((k) => k.startsWith(_keyPrefix) && k.endsWith('_time'));
    
    for (final timeKey in keys) {
      final timestamp = prefs.getInt(timeKey);
      if (timestamp != null && (now - timestamp) > oneHour) {
        final roomKey = timeKey.replaceAll('_time', '');
        await prefs.remove(roomKey);
        await prefs.remove(timeKey);
      }
    }
  }

  // ─── QR Code Data ────────────────────────────────────────
  
  /// Generate QR code content for signaling
  /// Includes room code + offer data
  String generateQrContent({
    required String roomCode,
    required String signalData,
  }) {
    return 'filesharepro://$roomCode#$signalData';
  }

  /// Parse QR code content
  Map<String, String>? parseQrContent(String qrData) {
    if (!qrData.startsWith('filesharepro://')) return null;
    
    final content = qrData.replaceFirst('filesharepro://', '');
    final hashIndex = content.indexOf('#');
    
    if (hashIndex == -1) {
      // Just room code
      return {'roomCode': content, 'signalData': ''};
    }
    
    return {
      'roomCode': content.substring(0, hashIndex),
      'signalData': content.substring(hashIndex + 1),
    };
  }

  // ─── Connection Flow Helper ──────────────────────────────
  
  /// Generate a shareable connection message for WhatsApp/SMS
  String generateShareMessage({
    required String roomCode,
    String? signalData,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🔗 FileShare Pro');
    buffer.writeln();
    buffer.writeln('I want to share files with you!');
    buffer.writeln('📥 Code: $roomCode');
    buffer.writeln();
    buffer.writeln('1. Open FileShare Pro app');
    buffer.writeln('2. Tap "Receive" → Enter code');
    
    if (signalData != null) {
      buffer.writeln();
      buffer.writeln('Connection data:');
      buffer.writeln(signalData);
    }
    
    return buffer.toString();
  }
}
