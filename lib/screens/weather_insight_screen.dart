// weather_insight_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'location_picker_screen.dart';

const String baseUrl = 'https://connect.io.kr'; // 실제 배포 주소로 변경
const String accessToken = 'YOUR_ACCESS_TOKEN'; // 토큰 교체 필수
const double searchRadius = 30.0;

class WeatherInsightScreen extends StatefulWidget {
  const WeatherInsightScreen({super.key});

  @override
  State<WeatherInsightScreen> createState() => _WeatherInsightScreenState();
}

class _WeatherInsightScreenState extends State<WeatherInsightScreen> {
  String? selectedYear;
  String? selectedRegion;
  LatLng? selectedLatLng;
  final tagController = TextEditingController();
  final List<String> selectedTags = [];

  final List<String> years =
      List.generate(30, (i) => (DateTime.now().year - i).toString());
  final List<String> regions = ['서울', '경기', '강원', '충청', '전라', '경상', '제주', '울릉'];
  final List<String> tagHints = ['추억', '여행', '일기', '기록', '맛집', '풍경', '산책', '카페', '우연', '친구'];

  List<PostItem> searchResults = [];
  bool isLoading = false;

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !selectedTags.contains(tag)) {
      setState(() => selectedTags.add(tag));
      _onFilterChanged();
    }
  }

  void _removeTag(String tag) {
    setState(() => selectedTags.remove(tag));
    _onFilterChanged();
  }

  void _onFilterChanged() {
    searchPosts();
  }

  Future<void> _selectLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() => selectedLatLng = result);
      _onFilterChanged();
    }
  }

  Future<void> searchPosts() async {
    setState(() => isLoading = true);

    try {
      final queryParams = {
        if (selectedYear != null && selectedYear!.isNotEmpty)
          'year': selectedYear!,
        if (selectedRegion != null && selectedRegion!.isNotEmpty)
          'region': selectedRegion!,
        if (selectedTags.isNotEmpty) 'tags': selectedTags.join(','),
        if (selectedLatLng != null) ...{
          'lat': selectedLatLng!.latitude.toString(),
          'lng': selectedLatLng!.longitude.toString(),
          'radius': searchRadius.toString(),
        }
      };

      final uri = Uri.parse('$baseUrl/posts/search').replace(queryParameters: queryParams);

      print('▶️ 검색 요청 URI: $uri');

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
      });

      print('▶️ 응답 상태: ${response.statusCode}');
      print('▶️ 응답 바디: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          searchResults = data.map((item) => PostItem.fromJson(item)).toList();
        });
      } else {
        throw Exception('검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('검색 오류: $e');
      setState(() => searchResults = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('날씨 통계 보기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selectedYear,
              decoration: const InputDecoration(labelText: '연도'),
              items: years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (val) {
                setState(() => selectedYear = val);
                _onFilterChanged();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRegion,
              decoration: const InputDecoration(labelText: '지역'),
              items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) {
                setState(() => selectedRegion = val);
                _onFilterChanged();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tagController,
                    decoration: const InputDecoration(labelText: '태그'),
                    onSubmitted: (v) {
                      _addTag(v);
                      tagController.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    _addTag(tagController.text);
                    tagController.clear();
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: tagHints.map((hint) {
                return ActionChip(
                  label: Text('# $hint'),
                  onPressed: () => _addTag(hint),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: selectedTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _selectLocation,
              icon: const Icon(Icons.place),
              label: Text(
                selectedLatLng != null
                    ? '선택된 위치: (${selectedLatLng!.latitude.toStringAsFixed(4)}, ${selectedLatLng!.longitude.toStringAsFixed(4)})'
                    : '지도에서 위치 선택',
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text('📄 검색 결과', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (searchResults.isEmpty)
              const Text('검색 결과가 없습니다.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final post = searchResults[index];
                  return ListTile(
                    leading: post.thumbnailUrl != null
                        ? Image.network(post.thumbnailUrl!, width: 48, height: 48, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(post.title),
                    subtitle: Text('${post.year}년 • ${post.region}'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('지도에서 게시글 ${post.id} 선택 예정')),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class PostItem {
  final int id;
  final String title;
  final String year;
  final String region;
  final String? thumbnailUrl;

  PostItem({
    required this.id,
    required this.title,
    required this.year,
    required this.region,
    this.thumbnailUrl,
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> images = json['image_urls'] ?? json['images'] ?? [];
    return PostItem(
      id: json['id'],
      title: json['title'],
      year: json['year'].toString(), // int → string
      region: json['region'],
      thumbnailUrl: images.isNotEmpty ? '$baseUrl${images[0]}' : null,
    );
  }
}



