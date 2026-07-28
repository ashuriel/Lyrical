import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/engagement/domain/poem_engagement.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Likes and private bookmarks via controlled RPCs (+ owner bookmark SELECT).
class EngagementRepository {
  EngagementRepository(this._client);

  final SupabaseClient _client;

  static const int defaultBookmarksPageSize = 20;

  static const String _bookmarkedPoemSelect = '''
created_at,
poem_id,
poems!inner (
  id,
  author_id,
  title,
  content,
  poetry_type_id,
  published_at,
  created_at,
  poetry_types ( name, slug ),
  profiles!poems_author_id_fkey ( anonymous_name, avatar_url )
)
''';

  Future<PoemEngagement> fetchPoemEngagement(String poemId) async {
    try {
      final raw = await _client.rpc(
        'get_poem_engagement',
        params: {'p_poem_id': poemId},
      );
      return PoemEngagement.fromJson(_asJsonMap(raw));
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos leer las interacciones del poema. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapEngagementError(error, fallback: 'engagement'));
    }
  }

  /// Returns like fields only; preserve [isBookmarked] from current state.
  Future<({bool isLiked, int likeCount})> likePoem(String poemId) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('like_poem', params: {'p_poem_id': poemId}),
      );
      final engagement = PoemEngagement(
        poemId: poemId,
        likeCount: 0,
        isLiked: false,
        isBookmarked: false,
      ).applyLikeResult(map);
      return (isLiked: engagement.isLiked, likeCount: engagement.likeCount);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos registrar tu Me gusta.');
    } catch (error) {
      throw AppException(_mapEngagementError(error, fallback: 'like'));
    }
  }

  Future<({bool isLiked, int likeCount})> unlikePoem(String poemId) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('unlike_poem', params: {'p_poem_id': poemId}),
      );
      final engagement = PoemEngagement(
        poemId: poemId,
        likeCount: 0,
        isLiked: false,
        isBookmarked: false,
      ).applyLikeResult(map);
      return (isLiked: engagement.isLiked, likeCount: engagement.likeCount);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos quitar tu Me gusta.');
    } catch (error) {
      throw AppException(_mapEngagementError(error, fallback: 'unlike'));
    }
  }

  Future<bool> bookmarkPoem(String poemId) async {
    try {
      final map = _asJsonMap(
        await _client.rpc('bookmark_poem', params: {'p_poem_id': poemId}),
      );
      final flagged = map['is_bookmarked'];
      if (flagged is! bool || !flagged) {
        throw const AppException('No pudimos guardar este poema.');
      }
      return true;
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos guardar este poema.');
    } catch (error) {
      throw AppException(_mapEngagementError(error, fallback: 'bookmark'));
    }
  }

  Future<bool> removeBookmark(String poemId) async {
    try {
      final map = _asJsonMap(
        await _client.rpc(
          'remove_poem_bookmark',
          params: {'p_poem_id': poemId},
        ),
      );
      final flagged = map['is_bookmarked'];
      if (flagged is! bool || flagged) {
        throw const AppException('No pudimos quitar este poema de guardados.');
      }
      return false;
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos quitar este poema de guardados.');
    } catch (error) {
      throw AppException(_mapEngagementError(error, fallback: 'unbookmark'));
    }
  }

  /// Bookmarks for the authenticated user; RLS enforces user_id = auth.uid().
  ///
  /// Only currently public poems are returned (!inner + visibility filters).
  Future<List<PublicPoem>> fetchCurrentUserBookmarkedPoems({
    required int limit,
    required int offset,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw const AppException('No hay una sesión activa.');
      }

      final safeLimit = limit.clamp(1, 50);
      final safeOffset = offset < 0 ? 0 : offset;

      final rows = await _client
          .from('poem_bookmarks')
          .select(_bookmarkedPoemSelect)
          .eq('user_id', userId)
          .eq('poems.status', 'approved')
          .eq('poems.is_hidden', false)
          .isFilter('poems.deleted_at', null)
          .order('created_at', ascending: false)
          .range(safeOffset, safeOffset + safeLimit - 1);

      return rows.map((row) {
        final poem = row['poems'];
        if (poem is! Map) {
          throw const FormatException('Bookmark poem embed is missing.');
        }
        return PublicPoem.fromJson(Map<String, dynamic>.from(poem));
      }).toList();
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos leer tus poemas guardados. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapEngagementError(error, fallback: 'bookmarks'));
    }
  }

  Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const FormatException('Engagement RPC returned an invalid payload.');
  }

  String _mapEngagementError(Object error, {required String fallback}) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      if (message.contains('authentication required')) {
        return 'No hay una sesión activa.';
      }
      if (message.contains('poem not available') || code == 'P0002') {
        return 'Este poema ya no está disponible.';
      }
      if (message.contains('cannot like own poem') || code == 'P0001') {
        return 'No puedes dar Me gusta a tu propio poema.';
      }
      if (code == '42501' || message.contains('permission')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (code == 'PGRST202' ||
          message.contains('could not find the function')) {
        return 'Esta función no está disponible en este momento.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'No se pudo conectar. Comprueba tu conexión a internet.';
      }
    }

    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.') {
      return switch (fallback) {
        'like' => 'No pudimos registrar tu Me gusta.',
        'unlike' => 'No pudimos quitar tu Me gusta.',
        'bookmark' => 'No pudimos guardar este poema.',
        'unbookmark' => 'No pudimos quitar este poema de guardados.',
        'bookmarks' =>
          'No pudimos leer tus poemas guardados. Inténtalo de nuevo.',
        _ => 'No pudimos cargar las interacciones. Inténtalo de nuevo.',
      };
    }
    return mapped;
  }
}
