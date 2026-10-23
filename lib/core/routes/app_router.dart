import 'package:flutter/material.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/conversations_list_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/groups/create_group_screen.dart';
import '../../features/stories/create_story_screen.dart';
import '../../features/stories/story_viewer_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Gestion centralisée des routes de l'application
class AppRouter {
  static const String initialRoute = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String createGroup = '/create-group';
  static const String createStory = '/create-story';
  static const String storyViewer = '/story-viewer';
  static const String profile = '/profile';
  static const String settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initialRoute:
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const ConversationsListScreen());

      case chat:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: args?['conversationId'] as String? ?? '',
            peerName: args?['peerName'] as String? ?? 'Contact',
            peerId: args?['peerId'] as String? ?? '',
          ),
        );

      case createGroup:
        return MaterialPageRoute(builder: (_) => const CreateGroupScreen());

      case createStory:
        return MaterialPageRoute(builder: (_) => const CreateStoryScreen());

      case storyViewer:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => StoryViewerScreen(
            userId: args?['userId'] as String? ?? '',
            initialIndex: args?['initialIndex'] as int? ?? 0,
          ),
        );

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());

      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page introuvable')),
          ),
        );
    }
  }
}
