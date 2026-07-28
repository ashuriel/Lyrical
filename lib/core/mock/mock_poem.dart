/// Temporary poem view model for UI prototypes only.
///
/// Replace with production poem models/repositories when connecting Supabase.
class MockPoem {
  const MockPoem({
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
