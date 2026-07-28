import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/notifications/data/notification_repository.dart';
import 'package:lyrical/features/notifications/domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  await _requireAuthenticated(ref);
  return ref.watch(notificationRepositoryProvider).fetchUnreadCount();
});

@immutable
class NotificationsState {
  const NotificationsState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<AppNotification> items;
  final bool hasMore;
  final bool isLoadingMore;

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class NotificationsNotifier
    extends AutoDisposeAsyncNotifier<NotificationsState> {
  static const int pageSize = NotificationRepository.defaultPageSize;
  bool _loadMoreInFlight = false;

  @override
  Future<NotificationsState> build() async {
    await _requireAuthenticated(ref);
    final items = await ref
        .read(notificationRepositoryProvider)
        .fetchNotifications(limit: pageSize, offset: 0);
    return NotificationsState(items: items, hasMore: items.length >= pageSize);
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        _loadMoreInFlight) {
      return;
    }

    _loadMoreInFlight = true;
    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final next = await ref
          .read(notificationRepositoryProvider)
          .fetchNotifications(limit: pageSize, offset: current.items.length);
      final seen = current.items.map((n) => n.id).toSet();
      final merged = [...current.items, ...next.where((n) => seen.add(n.id))];
      state = AsyncData(
        NotificationsState(
          items: merged,
          hasMore: next.length >= pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    } finally {
      _loadMoreInFlight = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _requireAuthenticated(ref);
      final items = await ref
          .read(notificationRepositoryProvider)
          .fetchNotifications(limit: pageSize, offset: 0);
      return NotificationsState(
        items: items,
        hasMore: items.length >= pageSize,
      );
    });
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.asData?.value;
    if (current == null) return;

    final previous = current.items;
    final updated = previous
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    state = AsyncData(current.copyWith(items: updated));

    try {
      await ref.read(notificationRepositoryProvider).markAsRead(notificationId);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      state = AsyncData(current.copyWith(items: previous));
      ref.invalidate(unreadNotificationCountProvider);
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.asData?.value;
    if (current == null) return;

    final previous = current.items;
    final updated = previous.map((n) => n.copyWith(isRead: true)).toList();
    state = AsyncData(current.copyWith(items: updated));

    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      state = AsyncData(current.copyWith(items: previous));
      ref.invalidate(unreadNotificationCountProvider);
      rethrow;
    }
  }

  /// Optimistic local read without failing navigation if the RPC errors.
  Future<void> markAsReadBestEffort(String notificationId) async {
    try {
      await markAsRead(notificationId);
    } catch (_) {
      // Navigation continues; unread badge refreshes on next fetch.
      ref.invalidate(unreadNotificationCountProvider);
    }
  }
}

final notificationsProvider =
    AutoDisposeAsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );

Future<void> _requireAuthenticated(Ref ref) async {
  final authStatus = await ref.watch(authStateProvider.future);
  if (authStatus != AppAuthStatus.authenticated) {
    throw const AppException('No hay una sesión activa.');
  }
}
