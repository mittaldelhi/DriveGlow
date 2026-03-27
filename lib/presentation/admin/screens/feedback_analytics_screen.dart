import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../application/providers/feature_providers.dart';
import '../../../domain/models/feedback_model.dart';
import '../../../theme/app_theme.dart';

class FeedbackAnalyticsScreen extends ConsumerWidget {
  const FeedbackAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Analytics',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(context, ref),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 0,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: PremiumTheme.orangePrimary,
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.pop(context);
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/admin/dashboard');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/admin/settings');
                break;
              case 3:
                Navigator.pushReplacementNamed(context, '/admin/profile');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(feedbackStatsProvider);

    return statsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF0541E)),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Error loading analytics', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text('$err', style: TextStyle(fontSize: 12, color: Colors.grey[400]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Stats: NPS & Avg Rating
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'NPS',
                    stats.nps.toStringAsFixed(0),
                    'NET PROMOTER SCORE',
                    const Color(0xFFF0541E),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Avg. Rating',
                    stats.averageRating.toStringAsFixed(1),
                    'OUT OF 5.0 STARS',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rating Trend Line Chart
            _buildTrendCard(context, stats.ratingTrends),
            const SizedBox(height: 16),

            // Sentiment Breakdown
            _buildSentimentCard(context, stats.sentiments),
            const SizedBox(height: 16),

            // Recent Reviews List
            _buildReviewsHeader(context),
            const SizedBox(height: 8),
            ...stats.recentReviews.map(
              (review) => _buildReviewItem(context, review, ref),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String sub,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 32,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(BuildContext context, List<double> trends) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rating Trends (Last 7 Days)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.withValues(alpha: 0.12)),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7'];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 5,
                barGroups: [
                  for (int i = 0; i < trends.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: trends[i],
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentCard(BuildContext context, List<SentimentBreakdown> sentiments) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Sentiment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 24),
          ...sentiments.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '${(s.percentage * 100).toInt()}%',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(int.parse(s.colorHex))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.percentage,
                      backgroundColor: Colors.grey[100],
                      color: Color(int.parse(s.colorHex)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Reviews',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Filters', style: TextStyle(color: Color(0xFFF0541E))),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(BuildContext context, FeedbackModel review, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.userName ?? 'Anonymous',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(Icons.star_rounded, size: 16, color: index < review.rating ? Colors.amber : Colors.grey[200]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            review.serviceName ?? 'General Service',
            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            review.comment ?? 'No comment provided.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF4A4A4A), height: 1.4),
          ),
          if (review.adminReply != null && review.adminReply!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('Admin Response', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(review.adminReply!, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton('Respond', Icons.reply_rounded, PremiumTheme.orangePrimary, () => _showReplyDialog(context, review, ref)),
              const SizedBox(width: 12),
              if (review.canEdit) _buildActionButton('Edit', Icons.edit_rounded, Colors.blue, () => _showEditDialog(context, review, ref)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, [VoidCallback? onTap]) {
    final button = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
    if (onTap != null) return GestureDetector(onTap: onTap, child: button);
    return button;
  }

  Future<void> _showReplyDialog(BuildContext context, FeedbackModel review, WidgetRef ref) async {
    final controller = TextEditingController(text: review.adminReply ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reply to Feedback'),
        content: TextField(controller: controller, maxLines: 4, decoration: InputDecoration(hintText: 'Write your response...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final client = Supabase.instance.client;
                await client.from('service_feedback').update({'admin_reply': controller.text, 'admin_reply_at': DateTime.now().toIso8601String()}).eq('id', review.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply submitted'), backgroundColor: Colors.green));
                  ref.invalidate(feedbackStatsProvider);
                }
              } catch (e) {
                if (context.mounted) showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: PremiumTheme.orangePrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, FeedbackModel review, WidgetRef ref) async {
    final ratingController = TextEditingController(text: review.rating.toString());
    final commentController = TextEditingController(text: review.comment ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Feedback'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: ratingController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Rating (1-5)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: commentController, maxLines: 4, decoration: InputDecoration(labelText: 'Comment', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final rating = int.tryParse(ratingController.text) ?? review.rating;
                if (rating < 1 || rating > 5) throw Exception('Rating must be 1-5');
                final client = Supabase.instance.client;
                await client.from('service_feedback').update({'rating': rating, 'comment': commentController.text, 'feedback_updated_at': DateTime.now().toIso8601String()}).eq('id', review.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback updated'), backgroundColor: Colors.green));
                  ref.invalidate(feedbackStatsProvider);
                }
              } catch (e) {
                if (context.mounted) showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: PremiumTheme.orangePrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
