import 'package:flutter/material.dart';
import 'anatomy_log.dart';

class BodyPart {
  final String id;
  final String label;
  final BodyView view;

  /// [view] 외에 바디맵에서 함께 보이는 면(예: 측면삼각근은 앞·뒷면 모두).
  final List<BodyView> extraViews;
  final List<String> recommendedExercises;
  final IconData icon;

  /// 예전 기록의 id 호환용. 바디맵에는 없고, 선택된 상태일 때만 칩으로 보인다.
  final bool legacy;

  const BodyPart({
    required this.id,
    required this.label,
    required this.view,
    required this.recommendedExercises,
    required this.icon,
    this.extraViews = const <BodyView>[],
    this.legacy = false,
  });

  bool visibleIn(BodyView target) =>
      view == target || extraViews.contains(target);
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
    id: 'delt_front',
    label: '전면삼각근',
    view: BodyView.front,
    recommendedExercises: ['숄더프레스', '프론트 레이즈', '아놀드 프레스', '푸쉬 프레스'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'delt_side',
    label: '측면삼각근',
    view: BodyView.front,
    extraViews: [BodyView.back],
    recommendedExercises: ['사이드 레터럴 레이즈', '케이블 레터럴 레이즈', '업라이트 로우', '숄더프레스'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'shoulder',
    label: '어깨',
    view: BodyView.front,
    recommendedExercises: ['숄더프레스', '사이드 레터럴 레이즈', '프론트 레이즈', '페이스풀'],
    icon: Icons.accessibility_new_rounded,
    legacy: true,
  ),
  BodyPart(
    id: 'biceps',
    label: '이두',
    view: BodyView.front,
    recommendedExercises: ['바벨 컬', '덤벨 컬', '해머 컬', '케이블 컬'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'forearm',
    label: '전완',
    view: BodyView.front,
    extraViews: [BodyView.back],
    recommendedExercises: ['리스트 컬', '리버스 컬', '파머스 워크', '해머 컬'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'hand',
    label: '손',
    view: BodyView.front,
    extraViews: [BodyView.back],
    recommendedExercises: ['악력기', '핑거 익스텐션', '데드 행', '그립 볼'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'abs',
    label: '복근',
    view: BodyView.front,
    recommendedExercises: [
      '크런치',
      '레그레이즈',
      '플랭크',
      '데드버그',
      '마운틴 클라이머',
      '복근 롤아웃',
      '할로우 홀드',
    ],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'oblique',
    label: '복사근',
    view: BodyView.front,
    recommendedExercises: ['사이드 크런치', '러시안 트위스트', '사이드 플랭크', '우드찹'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'iliopsoas',
    label: '장요근',
    view: BodyView.front,
    recommendedExercises: ['행잉 니 레이즈', '레그레이즈', '마치', '힙플렉서 스트레칭'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'tfl',
    label: 'TFL',
    view: BodyView.front,
    recommendedExercises: ['사이드라잉 힙 어브덕션', '밴드 몬스터 워크', '클램쉘', 'TFL 스트레칭'],
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
    extraViews: [BodyView.back],
    recommendedExercises: ['수모 스쿼트', '어덕터 머신', '사이드 런지', '케이블 어덕션'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'tibialis',
    label: '전경골근',
    view: BodyView.front,
    recommendedExercises: ['토 레이즈', '밴드 도르시플렉션', '힐 워크', '티비알리스 레이즈'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'foot',
    label: '발',
    view: BodyView.front,
    extraViews: [BodyView.back],
    recommendedExercises: ['토 레이즈', '타월 컬', '숏풋 운동', '발목 가동성'],
    icon: Icons.accessibility_new_rounded,
  ),

  // 구역이 없는 곳(머리·목·관절 등)에 점을 찍을 때의 부위. 선택 목록에는 없다.
  BodyPart(
    id: 'other',
    label: '기타 부위',
    view: BodyView.front,
    extraViews: [BodyView.back],
    recommendedExercises: [],
    icon: Icons.place_outlined,
    legacy: true,
  ),

  // 코어: 복근·복사근·기립근·허리를 묶어 함께 쓴 부위로 고를 때만 쓴다(바디맵 구역은
  // 따로 없고, 칠할 때 세 부위로 펼친다).
  BodyPart(
    id: 'core',
    label: '코어',
    view: BodyView.front,
    extraViews: [BodyView.back],
    recommendedExercises: [],
    icon: Icons.accessibility_new_rounded,
    legacy: true,
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
    id: 'upper_back',
    label: '윗등',
    view: BodyView.back,
    recommendedExercises: ['시티드 로우', '페이스풀', '벤트오버 로우', '리버스 플라이'],
    icon: Icons.accessibility_new_rounded,
  ),
  BodyPart(
    id: 'delt_rear',
    label: '후면삼각근',
    view: BodyView.back,
    recommendedExercises: ['리어델트 플라이', '페이스풀', '벤트오버 레이즈', '리버스 펙덱'],
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
    label: '기립근·허리',
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
    id: 'glute_med',
    label: '중둔근',
    view: BodyView.back,
    recommendedExercises: ['사이드라잉 힙 어브덕션', '클램쉘', '밴드 사이드 스텝', '케이블 힙 어브덕션'],
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

/// 좌우 표시용 접미사. 양쪽·가운데는 붙이지 않는다.
String bodySideSuffix(BodySide side) => switch (side) {
  BodySide.left => ' (왼쪽)',
  BodySide.right => ' (오른쪽)',
  _ => '',
};
