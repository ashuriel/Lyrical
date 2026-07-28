import 'package:lyrical/core/mock/mock_poem.dart';

/// Local Spanish mock poems for Explorer and Search UI prototypes.
///
/// TODO(lyrical): remove this file when poem queries are connected to Supabase.
abstract final class MockPoems {
  static final List<MockPoem> all = [
    MockPoem(
      id: 'mock-1',
      title: 'La hora quieta',
      preview:
          'Hay una hora en que la ciudad se vuelve casi un susurro,\n'
          'y el pecho recuerda que también es paisaje.',
      authorId: 'mock-author',
      authorAnonymousName: 'Serena Luna',
      poetryType: 'Verso libre',
      publishedAt: DateTime(2026, 7, 20),
    ),
    MockPoem(
      id: 'mock-2',
      title: 'Soneto del umbral',
      preview:
          'No cruzo aún la puerta que me nombra,\n'
          'pero ya late el aire de otro modo.',
      authorId: 'mock-author',
      authorAnonymousName: 'Noble Roble',
      poetryType: 'Soneto',
      publishedAt: DateTime(2026, 7, 18),
    ),
    MockPoem(
      id: 'mock-3',
      title: 'Tres líneas de lluvia',
      preview:
          'Lluvia en el cristal.\n'
          'El té se enfría despacio.\n'
          'Nadie pregunta.',
      authorId: 'mock-author',
      authorAnonymousName: 'Clara Aurora',
      poetryType: 'Haiku',
      publishedAt: DateTime(2026, 7, 15),
    ),
    MockPoem(
      id: 'mock-4',
      title: 'Carta sin destinatario',
      preview:
          'Escribo como quien deja una luz encendida\n'
          'en una casa que ya no habita.',
      authorId: 'mock-author',
      authorAnonymousName: 'Suave Brisa',
      poetryType: 'Poesía en prosa',
      publishedAt: DateTime(2026, 7, 12),
    ),
    MockPoem(
      id: 'mock-5',
      title: 'El río interior',
      preview:
          'Bajo la piel corre un agua antigua\n'
          'que no conoce fronteras ni apellidos.',
      authorId: 'mock-author',
      authorAnonymousName: 'Libre Gorrión',
      poetryType: 'Poesía lírica',
      publishedAt: DateTime(2026, 7, 10),
    ),
    MockPoem(
      id: 'mock-6',
      title: 'Historia de un domingo',
      preview:
          'Empezó con pan y silencio.\n'
          'Terminó con una pregunta abierta al cielo.',
      authorId: 'mock-author',
      authorAnonymousName: 'Dorada Niebla',
      poetryType: 'Poesía narrativa',
      publishedAt: DateTime(2026, 7, 8),
    ),
    MockPoem(
      id: 'mock-7',
      title: 'Elegía breve',
      preview:
          'Lo que se fue no pide luto:\n'
          'pide memoria con las manos limpias.',
      authorId: 'mock-author',
      authorAnonymousName: 'Plácida Orilla',
      poetryType: 'Elegía',
      publishedAt: DateTime(2026, 7, 5),
    ),
    MockPoem(
      id: 'mock-8',
      title: 'Nombre vertical',
      preview:
          'L\n'
          'U\n'
          'Z\n'
          'cae letra a letra sobre el papel.',
      authorId: 'mock-author',
      authorAnonymousName: 'Áurea Hoja',
      poetryType: 'Acróstico',
      publishedAt: DateTime(2026, 7, 2),
    ),
  ];

  static MockPoem get poemOfTheDay => all.first;

  static List<MockPoem> get discovery => all.skip(1).take(4).toList();

  static List<MockPoem> get monthlySelection => all.skip(2).take(3).toList();

  static List<MockPoem> get recent => List<MockPoem>.from(all);

  static List<MockPoem> search({required String query, String? poetryType}) {
    final normalized = query.trim().toLowerCase();
    return all.where((poem) {
      final matchesType = poetryType == null || poem.poetryType == poetryType;
      if (!matchesType) return false;
      if (normalized.isEmpty) return true;
      return poem.title.toLowerCase().contains(normalized) ||
          poem.preview.toLowerCase().contains(normalized) ||
          poem.authorAnonymousName.toLowerCase().contains(normalized);
    }).toList();
  }
}
