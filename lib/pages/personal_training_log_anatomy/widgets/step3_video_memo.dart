import 'package:flutter/material.dart';

class Step3VideoMemo extends StatelessWidget {
  const Step3VideoMemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.video_library_outlined,
              size: 36, color: Color(0xFF9CA3AF)),
          SizedBox(height: 12),
          Text('영상·음성 기능 준비 중',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text(
            '이번 단계에서는 영상 업로드와 음성 추출을 저장하지 않습니다. 기록 메모는 이전 단계에서 입력해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
