import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/jwt_storage.dart';
import '../models/friend_model.dart';
import '../models/recent_friend.dart';
import '../models/search_user_model.dart';
import '../models/friend_request_model.dart';

class FriendService {
  final Dio dio;
  final String baseUrl = 'https://connect.io.kr/friends';

  FriendService(this.dio);

  // ✅ 유저 검색
  Future<List<SearchUser>> searchUsers(String nickname, String token) async {
    const url = 'https://connect.io.kr/users/search';
    final headers = {'Authorization': 'Bearer $token'};

    print('▶ [searchUsers] 요청 URL: $url?nickname=$nickname');
    print('🔐 [searchUsers] token: $token');

    try {
      final response = await dio.get(
        url,
        queryParameters: {'nickname': nickname},
        options: Options(headers: headers),
      );
      print('✅ [searchUsers] 결과: ${response.statusCode}');
      print('📦 [searchUsers] 응답 데이터: ${response.data}');
      return (response.data as List)
          .map((item) => SearchUser.fromJson(item))
          .toList();
    } catch (e) {
      print('❌ [searchUsers] 실패: $e');
      return [];
    }
  }

  // ✅ 최근 게시물 작성 기준 친구 3명
  Future<List<RecentFriend>> getRecentActiveFriends(String token) async {
    final url = '$baseUrl/recent-active';
    print('▶ [recentActive] 요청 URL: $url');
    print('🔐 [recentActive] token: $token');

    try {
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ [recentActive] 응답 코드: ${response.statusCode}');
      print('📦 [recentActive] 응답 데이터: ${jsonEncode(response.data)}');
      return (response.data as List)
          .map((item) => RecentFriend.fromJson(item))
          .toList();
    } catch (e) {
      print('❌ [recentActive] 친구 조회 실패: $e');
      return [];
    }
  }

  // ✅ 친구 요청 보내기
  Future<void> sendFriendRequest(int toUserId, String token) async {
    final url = '$baseUrl/request/$toUserId';
    print('▶ [sendRequest] POST $url');

    try {
      final response = await dio.post(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ [sendRequest] 성공: ${response.data}');
    } catch (e) {
      print('❌ [sendRequest] 실패: $e');
      rethrow;
    }
  }

  // ✅ 친구 상태 확인
  Future<String> getFriendStatus(int userId, String token) async {
    final url = '$baseUrl/status/$userId';
    print('▶ [getStatus] GET $url');

    try {
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ [getStatus] 상태: ${response.data}');
      return response.data['status'];
    } catch (e) {
      print('❌ [getStatus] 실패: $e');
      return 'error';
    }
  }

  // ✅ 친구 목록
  Future<List<Friend>> getFriendList(String token) async {
    final url = '$baseUrl/list';
    print('▶ [getFriendList] GET $url');

    try {
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ [getFriendList] 응답: ${jsonEncode(response.data)}');
      return (response.data as List)
          .map((item) => Friend.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ [getFriendList] 실패: $e');
      return [];
    }
  }

  // ✅ 받은 친구 요청 목록
  Future<List<FriendRequest>> getIncomingRequests(String token) async {
    final url = '$baseUrl/requests/incoming';
    print('▶ [incomingRequests] GET $url');

    try {
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ [incomingRequests] 응답 수신');
      return (response.data as List)
          .map((json) => FriendRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ [incomingRequests] 실패: $e');
      return [];
    }
  }

  // ✅ 친구 요청 응답
  Future<void> respondToRequest(int requestId, {required bool accepted}) async {
    final url = '$baseUrl/respond/$requestId';
    final token = await JwtStorage.getAccessToken();

    print('▶ [respondToRequest] PUT $url');
    print('🔐 토큰: $token');

    try {
      final response = await dio.put(
        url,
        data: {'accepted': accepted},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('✅ [respondToRequest] 완료: ${response.data}');
    } catch (e) {
      print('❌ [respondToRequest] 실패: $e');
      rethrow;
    }
  }

  // ✅ 친구 요청 삭제
  Future<void> deleteFriendRequest(int requestId) async {
    final url = '$baseUrl/request/$requestId';
    final token = await JwtStorage.getAccessToken();

    print('▶ [deleteRequest] DELETE $url');
    print('🔐 토큰: $token');

    try {
      final response = await dio.delete(
        url,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      print('🗑️ [deleteRequest] 삭제 완료: ${response.statusCode}');
    } catch (e) {
      print('❌ [deleteRequest] 실패: $e');
      rethrow;
    }
  }
}







