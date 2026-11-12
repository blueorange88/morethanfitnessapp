/// 통증·주의 입력에서 누른 부위 근처의 위치 칩. 칩을 누르면 글자 칸에 그 단어가
/// 들어가고, 이어서 상세("안쪽 당김")를 쓰면 된다. 좌우는 점을 찍은 자리로 정해져
/// 따로 쓰지 않는다.
const Map<String, List<String>> kLocationChips = <String, List<String>>{
  'chest': ['가슴', '갈비뼈', '어깨 앞'],
  'delt_front': ['어깨 앞', '어깨 관절', '쇄골'],
  'delt_side': ['어깨', '어깨 바깥', '팔꿈치'],
  'delt_rear': ['어깨 뒤', '견갑골', '어깨 관절'],
  'biceps': ['팔 앞', '팔꿈치', '이두'],
  'triceps': ['팔 뒤', '팔꿈치', '삼두'],
  'forearm': ['팔꿈치', '손목', '전완'],
  'hand': ['손목', '손바닥', '손가락'],
  'abs': ['윗배', '아랫배', '명치'],
  'oblique': ['옆구리', '갈비뼈', '골반'],
  'iliopsoas': ['고관절 앞', '사타구니', '아랫배'],
  'tfl': ['고관절 바깥', '골반', '무릎 바깥'],
  'quad': ['무릎', '허벅지 앞', '고관절 앞'],
  'adductor': ['사타구니', '무릎 안쪽', '고관절'],
  'tibialis': ['정강이', '무릎', '발목'],
  'foot': ['발목', '발바닥', '발등', '뒤꿈치'],
  'trapezius': ['목', '승모근', '어깨 위'],
  'upper_back': ['견갑골', '등 위쪽', '어깨'],
  'lat': ['등', '옆구리', '겨드랑이'],
  'lower_back': ['허리', '꼬리뼈', '골반'],
  'glute': ['엉덩이', '고관절', '꼬리뼈'],
  'glute_med': ['골반 옆', '고관절 바깥', '엉덩이'],
  'hamstring': ['허벅지 뒤', '무릎 뒤', '엉덩이 아래'],
  'calf': ['종아리', '무릎 뒤', '아킬레스', '발목'],
};

/// 구역 밖(기타 부위)이나 목록에 없는 구역의 기본 칩.
const List<String> kGeneralLocationChips = <String>[
  '목',
  '머리',
  '어깨',
  '팔꿈치',
  '손목',
  '허리',
  '고관절',
  '무릎',
  '발목',
];

/// 가동성 입력에서 자주 하는 검사 이름 칩.
const List<String> kMobilityTestChips = <String>[
  '토마스 테스트',
  '스쿼트 패턴',
  '발목 굽히기',
  '햄스트링 길이(SLR)',
  '어깨 올리기',
  '흉추 회전',
  '고관절 내회전',
];

List<String> locationChipsFor(String partId) =>
    kLocationChips[partId] ?? kGeneralLocationChips;

/// 내가 추가한 칩을 저장하는 키(서버의 내 운동 저장소를 같이 쓴다).
String locationChipKey(String partId) => 'p:$partId';

const String kMobilityChipKey = 't:mobility';
