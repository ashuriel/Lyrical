import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:lyrical/features/search/data/public_poem_search_repository.dart';

final publicPoemSearchRepositoryProvider = Provider<PublicPoemSearchRepository>(
  (ref) {
    return PublicPoemSearchRepository(ref.watch(supabaseClientProvider));
  },
);

enum PoemSearchPhase {
  /// No active criteria — show the initial prompt.
  idle,

  /// Waiting for the typing debounce window.
  debouncing,

  /// First-page request in flight.
  loading,

  /// At least one result.
  results,

  /// Search completed with zero rows.
  empty,

  /// Failed first-page request.
  error,
}

@immutable
class PoemSearchState {
  const PoemSearchState({
    this.query = '',
    this.poetryTypeId,
    this.phase = PoemSearchPhase.idle,
    this.items = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final String query;
  final int? poetryTypeId;
  final PoemSearchPhase phase;
  final List<PublicPoem> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get hasActiveCriteria {
    final trimmed = query.trim();
    return poetryTypeId != null || trimmed.length >= 2;
  }

  /// Text filter sent to the RPC (empty when shorter than 2 chars).
  String get effectiveQuery {
    final trimmed = query.trim();
    return trimmed.length >= 2 ? trimmed : '';
  }

  PoemSearchState copyWith({
    String? query,
    int? poetryTypeId,
    bool clearPoetryTypeId = false,
    PoemSearchPhase? phase,
    List<PublicPoem>? items,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PoemSearchState(
      query: query ?? this.query,
      poetryTypeId: clearPoetryTypeId
          ? null
          : (poetryTypeId ?? this.poetryTypeId),
      phase: phase ?? this.phase,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PoemSearchNotifier extends Notifier<PoemSearchState> {
  static const Duration debounceDuration = Duration(milliseconds: 400);
  static const int pageSize = PublicPoemSearchRepository.defaultPageSize;

  Timer? _debounce;
  int _requestId = 0;
  bool _loadMoreInFlight = false;

  @override
  PoemSearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return const PoemSearchState();
  }

  void setQuery(String value) {
    _debounce?.cancel();

    final next = state.copyWith(query: value, clearError: true);

    if (!next.hasActiveCriteria) {
      _requestId++;
      _loadMoreInFlight = false;
      state = PoemSearchState(
        query: value,
        poetryTypeId: next.poetryTypeId,
        phase: PoemSearchPhase.idle,
      );
      return;
    }

    // Invalidate in-flight responses; drop stale results immediately.
    _requestId++;
    _loadMoreInFlight = false;
    state = next.copyWith(
      phase: PoemSearchPhase.debouncing,
      items: const [],
      hasMore: false,
      isLoadingMore: false,
    );

    _debounce = Timer(debounceDuration, () {
      unawaited(_runSearch());
    });
  }

  void setPoetryTypeId(int? poetryTypeId) {
    _debounce?.cancel();
    _requestId++;
    _loadMoreInFlight = false;

    final next = state.copyWith(
      poetryTypeId: poetryTypeId,
      clearPoetryTypeId: poetryTypeId == null,
      clearError: true,
      items: const [],
      hasMore: false,
      isLoadingMore: false,
    );

    if (!next.hasActiveCriteria) {
      _requestId++;
      _loadMoreInFlight = false;
      state = PoemSearchState(
        query: next.query,
        poetryTypeId: poetryTypeId,
        phase: PoemSearchPhase.idle,
      );
      return;
    }

    state = next.copyWith(phase: PoemSearchPhase.loading);
    unawaited(_runSearch());
  }

  void clear() {
    _debounce?.cancel();
    _requestId++;
    _loadMoreInFlight = false;
    state = const PoemSearchState();
  }

  Future<void> retry() => _runSearch();

  Future<void> refresh() => _runSearch();

  Future<void> loadMore() async {
    final current = state;
    if (!current.hasActiveCriteria ||
        !current.hasMore ||
        current.isLoadingMore ||
        _loadMoreInFlight ||
        current.phase == PoemSearchPhase.loading ||
        current.phase == PoemSearchPhase.debouncing ||
        current.phase == PoemSearchPhase.error) {
      return;
    }

    _loadMoreInFlight = true;
    final requestId = ++_requestId;
    state = current.copyWith(isLoadingMore: true);

    try {
      final nextPage = await ref
          .read(publicPoemSearchRepositoryProvider)
          .searchPublicPoems(
            query: current.effectiveQuery,
            poetryTypeId: current.poetryTypeId,
            limit: pageSize,
            offset: current.items.length,
          );

      if (requestId != _requestId) return;

      final seen = current.items.map((p) => p.id).toSet();
      final merged = [
        ...current.items,
        ...nextPage.where((p) => seen.add(p.id)),
      ];

      state = current.copyWith(
        phase: PoemSearchPhase.results,
        items: merged,
        hasMore: nextPage.length >= pageSize,
        isLoadingMore: false,
      );
    } catch (_) {
      if (requestId != _requestId) return;
      // Keep existing results; match Explorer load-more behavior.
      state = current.copyWith(isLoadingMore: false);
    } finally {
      if (requestId == _requestId) {
        _loadMoreInFlight = false;
      }
    }
  }

  Future<void> _runSearch() async {
    _debounce?.cancel();

    final snapshot = state;
    if (!snapshot.hasActiveCriteria) {
      state = PoemSearchState(
        query: snapshot.query,
        poetryTypeId: snapshot.poetryTypeId,
        phase: PoemSearchPhase.idle,
      );
      return;
    }

    final requestId = ++_requestId;
    _loadMoreInFlight = false;

    state = snapshot.copyWith(
      phase: PoemSearchPhase.loading,
      items: const [],
      hasMore: false,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      final items = await ref
          .read(publicPoemSearchRepositoryProvider)
          .searchPublicPoems(
            query: snapshot.effectiveQuery,
            poetryTypeId: snapshot.poetryTypeId,
            limit: pageSize,
            offset: 0,
          );

      if (requestId != _requestId) return;

      state = PoemSearchState(
        query: snapshot.query,
        poetryTypeId: snapshot.poetryTypeId,
        phase: items.isEmpty ? PoemSearchPhase.empty : PoemSearchPhase.results,
        items: items,
        hasMore: items.length >= pageSize,
      );
    } catch (error) {
      if (requestId != _requestId) return;
      final message = error is AppException
          ? error.message
          : PoemErrorMapper.map(error);
      state = PoemSearchState(
        query: snapshot.query,
        poetryTypeId: snapshot.poetryTypeId,
        phase: PoemSearchPhase.error,
        errorMessage: message,
      );
    }
  }
}

final poemSearchProvider =
    NotifierProvider<PoemSearchNotifier, PoemSearchState>(
      PoemSearchNotifier.new,
    );
