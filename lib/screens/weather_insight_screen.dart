// weather_insight_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_screen.dart';

class WeatherInsightScreen extends StatefulWidget {
  const WeatherInsightScreen({super.key});

  @override
  State<WeatherInsightScreen> createState() => _WeatherInsightScreenState();
}

class _WeatherInsightScreenState extends State<WeatherInsightScreen> {
  String? selectedYear;
  String? selectedRegion;
  final tagController = TextEditingController();
  final List<String> selectedTags = [];

  double? selectedLatitude;
  double? selectedLongitude;

  final List<String> years = List.generate(30, (i) => (DateTime.now().year - i).toString());
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
    _fetchPostsByFilter();
  }

  Future<void> _selectLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );

    if (result != null) {
      setState(() {
        selectedLatitude = result.latitude;
        selectedLongitude = result.longitude;
        _onFilterChanged();
      });
    }
  }

  Future<void> _fetchPostsByFilter() async {
    setState(() => isLoading = true);

    try {
      // TODO: 백엔드 연동 시 여기에 API 호출 추가
      await Future.delayed(const Duration(seconds: 1));

      setState(() => searchResults = []); // 초기화 또는 API 결과 대입
    } catch (e) {
      debugPrint('❌ 게시글 검색 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
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
              onChanged: (val) => setState(() => selectedYear = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedRegion,
              decoration: const InputDecoration(labelText: '지역'),
              items: regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => setState(() => selectedRegion = val),
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
                selectedLatitude != null && selectedLongitude != null
                    ? '선택된 위치: (${selectedLatitude!.toStringAsFixed(4)}, ${selectedLongitude!.toStringAsFixed(4)})'
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
                      // TODO: 지도 이동 및 상세 연결 예정
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
    return PostItem(
      id: json['id'],
      title: json['title'],
      year: json['year'],
      region: json['region'],
      thumbnailUrl: json['image_urls'] != null && json['image_urls'].isNotEmpty
          ? 'https://connect.io.kr${json['image_urls'][0]}'
          : null,
    );
  }
}


