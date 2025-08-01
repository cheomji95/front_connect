// lib/screens/map_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/post_service.dart';
import '../models/post_model.dart';
import 'post_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  Marker? _selectedMarker;

  // 반경 & 결과
  double _radiusKm = 2.0;
  bool _loading = false;
  final Set<Marker> _postMarkers = {};
  List<dynamic> _results = [];

  // 바텀시트(드래그 가능) 제어
  final _sheetCtrl = DraggableScrollableController();
  static const double _minSheetSize = 0.14; // 손잡이 + 슬라이더가 보이는 최소 높이
  static const double _maxSheetSize = 0.62; // 최대 높이
  static const Duration _animDur = Duration(milliseconds: 240);

  // 페이징 (리스트는 5개씩)
  int _page = 1;
  static const int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final granted = await _ensureLocationPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // fallback: 서울
      setState(() => _currentPosition = const LatLng(37.5665, 126.9780));
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var status = await Permission.location.status;
    if (status.isGranted) return true;
    status = await Permission.location.request();
    return status.isGranted;
  }

  // -----------------------------
  // 🔍 간단 주소/장소 검색 (의존성 추가 없음)
  // -----------------------------
  Future<void> _openSimpleSearch() async {
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
      await _handleMapTap(target); // 기존 로직 재사용
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('검색 실패: $e')));
    }
  }

  Future<void> _handleMapTap(LatLng point) async {
    // 바텀시트 접기(지도를 크게 보기)
    if (_sheetCtrl.isAttached) {
      _sheetCtrl.animateTo(
        _minSheetSize,
        duration: _animDur,
        curve: Curves.easeOut,
      );
    }

    // 역지오코딩으로 행정명
    String address = '행정명 불러오기 실패';
    try {
      final placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address =
            "${p.administrativeArea ?? ''} ${p.locality ?? ''} ${p.subLocality ?? ''}".trim();
      }
    } catch (_) {}

    setState(() {
      _selectedMarker = Marker(
        markerId: const MarkerId('selected-location'),
        position: point,
        infoWindow: InfoWindow(title: address),
      );
      _postMarkers.clear();
      _results = [];
      _page = 1;
    });

    // 카메라를 반경이 모두 보이도록 맞추기
    _fitCameraToRadius(point, _radiusKm);

    // 해당 반경에 게시글 로드
    await _fetchPostsInRadius(point);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 $address\n(${point.latitude}, ${point.longitude})'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _fitCameraToRadius(LatLng center, double radiusKm) {
    if (_mapController == null) return;

    // 위도 1도 ≈ 111km, 경도 1도 ≈ 111km * cos(lat)
    final latDelta = radiusKm / 111.0;
    final lngDelta =
        radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180.0));

    final sw = LatLng(center.latitude - latDelta, center.longitude - lngDelta);
    final ne = LatLng(center.latitude + latDelta, center.longitude + lngDelta);
    final bounds = LatLngBounds(southwest: sw, northeast: ne);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 48.0),
    );
  }

  Future<void> _fetchPostsInRadius(LatLng center) async {
    setState(() => _loading = true);
    try {
      final posts = await PostService.getPostsByRadius(
        lat: center.latitude,
        lng: center.longitude,
        radiusKm: _radiusKm,
        limit: 200,
      );

      // 1) 좌표 있는 것만 취합 + 거리 계산
      final List<Map<String, dynamic>> withDistance = posts
          .where((p) => p['latitude'] != null && p['longitude'] != null)
          .map<Map<String, dynamic>>((p) {
        final lat = (p['latitude'] as num).toDouble();
        final lng = (p['longitude'] as num).toDouble();

        final meters = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          lat,
          lng,
        );
        final distanceKm = meters / 1000.0;

        final map = Map<String, dynamic>.from(p as Map);
        map['distanceKm'] = distanceKm;
        return map;
      }).toList();

      // 2) 거리 오름차순 정렬
      withDistance.sort(
        (a, b) =>
            (a['distanceKm'] as double).compareTo(b['distanceKm'] as double),
      );

      // 3) 마커 구성 (좌표 대신 "거리" 표시)
      final markers = withDistance.map<Marker>((p) {
        final pos = LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        );
        final distanceKm = (p['distanceKm'] as double);
        return Marker(
          markerId: MarkerId('post-${p['id']}'),
          position: pos,
          infoWindow: InfoWindow(
            title: (p['title'] ?? '제목 없음').toString(),
            snippet: '${distanceKm.toStringAsFixed(2)} km',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }).toSet();

      setState(() {
        _postMarkers
          ..clear()
          ..addAll(markers);
        _results = withDistance; // 거리 포함 + 정렬된 결과
        _page = 1;
      });

      // 검색 후 카메라 다시 맞추기(선택)
      _fitCameraToRadius(center, _radiusKm);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 현재 페이지의 결과
  List<dynamic> get _pagedItems {
    final start = (_page - 1) * _pageSize;
    final end = (_page * _pageSize).clamp(0, _results.length);
    if (start >= _results.length || start < 0) return const [];
    return _results.sublist(start, end);
  }

  int get _totalPages =>
      _results.isEmpty ? 1 : ((_results.length - 1) ~/ _pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final circles = <Circle>{};
    if (_selectedMarker != null) {
      circles.add(
        Circle(
          circleId: const CircleId('radius'),
          center: _selectedMarker!.position,
          radius: _radiusKm * 1000, // km → m
          fillColor: Colors.blue.withOpacity(0.12),
          strokeColor: Colors.blueAccent,
          strokeWidth: 2,
        ),
      );
    }

    final markers = <Marker>{
      if (_selectedMarker != null) _selectedMarker!,
      ..._postMarkers,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('지도에서 지역 선택'),
        actions: [
          IconButton(
            tooltip: '주소/장소 검색',
            icon: const Icon(Icons.search),
            onPressed: _openSimpleSearch,
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
            onTap: _handleMapTap,
            markers: markers,
            circles: circles,
          ),

          // 드래그 가능한 바텀 시트
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: _minSheetSize,
            minChildSize: _minSheetSize,
            maxChildSize: _maxSheetSize,
            snap: true,
            builder: (context, scrollController) {
              // 하나의 스크롤러로 통일 (오버플로우 방지)
              return Material(
                elevation: 12,
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    // 헤더(손잡이, 슬라이더, 로딩, 구분선)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 반경 슬라이더
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Text('반경'),
                                const Spacer(),
                                Text('${_radiusKm.toStringAsFixed(1)} km'),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Slider(
                              value: _radiusKm,
                              min: 0.5,
                              max: 10.0,
                              divisions: 19, // 0.5 단위
                              label: '${_radiusKm.toStringAsFixed(1)} km',
                              onChanged: (v) async {
                                setState(() => _radiusKm = v);
                                if (_selectedMarker != null) {
                                  await _fetchPostsInRadius(
                                      _selectedMarker!.position);
                                }
                              },
                            ),
                          ),
                          if (_loading)
                            const LinearProgressIndicator(minHeight: 2),
                          const Divider(height: 1),
                        ],
                      ),
                    ),

                    // 결과 리스트(거리순, 5개 페이지)
                    if (_results.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('검색 결과가 없습니다.')),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _pagedItems[index]
                                as Map<String, dynamic>;
                            final id = item['id'] as int;
                            final title =
                                (item['title'] ?? '제목 없음').toString();
                            final region =
                                (item['region'] ?? '').toString();
                            final year = (item['year'] ?? '').toString();
                            final distanceKm =
                                (item['distanceKm'] as double?) ?? 0.0;

                            return ListTile(
                              leading: const Icon(Icons.place),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                  '${distanceKm.toStringAsFixed(2)} km · $region · $year'),
                              onTap: () async {
                                try {
                                  final Post detail =
                                      await PostService.getPostDetail(id);
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PostDetailScreen(post: detail),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('상세 조회 실패: $e')),
                                  );
                                }
                              },
                            );
                          },
                          childCount: _pagedItems.length,
                        ),
                      ),

                    // 페이지네이션(스크롤 내부)
                    if (_results.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(8, 4, 8, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: '이전',
                                onPressed: _page > 1
                                    ? () => setState(() => _page--)
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  borderRadius:
                                      BorderRadius.circular(22),
                                ),
                                child: Text(
                                  '$_page / $_totalPages',
                                  style: const TextStyle(
                                      color: Colors.white),
                                ),
                              ),
                              IconButton(
                                tooltip: '다음',
                                onPressed: _page < _totalPages
                                    ? () => setState(() => _page++)
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 🔍 간단 검색 Delegate (자동완성 없이 입력값 그대로 검색)
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
    // 단일 옵션: 입력값 그대로 검색
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






