import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lyrical/features/auth/providers/auth_providers.dart';

/// Opens a public author profile, or the Profile tab when the author is self.
///
/// [authorId] is the route identifier only — never display it in the UI.
void openAuthorProfile(BuildContext context, WidgetRef ref, String authorId) {
  final currentId = ref.read(supabaseClientProvider).auth.currentUser?.id;
  if (currentId != null && currentId == authorId) {
    context.go('/app/profile');
    return;
  }
  context.push('/app/users/$authorId');
}
