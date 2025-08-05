// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../models/avatar_model.dart';
import '../models/recent_friend.dart';
import '../models/friend_model.dart';
import '../models/post_model.dart';
import '../services/profile_service.dart';
import '../services/friend_service.dart';
import '../services/post_service.dart';
import '../core/jwt_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _friendService = FriendService(Dio());
  List<RecentFriend> recentFriends = [];
  List<Post> myPosts = [];
  bool showMyPosts = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      await _loadRecentFriends();
    });
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await ProfileService.fetchProfile();
      context.read<AvatarModel>().updateLocal(profile);
      await _loadRecentFriends();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 최신화되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('새로고침 실패: $e')),
      );
    }
  }

  Future<void> _loadRecentFriends() async {
    final token = await JwtStorage.getAccessToken();
    if (token == null) return;

    try {
      final friends = await _friendService.getRecentActiveFriends(token);
      setState(() {
        recentFriends = friends.take(3).toList();
      });
    } catch (e) {
      debugPrint('❌ 친구 목록 로딩 실패: $e');
    }
  }

  Future<void> _loadMyPosts() async {
    final token = await JwtStorage.getAccessToken();     // ✅ 토큰은 인증에 사용
    final userId = await JwtStorage.getUserId();         // ✅ userId를 따로 불러옴
    if (token == null || userId == null) return;

    try {
      final posts = await PostService.getUserPosts(userId); // ✅ userId 넘김 (int)
      setState(() {
        myPosts = posts;
        showMyPosts = true;
      });
    } catch (e) {
      debugPrint('❌ 게시글 로딩 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = context.watch<AvatarModel>().url;
    final nickname = context.watch<AvatarModel>().nickname;

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfile,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/my-posts'),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? const Icon(Icons.person, size: 40) : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(nickname ?? '닉네임 없음', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("친구 목록"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...recentFriends.map((f) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  final friend = Friend(
                                    id: int.parse(f.id.toString()), // ✅ 수정 완료: int 그대로 전달
                                    nickname: f.nickname,
                                    avatarUrl: f.avatarUrl,
                                    introduction: f.introduction,
                                  );
                                  Navigator.pushNamed(
                                    context,
                                    '/friend-detail',
                                    arguments: friend,
                                  );
                                },
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: f.avatarUrl != null && f.avatarUrl!.isNotEmpty
                                          ? NetworkImage(f.avatarUrl!)
                                          : null,
                                      child: f.avatarUrl == null || f.avatarUrl!.isEmpty
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(f.nickname, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/friends'),
                            child: Column(
                              children: const [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Color(0xFFE0D7F7),
                                  child: Icon(Icons.add, color: Colors.deepPurple),
                                ),
                                SizedBox(height: 4),
                                Text('더보기', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Column(
              children: [
                FilterButton(label: '게시글 제목', onTap: _loadMyPosts),
                const FilterButton(label: '연도 설정'),
                const FilterButton(label: '지역'),
                const FilterButton(label: '연관 태그'),
              ],
            ),

            if (showMyPosts) ...[
              const SizedBox(height: 16),
              const Text('내 게시글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...myPosts.map((p) => ListTile(
                    title: Text(p.title),
                    subtitle: Text('${p.year} · ${p.region}'),
                    onTap: () {
                      // TODO: 일치도 분석 및 미리보기 기능
                    },
                  )),
            ],

            const SizedBox(height: 16),

            Column(
              children: [
                Image.asset('assets/icons/구름.png', height: 140),
                const SizedBox(height: 8),
                const Text('50%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/create-post'),
                icon: const Icon(Icons.cloud_upload),
                label: const Text('구름 띄우기'),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/recent-posts'),
                  child: Image.asset('assets/icons/이슬.png', width: 80, height: 80),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/map'),
                  child: Image.asset('assets/icons/안개.png', width: 80, height: 80),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/weather-insight'),
                  child: Image.asset('assets/icons/일기예보.png', width: 80, height: 80),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const FilterButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }
}

