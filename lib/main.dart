// main.dart
// ✅ 자동 로그인 기능 포함 + 주석 정리

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
import 'screens/weather_insight_screen.dart';
import 'models/friend_model.dart';
import '../core/jwt_storage.dart';


/// SSL 인증서 무시용 HttpOverrides
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  AuthService.init(); // ✅ 인터셉터 초기화

  // ✅ 토큰 유효성 확인
  final isLoggedIn = await _verifyToken();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AvatarModel(),
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

/// ✅ 서버에 요청해 토큰 유효성 확인
Future<bool> _verifyToken() async {
  final token = await JwtStorage.getAccessToken();
  if (token == null) return false;

  try {
    final res = await AuthService.dio.get('/users/me');
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// ✅ 로그인 여부에 따라 시작 화면 결정
class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({required this.isLoggedIn, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect App',
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn ? '/home' : '/login',
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
        '/weather-insight': (context) => const WeatherInsightScreen(),
        // ❌ '/friend-detail'은 아래 onGenerateRoute로 처리
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/friend-detail') {
          final friend = settings.arguments as Friend;
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
