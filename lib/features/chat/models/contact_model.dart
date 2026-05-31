import 'package:flutter_contacts/flutter_contacts.dart' as fc;

/// Represents a phone contact that may or may not be paired
class AppContact {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? deviceId; // Null if not paired
  final String? roomCode; // Null if not paired
  final DateTime? lastSeen;
  final bool isOnline;
  final String? about;

  AppContact({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.deviceId,
    this.roomCode,
    this.lastSeen,
    this.isOnline = false,
    this.about,
  });

  bool get isPaired => deviceId != null && roomCode != null;

  AppContact copyWith({
    String? displayName,
    String? phoneNumber,
    String? deviceId,
    String? roomCode,
    DateTime? lastSeen,
    bool? isOnline,
    String? about,
  }) {
    return AppContact(
      id: id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      deviceId: deviceId ?? this.deviceId,
      roomCode: roomCode ?? this.roomCode,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      about: about ?? this.about,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'deviceId': deviceId,
        'roomCode': roomCode,
        'lastSeen': lastSeen?.toIso8601String(),
        'about': about,
      };

  factory AppContact.fromJson(Map<String, dynamic> json) => AppContact(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        phoneNumber: json['phoneNumber'] as String,
        deviceId: json['deviceId'] as String?,
        roomCode: json['roomCode'] as String?,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
        about: json['about'] as String?,
      );

  factory AppContact.fromFlutterContact(fc.Contact contact) {
    String phone = '';
    if (contact.phones.isNotEmpty) {
      phone = contact.phones.first.normalizedNumber.isNotEmpty
          ? contact.phones.first.normalizedNumber
          : contact.phones.first.number;
    }
    return AppContact(
      id: contact.id,
      displayName: contact.displayName,
      phoneNumber: phone,
    );
  }
}
