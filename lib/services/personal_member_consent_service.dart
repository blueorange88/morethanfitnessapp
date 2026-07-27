import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'mtf_firebase_functions.dart';

class PersonalMemberConsentState {
  const PersonalMemberConsentState({
    required this.agreed,
    required this.agreedAt,
  });

  final bool agreed;
  final DateTime? agreedAt;
}

class PersonalMemberConsentService {
  PersonalMemberConsentService({
    required String uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : uid = uid.trim(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? MtfFirebaseFunctions.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<PersonalMemberConsentState> update({
    required String memberId,
    required bool agreed,
  }) async {
    final normalizedMemberId = memberId.trim();
    if (uid.isEmpty || normalizedMemberId.isEmpty) {
      throw ArgumentError('member_identity_required');
    }
    final memberRef = _firestore.collection('members').doc(normalizedMemberId);
    final snapshotObserved = Completer<void>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
        subscription;
    subscription =
        memberRef.snapshots(includeMetadataChanges: true).listen((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists ||
          data == null ||
          snapshot.metadata.isFromCache ||
          data['trainerId'] != uid ||
          data['workspaceType'] != 'personal') {
        return;
      }
      if ((data['trainingLogConsentAgreed'] == true) == agreed &&
          !snapshotObserved.isCompleted) {
        snapshotObserved.complete();
      }
    });
    try {
      await MtfFirebaseFunctions.call(
        'updateManagedMemberConsent',
        functions: _functions,
        parameters: {
          'memberId': normalizedMemberId,
          'agreed': agreed,
        },
      );
      final readback = await memberRef.get(
        const GetOptions(source: Source.server),
      );
      final data = readback.data();
      if (!readback.exists ||
          data == null ||
          data['memberId'] != normalizedMemberId ||
          data['trainerId'] != uid ||
          data['workspaceType'] != 'personal' ||
          (data['trainingLogConsentAgreed'] == true) != agreed) {
        throw StateError('member_consent_readback_mismatch');
      }
      await snapshotObserved.future.timeout(const Duration(seconds: 12));
      final timestamp = data['trainingLogConsentAgreedAt'];
      return PersonalMemberConsentState(
        agreed: agreed,
        agreedAt: timestamp is Timestamp ? timestamp.toDate() : null,
      );
    } finally {
      await subscription.cancel();
    }
  }
}
