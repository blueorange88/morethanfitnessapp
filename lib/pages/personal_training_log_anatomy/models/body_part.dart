import 'package:flutter/material.dart';
import 'anatomy_log.dart';

class BodyPart {
  final String id;
  final String label;
  final BodyView view;
  final List<String> recommendedExercises;
  final IconData icon;

  const BodyPart({
    required this.id,
    required this.label,
    required this.view,
    required this.recommendedExercises,
    required this.icon,
  });
}

const List<BodyPart> kBodyParts = [
  // 앞면
  BodyPart(
    id: 'chest',
    label: '가슴',
    view: BodyView.front,
    recommendedExercises: ['벤치프레스', '덤벨 플라이', '푸쉬업', '케이블 크로스오버'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'shoulder',
    label: '어깨',
    view: BodyView.front,
    recommendedExercises: ['숄더프레스', '사이드 레터럴 레이즈', '프론트 레이즈', '페이스풀'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'biceps',
    label: '이두',
    view: BodyView.front,
    recommendedExercises: ['바벨 컬', '덤벨 컬', '해머 컬', '케이블 컬'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'abs',
    label: '복근',
    view: BodyView.front,
    recommendedExercises: ['크런치', '레그레이즈', '플랭크', '데드버그'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'quad',
    label: '대퇴사두',
    view: BodyView.front,
    recommendedExercises: ['스쿼트', '레그프레스', '런지', '레그 익스텐션'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'adductor',
    label: '내전근',
    view: BodyView.front,
    recommendedExercises: ['수모 스쿼트', '어덕터 머신', '사이드 런지', '케이블 어덕션'],
    icon: Icons.accessibility_new_rounded,
  ),

  // 뒷면
  BodyPart(
    id: 'trapezius',
    label: '승모근',
    view: BodyView.back,
    recommendedExercises: ['바벨 슈러그', '덤벨 슈러그', '페이스풀', '업라이트 로우'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'lat',
    label: '광배근',
    view: BodyView.back,
    recommendedExercises: ['풀업', '랫풀다운', '시티드 로우', '원암 덤벨 로우'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'triceps',
    label: '삼두',
    view: BodyView.back,
    recommendedExercises: ['트라이셉스 푸쉬다운', '오버헤드 익스텐션', '딥스', '클로즈그립 벤치'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'lower_back',
    label: '허리',
    view: BodyView.back,
    recommendedExercises: ['데드리프트', '굿모닝', '백 익스텐션', '버드독'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'glute',
    label: '둔근',
    view: BodyView.back,
    recommendedExercises: ['힙쓰러스트', '루마니안 데드리프트', '케이블 킥백', '글루트 브릿지'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'hamstring',
    label: '햄스트링',
    view: BodyView.back,
    recommendedExercises: ['레그 컬', '루마니안 데드리프트', '굿모닝', '노르딕 컬'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'calf',
    label: '종아리',
    view: BodyView.back,
    recommendedExercises: ['스탠딩 카프레이즈', '시티드 카프레이즈', '동키 카프레이즈'],
    icon: Icons.accessibility_new_rounded,
  ),
];
