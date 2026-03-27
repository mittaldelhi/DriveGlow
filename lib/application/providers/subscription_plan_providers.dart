import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/subscription_plan_model.dart';
import '../../infrastructure/repositories/subscription_plan_repository.dart';

final subscriptionPlanRepoProvider = Provider<SubscriptionPlanRepository>((
  ref,
) {
  return SubscriptionPlanRepository(Supabase.instance.client);
});

final activeSubscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
      return ref.watch(subscriptionPlanRepoProvider).getActivePlans();
    });

final subscriptionPlansByDurationProvider =
    FutureProvider.family<List<SubscriptionPlanModel>, String>((
      ref,
      duration,
    ) async {
      return ref
          .watch(subscriptionPlanRepoProvider)
          .getPlansByDuration(duration);
    });

final allSubscriptionPlansProvider =
    FutureProvider<List<SubscriptionPlanModel>>((ref) async {
      return ref.watch(subscriptionPlanRepoProvider).getAllPlans();
    });
