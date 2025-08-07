// home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../models/avatar_model.dart';
import '../models/recent_friend.dart';
import '../models/friend_model.dart';
import '../models/post_model.dart';
import '../models/matched_post.dart';
import '../services/profile_service.dart';
import '../services/friend_service.dart';
import '../services/post_service.dart';
import '../core/jwt_storage.dart';

const String baseUrl = 'https://connect.io.kr';

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
  int currentPage = 0;

  Post? _selectedPost;
  List<MatchedPost> _matchedPosts = [];
  int _matchRate = 0;
  int _currentMatchIndex = 0;

  List<Post> get pagedPosts {
    final start = currentPage * 3;
    final end = (start + 3).clamp(0, myPosts.length);
    return myPosts.sublist(start, end);
  }

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
      debugPrint('❌ 최근 친구 목록 로드 실패: $e');
    }
  }

  Future<void> _loadMyPosts() async {
    final token = await JwtStorage.getAccessToken();
    final userId = await JwtStorage.getUserId();
    if (token == null || userId == null) return;

    try {
      final posts = await PostService.getUserPosts(userId);
      setState(() {
        myPosts = posts;
        currentPage = 0;
        showMyPosts = true;
      });
    } catch (e) {
      debugPrint('❌ 게시글 로드 실패: $e');
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
                      const Text('친구 목록'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...recentFriends.map((f) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () {
                                  final friend = Friend(
                                    id: int.parse(f.id.toString()),
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
                FilterButton(label: '연도: ${_selectedPost?.year ?? '미선택'}'),
                FilterButton(label: '지역: ${_selectedPost?.region ?? '미선택'}'),
                FilterButton(
                  label: '태그: ${_selectedPost?.tags.map((t) => t['name']).join(', ') ?? '미선택'}',
                ),


              ],
            ),

            if (showMyPosts) ...[
              const SizedBox(height: 16),
              const Text('내 게시글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...pagedPosts.map((p) => ListTile(
                    leading: p.imageUrls.isNotEmpty
                        ? Image.network('$baseUrl${p.imageUrls.first}', width: 48, height: 48, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(p.title),
                    subtitle: Text('${p.year} · ${p.region}'),
                    onTap: () {
                      setState(() {
                        _selectedPost = p;
                      });
                    },
                  )),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
                  ),
                  Text('${currentPage + 1} / ${((myPosts.length - 1) / 3).floor() + 1}'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: (currentPage + 1) * 3 < myPosts.length
                        ? () => setState(() => currentPage++)
                        : null,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            Center(
              child: Column(
                children: [
                  // 구름 이미지 (탭 시 연관도 API 호출)
                  GestureDetector(
                    onTap: _onCloudTap,
                    child: Image.asset('assets/icons/구름.png', width: 120),
                  ),
                  const SizedBox(height: 8),

                  // 유사도 퍼센트 표시
                  Text(
                    '$_matchRate%',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  // 유사 게시글 제목 표시
                  if (_matchedPosts.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        final postId = _matchedPosts[_currentMatchIndex].postId;

                        Navigator.pushNamed(
                          context,
                          '/post-detail',
                          arguments: postId, // 🔥 postId만 넘김
                        );
                      },
                      child: Text(
                        _matchedPosts[_currentMatchIndex].title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // 좌우 넘기기 버튼
                  if (_matchedPosts.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _currentMatchIndex > 0
                              ? () {
                                  setState(() {
                                    _currentMatchIndex--;
                                    _matchRate = _matchedPosts[_currentMatchIndex].matchRate;
                                  });
                                }
                              : null,
                        ),
                        Text('${_currentMatchIndex + 1} / ${_matchedPosts.length}'),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _currentMatchIndex < _matchedPosts.length - 1
                              ? () {
                                  setState(() {
                                    _currentMatchIndex++;
                                    _matchRate = _matchedPosts[_currentMatchIndex].matchRate;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
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
  Future<void> _onCloudTap() async {
    if (_selectedPost == null) return;

    try {
      final matches = await PostService.getMatchedPosts(_selectedPost!.id);
      if (matches.isNotEmpty) {
        print('📦 받아온 유사 게시글 제목: ${matches.first.title}'); // ✅ 여기에 추가

        setState(() {
          _matchedPosts = matches;
          _currentMatchIndex = 0;
          _matchRate = matches.first.matchRate;
        });
      }
    } catch (e) {
      debugPrint('❌ 연관도 계산 실패: $e');
    }
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

