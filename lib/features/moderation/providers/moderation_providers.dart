import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/explore/providers/explore_providers.dart';
import 'package:lyrical/features/moderation/data/moderation_repository.dart';
import 'package:lyrical/features/moderation/domain/pending_moderation_poem.dart';
import 'package:lyrical/features/poems/providers/poem_providers.dart';
import 'package:lyrical/features/public_profile/providers/public_profile_providers.dart';
import 'package:lyrical/features/search/providers/search_providers.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(supabaseClientProvider));
});

/// Current-user admin flag from [is_current_user_admin]. Never inferred from email.
///
/// Rebuilds on auth changes. Failures surface as AsyncError for route gates.
final isCurrentUserAdminProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final authStatus = await ref.watch(authStateProvider.future);
  if (authStatus != AppAuthStatus.authenticated) {
    return false;
  }

  return ref.watch(moderationRepositoryProvider).isCurrentUserAdmin();
});

@immutable
class PendingModerationListState {
  const PendingModerationListState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<PendingModerationPoem> items;
  final bool hasMore;
  final bool isLoadingMore;

  PendingModerationListState copyWith({
    List<PendingModerationPoem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PendingModerationListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class PendingModerationListNotifier
    extends AutoDisposeAsyncNotifier<PendingModerationListState> {
  static const int pageSize = ModerationRepository.defaultPageSize;

  @override
  Future<PendingModerationListState> build() async {
    final items = await ref
        .read(moderationRepositoryProvider)
        .fetchPendingPoems(limit: pageSize, offset: 0);
    return PendingModerationListState(
      items: items,
      hasMore: items.length >= pageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final next = await ref
          .read(moderationRepositoryProvider)
          .fetchPendingPoems(limit: pageSize, offset: current.items.length);
      final seen = current.items.map((p) => p.poemId).toSet();
      final merged = [
        ...current.items,
        ...next.where((p) => seen.add(p.poemId)),
      ];
      state = AsyncData(
        PendingModerationListState(
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
      final items = await ref
          .read(moderationRepositoryProvider)
          .fetchPendingPoems(limit: pageSize, offset: 0);
      return PendingModerationListState(
        items: items,
        hasMore: items.length >= pageSize,
      );
    });
  }

  void removePoemLocally(String poemId) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((p) => p.poemId != poemId).toList(),
      ),
    );
  }
}

final pendingModerationListProvider =
    AsyncNotifierProvider.autoDispose<
      PendingModerationListNotifier,
      PendingModerationListState
    >(PendingModerationListNotifier.new);

final pendingModerationPoemProvider = FutureProvider.autoDispose
    .family<PendingModerationPoem, String>((ref, poemId) async {
      return ref.watch(moderationRepositoryProvider).fetchPendingPoem(poemId);
    });

class ModerationActionController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> approve(String poemId, {String? authorId}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(moderationRepositoryProvider).approvePoem(poemId);
      await _afterModeration(poemId, approved: true, authorId: authorId);
      state = const AsyncData(null);
    } catch (error, stack) {
      final mapped = error is AppException
          ? error
          : AppException(error.toString());
      state = AsyncError(mapped, stack);
      Error.throwWithStackTrace(mapped, stack);
    }
  }

  Future<void> reject(String poemId, {String? authorId}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(moderationRepositoryProvider).rejectPoem(poemId);
      await _afterModeration(poemId, approved: false, authorId: authorId);
      state = const AsyncData(null);
    } catch (error, stack) {
      final mapped = error is AppException
          ? error
          : AppException(error.toString());
      state = AsyncError(mapped, stack);
      Error.throwWithStackTrace(mapped, stack);
    }
  }

  Future<void> _afterModeration(
    String poemId, {
    required bool approved,
    String? authorId,
  }) async {
    ref.read(pendingModerationListProvider.notifier).removePoemLocally(poemId);
    ref.invalidate(pendingModerationPoemProvider(poemId));
    ref.invalidate(poemDetailProvider(poemId));
    invalidateCurrentUserPoemLists(ref);

    final resolvedAuthorId = authorId;
    if (resolvedAuthorId != null && resolvedAuthorId.isNotEmpty) {
      ref.invalidate(publicProfileProvider(resolvedAuthorId));
      ref.invalidate(authorPoemsProvider(resolvedAuthorId));
    }

    if (approved) {
      ref.invalidate(poemOfTheDayProvider);
      ref.invalidate(discoveryPoemsProvider);
      ref.invalidate(monthlySelectionProvider);
      try {
        await ref.read(recentPoemsProvider.notifier).refresh();
      } catch (_) {
        // Best-effort Explorer refresh.
      }
      try {
        final search = ref.read(poemSearchProvider);
        if (search.hasActiveCriteria) {
          await ref.read(poemSearchProvider.notifier).refresh();
        }
      } catch (_) {
        // Search may be idle.
      }
    }
  }
}

final moderationActionControllerProvider =
    AutoDisposeAsyncNotifierProvider<ModerationActionController, void>(
      ModerationActionController.new,
    );
