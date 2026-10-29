import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glass.dart';
import '../../core/utils/media_helper.dart';
import '../../data/models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/nearby_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_container.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _sentTyping = false;
  bool _searching = false;
  String _searchQuery = '';
  bool _showScrollDown = false;

  static const _quickEmojis = ['👍', '❤️', '🔥', '😂', '😮', '😢', '👏', '🎉'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markAsRead(
            widget.conversationId,
            endpointId: _resolveEndpointId(),
          );
    });
    _controller.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_sentTyping) {
      final id = _resolveEndpointId();
      if (id != null) context.read<ChatProvider>().sendTyping(id, false);
    }
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final show = max - _scrollController.offset > 180;
    if (show != _showScrollDown) setState(() => _showScrollDown = show);
  }

  String? _resolveEndpointId() {
    final nearby = context.read<NearbyProvider>();
    for (final e in nearby.connectedEndpoints.entries) {
      if (e.value == widget.peerId) return e.key;
    }
    return widget.peerId;
  }

  void _onTypingChanged() {
    final endpointId = _resolveEndpointId();
    if (endpointId == null) return;
    if (context.read<SettingsProvider>().typingIndicators &&
        _controller.text.isNotEmpty &&
        !_sentTyping) {
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
    setState(() {});
    _scrollToBottom();
  }

  void _sendEmoji(String emoji) {
    context.read<ChatProvider>().sendTextMessage(
          conversationId: widget.conversationId,
          text: emoji,
          endpointId: _resolveEndpointId(),
        );
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
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _openContact() async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.contactDetail,
      arguments: {
        'conversationId': widget.conversationId,
        'peerName': widget.peerName,
        'peerId': widget.peerId,
      },
    );
    if (result == 'search' && mounted) {
      setState(() {
        _searching = true;
        _searchQuery = '';
      });
    }
  }

  Future<void> _clearMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer cette conversation ?'),
        content: const Text(
            'Les messages seront supprimés de cet appareil. Action irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Effacer')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context
          .read<ChatProvider>()
          .clearConversationMessages(widget.conversationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final bottomSafe = media.viewPadding.bottom;
    // Le Scaffold ne redimensionne pas le body : les viewInsets déplacent donc
    // la saisie une seule fois, y compris lorsque le clavier Safari s’anime.
    final inputBottomPad =
        bottomInset > 0 ? bottomInset : (bottomSafe > 0 ? bottomSafe : 8.0);

    final messages = chat.messagesFor(widget.conversationId);
    final visible = _searchQuery.trim().isEmpty
        ? messages
        : messages
            .where((m) =>
                m.content.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
            .toList();
    final peerTyping = chat.isTyping(widget.peerId);
    final forceOpaque = settings.lowDataMode || !glass.enableBlur;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: glass.chatGradientTop,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [glass.chatGradientTop, glass.chatGradientBottom],
            ),
          ),
          child: Stack(
            children: [
              // Liste messages — padding pour passer sous header / saisie
              Positioned.fill(
                child: visible.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(
                          top: media.padding.top + 12,
                          bottom: 120 + inputBottomPad,
                        ),
                        child: const EmptyState(
                          icon: Icons.lock_outline_rounded,
                          title: 'Conversation sécurisée 🔒',
                          subtitle:
                              'Les messages restent sur cet appareil.\nIls partent dès que le contact est à portée.',
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: media.padding.top + 12,
                          bottom: 120 + inputBottomPad,
                        ),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final msg = visible[index];
                          final showDate = index == 0 ||
                              !_sameDay(
                                  visible[index - 1].createdAt, msg.createdAt);
                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: GlassSurface(
                                    forceOpaque: forceOpaque,
                                    blur: glass.blurChip,
                                    borderRadius: BorderRadius.circular(14),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    child: Text(
                                      _dateLabel(msg.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ),
                                ),
                              _MessageBubble(
                                message: msg,
                                isDark: isDark,
                                glass: glass,
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // En-tête flottant pastilles de verre
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: _searching
                        ? GlassSurface(
                            forceOpaque: forceOpaque,
                            blur: glass.blurHeader,
                            borderRadius: BorderRadius.circular(22),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v),
                                    decoration: const InputDecoration(
                                      hintText: 'Rechercher…',
                                      border: InputBorder.none,
                                      filled: false,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () => setState(() {
                                    _searching = false;
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            children: [
                              GlassSurface(
                                forceOpaque: forceOpaque,
                                blur: glass.blurHeader,
                                borderRadius: BorderRadius.circular(22),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _openContact,
                                  child: GlassSurface(
                                    forceOpaque: forceOpaque,
                                    blur: glass.blurHeader,
                                    borderRadius: BorderRadius.circular(22),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.peerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        Text(
                                          peerTyping ? 'écrit…' : 'à proximité',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontStyle: peerTyping
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            color: peerTyping
                                                ? AppColors.primary
                                                : (isDark
                                                    ? AppColors
                                                        .textSecondaryDark
                                                    : AppColors
                                                        .textSecondaryLight),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _openContact,
                                child: GlassSurface(
                                  forceOpaque: forceOpaque,
                                  blur: glass.blurHeader,
                                  borderRadius: BorderRadius.circular(24),
                                  padding: const EdgeInsets.all(3),
                                  child: Hero(
                                    tag: 'avatar_${widget.peerId}',
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.22),
                                      child: Text(
                                        widget.peerName.isNotEmpty
                                            ? widget.peerName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GlassSurface(
                                forceOpaque: forceOpaque,
                                blur: glass.blurHeader,
                                borderRadius: BorderRadius.circular(22),
                                child: PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'search') {
                                      setState(() => _searching = true);
                                    } else if (v == 'clear') {
                                      _clearMessages();
                                    } else if (v == 'info') {
                                      _openContact();
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'search',
                                        child: Text('Rechercher')),
                                    PopupMenuItem(
                                        value: 'info',
                                        child: Text('Fiche contact')),
                                    PopupMenuItem(
                                        value: 'clear',
                                        child: Text('Effacer messages')),
                                  ],
                                  icon: const Icon(Icons.more_vert_rounded),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              if (_showScrollDown)
                Positioned(
                  right: 16,
                  bottom: 100 + inputBottomPad,
                  child: GlassSurface(
                    forceOpaque: forceOpaque,
                    blur: 14,
                    borderRadius: BorderRadius.circular(22),
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: _scrollToBottom,
                    ),
                  ),
                ),

              // Saisie flottante + emojis
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: inputBottomPad),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.text.isEmpty)
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _quickEmojis.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _sendEmoji(_quickEmojis[i]),
                              child: GlassSurface(
                                forceOpaque: forceOpaque,
                                blur: glass.blurChip,
                                borderRadius: BorderRadius.circular(20),
                                padding: const EdgeInsets.all(8),
                                child: Text(_quickEmojis[i],
                                    style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: GlassSurface(
                          forceOpaque: forceOpaque,
                          blur: glass.blurInput,
                          borderRadius: BorderRadius.circular(26),
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Joindre',
                                onPressed: _pickAndSendMedia,
                                icon: Icon(
                                  Icons.attach_file_rounded,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  maxLines: 5,
                                  minLines: 1,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onChanged: (_) => _onTypingChanged(),
                                  decoration: const InputDecoration(
                                    hintText: 'Message',
                                    border: InputBorder.none,
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 4, bottom: 2),
                                child: Material(
                                  color: AppColors.primary,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      if (_controller.text.trim().isNotEmpty) {
                                        _sendMessage();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                '🎤 Notes vocales bientôt'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(11),
                                      child: Icon(
                                        _controller.text.trim().isNotEmpty
                                            ? Icons.send_rounded
                                            : Icons.mic_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return "Aujourd'hui";
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier';
    return DateFormat('d MMMM y', 'fr_FR').format(d);
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isDark;
  final AppGlass glass;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.glass,
  });

  bool get _onlyEmoji {
    final t = message.content.trim();
    if (t.isEmpty || message.type != MessageType.text) return false;
    return !RegExp(r'[a-zA-Z0-9àâäéèêëïîôùûüç]').hasMatch(t) &&
        t.runes.length <= 6;
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('HH:mm').format(message.createdAt);
    final onlyEmoji = _onlyEmoji;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: onlyEmoji
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(message.content,
                        style: const TextStyle(fontSize: 48, height: 1.1)),
                    Text(time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        )),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                decoration: BoxDecoration(
                  color: isMe ? glass.bubbleMe : glass.bubbleOther,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 5),
                    bottomRight: Radius.circular(isMe ? 5 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (message.type == MessageType.image &&
                        message.mediaPath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Container(
                                height: 160,
                                width: 200,
                                color: Colors.black26,
                                child: const Icon(Icons.image, size: 40),
                              )
                            : Image.file(
                                File(message.mediaPath!),
                                height: 160,
                                width: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 100,
                                  width: 160,
                                  color: Colors.black26,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (message.type == MessageType.text)
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          fontSize: 15.5,
                          height: 1.35,
                        ),
                      )
                    else if (message.type == MessageType.audio)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_filled,
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 8),
                          Text('Note vocale',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87)),
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
                            color: isDark
                                ? Colors.white38
                                : Colors.black.withOpacity(0.35),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
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
    String label;
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.schedule_rounded;
        color = isDark ? Colors.white30 : Colors.black26;
        label = 'Message en attente d’envoi';
        break;
      case MessageStatus.sent:
        icon = Icons.done_rounded;
        color = isDark ? Colors.white54 : Colors.black38;
        label = 'Message accepté par le relais';
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = isDark ? Colors.white54 : Colors.black38;
        label = 'Message livré';
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = AppColors.primary; // bleu, jamais vert
        label = 'Message lu';
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        label = 'Échec de l’envoi';
        break;
    }
    return Semantics(
      label: label,
      child: Icon(icon, size: 15, color: color),
    );
  }
}
