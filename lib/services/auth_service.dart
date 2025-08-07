import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../core/jwt_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthService {
  static final Dio dio = Dio(BaseOptions(baseUrl: 'https://connect.io.kr'));

  /// 인터셉터 설정 (토큰 자동 주입·갱신)
  static void init() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await JwtStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException err, handler) async {
        if (err.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final newToken = await JwtStorage.getAccessToken();
            if (newToken != null) {
              err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retry = await dio.request(
                err.requestOptions.path,
                options: Options(
                  method: err.requestOptions.method,
                  headers: err.requestOptions.headers,
                ),
                data: err.requestOptions.data,
                queryParameters: err.requestOptions.queryParameters,
              );
              return handler.resolve(retry);
            }
          }
        }
        handler.next(err);
      },
    ));
  }

  /// 액세스 토큰 갱신
  static Future<bool> _refreshToken() async {
    final refresh = await JwtStorage.getRefreshToken();
    if (refresh == null) return false;

    try {
      final resp = await dio.post(
        '/auth/refresh',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refresh,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final access = resp.data['access_token'] as String?;
      if (access != null) {
        await JwtStorage.setAccessToken(access);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<Response> signup({
    required String username,
    required String password,
    required String phoneNumber,
    required String nickname,  // ✅ 추가
  }) async {
    try {
      final response = await dio.post(
        '/auth/signup',
        data: {
          'username': username,
          'password': password,
          'phone_number': phoneNumber,
          'nickname': nickname,  // ✅ 함께 전송
        },
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      print('📤 전송 데이터: {username: $username, password: $password, phone_number: $phoneNumber, nickname: $nickname}');
      print('✅ 응답 상태: ${response.statusCode}');
      print('✅ 응답 데이터: ${response.data}');

      return response;
    } on DioException catch (e) {
      print('❌ Dio 예외 발생');
      print('📥 응답 상태: ${e.response?.statusCode}');
      print('📥 응답 데이터: ${e.response?.data}');
      rethrow;
    }
  }

  /// 로그인 + 유저 정보 반환
static Future<Map<String, dynamic>> login({
  required String username,
  required String password,
}) async {
  final form = FormData.fromMap({
    'username': username,
    'password': password,
    'grant_type': 'password',
  });

  // 1) 로그인 요청
  final loginResp = await dio.post(
    '/auth/login',
    data: form,
    options: Options(contentType: Headers.formUrlEncodedContentType),
  );

  final access = loginResp.data['access_token'] as String?;
  final refresh = loginResp.data['refresh_token'] as String?;

  if (access == null || refresh == null) {
    throw Exception('로그인 응답에 토큰이 없습니다.');
  }

  // ✅ 토큰 저장 (순서 중요)
  await JwtStorage.setAccessToken(access);
  await JwtStorage.setRefreshToken(refresh);
  print('✅ access_token 저장됨: $access');
  print('✅ refresh_token 저장됨: $refresh');

  // 2) 프로필 정보 요청
  final profileResp = await dio.get('/users/me');
  final userId = profileResp.data['id'];

  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('user_id', userId);
  print('📦 [SAVE] 유저 ID 저장 완료');

  return profileResp.data;
}


  /// OTP 전송
  static Future<Response> sendOtp(String phone) {
    return dio.post(
      '/auth/send-otp',
      data: {'phone_number': phone},
    );
  }

  /// OTP 검증
  static Future<Response> verifyOtp(String phone, String code) {
    return dio.post(
      '/auth/verify-otp',
      data: {'phone_number': phone, 'code': code},
    );
  }

  /// 프로필 사진 업로드
  static Future<Response> uploadAvatar(File file) async {
    final fileName = path.basename(file.path);
    final mp = await MultipartFile.fromFile(file.path, filename: fileName);
    final form = FormData.fromMap({'file': mp});
    final token = await JwtStorage.getAccessToken();

    return dio.post(
      '/upload/avatar',
      data: form,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
  // AuthService.dart 내부
  static Future<void> deleteAccount() async {
    final token = await JwtStorage.getAccessToken(); // JWT 토큰 가져오기
    await dio.delete(
      '/users/me', // 백엔드의 회원탈퇴 엔드포인트
      options: Options(
        headers: {
          'Authorization': 'Bearer $token', // 인증 헤더 포함
        },
      ),
    );
  }
}

