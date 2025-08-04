import 'package:flutter/material.dart';

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

  final List<String> years = List.generate(30, (i) => (DateTime.now().year - i).toString());
  final List<String> regions = ['서울', '경기', '강원', '충청', '전라', '경상', '제주', '울릉'];
  final List<String> tagHints = ['추억', '여행', '일기', '기록', '맛집', '풍경', '산책', '카페', '우연', '친구'];

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !selectedTags.contains(tag)) {
      setState(() => selectedTags.add(tag));
    }
  }

  void _removeTag(String tag) {
    setState(() => selectedTags.remove(tag));
  }

  void _onFilterChanged() {
    // 여기에 연도, 지역, 태그 기반 게시글 검색 API 호출 로직 연결 예정
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
                      _onFilterChanged();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    _addTag(tagController.text);
                    tagController.clear();
                    _onFilterChanged();
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
                  onPressed: () {
                    _addTag(hint);
                    _onFilterChanged();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: selectedTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  onDeleted: () {
                    _removeTag(tag);
                    _onFilterChanged();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text('※ 검색 결과 및 지도는 다음 단계에서 표시됩니다.'),
          ],
        ),
      ),
    );
  }
}

