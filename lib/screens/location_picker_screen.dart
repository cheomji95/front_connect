// lib/screens/location_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;

  LatLng? _currentPosition; // 초기 카메라 위치(현재 위치 또는 기본값)
  LatLng? _selected;        // 선택된 좌표
  Marker? _marker;          // 선택 마커

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final granted = await _ensureLocationPermission();
    if (!granted) {
      // 권한 거부 시 서울로 기본 이동
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

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var status = await Permission.location.status;
    if (status.isGranted) return true;
    status = await Permission.location.request();
    return status.isGranted;
  }

  // 🔍 간단 검색(지오코딩): 입력값 그대로 주소→좌표 변환
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('검색 결과가 없습니다.')));
        return;
      }
      final first = locations.first;
      final target = LatLng(first.latitude, first.longitude);
      _moveAndMark(target, showSnack: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('검색 실패: $e')));
    }
  }

  // 지도 탭으로 선택
  void _onMapTap(LatLng point) => _moveAndMark(point, showSnack: true);

  // 카메라 이동 + 마커 표시 + 선택값 저장
  Future<void> _moveAndMark(LatLng target, {bool showSnack = false}) async {
    // 간단한 역지오코딩으로 안내 문구
    String label = '위치 선택됨';
    try {
      final placemarks =
          await placemarkFromCoordinates(target.latitude, target.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        label =
            "${p.administrativeArea ?? ''} ${p.locality ?? ''} ${p.subLocality ?? ''}"
                .trim();
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

    // 카메라 이동(적당한 줌)
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final markers = <Marker>{if (_marker != null) _marker!};

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
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 14.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: _onMapTap,
            markers: markers,
          ),
          // 하단 저장 버튼
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop<LatLng>(context, _selected),
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

// 🔍 간단 검색 Delegate (자동완성 없이, 입력 그대로 지오코딩)
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
