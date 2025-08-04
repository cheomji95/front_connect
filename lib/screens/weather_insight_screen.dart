import 'package:flutter/material.dart';

class WeatherInsightScreen extends StatelessWidget {
  const WeatherInsightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨 통계 보기'),
      ),
      body: const Center(
        child: Text(
          '날씨 기반 게시글 통계 또는 감정 분석 결과 등을 보여줄 수 있어요.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
