import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/engagement/data/engagement_repository.dart';
import 'package:lyrical/features/engagement/domain/poem_engagement.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  return EngagementRepository(ref.watch(supabaseClientProvider));
});

/// Per-poem engagement: single source of truth for like count and flags.
class PoemEngagementNotifier
    extends AutoDisposeFamilyAsyncNotifier<PoemEngagement, String> {
  bool _mutating = false;

  @override
  Future<PoemEngagement> build(String poemId) {
    return ref.read(engagementRepositoryProvider).fetchPoemEngagement(poemId);
  }

  Future<void> like() => _mutateLike(like: true);

  Future<void> unlike() => _mutateLike(like: false);

  Future<void> bookmark() => _mutateBookmark(bookmark: true);

  Future<void> removeBookmark() => _mutateBookmark(bookmark: false);

  Future<void> _mutateLike({required bool like}) async {
    if (_mutating) return;
    final poemId = arg;
    final previous = state.asData?.value;
    if (previous == null) return;
    if (like && previous.isLiked) return;
    if (!like && !previous.isLiked) return;

    _mutating = true;
    state = AsyncData(
      previous.copyWith(
        isLiked: like,
        likeCount: like
            ? previous.likeCount + 1
            : (previous.likeCount > 0 ? previous.likeCount - 1 : 0),
      ),
    );

    try {
      final repo = ref.read(engagementRepositoryProvider);
      final result = like
          ? await repo.likePoem(poemId)
          : await repo.unlikePoem(poemId);
      state = AsyncData(
        previous.copyWith(
          isLiked: result.isLiked,
          likeCount: result.likeCount,
          isBookmarked: previous.isBookmarked,
        ),
      );
    } catch (error, stack) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(
        error is AppException
            ? error
            : AppException(PoemErrorMapper.map(error)),
        stack,
      );
    } finally {
      _mutating = false;
    }
  }

  Future<void> _mutateBookmark({required bool bookmark}) async {
    if (_mutating) return;
    final poemId = arg;
    final previous = state.asData?.value;
    if (previous == null) return;
    if (bookmark && previous.isBookmarked) return;
    if (!bookmark && !previous.isBookmarked) return;

    _mutating = true;
    state = AsyncData(previous.copyWith(isBookmarked: bookmark));

    try {
      final repo = ref.read(engagementRepositoryProvider);
      final isBookmarked = bookmark
          ? await repo.bookmarkPoem(poemId)
          : await repo.removeBookmark(poemId);
      state = AsyncData(previous.copyWith(isBookmarked: isBookmarked));

      if (!bookmark) {
        ref.read(savedPoemsProvider.notifier).removeLocally(poemId);
      } else {
        ref.invalidate(savedPoemsProvider);
      }
    } catch (error, stack) {
      state = AsyncData(previous);
      Error.throwWithStackTrace(
        error is AppException
            ? error
            : AppException(PoemErrorMapper.map(error)),
        stack,
      );
    } finally {
      _mutating = false;
    }
  }
}

final poemEngagementProvider = AsyncNotifierProvider.autoDispose
    .family<PoemEngagementNotifier, PoemEngagement, String>(
      PoemEngagementNotifier.new,
    );

@immutable
class SavedPoemsState {
  const SavedPoemsState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<PublicPoem> items;
  final bool hasMore;
  final bool isLoadingMore;

  SavedPoemsState copyWith({
    List<PublicPoem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SavedPoemsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class SavedPoemsNotifier extends AutoDisposeAsyncNotifier<SavedPoemsState> {
  static const int pageSize = EngagementRepository.defaultBookmarksPageSize;

  @override
  Future<SavedPoemsState> build() async {
    await _requireAuthenticated(ref);
    final items = await ref
        .read(engagementRepositoryProvider)
        .fetchCurrentUserBookmarkedPoems(limit: pageSize, offset: 0);
    return SavedPoemsState(items: items, hasMore: items.length >= pageSize);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final next = await ref
          .read(engagementRepositoryProvider)
          .fetchCurrentUserBookmarkedPoems(
            limit: pageSize,
            offset: current.items.length,
          );
      final seen = current.items.map((p) => p.id).toSet();
      final merged = [...current.items, ...next.where((p) => seen.add(p.id))];
      state = AsyncData(
        SavedPoemsState(
          items: merged,
          hasMore: next.length >= pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _requireAuthenticated(ref);
      final items = await ref
          .read(engagementRepositoryProvider)
          .fetchCurrentUserBookmarkedPoems(limit: pageSize, offset: 0);
      return SavedPoemsState(items: items, hasMore: items.length >= pageSize);
    });
  }

  void removeLocally(String poemId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((p) => p.id != poemId).toList(),
      ),
    );
  }
}

final savedPoemsProvider =
    AutoDisposeAsyncNotifierProvider<SavedPoemsNotifier, SavedPoemsState>(
      SavedPoemsNotifier.new,
    );

Future<void> _requireAuthenticated(Ref ref) async {
  final authStatus = await ref.watch(authStateProvider.future);
  if (authStatus != AppAuthStatus.authenticated) {
    throw const AppException('No hay una sesión activa.');
  }
}
