import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public (approved, visible) poem queries for Explorer.
///
/// Always filters status/is_hidden/deleted_at even though RLS also enforces this.
class PublicPoemRepository {
  PublicPoemRepository(this._client);

  final SupabaseClient _client;

  static const int defaultRecentPageSize = 10;
  static const int discoveryFetchSize = 30;
  static const int discoveryReturnSize = 8;
  static const int monthlyLimit = 5;
  static const int poemOfTheDayCandidateLimit = 50;

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

  /// Temporary poem-of-the-day until featured_poems administration exists.
  ///
  /// Deterministic for a given UTC calendar day: picks index
  /// `dayOfYear % candidateCount` from recent public poems ordered by
  /// published_at descending.
  Future<PublicPoem?> fetchPoemOfTheDay({DateTime? now}) async {
    try {
      final rows = await _client
          .from('poems')
          .select(_selectColumns)
          .eq('status', 'approved')
          .eq('is_hidden', false)
          .isFilter('deleted_at', null)
          .not('published_at', 'is', null)
          .order('published_at', ascending: false)
          .limit(poemOfTheDayCandidateLimit);

      final poems = _mapRows(rows);
      if (poems.isEmpty) return null;

      final date = now?.toUtc() ?? DateTime.now().toUtc();
      final dayOfYear = date.difference(DateTime.utc(date.year)).inDays;
      final index = dayOfYear % poems.length;
      return poems[index];
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

  /// Temporary monthly selection until featured_poems administration exists.
  ///
  /// Prefers poems published in the current UTC month; falls back to recent
  /// public poems when the month has no rows.
  Future<List<PublicPoem>> fetchMonthlySelection({
    int limit = monthlyLimit,
    DateTime? now,
  }) async {
    try {
      final date = now?.toUtc() ?? DateTime.now().toUtc();
      final monthStart = DateTime.utc(date.year, date.month, 1);

      final monthRows = await _client
          .from('poems')
          .select(_selectColumns)
          .eq('status', 'approved')
          .eq('is_hidden', false)
          .isFilter('deleted_at', null)
          .not('published_at', 'is', null)
          .gte('published_at', monthStart.toIso8601String())
          .order('published_at', ascending: false)
          .limit(limit);

      final monthPoems = _mapRows(monthRows);
      if (monthPoems.isEmpty) {
        return fetchRecentPoems(limit: limit, offset: 0);
      }
      return monthPoems;
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

  List<PublicPoem> _mapRows(List<dynamic> rows) {
    return rows
        .map(
          (row) => PublicPoem.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  String _mapExploreError(Object error) {
    final mapped = PoemErrorMapper.map(error);
    if (mapped == 'Ocurrió un error inesperado. Inténtalo de nuevo.' ||
        mapped == 'No se pudo completar la operación. Inténtalo de nuevo.') {
      return 'No pudimos cargar los poemas. Inténtalo de nuevo.';
    }
    return mapped;
  }
}
