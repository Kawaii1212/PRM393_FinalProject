class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isFromUser;
  final String? attachedRacketName;
  final String? attachedTension;
  final bool isSystemNotice;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isFromUser,
    this.attachedRacketName,
    this.attachedTension,
    this.isSystemNotice = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFromUser': isFromUser,
      'attachedRacketName': attachedRacketName,
      'attachedTension': attachedTension,
      'isSystemNotice': isSystemNotice,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isFromUser: map['isFromUser'] == true,
      attachedRacketName: map['attachedRacketName']?.toString(),
      attachedTension: map['attachedTension']?.toString(),
      isSystemNotice: map['isSystemNotice'] == true,
    );
  }
}

class ChatThread {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String shopId;
  final String? shopOwnerUid;
  final String shopName;
  final String shopAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final List<ChatMessage> messages;

  ChatThread({
    required this.id,
    this.userId = '',
    this.userName,
    this.userEmail,
    required this.shopId,
    this.shopOwnerUid,
    required this.shopName,
    required this.shopAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    required this.messages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'shopId': shopId,
      'shopOwnerUid': shopOwnerUid,
      'shopName': shopName,
      'shopAvatar': shopAvatar,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'messages': messages.map((m) => m.toMap()).toList(),
    };
  }

  factory ChatThread.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ChatThread(
      id: (docId != null && docId.isNotEmpty) ? docId : (map['id']?.toString() ?? ''),
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString(),
      userEmail: map['userEmail']?.toString(),
      shopId: map['shopId']?.toString() ?? '',
      shopOwnerUid: map['shopOwnerUid']?.toString(),
      shopName: map['shopName']?.toString() ?? '',
      shopAvatar: map['shopAvatar']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.tryParse(map['lastMessageTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: (map['unreadCount'] as num?)?.toInt() ?? 0,
      messages: (map['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
    );
  }
}
