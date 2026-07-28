import 'dart:convert';

import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public (approved, visible) poem queries for Explorer.
///
/// Canonical visibility (also enforced by RLS / RPCs):
/// status=approved, is_hidden=false, deleted_at null, published_at not null.
class PublicPoemRepository {
  PublicPoemRepository(this._client);

  final SupabaseClient _client;

  static const int defaultRecentPageSize = 10;
  static const int discoveryFetchSize = 30;
  static const int discoveryReturnSize = 8;

  static const String _selectColumns = '''
id,
author_id,
title,
content,
poetry_type_id,
published_at,
created_at,
poetry_types ( name, slug ),
profiles!poems_author_id_fkey ( anonymous_name, avatar_url )
''';

  Future<List<PublicPoem>> fetchRecentPoems({
    int limit = defaultRecentPageSize,
    int offset = 0,
  }) async {
    try {
      final rows = await _client
          .from('poems')
          .select(_selectColumns)
          .eq('status', 'approved')
          .eq('is_hidden', false)
          .isFilter('deleted_at', null)
          .not('published_at', 'is', null)
          .order('published_at', ascending: false)
          .range(offset, offset + limit - 1);

      return _mapRows(rows);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos leer los poemas. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapExploreError(error));
    }
  }

  /// Temporary random discovery: fetch a limited public set, shuffle, take N.
  Future<List<PublicPoem>> fetchDiscoveryPoems({
    int limit = discoveryReturnSize,
  }) async {
    try {
      final rows = await _client
          .from('poems')
          .select(_selectColumns)
          .eq('status', 'approved')
          .eq('is_hidden', false)
          .isFilter('deleted_at', null)
          .not('published_at', 'is', null)
          .order('published_at', ascending: false)
          .limit(discoveryFetchSize);

      final poems = _mapRows(rows);
      poems.shuffle();

      final seen = <String>{};
      final unique = <PublicPoem>[];
      for (final poem in poems) {
        if (seen.add(poem.id)) {
          unique.add(poem);
        }
        if (unique.length >= limit) break;
      }
      return unique;
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos leer los poemas. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapExploreError(error));
    }
  }

  /// Most-liked public poem during the current America/Santo_Domingo day.
  Future<PublicPoem?> fetchPoemOfTheDay() async {
    try {
      final raw = await _client.rpc('get_daily_featured_poem');
      if (raw == null) return null;
      final map = _asJsonMap(raw);
      return PublicPoem.fromSearchRpc(map);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos leer el poema del día. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapExploreError(error));
    }
  }

  /// Most-liked public poem during the current America/Santo_Domingo month.
  Future<PublicPoem?> fetchMonthlySelection() async {
    try {
      final raw = await _client.rpc('get_monthly_featured_poem');
      if (raw == null) return null;
      final map = _asJsonMap(raw);
      return PublicPoem.fromSearchRpc(map);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No pudimos leer la selección del mes. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(_mapExploreError(error));
    }
  }

  Future<PublicPoem> fetchPublicPoemById(String poemId) async {
    try {
      final row = await _client
          .from('poems')
          .select(_selectColumns)
          .eq('status', 'approved')
          .eq('is_hidden', false)
          .isFilter('deleted_at', null)
          .not('published_at', 'is', null)
          .eq('id', poemId)
          .maybeSingle();

      if (row == null) {
        throw const AppException('Este poema ya no está disponible.');
      }

      return PublicPoem.fromJson(Map<String, dynamic>.from(row));
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException('No pudimos leer el poema. Inténtalo de nuevo.');
    } catch (error) {
      throw AppException(_mapExploreError(error));
    }
  }

  Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw == null) {
      throw const FormatException('Featured RPC returned null.');
    }
    if (raw is String) {
      return _asJsonMap(jsonDecode(raw));
    }
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List) {
      if (raw.isEmpty) {
        throw const FormatException('Featured RPC returned an empty list.');
      }
      return _asJsonMap(raw.first);
    }
    throw FormatException(
      'Featured RPC returned unsupported type: ${raw.runtimeType}',
    );
  }

  List<PublicPoem> _mapRows(List<dynamic> rows) {
    return rows
        .map(
          (row) => PublicPoem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  String _mapExploreError(Object error) {
    if (error is PostgrestException) {
      final combined = '${error.message} ${error.details}'.toLowerCase();
      if (error.code == 'PGRST202' ||
          combined.contains('could not find the function')) {
        return 'Esta función aún no está configurada.';
      }
    }
    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.') {
      return 'No pudimos cargar los poemas. Inténtalo de nuevo.';
    }
    return mapped;
  }
}
