import 'package:lyrical/core/widgets/poem_card_view_data.dart';

/// Temporary poem view model for UI prototypes only.
///
/// Still used by Search until that feature connects to Supabase.
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

  PoemCardViewData toCardViewData() {
    return PoemCardViewData(
      id: id,
      title: title,
      preview: preview,
      authorAnonymousName: authorAnonymousName,
      poetryType: poetryType,
      publishedAt: publishedAt,
      authorAvatarUrl: authorAvatarUrl,
    );
  }
}
