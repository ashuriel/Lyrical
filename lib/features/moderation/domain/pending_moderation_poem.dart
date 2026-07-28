/// Pending poem row for administrator moderation.
///
/// Never includes email, role, or private auth metadata.
class PendingModerationPoem {
  const PendingModerationPoem({
    required this.poemId,
    required this.title,
    required this.content,
    required this.poetryTypeId,
    required this.poetryTypeName,
    required this.authorId,
    required this.authorAnonymousName,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  final String poemId;
  final String title;
  final String content;
  final int poetryTypeId;
  final String poetryTypeName;
  final String authorId;
  final String authorAnonymousName;
  final String? authorAvatarUrl;
  final DateTime createdAt;

  String get preview {
    final trimmed = content.trim();
    if (trimmed.length <= 120) return trimmed;
    return '${trimmed.substring(0, 120).trimRight()}…';
  }

  factory PendingModerationPoem.fromJson(Map<String, dynamic> json) {
    final poemId = json['poem_id'];
    final title = json['title'];
    final content = json['content'];
    final authorId = json['author_id'];
    final authorName = json['author_anonymous_name'];
    final poetryTypeName = json['poetry_type_name'];
    final createdAt = json['created_at'];
    final avatarUrl = json['author_avatar_url'];

    if (poemId is! String || poemId.isEmpty) {
      throw const FormatException('PendingModerationPoem.poem_id invalid.');
    }
    if (title is! String || title.isEmpty) {
      throw const FormatException('PendingModerationPoem.title invalid.');
    }
    if (content is! String) {
      throw const FormatException('PendingModerationPoem.content invalid.');
    }
    if (authorId is! String || authorId.isEmpty) {
      throw const FormatException('PendingModerationPoem.author_id invalid.');
    }
    if (authorName is! String || authorName.isEmpty) {
      throw const FormatException(
        'PendingModerationPoem.author_anonymous_name invalid.',
      );
    }
    if (poetryTypeName is! String || poetryTypeName.isEmpty) {
      throw const FormatException(
        'PendingModerationPoem.poetry_type_name invalid.',
      );
    }
    if (createdAt is! String || createdAt.isEmpty) {
      throw const FormatException('PendingModerationPoem.created_at invalid.');
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException(
        'PendingModerationPoem.author_avatar_url invalid.',
      );
    }

    return PendingModerationPoem(
      poemId: poemId,
      title: title,
      content: content,
      poetryTypeId: _parsePoetryTypeId(json['poetry_type_id']),
      poetryTypeName: poetryTypeName,
      authorId: authorId,
      authorAnonymousName: authorName,
      authorAvatarUrl: avatarUrl as String?,
      createdAt: DateTime.parse(createdAt),
    );
  }

  static int _parsePoetryTypeId(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      final String value when int.tryParse(value) != null => int.parse(value),
      _ => throw const FormatException(
        'PendingModerationPoem.poetry_type_id invalid.',
      ),
    };
  }
}
