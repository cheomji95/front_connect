// lib/screens/edit_post_screen.dart
// 222
import 'dart:convert';   
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'location_picker_screen.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;
  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<XFile> _newImages = [];

  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late String _year;
  late String _region;
  late List<String> _tags;
  late List<String> _existingImageUrls;

  double? _latitude;
  double? _longitude;

  final List<String> _yearOptions =
      List.generate(30, (i) => (DateTime.now().year - i).toString());
  final List<String> _regionOptions = [
    '서울', '경기', '강원', '충청', '전라', '경상', '제주', '울릉',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    _titleCtrl = TextEditingController(text: p.title);
    _contentCtrl = TextEditingController(text: p.content);
    _year = p.year;
    _region = p.region;
    _tags = p.tags.map((m) => (m['name'] ?? '').toString()).where((e) => e.isNotEmpty).toList();
    _existingImageUrls = List<String>.from(p.imageUrls);
    _latitude = p.latitude;
    _longitude = p.longitude;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => _newImages.addAll(picked));
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      final contentItemsJson = jsonEncode([
        {'type': 'text', 'data': _contentCtrl.text.trim()}
      ]);

      await PostService.updatePost(
        postId: widget.post.id,
        title: _titleCtrl.text.trim(),
        content_items: contentItemsJson,
        year: _year,
        region: _region,
        tags: _tags,
        images: _newImages,
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        existingImageUrls: _existingImageUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 수정되었습니다.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패: $e')),
      );
    }
  }

  void _addTag(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (!_tags.contains(t)) {
      setState(() => _tags.add(t));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = (_latitude != null && _longitude != null);

    return Scaffold(
      appBar: AppBar(title: const Text('게시글 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '제목'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(labelText: '내용'),
                maxLines: 6,
                validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _year.isEmpty ? null : _year,
                items: _yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (v) => setState(() => _year = v ?? ''),
                decoration: const InputDecoration(labelText: '연도'),
                validator: (v) => (v == null || v.isEmpty) ? '연도를 선택하세요' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _region.isEmpty ? null : _region,
                items: _regionOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _region = v ?? ''),
                decoration: const InputDecoration(labelText: '지역'),
                validator: (v) => (v == null || v.isEmpty) ? '지역을 선택하세요' : null,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _tags.map(
                  (t) => Chip(
                    label: Text('# $t'),
                    onDeleted: () => setState(() => _tags.remove(t)),
                  ),
                ).toList(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: '태그 추가'),
                onFieldSubmitted: _addTag,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.place),
                label: Text(
                  hasLocation
                      ? '위치 선택 완료 (${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)})'
                      : '위치 지정',
                ),
              ),
              const SizedBox(height: 16),
              if (_existingImageUrls.isNotEmpty) ...[
                const Text('기존 이미지:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final imageUrl = _existingImageUrls[index];
                      final fullUrl = 'http://connect.io.kr$imageUrl';
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              fullUrl,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, color: Colors.red),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _existingImageUrls.removeAt(index)),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('이미지 선택'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _newImages.isEmpty
                          ? '선택된 이미지 없음'
                          : _newImages.map((e) => e.name).join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('수정 완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
