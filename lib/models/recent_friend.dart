// models/recent_friend.dart
class RecentFriend {
  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? introduction;

  RecentFriend({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.introduction,
  });

  factory RecentFriend.fromJson(Map<String, dynamic> json) {
    return RecentFriend(
      id: int.parse(json['id'].toString()),
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      introduction: json['introduction'],
    );
  }
}
