import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/core/errors/app_exception.dart';
import 'package:lyrical/core/errors/poem_error_mapper.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/poems/data/poem_repository.dart';
import 'package:lyrical/features/poems/data/poetry_type_repository.dart';
import 'package:lyrical/features/poems/domain/poem.dart';
import 'package:lyrical/features/poems/domain/poetry_type.dart';

final poetryTypeRepositoryProvider = Provider<PoetryTypeRepository>((ref) {
  return PoetryTypeRepository(ref.watch(supabaseClientProvider));
});

final poemRepositoryProvider = Provider<PoemRepository>((ref) {
  return PoemRepository(ref.watch(supabaseClientProvider));
});

final poetryTypesProvider = FutureProvider<List<PoetryType>>((ref) async {
  return ref.watch(poetryTypeRepositoryProvider).fetchPoetryTypes();
});

final currentUserPendingPoemsProvider = FutureProvider<List<Poem>>((ref) async {
  await _requireAuthenticated(ref);
  return ref.watch(poemRepositoryProvider).fetchCurrentUserPendingPoems();
});

final currentUserPublishedPoemsProvider = FutureProvider<List<Poem>>((
  ref,
) async {
  await _requireAuthenticated(ref);
  return ref.watch(poemRepositoryProvider).fetchCurrentUserPublishedPoems();
});

final currentUserHiddenPoemsProvider = FutureProvider<List<Poem>>((ref) async {
  await _requireAuthenticated(ref);
  return ref.watch(poemRepositoryProvider).fetchCurrentUserHiddenPoems();
});

final currentUserRejectedPoemsProvider = FutureProvider<List<Poem>>((
  ref,
) async {
  await _requireAuthenticated(ref);
  return ref.watch(poemRepositoryProvider).fetchCurrentUserRejectedPoems();
});

/// Latest poem by id. Auto-dispose so reopening the detail route refetches.
final currentUserPoemProvider = FutureProvider.autoDispose.family<Poem, String>(
  (ref, poemId) async {
    await _requireAuthenticated(ref);
    return ref.watch(poemRepositoryProvider).fetchCurrentUserPoemById(poemId);
  },
);

/// Invalidates all current-user poem list providers (no fetch).
void invalidateCurrentUserPoemLists(Ref ref) {
  ref.invalidate(currentUserPendingPoemsProvider);
  ref.invalidate(currentUserPublishedPoemsProvider);
  ref.invalidate(currentUserHiddenPoemsProvider);
  ref.invalidate(currentUserRejectedPoemsProvider);
}

/// Pull-to-refresh / screen-open helper: invalidate then await all four lists.
Future<void> refreshCurrentUserPoemLists(WidgetRef ref) async {
  ref.invalidate(currentUserPendingPoemsProvider);
  ref.invalidate(currentUserPublishedPoemsProvider);
  ref.invalidate(currentUserHiddenPoemsProvider);
  ref.invalidate(currentUserRejectedPoemsProvider);
  await Future.wait([
    ref.read(currentUserPendingPoemsProvider.future),
    ref.read(currentUserPublishedPoemsProvider.future),
    ref.read(currentUserHiddenPoemsProvider.future),
    ref.read(currentUserRejectedPoemsProvider.future),
  ]);
}

/// Session-local publish draft. Not auto-disposed so tab switches keep it.
@immutable
class PublishFormState {
  const PublishFormState({
    this.title = '',
    this.content = '',
    this.poetryTypeId,
  });

  final String title;
  final String content;
  final int? poetryTypeId;

  bool get hasUnsavedChanges =>
      title.trim().isNotEmpty ||
      content.trim().isNotEmpty ||
      poetryTypeId != null;

  int get titleLength => title.length;
  int get contentLength => content.length;

  String? get titleError {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'El título es obligatorio.';
    if (trimmed.length > PoemRepository.maxTitleLength) {
      return 'El título no puede superar los 100 caracteres.';
    }
    return null;
  }

  String? get contentError {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 'El poema no puede estar vacío.';
    if (trimmed.length > PoemRepository.maxContentLength) {
      return 'El poema no puede superar los 10000 caracteres.';
    }
    return null;
  }

  String? get poetryTypeError {
    if (poetryTypeId == null) return 'Selecciona un tipo de poema.';
    return null;
  }

  bool get isValid =>
      titleError == null && contentError == null && poetryTypeError == null;

  PublishFormState copyWith({
    String? title,
    String? content,
    int? poetryTypeId,
    bool clearPoetryType = false,
  }) {
    return PublishFormState(
      title: title ?? this.title,
      content: content ?? this.content,
      poetryTypeId: clearPoetryType
          ? null
          : (poetryTypeId ?? this.poetryTypeId),
    );
  }
}

class PublishFormNotifier extends Notifier<PublishFormState> {
  @override
  PublishFormState build() => const PublishFormState();

  void setTitle(String value) {
    state = state.copyWith(title: value);
  }

  void setContent(String value) {
    state = state.copyWith(content: value);
  }

  void setPoetryTypeId(int? value) {
    if (value == null) {
      state = state.copyWith(clearPoetryType: true);
    } else {
      state = state.copyWith(poetryTypeId: value);
    }
  }

  void clear() {
    state = const PublishFormState();
  }
}

final publishFormProvider =
    NotifierProvider<PublishFormNotifier, PublishFormState>(
      PublishFormNotifier.new,
    );

final publishPoemControllerProvider =
    AutoDisposeAsyncNotifierProvider<PublishPoemController, void>(
      PublishPoemController.new,
    );

final poemActionControllerProvider =
    AutoDisposeAsyncNotifierProvider<PoemActionController, void>(
      PoemActionController.new,
    );

class PublishPoemController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit() async {
    if (state.isLoading) return false;

    final form = ref.read(publishFormProvider);
    if (!form.isValid || form.poetryTypeId == null) {
      state = AsyncError(
        const AppException('Revisa los campos del formulario.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(poemRepositoryProvider)
            .createPoem(
              title: form.title,
              content: form.content,
              poetryTypeId: form.poetryTypeId!,
            );
        ref.read(publishFormProvider.notifier).clear();
        invalidateCurrentUserPoemLists(ref);
      } catch (error) {
        throw AppException(PoemErrorMapper.map(error));
      }
    });

    return !state.hasError;
  }
}

class PoemActionController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> hide(String poemId) async {
    return _run(() async {
      await ref.read(poemRepositoryProvider).hidePoem(poemId);
      invalidateCurrentUserPoemLists(ref);
      ref.invalidate(currentUserPoemProvider(poemId));
    });
  }

  Future<bool> unhide(String poemId) async {
    return _run(() async {
      await ref.read(poemRepositoryProvider).unhidePoem(poemId);
      invalidateCurrentUserPoemLists(ref);
      ref.invalidate(currentUserPoemProvider(poemId));
    });
  }

  Future<bool> softDelete(String poemId) async {
    return _run(() async {
      await ref.read(poemRepositoryProvider).softDeletePoem(poemId);
      invalidateCurrentUserPoemLists(ref);
      ref.invalidate(currentUserPoemProvider(poemId));
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.isLoading) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await action();
      } catch (error) {
        throw AppException(PoemErrorMapper.map(error));
      }
    });

    return !state.hasError;
  }
}

Future<void> _requireAuthenticated(Ref ref) async {
  final authStatus = await ref.watch(authStateProvider.future);
  if (authStatus != AppAuthStatus.authenticated) {
    throw const AppException('No hay una sesión activa.');
  }
}
