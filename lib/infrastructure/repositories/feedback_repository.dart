import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/feedback_model.dart';

class FeedbackRepository {
  final _client = Supabase.instance.client;

  Future<void> saveFeedback(FeedbackModel feedback) async {
    // Check if feedback exists
    final existing = await _client
        .from('service_feedback')
        .select('id')
        .eq('booking_id', feedback.bookingId)
        .maybeSingle();
    
    if (existing != null) {
      // Update existing feedback
      await _client
          .from('service_feedback')
          .update({
            'rating': feedback.rating,
            'comment': feedback.comment,
            'tags': feedback.tags,
            'is_complaint': feedback.isComplaint,
            'feedback_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('booking_id', feedback.bookingId);
    } else {
      // Insert new feedback
      await _client.from('service_feedback').insert(feedback.toJson());
    }
  }

  Future<FeedbackModel?> getFeedbackByBookingId(String bookingId) async {
    final response = await _client
        .from('service_feedback')
        .select()
        .eq('booking_id', bookingId)
        .maybeSingle();
    
    if (response == null) return null;
    return FeedbackModel.fromJson(response);
  }

  Future<List<FeedbackModel>> getFeedbackForService(String serviceId) async {
    final response = await _client
        .from('service_feedback')
        .select()
        .eq('service_id', serviceId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => FeedbackModel.fromJson(json))
        .toList();
  }

  Future<FeedbackStatsModel> getFeedbackStats() async {
    try {
      final raw = await _client
          .from('service_feedback')
          .select('id,booking_id,user_id,rating,comment,tags,created_at')
          .order('created_at', ascending: false);
      final rows = (raw as List).cast<Map<String, dynamic>>();

      if (rows.isEmpty) {
        return FeedbackStatsModel(
          nps: 0,
          averageRating: 0,
          ratingTrends: const [0, 0, 0, 0, 0, 0, 0],
          sentiments: [
            SentimentBreakdown(
              label: 'Positive',
              percentage: 0,
              colorHex: '0xFF4CAF50',
            ),
            SentimentBreakdown(
              label: 'Neutral',
              percentage: 0,
              colorHex: '0xFFFFC107',
            ),
            SentimentBreakdown(
              label: 'Negative',
              percentage: 0,
              colorHex: '0xFFF44336',
            ),
          ],
          recentReviews: const [],
        );
      }

      final total = rows.length.toDouble();
      final ratings = rows
          .map((r) => (r['rating'] as num?)?.toDouble() ?? 0)
          .toList();

      final averageRating = ratings.fold<double>(0, (a, b) => a + b) / total;
      final promoters = ratings.where((r) => r >= 4).length;
      final detractors = ratings.where((r) => r <= 2).length;
      final nps = ((promoters / total) - (detractors / total)) * 100;

      final positive = ratings.where((r) => r >= 4).length / total;
      final neutral = ratings.where((r) => r >= 3 && r < 4).length / total;
      final negative = ratings.where((r) => r < 3).length / total;

      final ratingTrends = _last7DayAverage(rows);
      final recentReviews = rows.take(10).map((r) {
        final userId = (r['user_id'] ?? '').toString();
        final shortUser = userId.length >= 6 ? userId.substring(0, 6) : userId;
        return FeedbackModel(
          id: (r['id'] ?? '').toString(),
          bookingId: (r['booking_id'] ?? '').toString(),
          userId: userId,
          userName: 'User $shortUser',
          serviceName: 'Service',
          rating: (r['rating'] as num?)?.toDouble() ?? 0,
          comment: (r['comment'] ?? '').toString(),
          tags: List<String>.from(r['tags'] ?? const []),
          createdAt:
              DateTime.tryParse((r['created_at'] ?? '').toString()) ??
              DateTime.now(),
        );
      }).toList();

      return FeedbackStatsModel(
        nps: nps,
        averageRating: averageRating,
        ratingTrends: ratingTrends,
        sentiments: [
          SentimentBreakdown(
            label: 'Positive',
            percentage: positive,
            colorHex: '0xFF4CAF50',
          ),
          SentimentBreakdown(
            label: 'Neutral',
            percentage: neutral,
            colorHex: '0xFFFFC107',
          ),
          SentimentBreakdown(
            label: 'Negative',
            percentage: negative,
            colorHex: '0xFFF44336',
          ),
        ],
        recentReviews: recentReviews,
      );
    } catch (_) {
      return FeedbackStatsModel(
        nps: 0,
        averageRating: 0,
        ratingTrends: const [0, 0, 0, 0, 0, 0, 0],
        sentiments: [
          SentimentBreakdown(
            label: 'Positive',
            percentage: 0,
            colorHex: '0xFF4CAF50',
          ),
          SentimentBreakdown(
            label: 'Neutral',
            percentage: 0,
            colorHex: '0xFFFFC107',
          ),
          SentimentBreakdown(
            label: 'Negative',
            percentage: 0,
            colorHex: '0xFFF44336',
          ),
        ],
        recentReviews: const [],
      );
    }
  }

  List<double> _last7DayAverage(List<Map<String, dynamic>> feedbackRows) {
    final now = DateTime.now();
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);

    for (final row in feedbackRows) {
      final created = DateTime.tryParse((row['created_at'] ?? '').toString());
      if (created == null) continue;
      final dayDiff = now
          .difference(DateTime(created.year, created.month, created.day))
          .inDays;
      if (dayDiff < 0 || dayDiff > 6) continue;
      final idx = 6 - dayDiff;
      sums[idx] += (row['rating'] as num?)?.toDouble() ?? 0;
      counts[idx] += 1;
    }

    return List<double>.generate(7, (index) {
      if (counts[index] == 0) return 0;
      return sums[index] / counts[index];
    });
  }
}
