import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/fcm_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/feed_screen.dart';
import 'screens/workout/log_workout_screen.dart';
import 'screens/challenges/challenges_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/photos/photo_journal_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/shell_screen.dart';

// Background FCM handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background FCM message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const BeastModeApp());
}

class BeastModeApp extends StatelessWidget {
  const BeastModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => FCMService()),
      ],
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MaterialApp.router(
            title: 'Beast Mode',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            routerConfig: _buildRouter(auth),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0057FF), // electric blue
        brightness: Brightness.dark,
        surface: const Color(0xFF0A0E1A),   // deep navy
        primary: const Color(0xFF0057FF),
        error: const Color(0xFFFF3B30),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0E1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3B30), // red CTA
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141824),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0057FF), width: 2),
        ),
      ),
    );
  }

  GoRouter _buildRouter(AuthService auth) {
    return GoRouter(
      initialLocation: '/login',
      redirect: (context, state) {
        final isLoggedIn = auth.currentUser != null;
        final isAuthRoute =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/feed';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => ShellScreen(child: child),
          routes: [
            GoRoute(
              path: '/feed',
              builder: (context, state) => const FeedScreen(),
            ),
            GoRoute(
              path: '/log',
              builder: (context, state) => const LogWorkoutScreen(),
            ),
            GoRoute(
              path: '/challenges',
              builder: (context, state) => const ChallengesScreen(),
            ),
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/photos',
              builder: (context, state) => const PhotoJournalScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
