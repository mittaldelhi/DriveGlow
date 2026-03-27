import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../application/helpers/error_helper.dart';
import '../../../application/providers/feature_providers.dart';
import '../../../domain/models/feedback_model.dart';
import '../../../theme/app_theme.dart';

final allTicketsProvider = FutureProvider<List<FeedbackModel>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client.rpc('get_all_tickets');
  final list = response as List;
  return list.map((json) => FeedbackModel.fromJson(json)).toList();
});

class AdminTicketsScreen extends ConsumerStatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  ConsumerState<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends ConsumerState<AdminTicketsScreen> {
  String _filterPriority = 'All';

  @override
  Widget build(BuildContext context) {
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
                    'Support Tickets',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildContent(),
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

  Widget _buildContent() {
    final ticketsAsync = ref.watch(allTicketsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filterPriority == 'All',
                onSelected: (_) => setState(() => _filterPriority = 'All'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('High'),
                selected: _filterPriority == 'High',
                onSelected: (_) => setState(() => _filterPriority = 'High'),
                backgroundColor: Colors.red[50],
                selectedColor: Colors.red[100],
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Open'),
                selected: _filterPriority == 'Open',
                onSelected: (_) => setState(() => _filterPriority = 'Open'),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(allTicketsProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: PremiumTheme.orangePrimary),
            ),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $err'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(allTicketsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (tickets) {
              var filtered = tickets;
              if (_filterPriority == 'High') {
                filtered = tickets.where((t) => t.ticketPriority == 'high').toList();
              } else if (_filterPriority == 'Open') {
                filtered = tickets.where((t) => t.ticketStatus == 'open').toList();
              }

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text('No tickets found', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final ticket = filtered[index];
                  return _buildTicketCard(ticket);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(FeedbackModel ticket) {
    final isHighPriority = ticket.ticketPriority == 'high';
    final statusColor = _getStatusColor(ticket.ticketStatus ?? 'open');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighPriority
            ? BorderSide(color: Colors.red[300]!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showTicketDetails(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHighPriority ? Colors.red[100] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.ticketNumber ?? 'No Ticket #',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isHighPriority ? Colors.red[700] : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (ticket.ticketStatus ?? 'open').toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        ticket.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  _getServiceDisplayName(ticket),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${ticket.userName ?? 'Unknown'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              if (ticket.comment != null && ticket.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ticket.comment!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(ticket.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  if (ticket.staffName != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.person, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Staff: ${ticket.staffName}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getServiceDisplayName(FeedbackModel ticket) {
    final name = ticket.serviceName ?? '';
    if (name.isEmpty || name.length > 50) {
      return 'Service';
    }
    if (name.startsWith('subscription::')) {
      final parts = name.split('::');
      if (parts.length >= 3) return parts[2];
      return 'Subscription Service';
    }
    return name;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }

  void _showTicketDetails(FeedbackModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _TicketDetailsSheet(
          ticket: ticket,
          scrollController: scrollController,
          onStatusUpdate: (status) async {
            final client = Supabase.instance.client;
            await client.rpc('update_ticket_status', params: {
              'p_feedback_id': ticket.id,
              'p_status': status,
            });
            ref.invalidate(allTicketsProvider);
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _TicketDetailsSheet extends StatefulWidget {
  final FeedbackModel ticket;
  final ScrollController scrollController;
  final Function(String) onStatusUpdate;

  const _TicketDetailsSheet({
    required this.ticket,
    required this.scrollController,
    required this.onStatusUpdate,
  });

  @override
  State<_TicketDetailsSheet> createState() => _TicketDetailsSheetState();
}

class _TicketDetailsSheetState extends State<_TicketDetailsSheet> {
  final _notesController = TextEditingController();

  String _getServiceDisplayName(FeedbackModel ticket) {
    final name = ticket.serviceName ?? '';
    if (name.isEmpty || name.length > 50) {
      return 'Service';
    }
    if (name.startsWith('subscription::')) {
      final parts = name.split('::');
      if (parts.length >= 3) return parts[2];
      return 'Subscription Service';
    }
    return name;
  }

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.ticket.adminNotes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                ticket.ticketNumber ?? 'Ticket Details',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ticket.ticketPriority == 'high' ? Colors.red[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ticket.ticketPriority == 'high' ? 'HIGH PRIORITY' : 'Normal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ticket.ticketPriority == 'high' ? Colors.red[700] : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDetailRow('Customer', ticket.userName ?? 'Unknown'),
        _buildDetailRow('Service', _getServiceDisplayName(ticket)),
        _buildDetailRow('Rating', '${ticket.rating.toStringAsFixed(1)} / 5.0'),
        _buildDetailRow('Status', ticket.ticketStatus?.toUpperCase() ?? 'OPEN'),
        _buildDetailRow('Created', _formatFullDate(ticket.createdAt)),
        if (ticket.staffName != null) _buildDetailRow('Staff', ticket.staffName!),
        const SizedBox(height: 16),
        const Text('Comment', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(ticket.comment ?? 'No comment'),
        ),
        const SizedBox(height: 20),
        const Text('Admin Notes', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add internal notes...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Update Status', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusButton('open', 'Open', Colors.orange),
            _buildStatusButton('in_progress', 'In Progress', Colors.blue),
            _buildStatusButton('resolved', 'Resolved', Colors.green),
            _buildStatusButton('closed', 'Closed', Colors.grey),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String status, String label, Color color) {
    final isActive = widget.ticket.ticketStatus == status;
    return ElevatedButton(
      onPressed: isActive ? null : () => widget.onStatusUpdate(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? color : color.withValues(alpha: 0.1),
        foregroundColor: isActive ? Colors.white : color,
        disabledBackgroundColor: color,
        disabledForegroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
