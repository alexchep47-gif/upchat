import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/media_helper.dart';
import '../../data/models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/nearby_provider.dart';
import '../../widgets/empty_state.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String peerName;
  final String peerId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.peerName,
    required this.peerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _sentTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final endpointId = _resolveEndpointId();
      context.read<ChatProvider>().markAsRead(
            widget.conversationId,
            endpointId: endpointId,
          );
    });
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_sentTyping) {
      final endpointId = _resolveEndpointId();
      if (endpointId != null) {
        context.read<ChatProvider>().sendTyping(endpointId, false);
      }
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? _resolveEndpointId() {
    final nearby = context.read<NearbyProvider>();
    for (final entry in nearby.connectedEndpoints.entries) {
      if (entry.value == widget.peerId) return entry.key;
    }
    return widget.peerId;
  }

  void _onTextChanged() {
    final endpointId = _resolveEndpointId();
    if (endpointId == null) return;

    if (_controller.text.isNotEmpty && !_sentTyping) {
      context.read<ChatProvider>().sendTyping(endpointId, true);
      _sentTyping = true;
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_sentTyping) {
        context.read<ChatProvider>().sendTyping(endpointId, false);
        _sentTyping = false;
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final endpointId = _resolveEndpointId();
    context.read<ChatProvider>().sendTextMessage(
          conversationId: widget.conversationId,
          text: text,
          endpointId: endpointId,
        );

    if (_sentTyping && endpointId != null) {
      context.read<ChatProvider>().sendTyping(endpointId, false);
      _sentTyping = false;
    }

    _controller.clear();
    _scrollToBottom();
  }

  void _pickAndSendMedia() {
    MediaHelper.showMediaPicker(
      context: context,
      onPicked: (path, type) {
        final msgType = type == 'image'
            ? MessageType.image
            : type == 'video'
                ? MessageType.video
                : MessageType.file;

        context.read<ChatProvider>().sendMediaMessage(
              conversationId: widget.conversationId,
              mediaPath: path,
              type: msgType,
              endpointId: _resolveEndpointId(),
            );
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesFor(widget.conversationId);
    final peerTyping = chat.isTyping(widget.peerId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName, style: const TextStyle(fontSize: 17)),
            Text(
              peerTyping ? 'en train d\'écrire…' : 'à proximité',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                fontStyle: peerTyping ? FontStyle.italic : FontStyle.normal,
                color: peerTyping ? AppColors.accent : null,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Conversation chiffrée',
                    subtitle:
                        'Les messages sont stockés uniquement sur cet appareil.\nIls seront envoyés dès que le contact est à portée.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _AnimatedBubble(
                        message: messages[index],
                        isDark: isDark,
                      );
                    },
                  ),
          ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _pickAndSendMedia,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      key: ValueKey(_controller.text.trim().isNotEmpty),
                      onTap: () {
                        if (_controller.text.trim().isNotEmpty) {
                          _sendMessage();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notes vocales bientôt disponibles'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller.text.trim().isNotEmpty
                              ? Icons.send_rounded
                              : Icons.mic,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
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
}

class _AnimatedBubble extends StatelessWidget {
  final MessageModel message;
  final bool isDark;

  const _AnimatedBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('HH:mm').format(message.createdAt);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(isMe ? 20 * (1 - value) : -20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? (isDark ? AppColors.bubbleMeDark : AppColors.bubbleMe)
                : (isDark ? AppColors.bubbleOtherDark : AppColors.bubbleOther),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMe ? 14 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.type == MessageType.image && message.mediaPath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: kIsWeb
                      ? Container(
                          height: 180,
                          width: 220,
                          color: Colors.black26,
                          child: const Icon(Icons.image, size: 48),
                        )
                      : Image.file(
                          File(message.mediaPath!),
                          height: 180,
                          width: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            width: 180,
                            color: Colors.black26,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                ),
                const SizedBox(height: 4),
              ],
              if (message.type == MessageType.audio)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_filled, color: AppColors.primary, size: 36),
                    const SizedBox(width: 8),
                    Text(
                      'Note vocale',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              else if (message.type == MessageType.text)
                Text(
                  message.content,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.3,
                  ),
                )
              else if (message.type == MessageType.video)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _StatusIcon(status: message.status, isDark: isDark),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final bool isDark;

  const _StatusIcon({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = isDark ? Colors.white38 : Colors.black38;
        break;
      case MessageStatus.sent:
        icon = Icons.done;
        color = isDark ? Colors.white54 : Colors.black45;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = isDark ? Colors.white54 : Colors.black45;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF53BDEB); // bleu WhatsApp
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
    }

    return Icon(icon, size: 14, color: color);
  }
}
