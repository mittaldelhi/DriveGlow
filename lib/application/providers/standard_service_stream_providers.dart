import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/standard_service_model.dart';
import 'standard_service_providers.dart';

final streamAllStandardServicesProvider = StreamProvider<List<StandardServiceModel>>(
  (ref) {
    final repo = ref.watch(standardServiceRepoProvider);
    return repo.streamAllServices();
  },
);

final streamActiveStandardServicesProvider = StreamProvider<List<StandardServiceModel>>(
  (ref) {
    final repo = ref.watch(standardServiceRepoProvider);
    return repo.streamAllServices(onlyActive: true);
  },
);
