// post_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/comment_section.dart';

class PostDetailScreen extends StatelessWidget {
  final Post post;
  static const String baseUrl = 'https://connect.io.kr';

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시글 상세보기')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // 제목
            Text(
              post.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 본문 (JSON 블록에서 텍스트만 추출하여 표시)
            Text(
              _extractBodyText(post.content),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // 연도와 지역
            Row(
              children: [
                Chip(label: Text('연도: ${post.year}')),
                const SizedBox(width: 8),
                Chip(label: Text('지역: ${post.region}')),
              ],
            ),
            const SizedBox(height: 16),

            // 태그
            if (post.tags.isNotEmpty)
              Wrap(
                spacing: 8,
                children: post.tags.map((tag) {
                  final tagName = tag['name']?.toString() ?? '';
                  return Chip(label: Text('#$tagName'));
                }).toList(),
              ),
            const SizedBox(height: 16),

            // 이미지
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

            // 댓글 섹션
            CommentSection(postId: post.id),
          ],
        ),
      ),
    );
  }

  /// 서버에서 내려온 content가 블록(JSON)일 때 텍스트만 이어붙여 반환.
  /// 파싱 실패 시 원문을 그대로 반환.
  String _extractBodyText(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .where((e) => e is Map && e['type'] == 'text')
            .map((e) => (e['data'] ?? '').toString())
            .join('\n');
      }
    } catch (_) {
      // ignore and fall back to raw
    }
    return raw;
  }
}
