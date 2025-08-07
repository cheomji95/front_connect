// models/matched_post.dart
class MatchedPost {
  final int postId;
  final String title;
  final int matchRate;

  MatchedPost({
    required this.postId,
    required this.title,
    required this.matchRate,
  });

  factory MatchedPost.fromJson(Map<String, dynamic> json) {
    return MatchedPost(
      postId: json['post_id'],
      title: json['title'],
      matchRate: json['match_rate'],
    );
  }
}
