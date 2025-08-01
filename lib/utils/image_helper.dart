import 'package:image_picker/image_picker.dart';

class ImageHelper {
  static final _picker = ImagePicker();

  /// 갤러리에서 이미지 하나 선택
  static Future<XFile?> pickImage() {
    return _picker.pickImage(source: ImageSource.gallery);
  }
}
