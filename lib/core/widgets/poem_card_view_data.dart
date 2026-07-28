/// Shared card-facing poem data for Explorer and remaining mock Search UI.
class PoemCardViewData {
  const PoemCardViewData({
    required this.id,
    required this.title,
    required this.preview,
    required this.authorAnonymousName,
    required this.poetryType,
    required this.publishedAt,
    this.authorAvatarUrl,
  });

  final String id;
  final String title;
  final String preview;
  final String authorAnonymousName;
  final String poetryType;
  final DateTime publishedAt;
  final String? authorAvatarUrl;
}
