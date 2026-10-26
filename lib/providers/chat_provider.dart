import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../data/mock_data.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatThread> _threads = List.from(MockData.initialThreads);

  List<ChatThread> get threads => List.unmodifiable(_threads);

  int get unreadMessagesCount {
    return _threads.fold(0, (sum, t) => sum + t.unreadCount);
  }

  ChatThread? getThread(String threadId) {
    try {
      return _threads.firstWhere((t) => t.id == threadId);
    } catch (_) {
      return null;
    }
  }

  ChatThread getOrCreateThreadForShop(String shopId, String shopName, String shopAvatar) {
    final existing = _threads.indexWhere((t) => t.shopId == shopId);
    if (existing != -1) {
      return _threads[existing];
    }
    final newThread = ChatThread(
      id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      shopName: shopName,
      shopAvatar: shopAvatar,
      lastMessage: 'Bắt đầu cuộc trò chuyện với $shopName',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      messages: [],
    );
    _threads.insert(0, newThread);
    notifyListeners();
    return newThread;
  }

  void sendMessage(
    String threadId,
    String text, {
    String? attachedRacketName,
    String? attachedTension,
  }) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _threads[index];
      final newMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'user',
        text: text,
        timestamp: DateTime.now(),
        isFromUser: true,
        attachedRacketName: attachedRacketName,
        attachedTension: attachedTension,
      );

      final updatedMessages = List<ChatMessage>.from(thread.messages)..add(newMsg);
      _threads[index] = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        messages: updatedMessages,
      );
      notifyListeners();

      // Simulated auto-reply from shop stringer after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        final currentIdx = _threads.indexWhere((t) => t.id == threadId);
        if (currentIdx != -1) {
          final curThread = _threads[currentIdx];
          final replyMsg = ChatMessage(
            id: 'msg_reply_${DateTime.now().millisecondsSinceEpoch}',
            senderId: curThread.shopId,
            text: 'Cảm ơn anh! Kỹ thuật viên của ${curThread.shopName} đã nhận thông tin. Anh có thể ghé shop hoặc đặt lịch trên app để được ưu tiên lên máy sớm nhất nhé!',
            timestamp: DateTime.now(),
            isFromUser: false,
          );
          final msgs = List<ChatMessage>.from(curThread.messages)..add(replyMsg);
          _threads[currentIdx] = ChatThread(
            id: curThread.id,
            shopId: curThread.shopId,
            shopName: curThread.shopName,
            shopAvatar: curThread.shopAvatar,
            lastMessage: replyMsg.text,
            lastMessageTime: DateTime.now(),
            unreadCount: 1,
            messages: msgs,
          );
          notifyListeners();
        }
      });
    }
  }

  void markThreadAsRead(String threadId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1 && _threads[index].unreadCount > 0) {
      final thread = _threads[index];
      _threads[index] = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: thread.lastMessage,
        lastMessageTime: thread.lastMessageTime,
        unreadCount: 0,
        messages: thread.messages,
      );
      notifyListeners();
    }
  }
}
