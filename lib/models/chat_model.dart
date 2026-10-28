class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isFromUser;
  final String? attachedRacketName;
  final String? attachedTension;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isFromUser,
    this.attachedRacketName,
    this.attachedTension,
  });
}

class ChatThread {
  final String id;
  final String shopId;
  final String shopName;
  final String shopAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final List<ChatMessage> messages;

  ChatThread({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.shopAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    required this.messages,
  });
}
