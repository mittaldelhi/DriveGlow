enum BookingStatus { pending, inProgress, checkedIn, completed }

class BookingSlotModel {
  final String id;
  final String customerName;
  final String? customerAvatar;
  final String carModel;
  final String carColor;
  final String serviceType;
  final DateTime startTime;
  final int durationMinutes;
  final BookingStatus status;
  final String? bayNumber;

  BookingSlotModel({
    required this.id,
    required this.customerName,
    this.customerAvatar,
    required this.carModel,
    required this.carColor,
    required this.serviceType,
    required this.startTime,
    required this.durationMinutes,
    required this.status,
    this.bayNumber,
  });
}
