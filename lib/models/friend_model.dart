//friend_model.dart
class Friend {
  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? introduction;

  Friend({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.introduction,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      introduction: json['introduction'],
    );
  }
}
