import 'package:fitness_exercise_application/core/constants/debug_config.dart';
import 'package:fitness_exercise_application/core/storage/database_helper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'app_providers.g.dart';

/// Database Helper Provider
@riverpod
DatabaseHelper databaseHelper(DatabaseHelperRef ref) {
  return DatabaseHelper.instance;
}

/// Supabase Client Provider
@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  return Supabase.instance.client;
}

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// Current User ID Provider
@riverpod
String? currentUserId(CurrentUserIdRef ref) {
  if (kDebugBypassAuth) {
    return 'debug-user';
  }
  ref.watch(authStateChangesProvider);
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  return user?.id;
}
