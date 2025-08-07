// 최근 게시글 목록
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'package:connect/services/post_service.dart';
import 'post_detail_screen.dart';

class RecentPostsScreen extends StatefulWidget {
  const RecentPostsScreen({super.key});

  @override
  State<RecentPostsScreen> createState() => _RecentPostsScreenState();
}

class _RecentPostsScreenState extends State<RecentPostsScreen> {
  List<Post> posts = [];
  bool isLoading = true;
  static const String baseUrl = 'https://connect.io.kr';

  int currentPage = 1;
  final int pageSize = 8;

  @override
  void initState() {
    super.initState();
    fetchRecentPosts();
  }

  Future<void> fetchRecentPosts() async {
    try {
      final data = await PostService.getRecentPosts();
      setState(() {
        posts = data.map((json) => Post.fromJson(json)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('불러오기 실패: $e')),
      );
    }
  }

  List<Post> get postsForPage {
    final start = (currentPage - 1) * pageSize;
    final end = start + pageSize;
    return posts.sublist(start, end > posts.length ? posts.length : end);
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      appBar: AppBar(title: const Text('최근 게시글')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text('최근 게시글이 없습니다.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: postsForPage.length,
                        itemBuilder: (context, index) {
                          final post = postsForPage[index];
                          final imageUrl = post.imageUrls.isNotEmpty
                              ? '$baseUrl${post.imageUrls[0]}'
                              : null;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: ListTile(
                              leading: imageUrl != null
                                  ? Image.network(
                                      imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.image, size: 50),
                              title: Text(post.title),
                              subtitle: Text('${post.region} / ${post.year}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailScreen(postId: post.id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (posts.length > pageSize)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPagination(),
                      ),
                  ],
                ),
    );
  }
}


