import 'vehicle_model.dart';

class CustomerDetailModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final DateTime joinDate;
  final String status; // e.g. 'Active', 'Inactive'
  final double totalSpend;
  final int totalVisits;
  final double averageRating;
  final List<VehicleModel> vehicles;
  final List<SupportTicketModel> activeTickets;
  final List<PaymentRecordModel> recentPayments;

  CustomerDetailModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.joinDate,
    required this.status,
    required this.totalSpend,
    required this.totalVisits,
    required this.averageRating,
    required this.vehicles,
    required this.activeTickets,
    required this.recentPayments,
  });
}

class SupportTicketModel {
  final String id;
  final String type; // e.g. 'Service Delay'
  final String description;
  final String priority; // e.g. 'HIGH'

  SupportTicketModel({
    required this.id,
    required this.type,
    required this.description,
    required this.priority,
  });
}

class PaymentRecordModel {
  final String id;
  final String serviceName;
  final DateTime date;
  final double amount;

  PaymentRecordModel({
    required this.id,
    required this.serviceName,
    required this.date,
    required this.amount,
  });
}
