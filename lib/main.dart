import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_glass.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'data/services/storage_service.dart';
import 'data/services/firebase_auth_service.dart';
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
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  ));
  runApp(const AppBootstrap());
}

/// Initialise uniquement le stockage local (obligatoire).
/// Firebase est optionnel et ne bloque jamais le démarrage.
Future<void> _initializeLocalOnly() async {
  await Hive.initFlutter();
  await StorageService.init();
  if (StorageService.autoCleanup) {
    unawaited(CleanupService().run());
  }
}

/// Tente Firebase en arrière-plan (timeout court, erreurs ignorées).
Future<void> _warmUpFirebaseInBackground() async {
  try {
    await FirebaseAuthService.instance
        .initialize()
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // Hors ligne / config absente / réseau lent : OK.
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
    _initialization = _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Chemin critique : stockage local uniquement.
    await _initializeLocalOnly();
    // Firebase en best-effort, ne doit pas faire échouer le Future.
    unawaited(_warmUpFirebaseInBackground());
  }

  void _retry() {
    setState(() => _initialization = _bootstrap());
  }

  void _continueOffline() {
    // Force l’affichage de l’app même si l’init locale a échoué une fois
    // (cas extrême). L’utilisateur peut au moins ouvrir l’UI.
    setState(() {
      _initialization = Future<void>.value();
    });
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
          return _StartupError(
            error: snapshot.error,
            onRetry: _retry,
            onContinueOffline: _continueOffline,
          );
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
        backgroundColor: AppColors.backgroundLight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7FBFF), Color(0xFFE7F5FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.82, end: 1),
                    duration: const Duration(milliseconds: 800),
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
                          color: AppColors.textPrimaryLight,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Messagerie privée — mode local',
                        style: TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 13,
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
      ),
    );
  }
}

class _StartupLogo extends StatelessWidget {
  const _StartupLogo();
  @override
  Widget build(BuildContext context) {
    final size =
        (MediaQuery.sizeOf(context).shortestSide * 0.72).clamp(260.0, 300.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 34,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/upchat_u_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onContinueOffline;

  const _StartupError({
    required this.error,
    required this.onRetry,
    required this.onContinueOffline,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: AppColors.primary, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Préparation locale interrompue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Firebase n’est pas requis pour démarrer.\n'
                  'Tu peux continuer en mode hors ligne.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onContinueOffline,
                  icon: const Icon(Icons.wifi_off_rounded),
                  label: const Text('Continuer hors ligne'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
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

  ThemeData _withGlass(ThemeData base, SettingsProvider settings) {
    final glass = (base.extension<AppGlass>() ?? AppGlass.light)
        .withBlurEnabled(!settings.lowDataMode);
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[glass],
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: settings.transparentToolbar
            ? Colors.transparent
            : base.colorScheme.surface,
      ),
    );
  }

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
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, themeProvider, settings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: _withGlass(AppTheme.lightTheme, settings),
            darkTheme: _withGlass(AppTheme.darkTheme, settings),
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              final overlay = Theme.of(context).appBarTheme.systemOverlayStyle ??
                  SystemUiOverlayStyle.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay.copyWith(
                  systemNavigationBarContrastEnforced: false,
                  systemStatusBarContrastEnforced: false,
                ),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(settings.chatFontScale),
                  ),
                  child: child ?? const SizedBox.shrink(),
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
