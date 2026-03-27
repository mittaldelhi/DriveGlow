import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/subscription_plan_model.dart';
import 'subscription_plan_providers.dart';

final streamAllSubscriptionPlansProvider = StreamProvider<List<SubscriptionPlanModel>>(
  (ref) {
    final repo = ref.watch(subscriptionPlanRepoProvider);
    return repo.streamAllPlans();
  },
);

final streamActiveSubscriptionPlansProvider = StreamProvider<List<SubscriptionPlanModel>>(
  (ref) {
    final repo = ref.watch(subscriptionPlanRepoProvider);
    return repo.streamAllPlans(onlyActive: true);
  },
);
