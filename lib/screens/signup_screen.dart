// lib/screens/signup_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey             = GlobalKey<FormState>();
  final emailController      = TextEditingController();
  final passwordController   = TextEditingController();
  final confirmController    = TextEditingController();  // ← 추가
  final phoneController      = TextEditingController();
  final nicknameController = TextEditingController();  // ← 추가

  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    phoneController.dispose();
    nicknameController.dispose();  // ← 추가

    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      await AuthService.signup(
        username:    emailController.text,
        password:    passwordController.text,
        phoneNumber: phoneController.text,
        nickname:    nicknameController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 완료! 로그인해주세요.')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // 닉네임
              TextFormField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: '닉네임'),
                validator: (v) =>
                    v != null && v.length >= 2 ? null : '닉네임을 2자 이상 입력하세요.',
              ),
              const SizedBox(height: 16),

              // 이메일
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '이메일'),
                validator: (v) =>
                    v != null && v.contains('@') ? null : '유효한 이메일을 입력하세요.',
              ),
              const SizedBox(height: 16),

              // 비밀번호
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                validator: (v) =>
                    v != null && v.length >= 6 ? null : '6자 이상 입력하세요.',
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인 ← 새로 추가
              TextFormField(
                controller: confirmController,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return '비밀번호를 한번 더 입력하세요.';
                  if (v != passwordController.text) return '비밀번호가 일치하지 않습니다.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 휴대폰 번호 (+82 힌트 추가)
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: '휴대폰 번호',
                  prefixText: '+82 ',  // ← 국가코드 힌트
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v != null && v.length >= 9 ? null : '유효한 번호를 입력하세요.',
              ),
              const SizedBox(height: 24),

              // 가입 버튼
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _signup,
                      child: const Text('회원가입'),
                    ),

              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('이미 계정이 있으신가요? 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

