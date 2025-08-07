// post_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/post_model.dart';
import 'package:http/http.dart' as http;
import '../models/matched_post.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostService {
  static const String _baseUrl = 'https://connect.io.kr';

  /// 게시글 생성
  static Future<void> createPost({
    required String title,
    required String content_items, // JSON 문자열 (배열)
    required String year,
    required String region,
    required List<String> tags,
    required int userId,
    required List<XFile> images,
    required double latitude,
    required double longitude,
  }) async {
    final dio = Dio();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('인증 토큰이 없습니다. 로그인 상태를 확인하세요.');
    }

    final formData = FormData();
    formData.fields.addAll([
      MapEntry('title', title),
      MapEntry('content_items', content_items),  // 변경된 필드명
      MapEntry('year', year),
      MapEntry('region', region),
      MapEntry('tags', jsonEncode(tags)),  // tags는 리스트 → JSON 문자열 변환
      MapEntry('user_id', userId.toString()),
      MapEntry('latitude', latitude.toString()),
      MapEntry('longitude', longitude.toString()),
    ]);

    for (final img in images) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(img.path, filename: img.name),
        ),
      );
    }

    final response = await dio.post(
      '$_baseUrl/posts/',
      data: formData,
      options: Options(headers: {
        'Content-Type': 'multipart/form-data',
        'Authorization': 'Bearer $token',
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  }

  /// 게시글 수정
  static Future<void> updatePost({
    required int postId,
    required String title,
    required String content_items, // JSON 문자열 (배열)
    required String year,
    required String region,
    required List<String> tags,
    required List<XFile> images,
    required double latitude,
    required double longitude,
    required List<String> existingImageUrls,
  }) async {
    final dio = Dio();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('인증 토큰이 없습니다.');
    }

    final formData = FormData();
    formData.fields.addAll([
      MapEntry('title', title),
      MapEntry('content_items', content_items),  // 변경된 필드명
      MapEntry('year', year),
      MapEntry('region', region),
      MapEntry('tags', jsonEncode(tags)),
      MapEntry('latitude', latitude.toString()),
      MapEntry('longitude', longitude.toString()),
      MapEntry('existing_image_urls', jsonEncode(existingImageUrls)),
    ]);

    for (final image in images) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(image.path, filename: image.name),
        ),
      );
    }

    final response = await dio.put(
      '$_baseUrl/posts/$postId',
      data: formData,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/form-data',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('수정 실패: ${response.statusCode}');
    }
  }

  /// 특정 유저의 게시글 전체 조회 (★여기를 수정!)
  static Future<List<Post>> getUserPosts(int userId) async {
    final dio = Dio();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('인증 토큰이 없습니다. 로그인 상태를 확인하세요.');
    }

    final response = await dio.get(
      '$_baseUrl/posts/user/$userId',
      options: Options(headers: {
        'Authorization': 'Bearer $token',
      }),
    );

    if (response.statusCode == 200) {
      return (response.data as List)
          .map((json) => Post.fromJson(json))
          .toList();
    } else {
      throw Exception('내 게시글 불러오기 실패: ${response.statusCode}');
    }
  }

  /// 반경 검색
  static Future<List<dynamic>> getPostsByRadius({
    required double lat,
    required double lng,
    required double radiusKm,
    int limit = 200,
  }) async {
    final dio = Dio();
    final response = await dio.get(
      '$_baseUrl/posts/search-by-radius',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'limit': limit,
      },
    );

    if (response.statusCode == 200) {
      return (response.data as List);
    } else {
      throw Exception('반경 검색 실패: ${response.statusCode}');
    }
  }

  /// 상세 조회
  static Future<Post> getPostDetail(int id) async {
    final dio = Dio();
    final response = await dio.get('$_baseUrl/posts/$id');
    if (response.statusCode == 200) {
      return Post.fromJson(response.data);
    } else {
      throw Exception('상세 조회 실패: ${response.statusCode}');
    }
  }

  /// 게시글 삭제
  static Future<void> deletePost(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('인증 토큰이 없습니다.');
    }

    final dio = Dio();
    final response = await dio.delete(
      '$_baseUrl/posts/$postId',
      options: Options(headers: {
        'Authorization': 'Bearer $token',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('삭제 실패: ${response.statusCode}');
    }
  }

  /// 최근 게시글 조회
  static Future<List<dynamic>> getRecentPosts() async {
    final dio = Dio();
    final response = await dio.get('$_baseUrl/posts/recent');
    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('최근 게시글 조회 실패: ${response.statusCode}');
    }
  }

  /// 특정 유저의 게시글 페이징 조회 (인스턴스 메서드 그대로 유지)
  Future<List<Post>> getPostsByUserId(
    int userId, {
    int page = 1,
    int pageSize = 5,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('인증 토큰이 없습니다.');
    }

    final dio = Dio();
    final response = await dio.get(
      '$_baseUrl/posts/user/$userId?page=$page&page_size=$pageSize',
      options: Options(headers: {
        'Authorization': 'Bearer $token',
      }),
    );

    if (response.statusCode == 200) {
      return (response.data as List)
          .map((json) => Post.fromJson(json))
          .toList();
    } else {
      throw Exception('유저 게시글 로딩 실패: ${response.statusCode}');
    }
  }
  static Future<List<MatchedPost>> getMatchedPosts(int postId) async {
    final url = Uri.parse('https://connect.io.kr/posts/match?post_id=$postId'); // 주소 수정
    final response = await http.post(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> matchedList = data['matched_posts'];
      return matchedList.map((e) => MatchedPost.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch matched posts');
    }
  }
}



