// main.dart
// 메인 주석추가
import 'dart:io';
import 'package:flutter/material.dart'; 
import 'package:provider/provider.dart';

import 'screens/map_screen.dart';
import 'screens/recent_posts_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'models/avatar_model.dart';
import 'services/auth_service.dart';
import 'screens/my_post_screen.dart';
import 'screens/my_post_create_screen.dart';
import 'screens/friend_list_screen.dart';
import 'screens/friend_detail_screen.dart';
import 'models/friend_model.dart'; // ✅ 올바른 모델로 변경

/// SSL 인증서 무시용 HttpOverrides
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  AuthService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AvatarModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect App',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/recent-posts': (context) => const RecentPostsScreen(),
        '/create-post': (context) => const PostCreateScreen(),
        '/my-posts': (context) => const MyPostsScreen(),
        '/friends': (context) => const FriendListScreen(),
        '/map': (context) => const MapScreen(),
        // ❌ '/friend-detail'은 onGenerateRoute로 이동
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/friend-detail') {
          final friend = settings.arguments as Friend; // ✅ 타입 일치
          return MaterialPageRoute(
            builder: (_) => FriendDetailScreen(friend: friend),
          );
        }

        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('알 수 없는 경로')),
          ),
        );
      },
    );
  }
}
