import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class TransferRecord {
  final String id;
  final String fileName;
  final int fileSize;
  final String direction; // sent | received
  final String mode; // nearby | webrtc
  final DateTime at;

  TransferRecord({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.mode,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'direction': direction,
        'mode': mode,
        'at': at.toIso8601String(),
      };

  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        direction: json['direction'] as String,
        mode: json['mode'] as String,
        at: DateTime.parse(json['at'] as String),
      );
}

/// Local transfer history (no server) — Play Store friendly analytics-free log.
class TransferHistoryService {
  Future<List<TransferRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyTransferHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TransferRecord.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(TransferRecord record) async {
    final items = await getHistory();
    items.insert(0, record);
    final trimmed = items.take(AppConstants.transferHistoryLimit).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyTransferHistory,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<Map<String, int>> getStats() async {
    final items = await getHistory();
    var sent = 0, received = 0, encrypted = 0;
    for (final i in items) {
      if (i.direction == 'sent') sent++;
      if (i.direction == 'received') received++;
    }
    return {
      'sent': sent,
      'received': received,
      'encrypted': encrypted,
      'total': items.length,
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyTransferHistory);
  }
}
