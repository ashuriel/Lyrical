import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for creating and managing the current user's poems.
class PoemRepository {
  PoemRepository(this._client);

  final SupabaseClient _client;

  static const String _selectColumns = '''
id,
author_id,
title,
content,
status,
is_hidden,
poetry_type_id,
published_at,
created_at,
updated_at,
deleted_at,
poetry_types ( name )
''';

  static const int maxTitleLength = 100;
  static const int maxContentLength = 10000;

  Future<Poem> createPoem({
    required String title,
    required String content,
    required int poetryTypeId,
  }) async {
    final userId = _requireUserId();
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();

    if (trimmedTitle.isEmpty) {
      throw const AppException('El título es obligatorio.');
    }
    if (trimmedTitle.length > maxTitleLength) {
      throw const AppException(
        'El título no puede superar los 100 caracteres.',
      );
    }
    if (trimmedContent.isEmpty) {
      throw const AppException('El poema no puede estar vacío.');
    }
    if (trimmedContent.length > maxContentLength) {
      throw const AppException(
        'El poema no puede superar los 10000 caracteres.',
      );
    }

    try {
      final row = await _client
          .from('poems')
          .insert({
            'author_id': userId,
            'title': trimmedTitle,
            'content': trimmedContent,
            'poetry_type_id': poetryTypeId,
          })
          .select(_selectColumns)
          .maybeSingle();

      if (row == null) {
        throw const AppException(
          'No se pudo publicar el poema. Inténtalo de nuevo.',
        );
      }

      return Poem.fromJson(Map<String, dynamic>.from(row));
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No se pudo leer el poema creado. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapInsertError(error));
    }
  }

  Future<List<Poem>> fetchCurrentUserPendingPoems() {
    return _fetchCurrentUserPoems(status: 'pending', isHidden: null);
  }

  Future<List<Poem>> fetchCurrentUserPublishedPoems() {
    return _fetchCurrentUserPoems(status: 'approved', isHidden: false);
  }

  Future<List<Poem>> fetchCurrentUserHiddenPoems() {
    return _fetchCurrentUserPoems(status: 'approved', isHidden: true);
  }

  Future<List<Poem>> fetchCurrentUserRejectedPoems() {
    return _fetchCurrentUserPoems(status: 'rejected', isHidden: null);
  }

  Future<Poem> fetchCurrentUserPoemById(String poemId) async {
    final userId = _requireUserId();

    try {
      final row = await _client
          .from('poems')
          .select(_selectColumns)
          .eq('id', poemId)
          .eq('author_id', userId)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (row == null) {
        throw const AppException('No se encontró el poema.');
      }

      return Poem.fromJson(Map<String, dynamic>.from(row));
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No se pudo leer el poema. Inténtalo de nuevo.');
    } catch (error) {
      throw AppException(PoemErrorMapper.map(error));
    }
  }

  Future<Poem> hidePoem(String poemId) {
    return _setHidden(poemId, hidden: true);
  }

  Future<Poem> unhidePoem(String poemId) {
    return _setHidden(poemId, hidden: false);
  }

  Future<void> softDeletePoem(String poemId) async {
    _requireUserId();

    try {
      await _client.rpc('soft_delete_poem', params: {'p_poem_id': poemId});
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(_mapSoftDeleteError(error));
    }
  }

  Future<List<Poem>> _fetchCurrentUserPoems({
    required String status,
    required bool? isHidden,
  }) async {
    final userId = _requireUserId();

    try {
      var query = _client
          .from('poems')
          .select(_selectColumns)
          .eq('author_id', userId)
          .eq('status', status)
          .isFilter('deleted_at', null);

      if (isHidden != null) {
        query = query.eq('is_hidden', isHidden);
      }

      final rows = await query.order('created_at', ascending: false);

      return rows
          .map((row) => Poem.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No se pudieron leer tus poemas. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(PoemErrorMapper.map(error));
    }
  }

  Future<Poem> _setHidden(String poemId, {required bool hidden}) async {
    final userId = _requireUserId();

    try {
      final row = await _client
          .from('poems')
          .update({'is_hidden': hidden})
          .eq('id', poemId)
          .eq('author_id', userId)
          .eq('status', 'approved')
          .isFilter('deleted_at', null)
          .select(_selectColumns)
          .maybeSingle();

      if (row == null) {
        throw AppException(
          hidden
              ? 'No se pudo ocultar el poema. Inténtalo de nuevo.'
              : 'No se pudo mostrar el poema. Inténtalo de nuevo.',
        );
      }

      return Poem.fromJson(Map<String, dynamic>.from(row));
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No se pudo actualizar el poema. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(
        hidden
            ? 'No se pudo ocultar el poema. Inténtalo de nuevo.'
            : 'No se pudo mostrar el poema. Inténtalo de nuevo.',
      );
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('No hay una sesión activa.');
    }
    return userId;
  }

  String _mapInsertError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('row-level security')) {
        return 'No tienes permiso para publicar este poema.';
      }
    }
    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.') {
      return 'No se pudo enviar el poema a revisión. Inténtalo de nuevo.';
    }
    return mapped;
  }

  String _mapSoftDeleteError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('authentication required')) {
        return 'No hay una sesión activa.';
      }
      if (message.contains('already deleted')) {
        return 'Este poema ya fue eliminado.';
      }
      if (message.contains('not found') ||
          message.contains('not authorized') ||
          message.contains('row-level security')) {
        return 'No se pudo eliminar el poema. Inténtalo de nuevo.';
      }
    }
    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.') {
      return 'No se pudo eliminar el poema. Inténtalo de nuevo.';
    }
    return mapped;
  }
}
