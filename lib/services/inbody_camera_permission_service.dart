import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/aifc_confirm_chat_sheet.dart';
import 'app_environment.dart';

enum InbodyCameraPermission {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

String inbodyCameraPreNoticeKey({
  required String uid,
  String? projectId,
}) =>
    AppEnvironmentConfig.personalPreferenceKey(
      uid: uid,
      featureKey: 'inbody_camera_pre_notice_v1',
      projectId: projectId,
    );

class InbodyCameraPermissionService {
  const InbodyCameraPermissionService();

  static const MethodChannel _channel =
      MethodChannel('com.example.mtf_app/camera_permission');

  Future<InbodyCameraPermission> check() => _invoke('check');

  Future<InbodyCameraPermission> request() => _invoke('request');

  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  Future<InbodyCameraPermission> _invoke(String method) async {
    final value = await _channel.invokeMethod<String>(method);
    return InbodyCameraPermission.values.firstWhere(
      (item) => item.name == value,
      orElse: () => InbodyCameraPermission.restricted,
    );
  }
}

Future<bool> prepareInbodyCameraUse(BuildContext context) async {
  const service = InbodyCameraPermissionService();
  final initialPermission = await service.check();
  if (initialPermission == InbodyCameraPermission.granted) {
    _logCameraPermission(false, initialPermission, 'openCamera');
    return true;
  }

  final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
  final key = uid.isEmpty ? null : inbodyCameraPreNoticeKey(uid: uid);
  final prefs = await SharedPreferences.getInstance();
  final preNoticeShown = key != null && prefs.getBool(key) == true;

  if (!preNoticeShown) {
    if (!context.mounted) return false;
    final useCamera = await AifcConfirmChatSheet.show(
      context: context,
      title: '인바디 결과를 읽으려면 카메라 사용 권한이 필요해요.',
      message: '촬영한 이미지는 기기에서 글자를 인식하는 데 사용해요. '
          '검토 화면에서 “인바디 이미지도 저장”을 선택한 경우에만 회원카드 보관용으로 업로드돼요.',
      confirmText: '카메라 사용하기',
      cancelText: '나중에',
    );
    if (key != null) await prefs.setBool(key, true);
    if (!useCamera) {
      _logCameraPermission(true, initialPermission, 'close');
      return false;
    }
  }

  final permission = await service.request();
  if (permission == InbodyCameraPermission.granted) {
    _logCameraPermission(!preNoticeShown, permission, 'openCamera');
    return true;
  }

  if (!context.mounted) return false;
  final openSettings = await AifcConfirmChatSheet.show(
    context: context,
    title: '카메라 권한이 꺼져 있어요.',
    message: '휴대폰 설정에서 권한을 허용해주세요.',
    confirmText: '설정 열기',
    cancelText: '닫기',
  );
  if (openSettings) {
    await service.openSettings();
    _logCameraPermission(!preNoticeShown, permission, 'openSettings');
  } else {
    _logCameraPermission(!preNoticeShown, permission, 'close');
  }
  return false;
}

void _logCameraPermission(
  bool preNoticeShown,
  InbodyCameraPermission permission,
  String action,
) {
  if (!kDebugMode) return;
  debugPrint(
    '[MTF_INBODY_CAMERA_PERMISSION] preNoticeShown=$preNoticeShown '
    'permission=${permission.name} action=$action',
  );
}
