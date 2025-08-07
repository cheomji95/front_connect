// my_post_create_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_screen.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  double? selectedLatitude;
  double? selectedLongitude;

  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final tagController = TextEditingController();

  String? selectedYear;
  String? selectedRegion;
  final List<String> tags = [];
  List<XFile> images = [];

  final years = List.generate(30, (i) => (DateTime.now().year - i).toString());
  final regions = ['서울', '경기', '강원', '충청', '전라', '경상', '제주', '울릉'];

  static const List<String> _tagHints = [
    '추억', '여행', '일기', '기록', '맛집', '풍경', '산책', '카페', '우연', '친구'
  ];

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (!tags.contains(tag)) {
      setState(() => tags.add(tag));
    }
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => images = picked);
    }
  }

  Future<void> selectLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen(
        selectedYear: selectedYear,
        selectedRegion: selectedRegion,
        selectedTags: const [],
      )),
    );

    if (result != null) {
      setState(() {
        selectedLatitude = result.latitude;
        selectedLongitude = result.longitude;
      });
    }
  }

  Future<void> submitPost() async {
    final title = titleController.text.trim();
    final contentText = contentController.text.trim();

    if (title.isEmpty ||
        contentText.isEmpty ||
        selectedYear == null ||
        selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 필수 항목을 입력해주세요.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 불러올 수 없습니다.')),
      );
      return;
    }

    try {
      // content_items JSON 문자열로 변환 (서버 요구 포맷)
      final contentItemsJson = jsonEncode([
        {"type": "text", "data": contentText}
      ]);

      // tagsJson 변수 삭제

      await PostService.createPost(
        title: title,
        content_items: contentItemsJson,
        year: selectedYear!,
        region: selectedRegion!,
        tags: tags,
        userId: userId,
        images: images,
        latitude: selectedLatitude ?? 0.0,
        longitude: selectedLongitude ?? 0.0,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 등록되었습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시글 작성')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '내용'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedYear,
              items: years
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) => setState(() => selectedYear = val),
              decoration: const InputDecoration(labelText: '연도'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedRegion,
              items: regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) => setState(() => selectedRegion = val),
              decoration: const InputDecoration(labelText: '지역'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tagController,
                    decoration: const InputDecoration(
                      labelText: '태그',
                      hintText: '예: 추억, 여행, 일기, 기록…',
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      _addTag(v);
                      tagController.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '태그 추가',
                  onPressed: () {
                    final tag = tagController.text;
                    if (tag.trim().isEmpty) return;
                    _addTag(tag);
                    tagController.clear();
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: -4,
              children: _tagHints
                  .map((s) => ActionChip(
                        label: Text('# $s'),
                        onPressed: () => _addTag(s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: tags
                  .map((tag) => Chip(
                        label: Text(tag),
                        onDeleted: () => setState(() => tags.remove(tag)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: selectLocation,
              icon: const Icon(Icons.place),
              label: Text(selectedLatitude != null && selectedLongitude != null
                  ? '위치 선택 완료'
                  : '위치 지정'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: pickImages,
                  icon: const Icon(Icons.image),
                  label: const Text('이미지 선택'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    images.map((e) => e.name).join(', '),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: submitPost,
                child: const Text('작성 완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
