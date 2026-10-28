import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final threads = chatProvider.threads;
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin Nhắn & Tư Vấn Thợ Đan'),
      ),
      body: threads.isEmpty
          ? const Center(
              child: Text(
                'Chưa có cuộc trò chuyện nào.\nHãy vào trang Chi Tiết Shop để nhắn tin tư vấn!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: threads.length,
              itemBuilder: (context, idx) {
                final thread = threads[idx];
                return InkWell(
                  onTap: () {
                    chatProvider.markThreadAsRead(thread.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatConversationScreen(threadId: thread.id),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: thread.unreadCount > 0
                            ? AppTheme.primary.withOpacity(0.4)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryDark),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.primaryDark,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.shopName,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: thread.unreadCount > 0
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    timeFormat.format(thread.lastMessageTime),
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                thread.lastMessage,
                                style: TextStyle(
                                  color: thread.unreadCount > 0
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: thread.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (thread.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final String threadId;
  final bool isShopOwner;

  const ChatConversationScreen({
    super.key,
    required this.threadId,
    this.isShopOwner = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _timeFormat = DateFormat('HH:mm');

  List<String> get _quickReplies => widget.isShopOwner
      ? [
          'Vợt của bạn đã đan xong rồi nhé! Bạn có thể ghé shop lấy.',
          'Shop đang tiến hành đan cước cho bạn ạ.',
          'Dạ shop còn cước BG66 Ultimax và Exbolt 65 ạ.',
          'Bạn cần đặt lịch vào khung giờ nào ạ?',
        ]
      : [
          'Vợt thân cứng nên đan Exbolt 65 hay BG66UM?',
          'Shop có nhận đan lấy liền trong 20 phút không?',
          'Em muốn căng 4 nút kẹp đôi chuẩn Yonex ạ.',
        ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? quickText}) {
    final text = quickText ?? _msgController.text.trim();
    if (text.isEmpty) return;

    if (widget.isShopOwner) {
      context.read<ChatProvider>().sendMessageAsShop(widget.threadId, text);
    } else {
      context.read<ChatProvider>().sendMessage(widget.threadId, text);
    }
    if (quickText == null) _msgController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final thread = chatProvider.getThread(widget.threadId);

    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuộc trò chuyện')),
        body: const Center(child: Text('Không tìm thấy cuộc trò chuyện')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isShopOwner ? 'Tư Vấn Khách Hàng' : thread.shopName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Icon(Icons.circle, color: AppTheme.primary, size: 8),
                const SizedBox(width: 4),
                Text(
                  widget.isShopOwner
                      ? 'Khách hàng quan tâm đan vợt'
                      : 'Kỹ thuật viên đang trực tuyến',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: thread.messages.length,
              itemBuilder: (context, idx) {
                final msg = thread.messages[idx];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Quick Prompt Suggestions
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickReplies.length,
              itemBuilder: (context, idx) {
                final prompt = _quickReplies[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    backgroundColor: AppTheme.surfaceLight,
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onPressed: () => _sendMessage(quickText: prompt),
                  ),
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: widget.isShopOwner
                            ? 'Nhập tin nhắn phản hồi cho khách hàng...'
                            : 'Nhắn tin hỏi kỹ thuật viên về mức căng, dây cước...',
                        hintStyle: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // If shop owner: shop owner's own message is !msg.isFromUser
    // If player: player's own message is msg.isFromUser
    final isMe = widget.isShopOwner ? !msg.isFromUser : msg.isFromUser;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.attachedRacketName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sports_tennis_rounded,
                      size: 12,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${msg.attachedRacketName} (${msg.attachedTension})',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.black : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeFormat.format(msg.timestamp),
              style: TextStyle(
                color: isMe ? Colors.black54 : AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
