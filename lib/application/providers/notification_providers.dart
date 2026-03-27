import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infrastructure/repositories/notification_repository.dart';
import '../../domain/models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationsProvider = FutureProvider.family<List<NotificationModel>, String>((ref, userId) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications(userId);
});

final unreadNotificationCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount(userId);
});

final notificationPreferencesProvider = FutureProvider.family<NotificationPreferencesModel, String>((ref, userId) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getPreferences(userId);
});

// Current user notifications provider
final currentUserNotificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications(user.id);
});

final currentUserUnreadCountProvider = FutureProvider<int>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 0;
  
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount(user.id);
});
