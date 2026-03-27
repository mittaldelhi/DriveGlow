class FeedbackModel {
  final String id;
  final String bookingId;
  final String userId;
  final String? userName;
  final String? serviceName;
  final double rating;
  final String? comment;
  final List<String>? tags;
  final DateTime createdAt;
  final String? staffId;
  final String? staffName;
  final bool isComplaint;
  final String? ticketNumber;
  final String? ticketStatus;
  final String? ticketPriority;
  final String? adminNotes;
  final DateTime? feedbackUpdatedAt;
  // New enhanced feedback fields
  final int? staffRating;
  final String? staffBehavior;
  final String? staffComment;
  final bool? wouldRecommend;
  final String? adminReply;
  final DateTime? adminReplyAt;
  final DateTime? editableUntil;

  FeedbackModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    this.userName,
    this.serviceName,
    required this.rating,
    this.comment,
    this.tags,
    required this.createdAt,
    this.staffId,
    this.staffName,
    this.isComplaint = false,
    this.ticketNumber,
    this.ticketStatus,
    this.ticketPriority,
    this.adminNotes,
    this.feedbackUpdatedAt,
    this.staffRating,
    this.staffBehavior,
    this.staffComment,
    this.wouldRecommend,
    this.adminReply,
    this.adminReplyAt,
    this.editableUntil,
  });

  bool get hasFeedback => id.isNotEmpty;
  bool get isTicket => ticketNumber != null && ticketNumber!.isNotEmpty;
  bool get isHighPriority => ticketPriority == 'high';
  bool get isOpen => ticketStatus == 'open';
  bool get isResolved => ticketStatus == 'resolved' || ticketStatus == 'closed';
  bool get canEdit => editableUntil != null && DateTime.now().isBefore(editableUntil!);
  bool get hasAdminReply => adminReply != null && adminReply!.isNotEmpty;

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] ?? '',
      bookingId: json['booking_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['customer_name'] ?? json['user_name'],
      serviceName: json['service_name'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      staffId: json['staff_id'],
      staffName: json['staff_name'],
      isComplaint: json['is_complaint'] ?? false,
      ticketNumber: json['ticket_number'],
      ticketStatus: json['ticket_status'],
      ticketPriority: json['ticket_priority'],
      adminNotes: json['admin_notes'],
      feedbackUpdatedAt: json['feedback_updated_at'] != null 
          ? DateTime.parse(json['feedback_updated_at']) 
          : null,
      staffRating: json['staff_rating'],
      staffBehavior: json['staff_behavior'],
      staffComment: json['staff_comment'],
      wouldRecommend: json['would_recommend'],
      adminReply: json['admin_reply'],
      adminReplyAt: json['admin_reply_at'] != null ? DateTime.parse(json['admin_reply_at']) : null,
      editableUntil: json['editable_until'] != null ? DateTime.parse(json['editable_until']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
      'tags': tags,
      'is_complaint': isComplaint,
      'staff_id': staffId,
      'staff_rating': staffRating,
      'staff_behavior': staffBehavior,
      'staff_comment': staffComment,
      'would_recommend': wouldRecommend,
      'admin_reply': adminReply,
      'editable_until': editableUntil?.toIso8601String(),
    };
  }
}

class SentimentBreakdown {
  final String label;
  final double percentage;
  final String colorHex;

  SentimentBreakdown({
    required this.label,
    required this.percentage,
    required this.colorHex,
  });

  factory SentimentBreakdown.fromJson(Map<String, dynamic> json) {
    return SentimentBreakdown(
      label: json['label'],
      percentage: (json['percentage'] as num).toDouble(),
      colorHex: json['color_hex'],
    );
  }
}

class FeedbackStatsModel {
  final double nps;
  final double averageRating;
  final List<double> ratingTrends;
  final List<SentimentBreakdown> sentiments;
  final List<FeedbackModel> recentReviews;

  FeedbackStatsModel({
    required this.nps,
    required this.averageRating,
    required this.ratingTrends,
    required this.sentiments,
    required this.recentReviews,
  });

  factory FeedbackStatsModel.fromJson(Map<String, dynamic> json) {
    return FeedbackStatsModel(
      nps: (json['nps'] as num? ?? 0).toDouble(),
      averageRating: (json['average_rating'] as num? ?? 0).toDouble(),
      ratingTrends: List<double>.from(json['rating_trends'] ?? []),
      sentiments: (json['sentiments'] as List? ?? [])
          .map((s) => SentimentBreakdown.fromJson(s))
          .toList(),
      recentReviews: (json['recent_reviews'] as List? ?? [])
          .map((r) => FeedbackModel.fromJson(r))
          .toList(),
    );
  }
}
