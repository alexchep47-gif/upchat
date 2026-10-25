import 'dart:async';
import 'dart:io';
import 'dart:ui';
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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _sentTyping = false;
  bool _searching = false;
  String _searchQuery = '';
  bool _showQuickActions = true;

  // Emojis rapides style Telegram
  static const _quickEmojis = ['👍', '❤️', '🔥', '😂', '😮', '😢', '👏', '🎉'];

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
    _searchController.dispose();
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
    setState(() {}); // rebuild pour icône send/mic
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _startSearch() {
    setState(() {
      _searching = true;
      _searchQuery = '';
    });
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _showChatInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.peerName),
        content: SelectableText(
          'Identifiant du contact\n${widget.peerId}\n\n'
          'Les messages restent stockés localement et sont transmis via '
          'les canaux disponibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer cette conversation ?'),
        content: const Text(
          'Les messages seront supprimés de cet appareil. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ChatProvider>().clearConversationMessages(
            widget.conversationId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages effacés')),
        );
      }
    }
  }

  Future<void> _showQuickAction(_ChatAction action) async {
    if (action.id == 'media') {
      _pickAndSendMedia();
      return;
    }
    if (action.id == 'clear') {
      await _clearMessages();
      return;
    }
    if (action.id == 'search') {
      _startSearch();
      return;
    }

    final details = <String, String>{
      'stats': 'Messages locaux : ${context.read<ChatProvider>().messagesFor(widget.conversationId).length}\n\nLes statistiques restent disponibles hors connexion.',
      'tokens': 'UpChat ne consomme aucun token IA pour la messagerie locale. Les échanges passent par les canaux disponibles.',
      'memory': 'Les fichiers et médias reçus sont conservés dans l’espace local sécurisé de cette conversation.',
      'download': 'Le téléchargement de fichiers sera proposé ici dès qu’un fichier est partagé dans cette conversation.',
      'generate': 'Cette action prépare l’interface pour les assistants et bots qui pourront être branchés à UpChat.',
      'editor': 'L’éditeur en ligne est prêt à accueillir un module de code partagé dans la conversation.',
      'system': 'Canal : ${_resolveEndpointId() == null ? 'hors connexion' : 'appareil connecté'}\nChiffrement local : activé',
      'zip': 'La préparation du fichier source est disponible depuis le dépôt du projet. Aucun fichier n’est envoyé automatiquement.',
    };
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${action.icon}  ${action.title}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(details[action.id] ?? action.subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'info':
        _showChatInfo();
        break;
      case 'clear':
        _clearMessages();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesFor(widget.conversationId);
    final visibleMessages = _searchQuery.trim().isEmpty
        ? messages
        : messages
            .where((message) => message.content
                .toLowerCase()
                .contains(_searchQuery.trim().toLowerCase()))
            .toList();
    final peerTyping = chat.isTyping(widget.peerId);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        titleSpacing: 0,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Rechercher dans la conversation',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.peerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            fontStyle: peerTyping
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: peerTyping
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          child: Text(peerTyping ? 'écrit…' : 'à proximité'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: _searching
            ? [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Rechercher',
                  onPressed: _startSearch,
                ),
                PopupMenuButton<String>(
                  onSelected: _handleMenu,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'info',
                      child: ListTile(
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text('Informations'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Effacer les messages'),
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0B0B10), const Color(0xFF1B1520)]
                : [const Color(0xFFF0E8F3), const Color(0xFFE1D8E7)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth > 900
                ? 860.0
                : constraints.maxWidth;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                itemCount: (_showQuickActions ? 1 : 0) +
                    (visibleMessages.isEmpty ? 1 : visibleMessages.length),
                itemBuilder: (context, index) {
                  if (_showQuickActions && index == 0) {
                    return _QuickActionsPanel(
                      isDark: isDark,
                      onAction: _showQuickAction,
                    );
                  }
                  final messageIndex = index - (_showQuickActions ? 1 : 0);
                  if (visibleMessages.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 36),
                      child: EmptyState(
                        icon: Icons.lock_outline_rounded,
                        title: 'Conversation sécurisée 🔒',
                        subtitle:
                            'Les messages restent sur cet appareil.\nIls partent dès que le contact est à portée.',
                      ),
                    );
                  }
                  return _TelegramBubble(
                    message: visibleMessages[messageIndex],
                    isDark: isDark,
                  );
                },
              ),
            ),

            // Barre d'emojis rapides
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _sendEmoji(_quickEmojis[i]),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.surfaceDark : Colors.white)
                            .withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // Zone de saisie glass
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.surfaceDark : Colors.white)
                        .withOpacity(0.82),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Actions rapides',
                          icon: Icon(
                            Icons.bolt_rounded,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          onPressed: () => setState(
                            () => _showQuickActions = !_showQuickActions,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Joindre un média',
                          icon: Icon(
                            Icons.attach_file_rounded,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          onPressed: _pickAndSendMedia,
                        ),
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceElevatedDark.withOpacity(0.9)
                                  : const Color(0xFFF4F4F5),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: TextField(
                              controller: _controller,
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Message',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Material(
                              key: ValueKey(_controller.text.trim().isNotEmpty),
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  if (_controller.text.trim().isNotEmpty) {
                                    _sendMessage();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🎤 Notes vocales bientôt'),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatAction {
  final String id;
  final String icon;
  final String title;
  final String subtitle;

  const _ChatAction(this.id, this.icon, this.title, this.subtitle);
}

class _QuickActionsPanel extends StatelessWidget {
  final bool isDark;
  final ValueChanged<_ChatAction> onAction;

  const _QuickActionsPanel({required this.isDark, required this.onAction});

  static const actions = [
    _ChatAction('stats', '📊', 'Statistiques', 'Voir l’activité'),
    _ChatAction('tokens', '⚡', 'Usage IA', 'Consommation'),
    _ChatAction('memory', '📁', 'Fichiers mémoire', 'Documents partagés'),
    _ChatAction('download', '📦', 'Télécharger', 'Fichiers reçus'),
    _ChatAction('generate', '📄', 'Tester génération', 'Assistant'),
    _ChatAction('editor', '🛠️', 'Éditeur en ligne', 'Code partagé'),
    _ChatAction('system', '🛡️', 'Configuration système', 'État du canal'),
    _ChatAction('zip', '🗜️', 'Préparer un ZIP', 'Source du projet'),
  ];

  @override
  Widget build(BuildContext context) {
    final panel = isDark ? const Color(0xB52D2332) : const Color(0xD9FFFFFF);
    final tile = isDark ? const Color(0xCC3A2F3F) : const Color(0xE6FFFFFF);
    final foreground = isDark ? Colors.white : const Color(0xFF241C2B);
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 8, 2, 10),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(isDark ? .08 : .55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? .24 : .08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                Text(
                  'Actions rapides',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'appuyer pour ouvrir',
                  style: TextStyle(color: foreground.withOpacity(.58), fontSize: 11),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 3.25,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return Material(
                color: tile,
                borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => onAction(action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Text(action.icon, style: const TextStyle(fontSize: 17)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            action.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TelegramBubble extends StatelessWidget {
  final MessageModel message;
  final bool isDark;

  const _TelegramBubble({required this.message, required this.isDark});

  bool get _isOnlyEmoji {
    final t = message.content.trim();
    if (t.isEmpty || message.type != MessageType.text) return false;
    // Heuristique simple : 1–3 caractères / emojis sans lettres
    final noLetters = !RegExp(r'[a-zA-Z0-9àâäéèêëïîôùûüç]').hasMatch(t);
    return noLetters && t.runes.length <= 6;
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final time = DateFormat('HH:mm').format(message.createdAt);
    final onlyEmoji = _isOnlyEmoji;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(isMe ? 12 * (1 - value) : -12 * (1 - value), 4 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
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
                      Text(
                        message.content,
                        style: const TextStyle(fontSize: 48, height: 1.1),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark ? AppColors.bubbleMeDark : AppColors.bubbleMe)
                        : (isDark
                            ? AppColors.bubbleOtherDark.withOpacity(0.92)
                            : AppColors.bubbleOther.withOpacity(0.95)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                        blurRadius: 8,
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
                      if (message.type == MessageType.text)
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 15.5,
                            height: 1.35,
                          ),
                        )
                      else if (message.type == MessageType.audio)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_filled,
                                color: AppColors.primary, size: 34),
                            const SizedBox(width: 8),
                            Text(
                              'Note vocale',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        )
                      else if (message.type == MessageType.video)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_outline, size: 22),
                            const SizedBox(width: 6),
                            Text(message.content),
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
        icon = Icons.schedule_rounded;
        color = isDark ? Colors.white30 : Colors.black26;
        break;
      case MessageStatus.sent:
        icon = Icons.done_rounded;
        color = isDark ? Colors.white54 : Colors.black38;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = isDark ? Colors.white54 : Colors.black38;
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = const Color(0xFF53BDEB);
        break;
      case MessageStatus.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        break;
    }

    return Icon(icon, size: 15, color: color);
  }
}
