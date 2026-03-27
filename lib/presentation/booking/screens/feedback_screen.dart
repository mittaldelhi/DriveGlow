import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../application/providers/feature_providers.dart';
import '../../../../application/providers/auth_providers.dart';
import '../../../../domain/models/feedback_model.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const FeedbackScreen({super.key, required this.bookingId});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int _rating = 0;
  bool _isComplaint = false;
  bool? _wouldRecommend;
  final TextEditingController _commentController = TextEditingController();
  final List<String> _quickTags = [
    'On Time',
    'Professional',
    'Great Wash',
    'Deep Clean',
    'Value for Money',
  ];
  final Set<String> _selectedTags = {};
  bool _isLoading = true;
  FeedbackModel? _existingFeedback;

  @override
  void initState() {
    super.initState();
    _loadExistingFeedback();
  }

  Future<void> _loadExistingFeedback() async {
    try {
      final feedbackRepo = ref.read(feedbackRepositoryProvider);
      final feedback = await feedbackRepo.getFeedbackByBookingId(widget.bookingId);
      if (feedback != null && mounted) {
        setState(() {
          _existingFeedback = feedback;
          _rating = feedback.rating.round();
          _isComplaint = feedback.isComplaint;
          _wouldRecommend = feedback.wouldRecommend;
          _commentController.text = feedback.comment ?? '';
          _selectedTags.addAll(feedback.tags ?? []);
        });
      }
    } catch (e) {
      // No existing feedback
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _canEdit {
    if (_existingFeedback == null) return true;
    return _existingFeedback!.canEdit;
  }

  Future<void> _handleSubmit() async {
    final user = await ref.read(authRepositoryProvider).getCurrentUser();
    if (!mounted) return;
    if (user == null) return;

    if (_isComplaint && _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your complaint.')),
      );
      return;
    }

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating.')),
      );
      return;
    }

    if (_wouldRecommend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please let us know if you would recommend us.')),
      );
      return;
    }

    final tags = _selectedTags.toList();
    if (_isComplaint && !tags.contains('Complaint')) {
      tags.add('Complaint');
    }

    // Calculate editable_until (1 week from now)
    final editableUntil = DateTime.now().add(const Duration(days: 7));

    final feedback = FeedbackModel(
      id: _existingFeedback?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      bookingId: widget.bookingId,
      userId: user.id,
      rating: _rating.toDouble(),
      comment: _commentController.text.trim(),
      tags: tags,
      createdAt: _existingFeedback?.createdAt ?? DateTime.now(),
      isComplaint: _isComplaint,
      wouldRecommend: _wouldRecommend,
      editableUntil: editableUntil,
    );

    try {
      await ref.read(feedbackRepositoryProvider).saveFeedback(feedback);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show existing feedback view if not editable
    if (_existingFeedback != null && !_canEdit) {
      return _buildExistingFeedbackView();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_existingFeedback != null ? 'Edit Feedback' : 'Share Feedback'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              'How was your experience?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us improve our service.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  icon: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 48,
                    color: index < _rating ? const Color(0xFFF0541E) : Colors.grey[300],
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Text(
                _getRatingLabel(_rating),
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 32),

            // Would you recommend?
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Would you recommend us to a friend?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wouldRecommend = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _wouldRecommend == true ? Colors.green.withValues(alpha: 0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _wouldRecommend == true ? Colors.green : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.thumb_up, color: _wouldRecommend == true ? Colors.green : Colors.grey[400], size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'Yes, definitely!',
                            style: TextStyle(
                              color: _wouldRecommend == true ? Colors.green : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _wouldRecommend = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _wouldRecommend == false ? Colors.red.withValues(alpha: 0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _wouldRecommend == false ? Colors.red : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.thumb_down, color: _wouldRecommend == false ? Colors.red : Colors.grey[400], size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'Maybe not',
                            style: TextStyle(
                              color: _wouldRecommend == false ? Colors.red : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Tags
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What did you like specifically?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  selectedColor: const Color(0xFFF0541E).withValues(alpha: 0.1),
                  checkmarkColor: const Color(0xFFF0541E),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            SwitchListTile(
              title: const Text('This is a complaint'),
              subtitle: const Text('Mark if you had a service issue'),
              value: _isComplaint,
              onChanged: _canEdit ? (value) => setState(() => _isComplaint = value) : null,
              activeThumbColor: const Color(0xFFF0541E),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Comment Box
            TextField(
              controller: _commentController,
              maxLines: 4,
              enabled: _canEdit,
              decoration: InputDecoration(
                hintText: 'Any other comments or suggestions?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canEdit ? _handleSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0541E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _existingFeedback != null ? 'Update Feedback' : 'Submit Feedback',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_existingFeedback != null && _canEdit) ...[
              const SizedBox(height: 12),
              Text(
                'You can edit until ${DateFormat('MMM dd, yyyy').format(_existingFeedback!.editableUntil ?? DateTime.now().add(const Duration(days: 7)))}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExistingFeedbackView() {
    final feedback = _existingFeedback!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Your Feedback'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating display
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < feedback.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40,
                        color: index < feedback.rating.round() ? const Color(0xFFF0541E) : Colors.grey[300],
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getRatingLabel(feedback.rating.round()),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Would recommend
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    feedback.wouldRecommend == true ? Icons.thumb_up : Icons.thumb_down,
                    color: feedback.wouldRecommend == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    feedback.wouldRecommend == true 
                        ? 'Would recommend to a friend' 
                        : 'Would not recommend',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Comment
            if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
              const Text('Comment', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(feedback.comment!),
              const SizedBox(height: 16),
            ],

            // Tags
            if (feedback.tags != null && feedback.tags!.isNotEmpty) ...[
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: feedback.tags!.map((tag) => Chip(label: Text(tag))).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Admin reply
            if (feedback.hasAdminReply) ...[
              const Divider(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        const Text('Admin Reply', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(feedback.adminReply!),
                    if (feedback.adminReplyAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(feedback.adminReplyAt!),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Submitted on ${DateFormat('MMM dd, yyyy').format(feedback.createdAt)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Very Good';
      case 5: return 'Excellent';
      default: return '';
    }
  }
}
