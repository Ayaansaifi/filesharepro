class UserProfile {
  final String uniqueId;
  final String displayName;
  final String about;
  final String? avatarPath;
  final DateTime createdAt;

  UserProfile({
    required this.uniqueId,
    required this.displayName,
    this.about = 'Available',
    this.avatarPath,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? displayName,
    String? about,
    String? avatarPath,
  }) {
    return UserProfile(
      uniqueId: uniqueId,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'uniqueId': uniqueId,
        'displayName': displayName,
        'about': about,
        'avatarPath': avatarPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uniqueId: json['uniqueId'] as String,
        displayName: json['displayName'] as String,
        about: json['about'] as String? ?? 'Available',
        avatarPath: json['avatarPath'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
