import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../services/inbody_camera_permission_service.dart';
import '../services/inbody_record_service.dart';
import '../services/inbody_scan.dart';
import 'inbody_review_sheet.dart';

/// 인바디 측정 흐름의 결과. [summary]는 체크리스트 줄에 보여줄 한 줄 요약.
class InbodyMeasureResult {
  const InbodyMeasureResult({
    required this.summary,
    this.checkBirthDate = false,
  });

  final String summary;

  /// 나이 차이가 커서 회원카드 생년월일을 확인해야 하는지.
  final bool checkBirthDate;
}

enum InbodyMeasureSource { camera, gallery, manual }

Future<InbodyMeasureSource?> _chooseSource(BuildContext context) {
  return showModalBottomSheet<InbodyMeasureSource>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('inbody_source_camera'),
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('카메라로 인바디 읽기'),
                  subtitle: const Text('용지를 촬영하면 수치를 자동으로 읽어요'),
                  onTap:
                      () => Navigator.pop(
                        sheetContext,
                        InbodyMeasureSource.camera,
                      ),
                ),
                ListTile(
                  key: const Key('inbody_source_gallery'),
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('갤러리에서 인바디 읽기'),
                  subtitle: const Text('저장된 인바디 사진을 불러와요'),
                  onTap:
                      () => Navigator.pop(
                        sheetContext,
                        InbodyMeasureSource.gallery,
                      ),
                ),
                ListTile(
                  key: const Key('inbody_source_manual'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('직접 입력'),
                  subtitle: const Text('측정한 값을 직접 입력해요'),
                  onTap:
                      () => Navigator.pop(
                        sheetContext,
                        InbodyMeasureSource.manual,
                      ),
                ),
              ],
            ),
          ),
        ),
  );
}

DateTime? _timestampToDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// 인바디를 측정·기록하는 흐름: 읽기 방식 선택 → (읽기) → 본인 확인·값 확인 → 서버 기록.
///
/// 읽은 이미지는 저장하지 않는다. 용지의 나이·성별을 회원 정보와 비교해 다른 회원 용지가
/// 아닌지 확인하고, 성별이 다를 때 사용자가 고르면 회원 성별도 고친다. 취소·실패하면 null.
Future<InbodyMeasureResult?> runInbodyMeasureFlow(
  BuildContext context, {
  required String memberId,
  required String memberName,
  InbodyRecordService? service,
  ImagePicker? picker,
  FirebaseFirestore? firestore,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void toast(String message) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final choice = await _chooseSource(context);
  if (choice == null || !context.mounted) return null;

  InbodyScanResult scan;
  var source = 'manual';
  if (choice == InbodyMeasureSource.manual) {
    scan = manualInbodyScan(DateTime.now());
  } else {
    if (choice == InbodyMeasureSource.camera &&
        !await prepareInbodyCameraUse(context)) {
      return null;
    }
    if (!context.mounted) return null;
    final picked = await (picker ?? ImagePicker()).pickImage(
      source:
          choice == InbodyMeasureSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (picked == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      scan = parseInbodyText(recognized.text);
      source = 'scan';
    } catch (_) {
      toast('인바디 용지 인식 중 오류가 발생했어요.');
      return null;
    } finally {
      await recognizer.close();
    }
  }

  // 회원카드의 나이·성별로 다른 회원 용지가 아닌지 확인한다. 못 읽어도 흐름은 계속한다.
  DateTime? birth;
  String? gender;
  try {
    final snapshot =
        await (firestore ?? FirebaseFirestore.instance)
            .collection('members')
            .doc(memberId)
            .get();
    final data = snapshot.data();
    birth =
        _timestampToDate(data?['birth']) ?? _timestampToDate(data?['birthAt']);
    gender = data?['gender']?.toString();
  } catch (_) {
    // 비교 정보 없이 진행: 확인 화면이 직접 확인을 요구한다.
  }
  if (!context.mounted) return null;

  final outcome = await showInbodyReviewSheet(
    context,
    scan: scan,
    memberName: memberName,
    cardBirthDate: birth,
    cardGender: gender,
    showRawText: kDebugMode,
    manualEntry: choice == InbodyMeasureSource.manual,
  );
  if (outcome == null) return null;

  final input = inbodyInputFromOutcome(
    outcome,
    source: source,
    memberConfirmed: outcome.memberVerified,
  );
  if (input == null) {
    toast('측정일과 인바디 값을 확인해 주세요.');
    return null;
  }

  final recorder = service ?? InbodyRecordService();
  try {
    await recorder.record(memberId: memberId, input: input);
    if (outcome.updateGender && scan.gender != null) {
      await recorder.updateMemberGender(
        memberId: memberId,
        genderKey: scan.gender!,
      );
    }
  } catch (_) {
    toast('인바디를 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
    return null;
  }

  toast(
    outcome.checkBirthDate ? '인바디를 기록했어요. 회원카드의 생년월일을 확인해 주세요.' : '인바디를 기록했어요.',
  );
  return InbodyMeasureResult(
    summary: inbodySummaryText(input),
    checkBirthDate: outcome.checkBirthDate,
  );
}
