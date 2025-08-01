import 'package:flutter/material.dart';
import '../services/profile_service.dart'; // ProfileData를 사용하기 위해 import

class AvatarModel extends ChangeNotifier {
  String? _url;
  String? _nickname;

  String? get url => _url;
  String? get nickname => _nickname;

  /// 간단한 업데이트용 (url만 필수, 닉네임은 선택)
  void update(String? newUrl, [String? newNickname]) {
    _url = newUrl;
    if (newNickname != null) {
      _nickname = newNickname;
    }
    notifyListeners();
  }

  /// ProfileData 기반으로 로컬 상태 최신화
  void updateLocal(ProfileData data) {
    _url = data.avatarUrl;
    _nickname = data.nickname;
    notifyListeners();
  }
}
