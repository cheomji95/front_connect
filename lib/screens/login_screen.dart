// login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator.pop
import 'package:provider/provider.dart';

import '../models/avatar_model.dart';
import '../services/auth_service.dart';
import '../core/jwt_storage.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = usernameController.text;
    final password = passwordController.text;

    setState(() => loading = true);
    try {
      final userData = await AuthService.login(username: username, password: password);

      if (!mounted) return;

      final accessToken = userData['access_token'] as String?;
      final refreshToken = userData['refresh_token'] as String?;
      final userId = userData['id'] as int?;

      if (accessToken != null) await JwtStorage.setAccessToken(accessToken);
      if (refreshToken != null) await JwtStorage.setRefreshToken(refreshToken);
      if (userId != null) await JwtStorage.setUserId(userId);

      context.read<AvatarModel>().update(
        userData['avatar_url'],
        userData['nickname'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 성공!')),
      );

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop(); // 앱 종료
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('로그인')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (v) => v != null && v.contains('@') ? null : '유효한 이메일을 입력하세요.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                  validator: (v) => v != null && v.length >= 4 ? null : '4자 이상 입력하세요.',
                ),
                const SizedBox(height: 24),
                loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('로그인'),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: const Text('회원가입 하러가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

