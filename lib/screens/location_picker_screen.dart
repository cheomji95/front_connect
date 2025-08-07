// location_picker_screen.dart (수정됨)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import 'post_detail_screen.dart';

const String baseUrl = 'https://connect.io.kr';
const String accessToken = 'YOUR_ACCESS_TOKEN';

class LocationPickerScreen extends StatefulWidget {
  final String? selectedYear;
  final String? selectedRegion;
  final List<String> selectedTags;

  const LocationPickerScreen({
    super.key,
    this.selectedYear,
    this.selectedRegion,
    required this.selectedTags,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  LatLng? _selected;
  Marker? _marker;
  Set<Marker> _postMarkers = {};
  Post? _selectedPost;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _fetchMarkersFromSearch();
  }

  Future<void> _initLocation() async {
    final granted = await _ensureLocationPermission();
    if (!granted) {
      setState(() => _currentPosition = const LatLng(37.5665, 126.9780));
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      setState(() => _currentPosition = const LatLng(37.5665, 126.9780));
    }
  }

  Future<void> _fetchMarkersFromSearch() async {
    final queryParams = {
      if (widget.selectedYear != null) 'year': widget.selectedYear!,
      if (widget.selectedRegion != null) 'region': widget.selectedRegion!,
      if (widget.selectedTags.isNotEmpty) 'tags': widget.selectedTags.join(','),
    };

    final uri = Uri.parse('$baseUrl/posts/search').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $accessToken',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _postMarkers = data.map((post) {
            final lat = post['latitude'];
            final lng = post['longitude'];
            if (lat == null || lng == null) return null;
            return Marker(
              markerId: MarkerId('post_${post['id']}'),
              position: LatLng(lat, lng),
              onTap: () {
                setState(() {
                  _selectedPost = Post.fromJson(post);
                });
              },
            );
          }).whereType<Marker>().toSet();
        });
      }
    } catch (e) {
      debugPrint('📌 마커 불러오기 실패: $e');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var status = await Permission.location.status;
    if (status.isGranted) return true;
    status = await Permission.location.request();
    return status.isGranted;
  }

  Future<void> _openSearch() async {
    final q = await showSearch<String?>(
      context: context,
      delegate: _SimpleAddressSearchDelegate(),
    );
    if (q == null || q.trim().isEmpty) return;

    try {
      final locations = await locationFromAddress(q.trim());
      if (locations.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('검색 결과가 없습니다.')));
        return;
      }
      final first = locations.first;
      final target = LatLng(first.latitude, first.longitude);
      _moveAndMark(target, showSnack: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
    }
  }

  void _onMapTap(LatLng point) => _moveAndMark(point, showSnack: true);

  Future<void> _moveAndMark(LatLng target, {bool showSnack = false}) async {
    String label = '위치 선택됨';
    try {
      final placemarks = await placemarkFromCoordinates(target.latitude, target.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        label = "${p.administrativeArea ?? ''} ${p.locality ?? ''} ${p.subLocality ?? ''}".trim();
      }
    } catch (_) {}

    setState(() {
      _selected = target;
      _marker = Marker(
        markerId: const MarkerId('picked'),
        position: target,
        draggable: true,
        onDragEnd: (pos) => _selected = pos,
        infoWindow: InfoWindow(title: label),
      );
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );

    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 $label\n(${target.latitude}, ${target.longitude})'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final markers = <Marker>{if (_marker != null) _marker!, ..._postMarkers};

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택'),
        actions: [
          IconButton(
            tooltip: '주소/장소 검색',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: _onMapTap,
            markers: markers,
          ),

          if (_selectedPost != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 80,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(postId: _selectedPost!.id),
                    ),
                  );
                },
                child: Card(
                  elevation: 4,
                  child: ListTile(
                    leading: _selectedPost!.imageUrls.isNotEmpty
                        ? Image.network('$baseUrl${_selectedPost!.imageUrls[0]}', width: 50, height: 50, fit: BoxFit.cover)
                        : const Icon(Icons.image),
                    title: Text(_selectedPost!.title),
                    subtitle: Text('${_selectedPost!.year}년 · ${_selectedPost!.region}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected == null ? null : () => Navigator.pop<LatLng>(context, _selected),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _selected == null
                        ? '지도를 탭하여 위치를 선택하세요'
                        : '이 위치로 저장 (${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)})',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleAddressSearchDelegate extends SearchDelegate<String?> {
  _SimpleAddressSearchDelegate()
      : super(
          searchFieldLabel: '장소/주소 입력 (예: 에버랜드, 서울시청)',
          textInputAction: TextInputAction.search,
        );

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            onPressed: () => query = '',
            icon: const Icon(Icons.clear),
            tooltip: '지우기',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('검색어를 입력하세요.'));
    }
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.search),
          title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: const Text('이 텍스트로 위치 검색'),
          onTap: () => close(context, query),
        ),
      ],
    );
  }
}
