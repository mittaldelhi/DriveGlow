class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    this.referenceType,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get icon {
    switch (type) {
      case 'booking_complete':
        return '✓';
      case 'payment':
        return '💰';
      case 'subscription':
        return '📦';
      case 'promotion':
        return '🎁';
      case 'feedback':
        return '⭐';
      case 'reminder':
        return '⏰';
      default:
        return '🔔';
    }
  }
}

class NotificationPreferencesModel {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool notifyBookingComplete;
  final bool notifyPaymentDone;
  final bool notifySubscriptionDone;
  final bool notifyPromotions;
  final bool notifyFeedbackReminders;

  NotificationPreferencesModel({
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.smsEnabled = false,
    this.notifyBookingComplete = true,
    this.notifyPaymentDone = true,
    this.notifySubscriptionDone = true,
    this.notifyPromotions = false,
    this.notifyFeedbackReminders = true,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? true,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
      notifyBookingComplete: json['notify_booking_complete'] as bool? ?? true,
      notifyPaymentDone: json['notify_payment_done'] as bool? ?? true,
      notifySubscriptionDone: json['notify_subscription_done'] as bool? ?? true,
      notifyPromotions: json['notify_promotions'] as bool? ?? false,
      notifyFeedbackReminders: json['notify_feedback_reminders'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
      'email_enabled': emailEnabled,
      'sms_enabled': smsEnabled,
      'notify_booking_complete': notifyBookingComplete,
      'notify_payment_done': notifyPaymentDone,
      'notify_subscription_done': notifySubscriptionDone,
      'notify_promotions': notifyPromotions,
      'notify_feedback_reminders': notifyFeedbackReminders,
    };
  }
}
