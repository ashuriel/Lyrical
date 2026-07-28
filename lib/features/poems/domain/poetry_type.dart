/// Catalog entry from public.poetry_types.
class PoetryType {
  const PoetryType({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;

  factory PoetryType.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = switch (idRaw) {
      final int value => value,
      final num value => value.toInt(),
      _ => throw const FormatException('PoetryType.id is missing or invalid.'),
    };
    final name = json['name'];
    final slug = json['slug'];

    if (name is! String || name.isEmpty) {
      throw const FormatException('PoetryType.name is missing or invalid.');
    }
    if (slug is! String || slug.isEmpty) {
      throw const FormatException('PoetryType.slug is missing or invalid.');
    }

    return PoetryType(id: id, name: name, slug: slug);
  }
}
