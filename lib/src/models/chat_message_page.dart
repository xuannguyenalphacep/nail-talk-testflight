import 'chat_message.dart';

class ChatMessagePage {
  ChatMessagePage({
    required this.messages,
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });

  final List<ChatMessage> messages;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
}
