/// Public anonymous profile. Never includes email or auth metadata.
class Profile {
  const Profile({
    required this.id,
    required this.anonymousName,
    required this.hasCompletedOnboarding,
    this.gender,
    this.bio,
    this.avatarUrl,
  });

  final String id;
  final String anonymousName;
  final String? gender;
  final String? bio;
  final String? avatarUrl;
  final bool hasCompletedOnboarding;

  factory Profile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final anonymousName = json['anonymous_name'];
    final hasCompleted = json['has_completed_onboarding'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('Profile.id is missing or invalid.');
    }
    if (anonymousName is! String || anonymousName.isEmpty) {
      throw const FormatException(
        'Profile.anonymous_name is missing or invalid.',
      );
    }
    if (hasCompleted is! bool) {
      throw const FormatException(
        'Profile.has_completed_onboarding is missing or invalid.',
      );
    }

    return Profile(
      id: id,
      anonymousName: anonymousName,
      gender: json['gender'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      hasCompletedOnboarding: hasCompleted,
    );
  }

  Profile copyWith({
    String? id,
    String? anonymousName,
    String? gender,
    String? bio,
    String? avatarUrl,
    bool? hasCompletedOnboarding,
  }) {
    return Profile(
      id: id ?? this.id,
      anonymousName: anonymousName ?? this.anonymousName,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}
