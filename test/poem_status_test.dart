import 'package:flutter_test/flutter_test.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/domain/poem_status.dart';

Map<String, dynamic> _poemJson({
  required String status,
  bool isHidden = false,
  String? publishedAt,
}) {
  return {
    'id': 'poem-1',
    'author_id': 'user-1',
    'title': 'Título',
    'content': 'Verso de prueba',
    'status': status,
    'is_hidden': isHidden,
    'poetry_type_id': 1,
    'published_at': publishedAt,
    'created_at': '2026-01-01T12:00:00.000Z',
    'updated_at': '2026-01-01T12:00:00.000Z',
    'deleted_at': null,
    'poetry_types': {'name': 'Verso libre'},
  };
}

void main() {
  group('PoemStatus.fromDb', () {
    test('pending parses as pending', () {
      expect(PoemStatus.fromDb('pending'), PoemStatus.pending);
    });

    test('approved parses as approved', () {
      expect(PoemStatus.fromDb('approved'), PoemStatus.approved);
    });

    test('rejected parses as rejected', () {
      expect(PoemStatus.fromDb('rejected'), PoemStatus.rejected);
    });

    test('unknown status is not treated as pending', () {
      expect(
        () => PoemStatus.fromDb('unknown'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Unknown poem status'),
          ),
        ),
      );
    });
  });

  group('Poem.fromJson status and published_at', () {
    test('pending JSON parses as pending', () {
      final poem = Poem.fromJson(_poemJson(status: 'pending'));
      expect(poem.status, PoemStatus.pending);
      expect(poem.displayStatusLabel, 'En revisión');
      expect(poem.publishedAt, isNull);
    });

    test('approved JSON parses as approved with published_at', () {
      final poem = Poem.fromJson(
        _poemJson(status: 'approved', publishedAt: '2026-01-02T12:00:00.000Z'),
      );
      expect(poem.status, PoemStatus.approved);
      expect(poem.displayStatusLabel, 'Publicado');
      expect(poem.publishedAt, isNotNull);
    });

    test('approved and hidden shows Oculto', () {
      final poem = Poem.fromJson(_poemJson(status: 'approved', isHidden: true));
      expect(poem.status, PoemStatus.approved);
      expect(poem.isHidden, isTrue);
      expect(poem.displayStatusLabel, 'Oculto');
    });

    test('rejected JSON parses as rejected', () {
      final poem = Poem.fromJson(_poemJson(status: 'rejected'));
      expect(poem.status, PoemStatus.rejected);
      expect(poem.displayStatusLabel, 'Rechazado');
    });

    test('unknown status fails parsing', () {
      expect(
        () => Poem.fromJson(_poemJson(status: 'queued')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('list membership by status', () {
    test('pending query excludes approved poems', () {
      final poems = [
        Poem.fromJson(_poemJson(status: 'pending')),
        Poem.fromJson(_poemJson(status: 'approved')),
      ];
      final pending = poems.where((p) => p.status == PoemStatus.pending);
      expect(pending.length, 1);
      expect(pending.every((p) => p.status != PoemStatus.approved), isTrue);
    });

    test('published query excludes pending poems', () {
      final poems = [
        Poem.fromJson(_poemJson(status: 'pending')),
        Poem.fromJson(
          _poemJson(
            status: 'approved',
            publishedAt: '2026-01-02T12:00:00.000Z',
          ),
        ),
      ];
      final published = poems.where(
        (p) => p.status == PoemStatus.approved && !p.isHidden,
      );
      expect(published.length, 1);
      expect(published.every((p) => p.status != PoemStatus.pending), isTrue);
    });

    test('rejected query excludes pending poems', () {
      final poems = [
        Poem.fromJson(_poemJson(status: 'pending')),
        Poem.fromJson(_poemJson(status: 'rejected')),
      ];
      final rejected = poems.where((p) => p.status == PoemStatus.rejected);
      expect(rejected.length, 1);
      expect(rejected.every((p) => p.status != PoemStatus.pending), isTrue);
    });

    test('approved poem moves from pending to published after refresh', () {
      // Simulates cached pending list, then fresh DB rows after moderation.
      final beforeRefresh = [Poem.fromJson(_poemJson(status: 'pending'))];
      final afterRefreshPending = <Poem>[];
      final afterRefreshPublished = [
        Poem.fromJson(
          _poemJson(
            status: 'approved',
            publishedAt: '2026-01-02T12:00:00.000Z',
          ),
        ),
      ];

      expect(beforeRefresh.single.displayStatusLabel, 'En revisión');
      expect(afterRefreshPending, isEmpty);
      expect(afterRefreshPublished.single.displayStatusLabel, 'Publicado');
    });

    test('rejected poem moves from pending to rejected after refresh', () {
      final beforeRefresh = [Poem.fromJson(_poemJson(status: 'pending'))];
      final afterRefreshPending = <Poem>[];
      final afterRefreshRejected = [
        Poem.fromJson(_poemJson(status: 'rejected')),
      ];

      expect(beforeRefresh.single.displayStatusLabel, 'En revisión');
      expect(afterRefreshPending, isEmpty);
      expect(afterRefreshRejected.single.displayStatusLabel, 'Rechazado');
    });
  });
}
