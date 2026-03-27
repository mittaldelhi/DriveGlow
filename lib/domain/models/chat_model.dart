class SupportMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final bool isFromSupport;

  SupportMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.message,
    required this.createdAt,
    this.isFromSupport = false,
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'],
      chatId: json['chat_id'],
      senderId: json['sender_id'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      isFromSupport: json['is_from_support'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'is_from_support': isFromSupport,
    };
  }
}
