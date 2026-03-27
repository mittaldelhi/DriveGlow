import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../infrastructure/repositories/staff_ops_repository.dart';
import '../../domain/models/staff_profile_model.dart';

final staffOpsRepositoryProvider = Provider<StaffOpsRepository>((ref) {
  return StaffOpsRepository(Supabase.instance.client);
});

final streamTodayStatsProvider = StreamProvider<StaffDashboardStats>((ref) {
  final repo = ref.watch(staffOpsRepositoryProvider);
  return repo.streamTodayStats();
});

final staffProfileProvider = FutureProvider<StaffProfileModel?>((ref) async {
  final repo = ref.watch(staffOpsRepositoryProvider);
  return repo.getStaffProfile();
});

final staffWorkStatsProvider = FutureProvider<StaffWorkStats>((ref) async {
  final repo = ref.watch(staffOpsRepositoryProvider);
  return repo.getStaffWorkStats();
});

final staffNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(staffOpsRepositoryProvider);
  return repo.getNotifications();
});

final staffUnreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(staffOpsRepositoryProvider);
  return repo.getUnreadNotificationCount();
});

final passwordRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(staffOpsRepositoryProvider);
  return repo.getPendingPasswordRequests();
});
