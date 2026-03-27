import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/chat_model.dart';

class ChatRepository {
  final _client = Supabase.instance.client;

  Stream<List<SupportMessageModel>> getMessagesStream(String userId) {
    return _client
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map(
          (data) =>
              data.map((json) => SupportMessageModel.fromJson(json)).toList(),
        );
  }

  Future<void> sendMessage(SupportMessageModel message) async {
    await _client.from('support_messages').insert(message.toJson());
  }

  Future<List<SupportMessageModel>> getMessageHistory(String userId) async {
    final response = await _client
        .from('support_messages')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    return (response as List)
        .map((json) => SupportMessageModel.fromJson(json))
        .toList();
  }
}
