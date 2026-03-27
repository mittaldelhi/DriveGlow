import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/feedback_repository.dart';
import '../../infrastructure/repositories/chat_repository.dart';
import '../../infrastructure/repositories/admin_stats_repository.dart';
import '../../infrastructure/repositories/admin_ops_repository.dart';
import '../../domain/models/admin_stats_model.dart';
import '../../domain/models/chat_model.dart';
import '../../domain/models/service_pricing_model.dart';
import '../../domain/models/feedback_model.dart';

// Repositories
final feedbackRepositoryProvider = Provider((ref) => FeedbackRepository());
final chatRepositoryProvider = Provider((ref) => ChatRepository());
final adminStatsRepositoryProvider = Provider((ref) => AdminStatsRepository());
final adminOpsRepositoryProvider = Provider((ref) => AdminOpsRepository());

// Dynamic App Config (for labels, links, constants)
final appConfigProvider = FutureProvider<Map<String, String>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client.from('app_config').select();

  final config = <String, String>{};
  for (var item in response) {
    config[item['key']] = item['value'];
  }
  return config;
});

// Admin Dashboard Data
final adminDashboardProvider = StreamProvider<AdminDashboardModel>((
  ref,
) async* {
  final repo = ref.read(adminStatsRepositoryProvider);
  yield await repo.getDashboardStats();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 15));
    yield await repo.getDashboardStats();
  }
});

// Feedback Analytics
final feedbackStatsProvider = StreamProvider<FeedbackStatsModel>((ref) async* {
  final repo = ref.read(feedbackRepositoryProvider);
  yield await repo.getFeedbackStats();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 15));
    yield await repo.getFeedbackStats();
  }
});

// chat Messages
final chatMessagesProvider =
    StreamProvider.family<List<SupportMessageModel>, String>((ref, userId) {
      return ref.read(chatRepositoryProvider).getMessagesStream(userId);
    });

// Service Pricing - All pricing options (one-time & subscription)
final servicePricingProvider =
    FutureProvider.family<List<ServicePricingModel>, String>((
      ref,
      category,
    ) async {
      return ref.read(adminOpsRepositoryProvider).getServicePricing(category);
    });

// One-Time Services Only
final oneTimeServicesProvider = FutureProvider<List<ServicePricingModel>>((
  ref,
) async {
  return ref.read(adminOpsRepositoryProvider).getOneTimeServices();
});

// Subscription Services by Duration
final subscriptionServicesByDurationProvider =
    FutureProvider.family<List<ServicePricingModel>, String>((
      ref,
      duration,
    ) async {
      return ref
          .read(adminOpsRepositoryProvider)
          .getSubscriptionServices(duration);
    });

// All services by plan type (including inactive) for admin
final allServicesByPlanTypeProvider =
    FutureProvider.family<List<ServicePricingModel>, String>((
      ref,
      planType,
    ) async {
      return ref
          .read(adminOpsRepositoryProvider)
          .getAllServicesByPlanType(planType);
    });

// All subscription plans (Monthly)
final monthlySubscriptionPlansProvider =
    FutureProvider<List<ServicePricingModel>>((ref) async {
      return ref
          .read(adminOpsRepositoryProvider)
          .getSubscriptionServices('Monthly');
    });

// All subscription plans (Yearly)
final yearlySubscriptionPlansProvider =
    FutureProvider<List<ServicePricingModel>>((ref) async {
      return ref
          .read(adminOpsRepositoryProvider)
          .getSubscriptionServices('Yearly');
    });
