// lib/models/search_user_model.dart
class SearchUser {
  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? introduction;

  SearchUser({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.introduction,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['id'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      introduction: json['introduction'],
    );
  }
}

