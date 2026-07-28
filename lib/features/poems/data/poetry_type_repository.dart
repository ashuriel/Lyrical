import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/poems/domain/poetry_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only access to the poetry type catalog.
class PoetryTypeRepository {
  PoetryTypeRepository(this._client);

  final SupabaseClient _client;

  Future<List<PoetryType>> fetchPoetryTypes() async {
    try {
      final rows = await _client
          .from('poetry_types')
          .select('id, name, slug')
          .order('id', ascending: true);

      return rows
          .map((row) => PoetryType.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on AppException {
      rethrow;
    } on FormatException {
      throw const AppException(
        'No se pudieron leer los tipos de poema. Inténtalo de nuevo.',
      );
    } catch (error) {
      throw AppException(PoemErrorMapper.map(error));
    }
  }
}
