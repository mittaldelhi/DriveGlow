import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/standard_service_model.dart';

/// Repository for standard service operations with Supabase Postgres backend.
/// Handles CRUD operations and realtime streams for admin service management.
/// 
/// Error handling: Catches PostgreSQL exceptions and provides diagnostic info.
/// Tables: Uses `standard_services` table with admin-facing CRUD + customer-facing read-only.
class StandardServiceRepository {
  final SupabaseClient _client;
  static const String tableName = 'standard_services';

  StandardServiceRepository(this._client);

  /// Fetch active services for customer-facing screens.
  /// Returns: List of services where is_active=true, ordered by display_order.
  Future<List<StandardServiceModel>> getActiveServices() async {
    try {
      final response = await _client
          .from(tableName)
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => StandardServiceModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      print('❌ StandardServiceRepository.getActiveServices() - PostgreSQL Error: ${e.message}');
      print('📋 Details: code=${e.code}, table=$tableName');
      rethrow;
    } catch (e) {
      print('❌ StandardServiceRepository.getActiveServices() - Unexpected Error: $e');
      rethrow;
    }
  }

  /// Fetch all services for admin (including inactive).
  /// Used by admin panel to list, edit, and manage all services.
  Future<List<StandardServiceModel>> getAllServices() async {
    try {
      final response = await _client
          .from(tableName)
          .select()
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => StandardServiceModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      print('❌ getAllServices() - PostgreSQL Error: ${e.message}');
      if (e.code == 'PGRST116') {
        print('⚠️  Table "$tableName" not found in Supabase.');
        print('📝 Migration status: Check if migration 20240220_create_standard_services.sql was applied.');
      }
      rethrow;
    }
  }

  /// Upsert (create or update) a service.
  /// If id exists, updates; otherwise, creates new service.
  Future<void> upsertService(StandardServiceModel service) async {
    try {
      await _client.from(tableName).upsert(service.toJson());
      print('✅ Service upserted successfully: ${service.name}');
    } on PostgrestException catch (e) {
      print('❌ upsertService() - PostgreSQL Error: ${e.message}');
      rethrow;
    }
  }

  /// Delete a service by ID.
  Future<void> deleteService(String id) async {
    try {
      await _client.from(tableName).delete().eq('id', id);
      print('✅ Service deleted successfully: $id');
    } on PostgrestException catch (e) {
      print('❌ deleteService($id) - PostgreSQL Error: ${e.message}');
      rethrow;
    }
  }

  /// Toggle active status for a service.
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await _client
          .from(tableName)
          .update({'is_active': isActive})
          .eq('id', id);
      print('✅ Service status toggled: id=$id, isActive=$isActive');
    } on PostgrestException catch (e) {
      print('❌ toggleActive() - PostgreSQL Error: ${e.message}');
      rethrow;
    }
  }

  /// Stream all services (realtime) using Supabase realtime stream.
  /// Admin panel uses this for live updates on service changes.
  /// Parameters: onlyActive - if true, filters to is_active=true.
  /// Returns: Stream emitting updated list on any table change.
  Stream<List<StandardServiceModel>> streamAllServices({bool onlyActive = false}) {
    try {
      final query = _client
          .from(tableName)
          .stream(primaryKey: ['id'])
          .order('display_order', ascending: true);

      return query.map((event) {
        // event should be a List of json maps
        final list = event as List;
        final models = list
            .map((json) => StandardServiceModel.fromJson(json))
            .where((m) => onlyActive ? m.isActive : true)
            .toList();
        return models;
      }).handleError((e) {
        print('❌ streamAllServices() - Stream Error: $e');
      });
    } catch (e) {
      print('❌ streamAllServices() - Error initializing stream: $e');
      rethrow;
    }
  }
}
