import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 친구 모델
class Friend {
  final String avatarUrl;
  final String nickname;
  Friend({required this.avatarUrl, required this.nickname});
}

class HomeModel extends ChangeNotifier {
  String? avatarUrl;
  String nickname = '';
  int matchRate = 0;
  List<Friend> friends = [];

  /// 홈화면 데이터 로드
  Future<void> fetchData() async {
    try {
      final res = await http.get(Uri.parse('https://api.example.com/home'));
      final json = jsonDecode(res.body);

      avatarUrl  = json['user']['avatarUrl'];
      nickname   = json['user']['nickname'];
      matchRate  = json['matchRate'];
      friends    = (json['friends'] as List)
          .map((e) => Friend(
                avatarUrl: e['avatarUrl'],
                nickname: e['nickname'],
              ))
          .toList();

      notifyListeners();
    } catch (e) {
      // TODO: 에러 처리
    }
  }
}
