/// Public like count and current-user like/bookmark flags for a poem.
///
/// Never includes bookmark counts or liker/bookmarker identities.
class PoemEngagement {
  const PoemEngagement({
    required this.poemId,
    required this.likeCount,
    required this.isLiked,
    required this.isBookmarked,
  });

  final String poemId;
  final int likeCount;
  final bool isLiked;
  final bool isBookmarked;

  PoemEngagement copyWith({
    String? poemId,
    int? likeCount,
    bool? isLiked,
    bool? isBookmarked,
  }) {
    return PoemEngagement(
      poemId: poemId ?? this.poemId,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  factory PoemEngagement.fromJson(Map<String, dynamic> json) {
    final poemId = json['poem_id'];
    if (poemId is! String || poemId.isEmpty) {
      throw const FormatException(
        'PoemEngagement.poem_id is missing or invalid.',
      );
    }

    return PoemEngagement(
      poemId: poemId,
      likeCount: _parseCount(json['like_count']),
      isLiked: _parseBool(json['is_liked_by_current_user'], field: 'is_liked'),
      isBookmarked: _parseBool(
        json['is_bookmarked_by_current_user'],
        field: 'is_bookmarked',
      ),
    );
  }

  /// Result of [like_poem] / [unlike_poem] merged onto an existing engagement.
  PoemEngagement applyLikeResult(Map<String, dynamic> json) {
    return copyWith(
      isLiked: _parseBool(json['is_liked'], field: 'is_liked'),
      likeCount: _parseCount(json['like_count']),
    );
  }

  /// Result of [bookmark_poem] / [remove_poem_bookmark].
  PoemEngagement applyBookmarkResult(Map<String, dynamic> json) {
    return copyWith(
      isBookmarked: _parseBool(json['is_bookmarked'], field: 'is_bookmarked'),
    );
  }

  static int _parseCount(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      _ => throw const FormatException(
        'PoemEngagement.like_count is missing or invalid.',
      ),
    };
  }

  static bool _parseBool(Object? raw, {required String field}) {
    if (raw is bool) return raw;
    throw FormatException('PoemEngagement.$field is missing or invalid.');
  }
}
