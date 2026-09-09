import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/usage_monitor_service.dart';
import 'services/detox_native_timer.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/insights/insights_screen.dart';
import 'screens/mood/mood_screen.dart';

/// Global navigator key — lets us show the detox dialog from anywhere,
/// even when there's no local BuildContext (e.g. arriving from a background
/// notification tap or a native service callback).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize background usage monitor (Android only)
  await UsageMonitorService.initialize();

  // Wire up the native detox timer alert callback — this fires when
  // the native Kotlin foreground service detects the limit is reached.
  DetoxNativeTimer.initialize((appName, limitMins) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      showDetoxAlertDialog(ctx, appName: appName, limitMins: limitMins);
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'AI Planner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        navigatorKey: navigatorKey, // ← global key for detox alert
        initialRoute: '/',
        routes: {
          '/': (context) => const InitialScreen(),
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/insights': (context) => const InsightsScreen(),
          '/mood': (context) => const MoodScreen(),
        },
      ),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenSplash = prefs.getBool('has_seen_splash') ?? false;

    if (!mounted) return;

    if (!hasSeenSplash) {
      Navigator.of(context).pushReplacementNamed('/splash');
      return;
    }

    final authService = context.read<AuthService>();
    final isLoggedIn = await authService.isLoggedIn();

    if (!mounted) return;
    if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );
  }
}
