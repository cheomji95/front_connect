import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_model.dart';
import '../services/auth_service.dart';
import '../utils/image_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = false, uploading = false;
  final nicknameController = TextEditingController();
  final introController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => loading = true);
    try {
      final r = await AuthService.dio.get('/users/me');
      final data = r.data as Map<String, dynamic>;
      nicknameController.text = data['nickname'] ?? '';
      introController.text = data['introduction'] ?? '';
      if (!mounted) return;
      context.read<AvatarModel>().update(data['avatar_url']);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Uint8List> _fetchImageBytes(String url) async {
    final resp = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data!);
  }

  Future<void> _onUploadAvatar() async {
    final picked = await ImageHelper.pickImage();
    if (picked == null) return;
    setState(() => uploading = true);

    try {
      final resp = await AuthService.uploadAvatar(File(picked.path));
      final newUrl = resp.data['url'] as String;
      if (!mounted) return;
      context.read<AvatarModel>().update(newUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => loading = true);
    try {
      await AuthService.dio.patch(
        '/users/me',
        data: {
          'nickname': nicknameController.text,
          'introduction': introController.text,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업데이트 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // 저장된 토큰 및 사용자 정보 제거
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text('정말로 탈퇴하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AuthService.deleteAccount();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탈퇴 실패: $e')),
      );
    }
  }

  @override
  void dispose() {
    nicknameController.dispose();
    introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = context.watch<AvatarModel>().url;
    final cacheBustedUrl = avatarUrl != null
        ? '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Center(
                    child: cacheBustedUrl == null
                        ? const CircleAvatar(
                            radius: 60,
                            child: Icon(Icons.person,
                                size: 60, color: Colors.grey),
                          )
                        : FutureBuilder<Uint8List>(
                            future: _fetchImageBytes(cacheBustedUrl),
                            builder: (context, snap) {
                              if (snap.connectionState !=
                                  ConnectionState.done) {
                                return const SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap.hasError || snap.data == null) {
                                return const CircleAvatar(
                                  radius: 60,
                                  child: Icon(Icons.error,
                                      size: 60, color: Colors.red),
                                );
                              }
                              return CircleAvatar(
                                radius: 60,
                                backgroundImage: MemoryImage(snap.data!),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: uploading
                        ? const CircularProgressIndicator()
                        : TextButton.icon(
                            onPressed: _onUploadAvatar,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('프로필 사진 변경'),
                          ),
                  ),
                  const Divider(),
                  TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: introController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '소개글',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _updateProfile,
                    child: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('프로필 저장'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever, color: Colors.grey),
                    label: const Text(
                      '회원탈퇴',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}



