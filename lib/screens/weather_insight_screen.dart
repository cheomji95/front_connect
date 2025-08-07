// weather_insight_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'location_picker_screen.dart';
import 'post_detail_screen.dart';

const String baseUrl = 'https://connect.io.kr';
const String accessToken = 'YOUR_ACCESS_TOKEN';
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

  final int itemsPerPage = 5;
  int currentPageIndex = 0;

  int get totalPages => (searchResults.length / itemsPerPage).ceil();

  List<PostItem> getPageItems() {
    final start = currentPageIndex * itemsPerPage;
    final end = (start + itemsPerPage).clamp(0, searchResults.length);
    return searchResults.sublist(start, end);
  }

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
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          selectedYear: selectedYear,
          selectedRegion: selectedRegion,
          selectedTags: selectedTags,
        ),
      ),
    );
    if (result != null) {
      setState(() => selectedLatLng = result);
      _onFilterChanged();
    }
  }

  void _goToPreviousPage() {
    if (currentPageIndex > 0) {
      setState(() => currentPageIndex--);
    }
  }

  void _goToNextPage() {
    if (currentPageIndex < totalPages - 1) {
      setState(() => currentPageIndex++);
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

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          searchResults = data.map((item) => PostItem.fromJson(item)).toList();
          currentPageIndex = 0;
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
            else ...[
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: getPageItems().length,
                itemBuilder: (context, index) {
                  final post = getPageItems()[index];
                  return ListTile(
                    leading: post.thumbnailUrl != null
                        ? Image.network(post.thumbnailUrl!, width: 48, height: 48, fit: BoxFit.cover)
                        : const Icon(Icons.image_not_supported),
                    title: Text(post.title),
                    subtitle: Text('${post.year}년 • ${post.region}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: post.id),
                        ),
                      );
                    }
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: currentPageIndex > 0 ? _goToPreviousPage : null,
                    child: const Text('← 이전'),
                  ),
                  const SizedBox(width: 16),
                  Text('페이지 ${currentPageIndex + 1} / $totalPages'),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: currentPageIndex < totalPages - 1 ? _goToNextPage : null,
                    child: const Text('다음 →'),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class PostItem {
  final int id;
  final String title;
  final String content;
  final String year;
  final String region;
  final List<dynamic> tags;
  final String createdAt;
  final String? thumbnailUrl;

  PostItem({
    required this.id,
    required this.title,
    required this.content,
    required this.year,
    required this.region,
    required this.tags,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> images = json['image_urls'] ?? json['images'] ?? [];
    return PostItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      year: json['year'].toString(),
      region: json['region'] ?? '',
      tags: json['tags'] ?? [],
      createdAt: json['created_at'] ?? '',
      thumbnailUrl: images.isNotEmpty ? '$baseUrl${images[0]}' : null,
    );
  }
}

