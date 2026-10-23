import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/media_helper.dart';
import '../../data/models/story_model.dart';
import '../../providers/stories_provider.dart';

/// Création d'une story (texte / photo / vidéo)
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final TextEditingController _textController = TextEditingController();
  String? _mediaPath;
  StoryType _type = StoryType.text;
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaPath == null) return;

    setState(() => _sending = true);

    await context.read<StoriesProvider>().createStory(
          type: _type,
          content: text.isEmpty ? (_type == StoryType.image ? '📷' : '🎬') : text,
          mediaPath: _mediaPath,
        );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story publiée (24 h)')),
      );
    }
  }

  void _pickMedia() {
    MediaHelper.showMediaPicker(
      context: context,
      onPicked: (path, type) {
        setState(() {
          _mediaPath = path;
          _type = type == 'image' ? StoryType.image : StoryType.video;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Nouvelle story'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _publish,
            child: Text(
              _sending ? '…' : 'Publier',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _mediaPath != null && !kIsWeb
                  ? Image.file(
                      File(_mediaPath!),
                      fit: BoxFit.contain,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: TextField(
                        controller: _textController,
                        maxLines: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Écris quelque chose…',
                          hintStyle: TextStyle(color: Colors.white54, fontSize: 22),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                    onPressed: _pickMedia,
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_fields, color: Colors.white, size: 32),
                    onPressed: () {
                      setState(() {
                        _mediaPath = null;
                        _type = StoryType.text;
                      });
                    },
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
