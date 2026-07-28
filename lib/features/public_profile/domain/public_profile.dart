/// Public-facing profile card. Never includes email, onboarding, or bookmarks.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.anonymousName,
    required this.createdAt,
    required this.publishedPoemCount,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowedByCurrentUser,
    required this.isCurrentUser,
    this.gender,
    this.bio,
    this.avatarUrl,
  });

  final String userId;
  final String anonymousName;
  final String? gender;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final int publishedPoemCount;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByCurrentUser;
  final bool isCurrentUser;

  PublicProfile copyWith({
    String? userId,
    String? anonymousName,
    String? gender,
    String? bio,
    String? avatarUrl,
    DateTime? createdAt,
    int? publishedPoemCount,
    int? followerCount,
    int? followingCount,
    bool? isFollowedByCurrentUser,
    bool? isCurrentUser,
    bool clearGender = false,
    bool clearBio = false,
    bool clearAvatarUrl = false,
  }) {
    return PublicProfile(
      userId: userId ?? this.userId,
      anonymousName: anonymousName ?? this.anonymousName,
      gender: clearGender ? null : (gender ?? this.gender),
      bio: clearBio ? null : (bio ?? this.bio),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      createdAt: createdAt ?? this.createdAt,
      publishedPoemCount: publishedPoemCount ?? this.publishedPoemCount,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowedByCurrentUser:
          isFollowedByCurrentUser ?? this.isFollowedByCurrentUser,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final userId = _parseUuid(json['user_id'], field: 'user_id');
    final anonymousName = json['anonymous_name'];
    final gender = json['gender'];
    final bio = json['bio'];
    final avatarUrl = json['avatar_url'];

    if (anonymousName is! String || anonymousName.isEmpty) {
      throw const FormatException(
        'PublicProfile.anonymous_name is missing or invalid.',
      );
    }
    if (gender != null && gender is! String) {
      throw const FormatException('PublicProfile.gender is invalid.');
    }
    if (bio != null && bio is! String) {
      throw const FormatException('PublicProfile.bio is invalid.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('PublicProfile.avatar_url is invalid.');
    }

    return PublicProfile(
      userId: userId,
      anonymousName: anonymousName,
      gender: gender as String?,
      bio: bio as String?,
      avatarUrl: avatarUrl as String?,
      createdAt: _parseDateTime(json['created_at']),
      publishedPoemCount: parseCount(json['published_poem_count']),
      followerCount: parseCount(json['follower_count']),
      followingCount: parseCount(json['following_count']),
      isFollowedByCurrentUser: parseBool(
        json['is_followed_by_current_user'],
        field: 'is_followed_by_current_user',
      ),
      isCurrentUser: parseBool(
        json['is_current_user'],
        field: 'is_current_user',
      ),
    );
  }

  static String _parseUuid(Object? raw, {required String field}) {
    if (raw is String && raw.isNotEmpty) return raw;
    // Some JSON codecs stringify UUIDs via toString()-compatible values.
    if (raw != null) {
      final text = raw.toString();
      if (text.isNotEmpty && text != 'null') return text;
    }
    throw FormatException('PublicProfile.$field is missing or invalid.');
  }

  static DateTime _parseDateTime(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
    throw const FormatException(
      'PublicProfile.created_at is missing or invalid.',
    );
  }

  /// Accepts int, num, or numeric strings from PostgREST/json.
  static int parseCount(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      final String value when int.tryParse(value) != null => int.parse(value),
      _ => throw const FormatException(
        'PublicProfile count field is missing or invalid.',
      ),
    };
  }

  static bool parseBool(Object? raw, {required String field}) {
    if (raw is bool) return raw;
    if (raw == 'true' || raw == 't') return true;
    if (raw == 'false' || raw == 'f') return false;
    throw FormatException('PublicProfile.$field is missing or invalid.');
  }
}
