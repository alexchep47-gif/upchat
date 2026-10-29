import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_glass.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/utils/web_theme_color.dart';
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
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  ));
  runApp(const AppBootstrap());
}

Future<void> _initializeLocalOnly() async {
  await Hive.initFlutter();
  await StorageService.init();
  if (StorageService.autoCleanup) {
    unawaited(CleanupService().run());
  }
}

Future<void> _warmUpFirebaseInBackground() async {
  try {
    await FirebaseAuthService.instance
        .initialize()
        .timeout(const Duration(seconds: 8));
  } catch (_) {}
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
    await _initializeLocalOnly();
    unawaited(_warmUpFirebaseInBackground());
  }

  void _retry() {
    setState(() => _initialization = _bootstrap());
  }

  void _continueOffline() {
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

/// Splash aligné sur la capture Adalo : fond bleu nuit, carte verre, bulle + flèche.
class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1565C0),
                Color(0xFF0D47A1),
                Color(0xFF061428),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Points décoratifs
              ..._dots(),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.85, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) => Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                      child: const _BrandCard(),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'UpChat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(flex: 4),
                    const SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Color(0x33FFFFFF),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Messagerie privée',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Widget> _dots() {
    const positions = <Offset>[
      Offset(0.12, 0.18),
      Offset(0.82, 0.22),
      Offset(0.22, 0.55),
      Offset(0.88, 0.48),
      Offset(0.15, 0.78),
      Offset(0.75, 0.72),
    ];
    return [
      for (final p in positions)
        Align(
          alignment: Alignment(p.dx * 2 - 1, p.dy * 2 - 1),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
          ),
        ),
    ];
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 168,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.55),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                // Contour type bulle (léger décalage bas-gauche pour « queue »)
                Icon(Icons.chat_bubble_rounded,
                    color: Color(0xFF1565C0), size: 72),
                Icon(Icons.arrow_upward_rounded,
                    color: Color(0xFF0A1628), size: 36),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'UpChat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        backgroundColor: const Color(0xFF061428),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Color(0xFF42A5F5), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Préparation locale interrompue',
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
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'Firebase n’est pas requis pour démarrer.\n'
                  'Tu peux continuer en mode hors ligne.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55), fontSize: 13),
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
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
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
              final activeTheme = Theme.of(context);
              final activeGlass =
                  activeTheme.extension<AppGlass>() ?? AppGlass.light;
              setWebThemeColor(activeGlass.chatGradientTop);
              final overlay =
                  Theme.of(context).appBarTheme.systemOverlayStyle ??
                      SystemUiOverlayStyle.light;
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
