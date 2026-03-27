import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/notification_model.dart';

class NotificationRepository {
  final _client = Supabase.instance.client;

  Future<List<NotificationModel>> getNotifications(String userId, {int limit = 20}) async {
    try {
      final response = await _client.rpc('get_user_notifications', params: {
        'p_user_id': userId,
        'p_limit': limit,
      });
      
      if (response == null) return [];
      
      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      // Fallback: query directly if RPC fails
      try {
        final response = await _client
            .from('user_notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(limit);
        
        return (response as List)
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      } catch (e2) {
        return [];
      }
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _client.rpc('get_unread_notification_count', params: {
        'p_user_id': userId,
      });
      return response as int? ?? 0;
    } catch (e) {
      // Fallback
      try {
        final response = await _client
            .from('user_notifications')
            .select('id')
            .eq('user_id', userId)
            .eq('is_read', false);
        return (response as List).length;
      } catch (e2) {
        return 0;
      }
    }
  }

  Future<bool> markAsRead(String notificationId, String userId) async {
    try {
      await _client.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
        'p_user_id': userId,
      });
      return true;
    } catch (e) {
      // Fallback
      try {
        await _client
            .from('user_notifications')
            .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
            .eq('id', notificationId)
            .eq('user_id', userId);
        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  Future<int> markAllAsRead(String userId) async {
    try {
      final count = await _client.rpc('mark_all_notifications_read', params: {
        'p_user_id': userId,
      });
      return count as int? ?? 0;
    } catch (e) {
      // Fallback
      try {
        await _client
            .from('user_notifications')
            .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
            .eq('user_id', userId)
            .eq('is_read', false);
        return 1;
      } catch (e2) {
        return 0;
      }
    }
  }

  Future<NotificationPreferencesModel> getPreferences(String userId) async {
    try {
      final response = await _client.rpc('get_notification_preferences', params: {
        'p_user_id': userId,
      });
      
      if (response == null || (response as List).isEmpty) {
        return NotificationPreferencesModel();
      }
      
      return NotificationPreferencesModel.fromJson((response as List).first);
    } catch (e) {
      // Fallback
      try {
        final response = await _client
            .from('user_notification_preferences')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        
        if (response == null) {
          return NotificationPreferencesModel();
        }
        
        return NotificationPreferencesModel.fromJson(response);
      } catch (e2) {
        return NotificationPreferencesModel();
      }
    }
  }

  Future<bool> updatePreferences(
    String userId, {
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? notifyBookingComplete,
    bool? notifyPaymentDone,
    bool? notifySubscriptionDone,
    bool? notifyPromotions,
    bool? notifyFeedbackReminders,
  }) async {
    try {
      await _client.rpc('update_notification_preferences', params: {
        'p_user_id': userId,
        'p_push_enabled': pushEnabled,
        'p_email_enabled': emailEnabled,
        'p_sms_enabled': smsEnabled,
        'p_notify_booking_complete': notifyBookingComplete,
        'p_notify_payment_done': notifyPaymentDone,
        'p_notify_subscription_done': notifySubscriptionDone,
        'p_notify_promotions': notifyPromotions,
        'p_notify_feedback_reminders': notifyFeedbackReminders,
      });
      return true;
    } catch (e) {
      // Fallback
      try {
        await _client.from('user_notification_preferences').upsert({
          'user_id': userId,
          'push_enabled': pushEnabled ?? true,
          'email_enabled': emailEnabled ?? true,
          'sms_enabled': smsEnabled ?? false,
          'notify_booking_complete': notifyBookingComplete ?? true,
          'notify_payment_done': notifyPaymentDone ?? true,
          'notify_subscription_done': notifySubscriptionDone ?? true,
          'notify_promotions': notifyPromotions ?? false,
          'notify_feedback_reminders': notifyFeedbackReminders ?? true,
          'updated_at': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (e2) {
        return false;
      }
    }
  }
}
