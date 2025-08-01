// models/friend_request.dart
class FriendRequest {
  final int id; // ✅ 요청 ID
  final int fromUserId;
  final String nickname;
  final String? avatarUrl;
  final String? introduction;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.nickname,
    this.avatarUrl,
    this.introduction,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      fromUserId: json['from_user_id'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      introduction: json['introduction'],
    );
  }
}
