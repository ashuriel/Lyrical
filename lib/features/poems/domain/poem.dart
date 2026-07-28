import 'package:lyrical/features/poems/domain/poem_status.dart';

/// Author-owned poem. Never includes author email.
class Poem {
  const Poem({
    required this.id,
    required this.authorId,
    required this.title,
    required this.content,
    required this.status,
    required this.isHidden,
    required this.poetryTypeId,
    required this.poetryTypeName,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.deletedAt,
  });

  final String id;
  final String authorId;
  final String title;
  final String content;
  final PoemStatus status;
  final bool isHidden;
  final int poetryTypeId;
  final String poetryTypeName;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Display label combining status and hidden state.
  String get displayStatusLabel {
    if (status == PoemStatus.approved && isHidden) {
      return 'Oculto';
    }
    return status.labelEs;
  }

  String get preview {
    final trimmed = content.trim();
    if (trimmed.length <= 140) return trimmed;
    return '${trimmed.substring(0, 140).trimRight()}…';
  }

  factory Poem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final authorId = json['author_id'];
    final title = json['title'];
    final content = json['content'];
    final statusRaw = json['status'];
    final isHidden = json['is_hidden'];
    final createdAt = json['created_at'];
    final updatedAt = json['updated_at'];
    final poetryTypeIdRaw = json['poetry_type_id'];
    final poetryTypeId = switch (poetryTypeIdRaw) {
      final int value => value,
      final num value => value.toInt(),
      _ => throw const FormatException(
        'Poem.poetry_type_id is missing or invalid.',
      ),
    };

    if (id is! String || id.isEmpty) {
      throw const FormatException('Poem.id is missing or invalid.');
    }
    if (authorId is! String || authorId.isEmpty) {
      throw const FormatException('Poem.author_id is missing or invalid.');
    }
    if (title is! String) {
      throw const FormatException('Poem.title is missing or invalid.');
    }
    if (content is! String) {
      throw const FormatException('Poem.content is missing or invalid.');
    }
    if (statusRaw is! String) {
      throw const FormatException('Poem.status is missing or invalid.');
    }
    if (isHidden is! bool) {
      throw const FormatException('Poem.is_hidden is missing or invalid.');
    }
    if (createdAt is! String) {
      throw const FormatException('Poem.created_at is missing or invalid.');
    }
    if (updatedAt is! String) {
      throw const FormatException('Poem.updated_at is missing or invalid.');
    }

    final poetryTypeName = _parsePoetryTypeName(json);

    return Poem(
      id: id,
      authorId: authorId,
      title: title,
      content: content,
      status: PoemStatus.fromDb(statusRaw),
      isHidden: isHidden,
      poetryTypeId: poetryTypeId,
      poetryTypeName: poetryTypeName,
      publishedAt: _parseOptionalDate(json['published_at']),
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      deletedAt: _parseOptionalDate(json['deleted_at']),
    );
  }

  static String _parsePoetryTypeName(Map<String, dynamic> json) {
    final embedded = json['poetry_types'];
    if (embedded is Map<String, dynamic>) {
      final name = embedded['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    final flat = json['poetry_type_name'];
    if (flat is String && flat.isNotEmpty) return flat;
    throw const FormatException('Poem.poetry_type name is missing.');
  }

  static DateTime? _parseOptionalDate(Object? value) {
    if (value == null) return null;
    if (value is! String || value.isEmpty) return null;
    return DateTime.parse(value);
  }
}
