import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';
import 'package:lyrical/features/profile/domain/profile.dart';
import 'package:lyrical/features/profile/providers/profile_providers.dart';

/// Notifies [GoRouter] when auth or profile status changes.
class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(this._ref) {
    _authSubscription = _ref.listen<AsyncValue<AppAuthStatus>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
    _profileSubscription = _ref.listen<AsyncValue<Profile>>(
      currentProfileProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AppAuthStatus>> _authSubscription;
  late final ProviderSubscription<AsyncValue<Profile>> _profileSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _profileSubscription.close();
    super.dispose();
  }
}
