import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public poem search via [search_public_poems] RPC.
class PublicPoemSearchRepository {
  PublicPoemSearchRepository(this._client);

  final SupabaseClient _client;

  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  Future<List<PublicPoem>> searchPublicPoems({
    required String query,
    int? poetryTypeId,
    required int limit,
    required int offset,
  }) async {
    try {
      final safeLimit = limit.clamp(1, maxPageSize);
      final safeOffset = offset < 0 ? 0 : offset;
      final trimmed = query.trim();

      final rows = await _client.rpc(
        'search_public_poems',
        params: {
          'p_query': trimmed.isEmpty ? null : trimmed,
          'p_poetry_type_id': poetryTypeId,
          'p_limit': safeLimit,
          'p_offset': safeOffset,
        },
      );

      if (rows is! List) {
        throw const AppException(
          'No pudimos interpretar los resultados de la búsqueda.',
        );
      }

      return rows
          .map(
            (row) =>
                PublicPoem.fromSearchRpc(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos interpretar los resultados de la búsqueda.',
      );
    } catch (error) {
      throw AppException(_mapSearchError(error));
    }
  }

  String _mapSearchError(Object error) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message.toLowerCase();
      if (code == 'PGRST202' ||
          message.contains('could not find the function') ||
          message.contains('search_public_poems')) {
        return 'La búsqueda no está disponible en este momento.';
      }
      if (code == '42501' || message.contains('permission')) {
        return 'No tienes permiso para buscar poemas.';
      }
      if (message.contains('network') || message.contains('fetch')) {
        return 'No se pudo conectar. Comprueba tu conexión a internet.';
      }
    }

    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.') {
      return 'No pudimos completar la búsqueda. Inténtalo de nuevo.';
    }
    return mapped;
  }
}
