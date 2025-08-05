import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/friend_service.dart';
import '../models/friend_model.dart';
import '../models/friend_request_model.dart';
import '../core/jwt_storage.dart';
import 'friend_detail_screen.dart';

class FriendListScreen extends StatefulWidget {
  const FriendListScreen({Key? key}) : super(key: key);

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  final friendService = FriendService(
    Dio()..interceptors.add(LogInterceptor(requestBody: true, responseBody: true)),
  );

  List<Friend> allFriends = [];
  List<Friend> filteredFriends = [];
  List<FriendRequest> searchedUsers = [];
  List<FriendRequest> incomingRequests = [];

  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    loadFriendList();
    loadIncomingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadFriendList() async {
    final token = await JwtStorage.getAccessToken();
    if (token == null) {
      setState(() {
        isLoading = false;
        allFriends = [];
        filteredFriends = [];
      });
      return;
    }

    try {
      final list = await friendService.getFriendList(token);
      setState(() {
        allFriends = list;
        filteredFriends = list;
      });
    } catch (e) {
      debugPrint('⚠️ 친구 목록 조회 실패: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadIncomingRequests() async {
    final token = await JwtStorage.getAccessToken();
    if (token == null) return;
    try {
      final requests = await friendService.getIncomingRequests(token);
      setState(() => incomingRequests = requests);
    } catch (e) {
      debugPrint('❌ 받은 친구 요청 조회 실패: $e');
    }
  }

  Future<void> _searchUsers() async {
    final query = _searchController.text.trim();
    final token = await JwtStorage.getAccessToken();

    if (query.isEmpty || token == null) {
      setState(() {
        isSearching = false;
        searchedUsers = [];
      });
      return;
    }

    try {
      final results = await friendService.searchUsers(query, token);
      setState(() {
        isSearching = true;
        searchedUsers = results.map((user) => FriendRequest(
          id: user.id,
          fromUserId: user.id,
          nickname: user.nickname,
          avatarUrl: user.avatarUrl,
          introduction: user.introduction,
        )).toList();
      });
    } catch (e) {
      debugPrint('❌ 검색 실패: $e');
      setState(() {
        isSearching = false;
        searchedUsers = [];
      });
    }
  }

  void _showRequestPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('받은 친구 요청'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: incomingRequests.length,
            itemBuilder: (context, index) {
              final user = incomingRequests[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user.nickname),
                subtitle: Text(user.introduction ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _respondToRequest(user.id, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _respondToRequest(user.id, false),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _respondToRequest(int requestId, bool accepted) async {
    try {
      await friendService.respondToRequest(requestId, accepted: accepted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(accepted ? '친구 요청 수락됨' : '친구 요청 거절됨')),
      );
      Navigator.pop(context);
      await loadFriendList();
      await loadIncomingRequests();
    } catch (e) {
      debugPrint('❌ 응답 실패: $e');
    }
  }

  Widget _buildListTile({
    required String nickname,
    String? introduction,
    String? avatarUrl,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    debugPrint('🖼 avatarUrl: $avatarUrl');
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(nickname),
      subtitle: Text(introduction ?? ''),
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('친구 목록'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _showRequestPopup,
              ),
              if (incomingRequests.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      '${incomingRequests.length}',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: '닉네임 검색',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _searchUsers,
                        child: const Text('검색'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isSearching ? _buildSearchResults() : _buildFriendList(),
                ),
              ],
            ),
    );
  }

  Widget _buildFriendList() {
    if (filteredFriends.isEmpty) {
      return const Center(child: Text('표시할 친구가 없습니다.'));
    }
    return ListView.builder(
      itemCount: filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = filteredFriends[index];
        return _buildListTile(
          nickname: friend.nickname,
          introduction: friend.introduction,
          avatarUrl: friend.avatarUrl,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FriendDetailScreen(friend: friend),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (searchedUsers.isEmpty) {
      return const Center(child: Text('검색된 사용자가 없습니다.'));
    }
    return ListView.builder(
      itemCount: searchedUsers.length,
      itemBuilder: (context, index) {
        final user = searchedUsers[index];
        return _buildListTile(
          nickname: user.nickname,
          introduction: user.introduction,
          avatarUrl: user.avatarUrl,
          trailing: ElevatedButton(
            onPressed: () async {
              final token = await JwtStorage.getAccessToken();
              if (token != null) {
                try {
                  await friendService.sendFriendRequest(user.id, token);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('친구 요청을 보냈습니다')),
                  );
                } catch (e) {
                  debugPrint('⚠️ 친구 요청 실패: $e');
                }
              }
            },
            child: const Text('요청'),
          ),
        );
      },
    );
  }
}
