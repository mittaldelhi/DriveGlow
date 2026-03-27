import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/user_profile_model.dart';
import '../../infrastructure/repositories/user_repository.dart';
import 'auth_providers.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(Supabase.instance.client);
});

final userProfileProvider = StreamProvider<UserProfileModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return ref.watch(userRepositoryProvider).watchProfile(user.id);
});

final userProfileNotifierProvider = FutureProvider<UserProfileModel?>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  return ref.watch(userRepositoryProvider).getProfile(user.id);
});
