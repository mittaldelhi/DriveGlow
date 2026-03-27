import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/standard_service_model.dart';
import '../../infrastructure/repositories/standard_service_repository.dart';

final standardServiceRepoProvider = Provider<StandardServiceRepository>((ref) {
  return StandardServiceRepository(Supabase.instance.client);
});

final activeStandardServicesProvider =
    FutureProvider<List<StandardServiceModel>>((ref) async {
  try {
    final services = await ref.watch(standardServiceRepoProvider).getActiveServices().timeout(
      const Duration(seconds: 15),
      onTimeout: () => [],
    );
    return services;
  } catch (e) {
    return [];
  }
});

final allStandardServicesProvider = FutureProvider<List<StandardServiceModel>>((
  ref,
) async {
  try {
    final services = await ref.watch(standardServiceRepoProvider).getAllServices().timeout(
      const Duration(seconds: 15),
      onTimeout: () => [],
    );
    return services;
  } catch (e) {
    return [];
  }
});
