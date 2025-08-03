import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 서버에서 받아올 프로필 데이터 모델
class ProfileData {
  final int id;
  final String username;
  final String nickname;
  final String phoneNumber;
  final String avatarUrl;
  final String introduction;

  ProfileData({
    required this.id,
    required this.username,
    required this.nickname,
    required this.phoneNumber,
    required this.avatarUrl,
    required this.introduction,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id:           json['id'] as int,
      username:     json['username'] as String,
      nickname:     json['nickname'] as String,
      phoneNumber:  json['phone_number'] as String,
      avatarUrl:    json['avatar_url'] as String,
      introduction: json['introduction'] as String,
    );
  }
}

/// 프로필 관련 API 호출 서비스
class ProfileService {
  static const _baseUrl = 'https://connect.io.kr';

  /// 전체 프로필 조회
  static Future<ProfileData> fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) throw Exception('토큰 없음: 로그인 필요');

    final dio = Dio();
    final response = await dio.get(
      '$_baseUrl/users/me',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      return ProfileData.fromJson(response.data as Map<String, dynamic>);
    } else if (response.statusCode == 401) {
      throw Exception('인증 실패 (401 Unauthorized)');
    } else {
      throw Exception('프로필 조회 실패: ${response.statusCode}');
    }
  }

  /// 아바타 URL만 조회
  static Future<String> fetchAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) throw Exception('토큰 없음: 로그인 필요');

    final dio = Dio();
    final response = await dio.get(
      '$_baseUrl/users/me/avatar-url',
      options: Options(headers: {
        'Authorization': 'Bearer $token',
      }),
    );

    if (response.statusCode == 200) {
      return response.data['avatar_url'] as String;
    } else {
      throw Exception('아바타 조회 실패: ${response.statusCode}');
    }
  }
}

