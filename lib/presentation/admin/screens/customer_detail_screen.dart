import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/models/customer_detail_model.dart';
import '../../../domain/models/vehicle_model.dart';
// Assuming base providers exist or using mock for now as per plan
import '../../../application/providers/feature_providers.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String userId;
  const CustomerDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In real app: final customerAsync = ref.watch(customerDetailProvider(userId));
    // For now, using logic to fetch from repo via a simple future for demo purposes
    final adminRepo = ref.read(adminOpsRepositoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFFF0541E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Close',
          style: TextStyle(color: Color(0xFFF0541E), fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFDF2ED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Color(0xFFF0541E),
                size: 20,
              ),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<CustomerDetailModel>(
        future: adminRepo.getCustomerDetail(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final customer = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(customer),
                const SizedBox(height: 24),
                _buildStatsGrid(customer),
                const SizedBox(height: 32),
                _buildSectionTitle('VEHICLE HISTORY', '+ Add New'),
                ...customer.vehicles.map((v) => _buildVehicleCard(v)),
                const SizedBox(height: 32),
                _buildSectionTitle('ACTIVE TICKETS', null),
                ...customer.activeTickets.map((t) => _buildTicketCard(t)),
                const SizedBox(height: 32),
                _buildSectionTitle('RECENT PAYMENTS', 'View All'),
                ...customer.recentPayments.map((p) => _buildPaymentCard(p)),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      bottomSheet: _buildBottomActions(),
    );
  }

  Widget _buildHeader(CustomerDetailModel customer) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            'https://i.pravatar.cc/150?u=${customer.id}',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 80,
              height: 80,
              color: const Color(0xFFE9ECEF),
              child: const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Customer since ${customer.joinDate.year}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text(
                    customer.status,
                    style: const TextStyle(
                      color: Color(0xFF2ECC71),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(CustomerDetailModel customer) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('SPEND', '₹${customer.totalSpend.toInt()}'),
          _buildStatDivider(),
          _buildStatItem('VISITS', '${customer.totalVisits}'),
          _buildStatDivider(),
          _buildStatItem('RATING', '${customer.averageRating} star'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 40, width: 1, color: const Color(0xFFE9ECEF));
  }

  Widget _buildSectionTitle(String title, String? actionText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF495057),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          if (actionText != null)
            Text(
              actionText,
              style: const TextStyle(
                color: Color(0xFFF0541E),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF2ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: Color(0xFFF0541E),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '${vehicle.licensePlate} • ${vehicle.color}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (vehicle.isPrimary)
            const Text(
              'Primary',
              style: TextStyle(
                color: Color(0xFFF0541E),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(SupportTicketModel ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE74C3C),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${ticket.type} - #${ticket.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC0392B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDEDE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.priority,
                  style: const TextStyle(
                    color: Color(0xFFC0392B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              ticket.description,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentRecordModel payment) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.serviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  payment.date.toString().substring(0, 10),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+₹${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF2ECC71),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECEF))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Direct Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF0541E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: _roundedRectangleV2(20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF0541E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFE9ECEF)),
                shape: _roundedRectangleV2(20),
              ),
              child: const Text('Issue Refund'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for custom radius scale from design rules
  OutlinedBorder _roundedRectangleV2(double radius) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }
}
