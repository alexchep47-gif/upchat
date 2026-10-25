import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'data/services/storage_service.dart';
import 'data/services/cleanup_service.dart';
import 'providers/theme_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/nearby_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/stories_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const AppBootstrap());
}

Future<void> _initializeApp() async {
  if (kIsWeb) {
    // Hive.initFlutter() relies on the platform path provider and can remain
    // pending in browsers. Hive's Web backend does not need a filesystem path.
    Hive.init('upchat_web');
  } else {
    await Hive.initFlutter();
  }
  await StorageService.init();
  if (StorageService.autoCleanup) {
    unawaited(CleanupService().run());
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeApp();
  }

  void _retry() {
    setState(() => _initialization = _initializeApp());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupScreen();
        }
        if (snapshot.hasError) {
          return _StartupError(error: snapshot.error, onRetry: _retry);
        }
        return const UpChatApp();
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: const _StartupLogo(),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 32,
                child: Column(
                  children: [
                    const Text(
                      'UpChat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Messagerie privée',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.42),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 116,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Color(0x332AABEE),
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupLogo extends StatelessWidget {
  const _StartupLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 116,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2AABEE).withOpacity(0.28),
            blurRadius: 34,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/upchat_u_icon.png',
          width: 116,
          height: 116,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _StartupError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Colors.white70, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Impossible de préparer UpChat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpChatApp extends StatelessWidget {
  const UpChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => NearbyProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => StoriesProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final settings = context.watch<SettingsProvider>();
          final lightTheme = AppTheme.lightTheme.copyWith(
            appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
              backgroundColor: settings.transparentToolbar
                  ? Colors.transparent
                  : AppTheme.lightTheme.colorScheme.surface,
            ),
          );
          final darkTheme = AppTheme.darkTheme.copyWith(
            appBarTheme: AppTheme.darkTheme.appBarTheme.copyWith(
              backgroundColor: settings.transparentToolbar
                  ? Colors.transparent
                  : AppTheme.darkTheme.colorScheme.surface,
            ),
          );
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final overlayStyle =
                  Theme.of(context).appBarTheme.systemOverlayStyle ??
                      SystemUiOverlayStyle.dark;
              final mediaQuery = MediaQuery.of(context);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(settings.chatFontScale),
                  ),
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SizedBox.expand(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
            initialRoute: AppRouter.initialRoute,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
