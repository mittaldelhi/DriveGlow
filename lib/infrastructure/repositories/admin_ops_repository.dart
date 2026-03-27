import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/service_pricing_model.dart';
import '../../domain/models/vehicle_model.dart';
import '../../domain/models/customer_detail_model.dart';
import '../../domain/models/booking_slot_model.dart';

class AdminOpsRepository {
  final _supabase = Supabase.instance.client;

  Future<List<ServicePricingModel>> getServicePricing(String category) async {
    try {
      final response = await _supabase
          .from('service_pricing')
          .select()
          .eq('category', category)
          .order('id', ascending: true);

      return (response as List)
          .map((p) => ServicePricingModel.fromJson(p))
          .toList();
    } catch (e) {
      throw Exception('Failed to load services: $e');
    }
  }

  /// Get all one-time services (for booking)
  Future<List<ServicePricingModel>> getOneTimeServices() async {
    try {
      final response = await _supabase
          .from('service_pricing')
          .select()
          .eq('plan_type', 'One-Time')
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return (response as List)
          .map((p) => ServicePricingModel.fromJson(p))
          .toList();
    } catch (e) {
      throw Exception('Failed to load one-time services: $e');
    }
  }

  /// Get subscription services by duration (Monthly/Yearly)
  Future<List<ServicePricingModel>> getSubscriptionServices(
    String duration,
  ) async {
    try {
      final response = await _supabase
          .from('service_pricing')
          .select()
          .eq('plan_type', duration)
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return (response as List)
          .map((p) => ServicePricingModel.fromJson(p))
          .toList();
    } catch (e) {
      throw Exception('Failed to load subscription services: $e');
    }
  }

  /// Get all services by plan type (including inactive) for admin
  Future<List<ServicePricingModel>> getAllServicesByPlanType(
    String planType,
  ) async {
    try {
      final response = await _supabase
          .from('service_pricing')
          .select()
          .eq('plan_type', planType)
          .order('display_order', ascending: true);

      return (response as List)
          .map((p) => ServicePricingModel.fromJson(p))
          .toList();
    } catch (e) {
      throw Exception('Failed to load services: $e');
    }
  }

  /// Create a new service
  Future<ServicePricingModel> createService(ServicePricingModel service) async {
    try {
      final json = service.toJson();
      // Remove id if it's empty to let Supabase auto-generate
      if (json['id'] == null || (json['id'] as String).isEmpty) {
        json.remove('id');
      }

      final response = await _supabase
          .from('service_pricing')
          .insert(json)
          .select()
          .single();

      return ServicePricingModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create service: $e');
    }
  }

  /// Update an existing service
  Future<ServicePricingModel> updateService(ServicePricingModel service) async {
    try {
      final response = await _supabase
          .from('service_pricing')
          .update(service.toJson())
          .eq('id', service.id)
          .select()
          .single();

      return ServicePricingModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update service: $e');
    }
  }

  /// Delete a service
  Future<void> deleteService(String serviceId) async {
    try {
      await _supabase.from('service_pricing').delete().eq('id', serviceId);
    } catch (e) {
      throw Exception('Failed to delete service: $e');
    }
  }

  /// Toggle active status of a service
  Future<void> toggleServiceActive(String serviceId, bool isActive) async {
    try {
      await _supabase
          .from('service_pricing')
          .update({'is_active': isActive})
          .eq('id', serviceId);
    } catch (e) {
      throw Exception('Failed to update service status: $e');
    }
  }

  Future<void> updatePricingBatch(List<ServicePricingModel> pricingList) async {
    for (var pricing in pricingList) {
      await _supabase
          .from('service_pricing')
          .update(pricing.toJson())
          .eq('id', pricing.id);
    }
  }

  Future<CustomerDetailModel> getCustomerDetail(String userId) async {
    // In a real app, this would be a join or multiple queries
    // For now, returning a mock that matches the blueprint
    return CustomerDetailModel(
      id: userId,
      name: 'Alexander Rossi',
      joinDate: DateTime(2022),
      status: 'Active',
      totalSpend: 1240,
      totalVisits: 48,
      averageRating: 4.9,
      vehicles: [
        VehicleModel(
          id: '1',
          userId: userId,
          model: 'Porsche 911 GT3',
          licensePlate: 'AB-1234',
          color: 'Shark Blue',
          isPrimary: true,
        ),
        VehicleModel(
          id: '2',
          userId: userId,
          model: 'Audi RS6 Avant',
          licensePlate: 'DE-5678',
          color: 'Nardo Gray',
        ),
      ],
      activeTickets: [
        SupportTicketModel(
          id: 'TKT-9021',
          type: 'Service Delay',
          description: 'Customer reported excessive wait time for...',
          priority: 'HIGH',
        ),
      ],
      recentPayments: [
        PaymentRecordModel(
          id: 'P1',
          serviceName: 'Ultimate Detailing Pkg',
          date: DateTime(2023, 10, 12),
          amount: 249.00,
        ),
        PaymentRecordModel(
          id: 'P2',
          serviceName: 'Ceramic Coating Renewal',
          date: DateTime(2023, 9, 15),
          amount: 850.00,
        ),
      ],
    );
  }

  Future<List<BookingSlotModel>> getDailyBookings(DateTime date) async {
    return [
      BookingSlotModel(
        id: 'CW-8821',
        customerName: 'Johnathan Doe',
        carModel: 'Lexus RX 350',
        carColor: 'Silver',
        serviceType: 'Full Interior Detail',
        startTime: DateTime(date.year, date.month, date.day, 9, 0),
        durationMinutes: 60,
        status: BookingStatus.pending,
      ),
      BookingSlotModel(
        id: 'CW-8822',
        customerName: 'Sarah Jenkins',
        carModel: 'Tesla Model S',
        carColor: 'White',
        serviceType: 'Ceramic Protection',
        startTime: DateTime(date.year, date.month, date.day, 9, 45),
        durationMinutes: 45,
        status: BookingStatus.inProgress,
        bayNumber: 'Bay 3',
      ),
      BookingSlotModel(
        id: 'CW-8819',
        customerName: 'Michael Ross',
        carModel: 'BMW M4',
        carColor: 'Black',
        serviceType: 'Express Exterior',
        startTime: DateTime(date.year, date.month, date.day, 8, 15),
        durationMinutes: 30,
        status: BookingStatus.completed,
      ),
    ];
  }
}
