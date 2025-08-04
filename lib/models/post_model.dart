// post_model.dart
import 'dart:convert'; // ⬅️ 추가

class Post {
  final int id;
  final String title;
  final String content;      // ✅ 화면에 쓸 "표시용 텍스트"
  final String? contentRaw;  // (옵션) 원본 JSON 문자열
  final int year;
  final String region;
  final double? latitude;   
  final double? longitude;
  final List<Map<String, dynamic>> tags;
  final List<String> imageUrls;
  final DateTime createdAt;

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
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final raw = (json['content'] ?? '').toString();
    String display = raw;

    // [{"type":"text","data":"..."}] → 텍스트만 이어붙임
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        display = parsed
            .where((e) => e is Map && e['type'] == 'text')
            .map((e) => (e['data'] ?? '').toString())
            .join('\n');
      }
    } catch (_) {
      // 파싱 실패 시 raw 그대로 둠
    }

    return Post(
      id: json['id'],
      title: json['title'] ?? '',
      content: display,     // ✅ 화면용 문자열
      contentRaw: raw,      // (옵션) 원본 저장
      year: json['year'] ?? '',
      region: json['region'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),   
      longitude: (json['longitude'] as num?)?.toDouble(), 
      tags: List<Map<String, dynamic>>.from(json['tags'] ?? []),
      imageUrls: List<String>.from(json['images'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
