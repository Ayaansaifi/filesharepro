class UserProfile {
  /// Stable per-install identity (UUID). Used for local discovery & internal refs.
  final String uniqueId;

  /// The user's verified phone number in E.164-ish form (e.g. "919876543210").
  /// This is the **peer address** for internet (WebRTC) chat: each user
  /// subscribes to `filesharepro/signaling/<peerId>` where peerId == phoneNumber.
  /// Null for legacy profiles that were created before phone pairing existed.
  final String? phoneNumber;

  final String displayName;
  final String about;
  final String? avatarPath;
  final DateTime createdAt;

  UserProfile({
    required this.uniqueId,
    this.phoneNumber,
    required this.displayName,
    this.about = 'Available',
    this.avatarPath,
    required this.createdAt,
  });

  /// The identity other people use to reach us over the internet.
  /// Falls back to uniqueId for local-only / legacy profiles.
  String get peerId => (phoneNumber != null && phoneNumber!.isNotEmpty)
      ? phoneNumber!
      : uniqueId;

  /// True once the user has registered a phone number and can be reached
  /// globally by contacts.
  bool get isPhonePaired =>
      phoneNumber != null && phoneNumber!.isNotEmpty;

  UserProfile copyWith({
    String? displayName,
    String? about,
    String? avatarPath,
    String? phoneNumber,
  }) {
    return UserProfile(
      uniqueId: uniqueId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uniqueId': uniqueId,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'about': about,
        'avatarPath': avatarPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uniqueId: json['uniqueId'] as String,
        phoneNumber: json['phoneNumber'] as String?,
        displayName: json['displayName'] as String,
        about: json['about'] as String? ?? 'Available',
        avatarPath: json['avatarPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
