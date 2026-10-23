import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/media_helper.dart';
import '../../data/models/message_model.dart';
import '../../data/services/voice_service.dart';
import '../../providers/chat_provider.dart';
import '../../providers/nearby_provider.dart';
import '../../widgets/empty_state.dart';

/// Écran de discussion 1-à-1
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
  final VoiceService _voice = VoiceService();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _player.dispose();
    super.dispose();
  }

  String? _resolveEndpointId() {
    final nearby = context.read<NearbyProvider>();
    for (final entry in nearby.connectedEndpoints.entries) {
      if (entry.value == widget.peerId) return entry.key;
    }
    return widget.peerId;
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<ChatProvider>().sendTextMessage(
          conversationId: widget.conversationId,
          text: text,
          endpointId: _resolveEndpointId(),
        );

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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _voice.stopRecording();
      setState(() => _isRecording = false);

      if (path != null) {
        context.read<ChatProvider>().sendMediaMessage(
              conversationId: widget.conversationId,
              mediaPath: path,
              type: MessageType.audio,
              endpointId: _resolveEndpointId(),
            );
        _scrollToBottom();
      }
    } else {
      final ok = await _voice.startRecording();
      if (ok) {
        setState(() => _isRecording = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission micro refusée ou indisponible')),
          );
        }
      }
    }
  }

  Future<void> _playAudio(String path, String messageId) async {
    if (_playingId == messageId) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }

    await _player.stop();
    await _player.play(DeviceFileSource(path));
    setState(() => _playingId = messageId);

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = context.watch<ChatProvider>().messagesFor(widget.conversationId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName, style: const TextStyle(fontSize: 17)),
            const Text(
              'à proximité',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
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
                      final msg = messages[index];
                      return _MessageBubble(
                        message: msg,
                        isDark: isDark,
                        isPlaying: _playingId == msg.id,
                        onPlayAudio: msg.type == MessageType.audio && msg.mediaPath != null
                            ? () => _playAudio(msg.mediaPath!, msg.id)
                            : null,
                      );
                    },
                  ),
          ),

          // Indicateur enregistrement
          if (_isRecording)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.withOpacity(0.15),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Enregistrement… (relâche pour envoyer)', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
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
                      enabled: !_isRecording,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  // Micro / Stop
                  GestureDetector(
                    onLongPressStart: (_) => _toggleRecording(),
                    onLongPressEnd: (_) {
                      if (_isRecording) _toggleRecording();
                    },
                    onTap: () {
                      if (_isRecording) {
                        _toggleRecording();
                      } else if (_controller.text.trim().isNotEmpty) {
                        _sendMessage();
                      } else {
                        _toggleRecording();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.stop
                            : (_controller.text.trim().isNotEmpty ? Icons.send_rounded : Icons.mic),
                        color: Colors.white,
                        size: 22,
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

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isDark;
  final bool isPlaying;
  final VoidCallback? onPlayAudio;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    this.isPlaying = false,
    this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? (isDark ? AppColors.bubbleMeDark : AppColors.bubbleMe)
              : (isDark ? AppColors.bubbleOtherDark : AppColors.bubbleOther),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Image
            if (message.type == MessageType.image && message.mediaPath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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

            // Audio
            if (message.type == MessageType.audio) ...[
              GestureDetector(
                onTap: onPlayAudio,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: AppColors.primary,
                      size: 36,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPlaying ? 'Lecture…' : 'Note vocale',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Texte / preview
            if (message.type == MessageType.text)
              Text(
                message.content,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
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

            const SizedBox(height: 2),
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
                  Icon(
                    message.status == MessageStatus.read
                        ? Icons.done_all
                        : message.status == MessageStatus.delivered ||
                                message.status == MessageStatus.sent
                            ? Icons.done_all
                            : message.status == MessageStatus.failed
                                ? Icons.error_outline
                                : Icons.access_time,
                    size: 14,
                    color: message.status == MessageStatus.read
                        ? Colors.blue
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
