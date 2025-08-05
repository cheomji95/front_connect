// post_model.dart
import 'dart:convert';

class Post {
  final int id;
  final String title;
  final String content;
  final String? contentRaw;
  final int year;
  final String region;
  final double? latitude;
  final double? longitude;
  final List<Map<String, dynamic>> tags;
  final List<String> imageUrls;
  final DateTime? createdAt; // ✅ 선택적으로 변경

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.contentRaw,
    this.latitude,
    this.longitude,
    required this.year,
    required this.region,
    required this.tags,
    required this.imageUrls,
    this.createdAt, // ✅ required 제거
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final raw = (json['content'] ?? '').toString();
    String display = raw;

    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        display = parsed
            .where((e) => e is Map && e['type'] == 'text')
            .map((e) => (e['data'] ?? '').toString())
            .join('\n');
      }
    } catch (_) {}

    return Post(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      content: display,
      contentRaw: raw,
      year: int.tryParse(json['year'].toString()) ?? 0,
      region: json['region'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      tags: List<Map<String, dynamic>>.from(json['tags'] ?? []),
      imageUrls: List<String>.from(json['images'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

