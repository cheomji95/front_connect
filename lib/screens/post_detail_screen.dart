// post_detail_screen.dart
import 'dart:convert';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/comment_section.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post> _postFuture;
  static const String baseUrl = 'https://connect.io.kr';

  @override
  void initState() {
    super.initState();
    _postFuture = fetchPost(widget.postId);
  }

  Future<Post> fetchPost(int postId) async {
    final response = await AuthService.dio.get('/posts/$postId');
    return Post.fromJson(response.data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시글 상세보기')),
      body: FutureBuilder<Post>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('게시글을 불러올 수 없습니다.'));
          }

          final post = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_extractBodyText(post.content), style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Chip(label: Text('연도: ${post.year}')),
                    const SizedBox(width: 8),
                    Chip(label: Text('지역: ${post.region}')),
                  ],
                ),
                const SizedBox(height: 16),
                if (post.tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: post.tags.map((tag) {
                      final tagName = tag['name']?.toString() ?? '';
                      return Chip(label: Text('#$tagName'));
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                if (post.imageUrls.isNotEmpty)
                  Column(
                    children: post.imageUrls.map((url) {
                      final fullUrl = url.startsWith('http') ? url : '$baseUrl$url';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Image.network(fullUrl, fit: BoxFit.cover),
                      );
                    }).toList(),
                  ),
                const Divider(height: 32),
                CommentSection(postId: post.id),
              ],
            ),
          );
        },
      ),
    );
  }

  String _extractBodyText(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .where((e) => e is Map && e['type'] == 'text')
            .map((e) => (e['data'] ?? '').toString())
            .join('\n');
      }
    } catch (_) {}
    return raw;
  }
}
