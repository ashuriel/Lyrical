import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/explore/domain/public_poem.dart';
import 'package:lyrical/features/public_profile/data/public_profile_repository.dart';
import 'package:lyrical/features/public_profile/domain/public_profile.dart';

final publicProfileRepositoryProvider = Provider<PublicProfileRepository>((
  ref,
) {
  return PublicProfileRepository(ref.watch(supabaseClientProvider));
});

/// Single source of truth for a public profile + follow mutations.
class PublicProfileNotifier
    extends AutoDisposeFamilyAsyncNotifier<PublicProfile, String> {
  bool _mutating = false;

  @override
  Future<PublicProfile> build(String userId) {
    return ref.read(publicProfileRepositoryProvider).fetchPublicProfile(userId);
  }

  Future<void> follow() => _mutateFollow(follow: true);

  Future<void> unfollow() => _mutateFollow(follow: false);

  Future<void> _mutateFollow({required bool follow}) async {
    if (_mutating) return;
    final userId = arg;
    final previous = state.asData?.value;
    if (previous == null || previous.isCurrentUser) return;
    if (follow && previous.isFollowedByCurrentUser) return;
    if (!follow && !previous.isFollowedByCurrentUser) return;

    _mutating = true;
    state = AsyncData(
      previous.copyWith(
        isFollowedByCurrentUser: follow,
        followerCount: follow
            ? previous.followerCount + 1
            : (previous.followerCount > 0 ? previous.followerCount - 1 : 0),
      ),
    );

    try {
      final repo = ref.read(publicProfileRepositoryProvider);
      final result = follow
          ? await repo.followUser(userId)
          : await repo.unfollowUser(userId);
      state = AsyncData(
        previous.copyWith(
          isFollowedByCurrentUser: result.isFollowing,
          followerCount: result.followerCount,
        ),
      );
      final currentId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (currentId != null && currentId != userId) {
        ref.invalidate(publicProfileProvider(currentId));
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

final publicProfileProvider = AsyncNotifierProvider.autoDispose
    .family<PublicProfileNotifier, PublicProfile, String>(
      PublicProfileNotifier.new,
    );

@immutable
class AuthorPoemsState {
  const AuthorPoemsState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<PublicPoem> items;
  final bool hasMore;
  final bool isLoadingMore;

  AuthorPoemsState copyWith({
    List<PublicPoem>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return AuthorPoemsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class AuthorPoemsNotifier
    extends AutoDisposeFamilyAsyncNotifier<AuthorPoemsState, String> {
  static const int pageSize =
      PublicProfileRepository.defaultAuthorPoemsPageSize;

  @override
  Future<AuthorPoemsState> build(String userId) async {
    final items = await ref
        .read(publicProfileRepositoryProvider)
        .fetchPublicPoemsByAuthor(userId: userId, limit: pageSize, offset: 0);
    return AuthorPoemsState(items: items, hasMore: items.length >= pageSize);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final next = await ref
          .read(publicProfileRepositoryProvider)
          .fetchPublicPoemsByAuthor(
            userId: arg,
            limit: pageSize,
            offset: current.items.length,
          );
      final seen = current.items.map((p) => p.id).toSet();
      final merged = [...current.items, ...next.where((p) => seen.add(p.id))];
      state = AsyncData(
        AuthorPoemsState(
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
          .read(publicProfileRepositoryProvider)
          .fetchPublicPoemsByAuthor(userId: arg, limit: pageSize, offset: 0);
      return AuthorPoemsState(items: items, hasMore: items.length >= pageSize);
    });
  }
}

final authorPoemsProvider = AsyncNotifierProvider.autoDispose
    .family<AuthorPoemsNotifier, AuthorPoemsState, String>(
      AuthorPoemsNotifier.new,
    );
