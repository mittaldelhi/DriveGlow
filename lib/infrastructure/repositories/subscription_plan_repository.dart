import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/subscription_plan_model.dart';

/// Repository for subscription plan operations with Supabase Postgres backend.
/// Handles CRUD operations and provides realtime streams for admin panel.
class SubscriptionPlanRepository {
  final SupabaseClient _client;
  static const String tableName = 'subscription_plans';

  SubscriptionPlanRepository(this._client);

  /// Fetch active plans for customer-facing screens.
  Future<List<SubscriptionPlanModel>> getActivePlans() async {
    try {
      final response = await _client
          .from(tableName)
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => SubscriptionPlanModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      print('SubscriptionPlanRepository.getActivePlans() PostgreSQL error: ${e.message}');
      print('Details: code=${e.code}, table=$tableName');
      rethrow;
    } catch (e) {
      print('SubscriptionPlanRepository.getActivePlans() unexpected error: $e');
      rethrow;
    }
  }

  /// Fetch plans filtered by duration (Monthly/Yearly).
  Future<List<SubscriptionPlanModel>> getPlansByDuration(String duration) async {
    try {
      final response = await _client
          .from(tableName)
          .select()
          .eq('is_active', true)
          .eq('duration', duration)
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => SubscriptionPlanModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      print('getPlansByDuration($duration) PostgreSQL error: ${e.message}');
      rethrow;
    }
  }

  /// Fetch all plans for admin (including inactive).
  Future<List<SubscriptionPlanModel>> getAllPlans() async {
    try {
      final response = await _client
          .from(tableName)
          .select()
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => SubscriptionPlanModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      print('getAllPlans() PostgreSQL error: ${e.message}');
      if (e.code == 'PGRST116') {
        print('Table "$tableName" not found in Supabase.');
        print('Migration needed: supabase/migrations/20250221_create_subscription_plans.sql');
      }
      rethrow;
    }
  }

  /// Upsert (create or update) a plan.
  /// Backward compatible with older DB schema that may not have included_service_ids.
  Future<void> upsertPlan(SubscriptionPlanModel plan) async {
    final payload = plan.toJson();
    try {
      await _client.from(tableName).upsert(payload);
      print('Plan upserted successfully: ${plan.name}');
    } on PostgrestException catch (e) {
      final missingColumn = e.message.contains('included_service_ids') ||
          e.message.contains('show_unlimited') ||
          e.message.contains('monthly_cap_override');
      
      if (missingColumn) {
        final fallbackPayload = Map<String, dynamic>.from(payload)
          ..remove('included_service_ids')
          ..remove('show_unlimited')
          ..remove('monthly_cap_override');
        await _client.from(tableName).upsert(fallbackPayload);
        print('Plan upsert fallback used (some columns missing in DB schema).');
        return;
      }

      print('upsertPlan() PostgreSQL error: ${e.message}');
      rethrow;
    }
  }

  /// Delete a plan by ID.
  Future<void> deletePlan(String id) async {
    try {
      await _client.from(tableName).delete().eq('id', id);
      print('Plan deleted successfully: $id');
    } on PostgrestException catch (e) {
      print('deletePlan($id) PostgreSQL error: ${e.message}');
      rethrow;
    }
  }

  /// Toggle active status for a plan.
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await _client
          .from(tableName)
          .update({'is_active': isActive})
          .eq('id', id);
      print('Plan status toggled: id=$id, isActive=$isActive');
    } on PostgrestException catch (e) {
      print('toggleActive() PostgreSQL error: ${e.message}');
      rethrow;
    }
  }

  /// Stream all subscription plans (realtime).
  Stream<List<SubscriptionPlanModel>> streamAllPlans({bool onlyActive = false}) {
    try {
      final query = _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .order('display_order', ascending: true);

      return query.map((event) {
        final list = event as List;
        return list
            .map((json) => SubscriptionPlanModel.fromJson(json))
            .where((p) => onlyActive ? p.isActive : true)
            .toList();
      }).handleError((e) {
        print('streamAllPlans() stream error: $e');
        if (e is PostgrestException) {
          print('PostgreSQL error details: ${e.message}');
        }
      });
    } catch (e) {
      print('streamAllPlans() initialization error: $e');
      rethrow;
    }
  }
}
