import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'post_detail_screen.dart';

class FriendDetailScreen extends StatefulWidget {
  final Friend friend;

  const FriendDetailScreen({Key? key, required this.friend}) : super(key: key);

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  final _postService = PostService();
  List<Post> posts = [];
  int currentPage = 1;
  final int pageSize = 5;

  static const String baseUrl = 'https://connect.io.kr';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final newPosts = await _postService.getPostsByUserId(
        widget.friend.id,
        page: 1, // 전체를 불러온 후 페이지네이션 처리
        pageSize: 1000,
      );
      setState(() {
        posts = newPosts;
      });
    } catch (e) {
      print('❌ 게시글 로딩 실패: $e');
    }
  }

  List<Post> get postsForPage {
    final start = (currentPage - 1) * pageSize;
    final end = start + pageSize;
    return posts.sublist(start, end > posts.length ? posts.length : end);
  }

  Widget _buildPostItem(Post post) {
    final imageUrl = post.imageUrls.isNotEmpty
        ? '$baseUrl${post.imageUrls[0]}'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: post),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 80),
                      )
                    : const Icon(Icons.image, size: 80),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${post.region} · ${post.year}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: post.tags.take(3).map((tag) {
                        return Chip(
                          label: Text(tag['name']),
                          backgroundColor: Colors.grey.shade200,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (posts.length / pageSize).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () => setState(() => currentPage--)
              : null,
        ),
        for (int i = 1; i <= totalPages; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    i == currentPage ? Colors.blue : Colors.grey.shade300,
                foregroundColor:
                    i == currentPage ? Colors.white : Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => setState(() => currentPage = i),
              child: Text('$i'),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () => setState(() => currentPage++)
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.friend.nickname)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: widget.friend.avatarUrl != null
                      ? NetworkImage(widget.friend.avatarUrl!)
                      : null,
                  child: widget.friend.avatarUrl == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    widget.friend.introduction ?? '소개글이 없습니다.',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: postsForPage.length,
                      itemBuilder: (context, index) {
                        return _buildPostItem(postsForPage[index]);
                      },
                    ),
                  ),
                  if (posts.length > pageSize)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildPagination(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}