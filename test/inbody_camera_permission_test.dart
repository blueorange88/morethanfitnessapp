import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/inbody_camera_permission_service.dart';

void main() {
  test('인바디 카메라 사전 안내는 projectId와 uid별로 분리된다', () {
    final devA = inbodyCameraPreNoticeKey(
      uid: 'uid-a',
      projectId: 'more-than-fitness-dev-mft',
    );
    final devB = inbodyCameraPreNoticeKey(
      uid: 'uid-b',
      projectId: 'more-than-fitness-dev-mft',
    );
    final prodA = inbodyCameraPreNoticeKey(
      uid: 'uid-a',
      projectId: 'more-than-fitness-f6adb',
    );
    expect(devA, isNot(devB));
    expect(devA, isNot(prodA));
  });
}
