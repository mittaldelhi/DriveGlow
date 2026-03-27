import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/service_model.dart';
import '../../domain/repositories/service_repository.dart';
import '../../infrastructure/repositories/supabase_service_repository.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return SupabaseServiceRepository();
});

final servicesProvider = FutureProvider<List<ServiceModel>>((ref) async {
  return ref.watch(serviceRepositoryProvider).getServices();
});

final serviceDetailProvider = FutureProvider.family<ServiceModel?, String>((
  ref,
  id,
) async {
  return ref.watch(serviceRepositoryProvider).getServiceById(id);
});
