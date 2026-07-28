import 'package:lyrical/core/widgets/poem_card_view_data.dart';

/// Publicly visible approved poem with author display fields.
///
/// Never includes email or private auth metadata.
class PublicPoem {
  const PublicPoem({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorAnonymousName,
    required this.poetryTypeId,
    required this.poetryTypeName,
    required this.publishedAt,
    required this.createdAt,
    this.authorAvatarUrl,
    this.periodLikeCount,
    this.totalLikeCount,
  });

  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorAnonymousName;
  final String? authorAvatarUrl;
  final int poetryTypeId;
  final String poetryTypeName;
  final DateTime publishedAt;
  final DateTime createdAt;

  /// Likes received in the daily/monthly selection window (RPC only).
  final int? periodLikeCount;

  /// Lifetime like count when returned by featured RPCs.
  final int? totalLikeCount;

  String get preview {
    final trimmed = content.trim();
    if (trimmed.length <= 140) return trimmed;
    return '${trimmed.substring(0, 140).trimRight()}…';
  }

  PoemCardViewData toCardViewData() {
    return PoemCardViewData(
      id: id,
      title: title,
      preview: preview,
      authorId: authorId,
      authorAnonymousName: authorAnonymousName,
      poetryType: poetryTypeName,
      publishedAt: publishedAt,
      authorAvatarUrl: authorAvatarUrl,
    );
  }

  factory PublicPoem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final content = json['content'];
    final authorId = json['author_id'];
    final createdAt = json['created_at'];
    final publishedAtRaw = json['published_at'];

    final poetryTypeId = _parsePoetryTypeId(json['poetry_type_id']);

    if (id is! String || id.isEmpty) {
      throw const FormatException('PublicPoem.id is missing or invalid.');
    }
    if (title is! String) {
      throw const FormatException('PublicPoem.title is missing or invalid.');
    }
    if (content is! String) {
      throw const FormatException('PublicPoem.content is missing or invalid.');
    }
    if (authorId is! String || authorId.isEmpty) {
      throw const FormatException(
        'PublicPoem.author_id is missing or invalid.',
      );
    }
    if (createdAt is! String) {
      throw const FormatException(
        'PublicPoem.created_at is missing or invalid.',
      );
    }
    if (publishedAtRaw is! String || publishedAtRaw.isEmpty) {
      throw const FormatException(
        'PublicPoem.published_at is required for public poems.',
      );
    }

    final profile = json['profiles'];
    if (profile is! Map<String, dynamic>) {
      throw const FormatException('PublicPoem.profiles embed is missing.');
    }
    final anonymousName = profile['anonymous_name'];
    if (anonymousName is! String || anonymousName.isEmpty) {
      throw const FormatException(
        'PublicPoem.author anonymous_name is missing.',
      );
    }
    final avatarUrl = profile['avatar_url'];
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('PublicPoem.author avatar_url is invalid.');
    }

    final poetryTypes = json['poetry_types'];
    if (poetryTypes is! Map<String, dynamic>) {
      throw const FormatException('PublicPoem.poetry_types embed is missing.');
    }
    final poetryTypeName = poetryTypes['name'];
    if (poetryTypeName is! String || poetryTypeName.isEmpty) {
      throw const FormatException('PublicPoem.poetry type name is missing.');
    }

    return PublicPoem(
      id: id,
      title: title,
      content: content,
      authorId: authorId,
      authorAnonymousName: anonymousName,
      authorAvatarUrl: avatarUrl as String?,
      poetryTypeId: poetryTypeId,
      poetryTypeName: poetryTypeName,
      publishedAt: DateTime.parse(publishedAtRaw),
      createdAt: DateTime.parse(createdAt),
    );
  }

  /// Flat row from [search_public_poems] or featured selection RPCs.
  factory PublicPoem.fromSearchRpc(Map<String, dynamic> json) {
    final id = json['poem_id'] ?? json['id'];
    final title = json['title'];
    final content = json['content'];
    final authorId = json['author_id'];
    final anonymousName = json['author_anonymous_name'];
    final avatarUrl = json['author_avatar_url'];
    final poetryTypeName = json['poetry_type_name'];
    final createdAt = json['created_at'];
    final publishedAtRaw = json['published_at'];
    final poetryTypeId = _parsePoetryTypeId(json['poetry_type_id']);

    if (id is! String || id.isEmpty) {
      throw const FormatException('PublicPoem.poem_id is missing or invalid.');
    }
    if (title is! String) {
      throw const FormatException('PublicPoem.title is missing or invalid.');
    }
    if (content is! String) {
      throw const FormatException('PublicPoem.content is missing or invalid.');
    }
    if (authorId is! String || authorId.isEmpty) {
      throw const FormatException(
        'PublicPoem.author_id is missing or invalid.',
      );
    }
    if (anonymousName is! String || anonymousName.isEmpty) {
      throw const FormatException(
        'PublicPoem.author_anonymous_name is missing.',
      );
    }
    if (avatarUrl != null && avatarUrl is! String) {
      throw const FormatException('PublicPoem.author_avatar_url is invalid.');
    }
    if (poetryTypeName is! String || poetryTypeName.isEmpty) {
      throw const FormatException('PublicPoem.poetry_type_name is missing.');
    }
    if (createdAt is! String && createdAt is! DateTime) {
      throw const FormatException(
        'PublicPoem.created_at is missing or invalid.',
      );
    }
    if (publishedAtRaw is! String && publishedAtRaw is! DateTime) {
      throw const FormatException(
        'PublicPoem.published_at is required for public poems.',
      );
    }

    return PublicPoem(
      id: id,
      title: title,
      content: content,
      authorId: authorId,
      authorAnonymousName: anonymousName,
      authorAvatarUrl: avatarUrl as String?,
      poetryTypeId: poetryTypeId,
      poetryTypeName: poetryTypeName,
      publishedAt: publishedAtRaw is DateTime
          ? publishedAtRaw
          : DateTime.parse(publishedAtRaw as String),
      createdAt: createdAt is DateTime
          ? createdAt
          : DateTime.parse(createdAt as String),
      periodLikeCount: _parseOptionalCount(json['period_like_count']),
      totalLikeCount: _parseOptionalCount(json['total_like_count']),
    );
  }

  static int? _parseOptionalCount(Object? raw) {
    return switch (raw) {
      null => null,
      final int value => value,
      final num value => value.toInt(),
      final String value when int.tryParse(value) != null => int.parse(value),
      _ => null,
    };
  }

  static int _parsePoetryTypeId(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      _ => throw const FormatException(
        'PublicPoem.poetry_type_id is missing or invalid.',
      ),
    };
  }
}
