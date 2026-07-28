/// Application notification kinds from public.notifications.type.
enum AppNotificationType {
  newFollower,
  poemLiked,
  poemApproved,
  poemRejected;

  static AppNotificationType fromDatabase(String raw) {
    switch (raw) {
      case 'new_follower':
        return AppNotificationType.newFollower;
      case 'poem_liked':
        return AppNotificationType.poemLiked;
      case 'poem_approved':
        return AppNotificationType.poemApproved;
      case 'poem_rejected':
        return AppNotificationType.poemRejected;
      default:
        throw FormatException('Unknown notification type: $raw');
    }
  }

  String get databaseValue {
    switch (this) {
      case AppNotificationType.newFollower:
        return 'new_follower';
      case AppNotificationType.poemLiked:
        return 'poem_liked';
      case AppNotificationType.poemApproved:
        return 'poem_approved';
      case AppNotificationType.poemRejected:
        return 'poem_rejected';
    }
  }
}

/// In-app notification row. Named to avoid clashing with Flutter's Notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.actorId,
    this.actorAnonymousName,
    this.actorAvatarUrl,
    this.poemId,
    this.poemTitle,
  });

  final String id;
  final AppNotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final String? actorId;
  final String? actorAnonymousName;
  final String? actorAvatarUrl;
  final String? poemId;
  final String? poemTitle;

  AppNotification copyWith({
    String? id,
    AppNotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    String? actorId,
    String? actorAnonymousName,
    String? actorAvatarUrl,
    String? poemId,
    String? poemTitle,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actorId: actorId ?? this.actorId,
      actorAnonymousName: actorAnonymousName ?? this.actorAnonymousName,
      actorAvatarUrl: actorAvatarUrl ?? this.actorAvatarUrl,
      poemId: poemId ?? this.poemId,
      poemTitle: poemTitle ?? this.poemTitle,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = json['notification_id'] ?? json['id'];
    final typeRaw = json['type'];
    final isRead = json['is_read'];
    final createdAt = json['created_at'];
    final actorId = json['actor_id'];
    final actorName = json['actor_anonymous_name'];
    final actorAvatar = json['actor_avatar_url'];
    final poemId = json['poem_id'];
    final poemTitle = json['poem_title'];

    if (id is! String || id.isEmpty) {
      throw const FormatException('AppNotification.id is missing or invalid.');
    }
    if (typeRaw is! String || typeRaw.isEmpty) {
      throw const FormatException(
        'AppNotification.type is missing or invalid.',
      );
    }
    if (isRead is! bool) {
      throw const FormatException(
        'AppNotification.is_read is missing or invalid.',
      );
    }
    if (createdAt is! String || createdAt.isEmpty) {
      throw const FormatException(
        'AppNotification.created_at is missing or invalid.',
      );
    }
    if (actorId != null && actorId is! String) {
      throw const FormatException('AppNotification.actor_id is invalid.');
    }
    if (actorName != null && actorName is! String) {
      throw const FormatException(
        'AppNotification.actor_anonymous_name is invalid.',
      );
    }
    if (actorAvatar != null && actorAvatar is! String) {
      throw const FormatException(
        'AppNotification.actor_avatar_url is invalid.',
      );
    }
    if (poemId != null && poemId is! String) {
      throw const FormatException('AppNotification.poem_id is invalid.');
    }
    if (poemTitle != null && poemTitle is! String) {
      throw const FormatException('AppNotification.poem_title is invalid.');
    }

    return AppNotification(
      id: id,
      type: AppNotificationType.fromDatabase(typeRaw),
      isRead: isRead,
      createdAt: DateTime.parse(createdAt),
      actorId: actorId as String?,
      actorAnonymousName: actorName as String?,
      actorAvatarUrl: actorAvatar as String?,
      poemId: poemId as String?,
      poemTitle: poemTitle as String?,
    );
  }
}
