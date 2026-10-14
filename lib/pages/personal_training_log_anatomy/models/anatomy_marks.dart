import 'anatomy_log.dart';
import 'body_map_data.dart';
import 'exercise_muscles.dart';

/// 바디맵 한 조각에 칠하는 표시 종류. 우선순위는 선언 순서(통증이 가장 앞).
enum AnatomyMark {
  pain,
  caution,
  mobility,

  /// 이번 수업의 목표(주) 부위로 운동한 곳.
  target,

  /// 목표 부위와 함께 쓴 보조 부위. 다른 표시가 있으면 나타나지 않는다.
  related,
}

/// [zone] 에 칠할 표시들(우선순위 순). 비어 있으면 아무것도 칠하지 않는다.
///
/// - 기록의 목표 부위(`bodyPartId`)가 같고 좌우가 닿으면 기록 종류에 따라
///   통증·주의·가동성·목표 표시가 된다. 둘 이상이면 색을 섞지 않고 줄무늬로 칠한다.
/// - 운동 기록의 함께 쓴 부위(`relatedPartIds`)는 다른 표시가 하나도 없을 때만
///   `related` 로 칠하고, 줄무늬에는 넣지 않는다.
List<AnatomyMark> anatomyMarksFor(
  BodyMapZone zone,
  Iterable<AnatomyLogRecord> records,
) {
  final found = <AnatomyMark>{};
  var related = false;
  for (final record in records) {
    // 점으로 찍은 통증·주의·가동성은 구역이 아니라 점으로만 표시한다.
    if (record.recordType != AnatomyRecordType.exercise && record.pin != null) {
      continue;
    }
    if (!zone.isCoveredBy(record.bodySide)) continue;
    if (record.bodyPartId == zone.part) {
      found.add(switch (record.recordType) {
        AnatomyRecordType.pain => AnatomyMark.pain,
        AnatomyRecordType.caution => AnatomyMark.caution,
        AnatomyRecordType.mobility => AnatomyMark.mobility,
        AnatomyRecordType.exercise => AnatomyMark.target,
      });
    } else if (record.recordType == AnatomyRecordType.exercise &&
        (record.relatedPartIds.contains(zone.part) ||
            (record.relatedPartIds.contains(kCorePartId) &&
                kCoreComponentParts.contains(zone.part)))) {
      related = true;
    }
  }
  if (found.isEmpty) {
    return related ? const [AnatomyMark.related] : const <AnatomyMark>[];
  }
  return [
    for (final mark in AnatomyMark.values)
      if (found.contains(mark)) mark,
  ];
}
