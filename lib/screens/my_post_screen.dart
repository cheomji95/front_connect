// my_post_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/post_service.dart';
import '../models/post_model.dart';
import 'post_detail_screen.dart';
import 'edit_post_screen.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  List<Post> posts = [];
  bool isLoading = true;

  static const String baseUrl = 'https://connect.io.kr';

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    try {
      final data = await PostService.getUserPosts(userId); // List<Post>
      if (!mounted) return;
      setState(() {
        posts = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('불러오기 실패: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> deletePost(int postId) async {
    try {
      await PostService.deletePost(postId);
      if (!mounted) return;
      setState(() {
        posts.removeWhere((p) => p.id == postId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 게시글')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(child: Text('작성한 게시글이 없습니다.'))
              : ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final imageUrl = post.imageUrls.isNotEmpty
                        ? '$baseUrl${post.imageUrls[0]}'
                        : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          );
                        },
                        leading: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image, size: 50),
                        title: Text(post.title),
                        subtitle: Text(
                          post.content.length > 20
                              ? '${post.content.substring(0, 20)}...'
                              : post.content,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '수정',
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditPostScreen(post: post),
                                  ),
                                );
                                if (result == true) {
                                  await loadPosts();
                                }
                              },
                            ),
                            IconButton(
                              tooltip: '삭제',
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deletePost(post.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

