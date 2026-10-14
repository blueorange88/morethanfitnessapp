import 'body_part.dart';

/// 운동별 기본 사용 부위(앞쪽일수록 주로 쓰는 부위). 입력 창에서 운동을 고르면
/// 누른 부위를 뺀 나머지가 보조 부위 기본값이 된다. 실제 수업의 목표 부위는
/// 강사가 정하므로 이 값은 제안일 뿐이고, 기록에는 강사가 정한 값이 저장된다.
const Map<String, List<String>> kExerciseMuscles = <String, List<String>>{
  // 가슴·어깨·팔
  '벤치프레스': ['chest', 'delt_front', 'triceps'],
  '덤벨 플라이': ['chest', 'delt_front'],
  '푸쉬업': ['chest', 'delt_front', 'triceps', 'abs'],
  '케이블 크로스오버': ['chest', 'delt_front'],
  '숄더프레스': ['delt_front', 'delt_side', 'triceps'],
  '아놀드 프레스': ['delt_front', 'delt_side', 'triceps'],
  '푸쉬 프레스': ['delt_front', 'delt_side', 'triceps'],
  '프론트 레이즈': ['delt_front'],
  '사이드 레터럴 레이즈': ['delt_side'],
  '케이블 레터럴 레이즈': ['delt_side'],
  '업라이트 로우': ['delt_side', 'trapezius', 'delt_front'],
  '리어델트 플라이': ['delt_rear', 'upper_back'],
  '벤트오버 레이즈': ['delt_rear', 'upper_back'],
  '리버스 펙덱': ['delt_rear', 'upper_back'],
  '페이스풀': ['delt_rear', 'trapezius', 'upper_back'],
  '바벨 컬': ['biceps', 'forearm'],
  '덤벨 컬': ['biceps', 'forearm'],
  '해머 컬': ['biceps', 'forearm'],
  '케이블 컬': ['biceps', 'forearm'],
  '트라이셉스 푸쉬다운': ['triceps'],
  '오버헤드 익스텐션': ['triceps'],
  '딥스': ['triceps', 'chest', 'delt_front'],
  '클로즈그립 벤치': ['triceps', 'chest', 'delt_front'],
  '리스트 컬': ['forearm'],
  '리버스 컬': ['forearm', 'biceps'],
  '파머스 워크': ['forearm', 'hand', 'trapezius'],
  '악력기': ['hand', 'forearm'],
  '핑거 익스텐션': ['hand', 'forearm'],
  '데드 행': ['hand', 'forearm', 'lat'],
  '그립 볼': ['hand', 'forearm'],

  // 등
  '바벨 슈러그': ['trapezius', 'forearm'],
  '덤벨 슈러그': ['trapezius', 'forearm'],
  '풀업': ['lat', 'biceps', 'upper_back', 'forearm'],
  '랫풀다운': ['lat', 'biceps', 'delt_rear'],
  '시티드 로우': ['lat', 'upper_back', 'biceps', 'delt_rear'],
  '벤트오버 로우': ['lat', 'upper_back', 'biceps', 'lower_back'],
  '원암 덤벨 로우': ['lat', 'biceps', 'upper_back'],
  '리버스 플라이': ['delt_rear', 'upper_back'],
  '백 익스텐션': ['lower_back', 'glute', 'hamstring'],
  '굿모닝': ['lower_back', 'hamstring', 'glute'],
  '버드독': ['lower_back', 'glute', 'abs'],

  // 코어
  '크런치': ['abs'],
  '레그레이즈': ['abs', 'iliopsoas'],
  '플랭크': ['abs', 'oblique', 'lower_back'],
  '데드버그': ['abs', 'oblique'],
  '마운틴 클라이머': ['abs', 'iliopsoas', 'delt_front'],
  '복근 롤아웃': ['abs', 'oblique', 'lat'],
  '할로우 홀드': ['abs', 'iliopsoas'],
  '사이드 크런치': ['oblique', 'abs'],
  '러시안 트위스트': ['oblique', 'abs'],
  '사이드 플랭크': ['oblique', 'abs', 'glute_med'],
  '우드찹': ['oblique', 'abs', 'delt_front'],
  '행잉 니 레이즈': ['iliopsoas', 'abs', 'forearm'],
  '마치': ['iliopsoas', 'quad'],
  '힙플렉서 스트레칭': ['iliopsoas'],

  // 하체
  '스쿼트': ['quad', 'glute', 'hamstring', 'adductor'],
  '레그프레스': ['quad', 'glute', 'adductor'],
  '런지': ['quad', 'glute', 'hamstring', 'adductor'],
  '레그 익스텐션': ['quad'],
  '수모 스쿼트': ['adductor', 'glute', 'quad'],
  '어덕터 머신': ['adductor'],
  '사이드 런지': ['adductor', 'quad', 'glute'],
  '케이블 어덕션': ['adductor'],
  '데드리프트': ['hamstring', 'glute', 'lower_back', 'trapezius', 'forearm'],
  '루마니안 데드리프트': ['hamstring', 'glute', 'lower_back'],
  '힙쓰러스트': ['glute', 'hamstring'],
  '케이블 킥백': ['glute'],
  '글루트 브릿지': ['glute', 'hamstring'],
  '사이드라잉 힙 어브덕션': ['glute_med', 'tfl'],
  '클램쉘': ['glute_med', 'tfl'],
  '밴드 몬스터 워크': ['tfl', 'glute_med', 'glute'],
  '밴드 사이드 스텝': ['glute_med', 'tfl', 'glute'],
  '케이블 힙 어브덕션': ['glute_med', 'tfl'],
  'TFL 스트레칭': ['tfl'],
  '레그 컬': ['hamstring'],
  '노르딕 컬': ['hamstring', 'calf', 'glute'],
  '스탠딩 카프레이즈': ['calf'],
  '시티드 카프레이즈': ['calf'],
  '동키 카프레이즈': ['calf'],
  '토 레이즈': ['tibialis', 'foot'],
  '밴드 도르시플렉션': ['tibialis'],
  '힐 워크': ['tibialis'],
  '티비알리스 레이즈': ['tibialis'],
  '타월 컬': ['foot'],
  '숏풋 운동': ['foot'],
  '발목 가동성': ['foot', 'calf'],
};

/// '코어'는 함께 쓴 부위에서만 고르는 묶음 부위다. 바디맵에서는 아래 세 부위로 칠한다.
const String kCorePartId = 'core';
const List<String> kCoreComponentParts = ['abs', 'oblique', 'lower_back'];

/// 운동 이름([exercise])의 보조 부위 제안. 목표(주) 부위 [mainPartId] 는 뺀다.
/// 모르는 운동(내 운동 등)은 빈 목록.
List<String> relatedPartsFor(String exercise, String mainPartId) {
  final parts = kExerciseMuscles[exercise.trim()];
  if (parts == null) return const <String>[];
  return parts.where((id) => id != mainPartId).toList(growable: false);
}

/// 부위 id 목록의 이름 목록(알 수 없는 id 는 버린다).
List<String> bodyPartLabels(Iterable<String> ids) {
  final labels = <String>[];
  for (final id in ids) {
    for (final part in kBodyParts) {
      if (part.id == id) labels.add(part.label);
    }
  }
  return labels;
}

/// 보조 부위에서 보조로 둘 수 있는 부위(레거시 제외, 코어는 포함).
List<BodyPart> get selectableRelatedParts => [
  for (final part in kBodyParts)
    if (!part.legacy || part.id == kCorePartId) part,
];
