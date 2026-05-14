import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:risha_v01/shared/services/auth_service.dart';
import 'package:risha_v01/shared/services/child_behavior_service.dart';
import 'package:risha_v01/shared/services/child_reward_service.dart';
import 'package:risha_v01/shared/services/child_service.dart';
import 'package:risha_v01/shared/services/device_sleep_lock_service.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:risha_v01/shared/services/pin_service.dart';
import 'package:risha_v01/shared/services/selected_child_service.dart';

import 'helpers/mocks.dart';

class _RecordingClient extends http.BaseClient {
  final List<Map<String, dynamic>> postedBodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      postedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
    }
    final response = jsonEncode(<String, dynamic>{
      'ok': true,
      'data': <String, dynamic>{
        'sent': true,
        'message': 'ok',
        'cooldownSeconds': 60,
      },
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response)),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}

class _ReportFakeFirestore extends FakeFirebaseFirestore {
  @override
  Future<void> waitForPendingWrites() async {}
}

class _NoopEmailNotificationService extends EmailNotificationService {
  _NoopEmailNotificationService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : super(auth: auth, firestore: firestore, httpClient: _RecordingClient());

  @override
  Future<void> syncChildProfile({
    required String childId,
    required String childName,
    int? ageYears,
    String? avatarBase64,
    bool fallbackToDurableOutbox = true,
  }) async {}

  @override
  Future<void> queueChildAddedEmail({
    required String childId,
    required String childName,
  }) async {}

  @override
  Future<void> queuePendingRewardEmail({
    required String childId,
    required String childName,
    required String rewardType,
    required String description,
    required int coins,
    required String rewardId,
    required String approvalToken,
    required String rejectionToken,
    String? taskId,
  }) async {}
}

class _RecordingSleepLockService extends DeviceSleepLockService {
  int syncCount = 0;
  int clearCount = 0;

  @override
  Future<void> syncSleepLockConfig({
    required String childId,
    String? childName,
    required bool configured,
    required bool enabled,
    required int sleepHour,
    required int sleepMinute,
  }) async {
    syncCount += 1;
  }

  @override
  Future<void> clearSleepLockConfig() async {
    clearCount += 1;
  }
}

void main() {
  late MockFirebaseAuth auth;
  late MockUser user;
  late MockUserCredential credential;
  late _ReportFakeFirestore firestore;

  setUpAll(registerFallbackValues);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    auth = MockFirebaseAuth();
    user = MockUser();
    credential = MockUserCredential();
    firestore = _ReportFakeFirestore();

    when(() => user.uid).thenReturn('parent-uid');
    when(() => user.email).thenReturn('parent@example.com');
    when(() => user.emailVerified).thenReturn(false);
    when(() => credential.user).thenReturn(user);
    when(() => auth.currentUser).thenReturn(user);
  });

  group('Report verification suite', () {
    test('AuthService.signInWithEmail normalizes parent email', () async {
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);

      await AuthService(
        auth: auth,
        firestore: firestore,
      ).signInWithEmail(email: '  Parent@Example.COM  ', password: 'pass123');

      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'parent@example.com',
          password: 'pass123',
        ),
      ).called(1);
    });

    test(
      'AuthService.signUpWithEmail writes the parent Firestore document',
      () async {
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => credential);

        await AuthService(auth: auth, firestore: firestore).signUpWithEmail(
          email: 'Parent@Example.COM',
          password: 'SecurePass123',
        );

        final doc = await firestore.collection('users').doc('parent-uid').get();
        expect(doc.data()?['email'], 'parent@example.com');
      },
    );

    test(
      'ChildService.addChild persists a child under users/{uid}/children',
      () async {
        final service = ChildService(
          auth: auth,
          firestore: firestore,
          emailNotificationService: _NoopEmailNotificationService(
            auth: auth,
            firestore: firestore,
          ),
        );

        await service.addChild(name: 'Ahmad', ageYears: 6);

        final children = await firestore
            .collection('users')
            .doc('parent-uid')
            .collection('children')
            .get();
        expect(children.docs.single.data()['name'], 'Ahmad');
      },
    );

    test(
      'ChildService.watchChildren reads Firestore and returns child profiles',
      () async {
        await firestore
            .collection('users')
            .doc('parent-uid')
            .collection('children')
            .doc('child-1')
            .set(<String, dynamic>{'name': 'Sara', 'ageYears': 7});

        final result = await ChildService(
          auth: auth,
          firestore: firestore,
          emailNotificationService: _NoopEmailNotificationService(
            auth: auth,
            firestore: firestore,
          ),
        ).watchChildren().first;

        expect(result.single.name, 'Sara');
      },
    );

    test(
      'PinService.savePin and verifyPin validate the saved parent PIN',
      () async {
        final service = PinService(auth: auth);

        await service.savePin('1234');

        expect(await service.verifyPin('1234'), isTrue);
        expect(await service.verifyPin('9999'), isFalse);
      },
    );

    test('PinService keeps child setup PINs isolated per child', () async {
      final service = PinService(auth: auth);

      await service.savePin('9999');
      await service.savePin('1111', childId: 'child-a');
      await service.savePin('2222', childId: 'child-b');

      expect(await service.hasSavedPin(childId: 'child-a'), isTrue);
      expect(await service.verifyPin('1111', childId: 'child-a'), isTrue);
      expect(await service.verifyPin('2222', childId: 'child-a'), isFalse);
      expect(await service.verifyPin('2222', childId: 'child-b'), isTrue);
      expect(await service.hasSavedPin(childId: 'child-new'), isFalse);
      expect(
        await service.verifyPin(
          '9999',
          childId: 'child-new',
          allowParentFallback: true,
        ),
        isTrue,
      );
    });

    test(
      'ChildBehaviorService.saveSleepRoutine does not activate device lock during setup',
      () async {
        final sleepLock = _RecordingSleepLockService();
        final service = ChildBehaviorService(
          auth: auth,
          firestore: firestore,
          deviceSleepLockService: sleepLock,
        );

        await service.saveSleepRoutine(
          childId: 'child-a',
          hour: 21,
          minute: 30,
          notificationsEnabled: true,
        );

        expect(sleepLock.syncCount, 0);
        expect(sleepLock.clearCount, 0);
      },
    );

    test(
      'ChildRewardService.addPendingReward stores pending reward locally and syncs wallet',
      () async {
        await _selectChild('parent-uid', 'child-1');
        await _seedChildWallet(firestore);

        final reward =
            await ChildRewardService(
              auth: auth,
              firestore: firestore,
              selectedChildService: _selectedChildService(auth),
              emailNotificationService: _NoopEmailNotificationService(
                auth: auth,
                firestore: firestore,
              ),
            ).addPendingReward(
              rewardType: 'task_completion',
              description: 'Quran reading',
              coins: 5,
              taskId: 'quran-reading',
            );

        final doc = await _childDoc(firestore).get();
        expect(reward.status, PendingRewardStatus.pending);
        expect(doc.data()?['pendingRewards'], isNotEmpty);
      },
    );

    test(
      'ChildRewardService.approvePendingReward approves reward and updates progress',
      () async {
        await _selectChild('parent-uid', 'child-1');
        await _seedChildWallet(
          firestore,
          pendingRewards: <Map<String, dynamic>>[
            PendingReward(
              id: 'reward-1',
              rewardType: 'task_completion',
              description: 'Quran reading',
              coins: 5,
              requestedAt: DateTime(2026, 5, 9),
              status: PendingRewardStatus.pending,
              approvalToken: 'approve-token',
              rejectionToken: 'reject-token',
              taskId: 'quran-reading',
            ).toMap(),
          ],
        );

        await ChildRewardService(
          auth: auth,
          firestore: firestore,
          selectedChildService: _selectedChildService(auth),
          emailNotificationService: _NoopEmailNotificationService(
            auth: auth,
            firestore: firestore,
          ),
        ).approvePendingReward('reward-1');

        final data = (await _childDoc(firestore).get()).data()!;
        expect(data['coins'], 5);
        expect(
          (data['dailyTaskProgress'] as Map)['completedTaskIds'],
          contains('quran-reading'),
        );
      },
    );

    test(
      'EmailNotificationService.requestVerificationCode posts Apps Script action',
      () async {
        await firestore.collection('users').doc('parent-uid').set(
          <String, dynamic>{'email': 'parent@example.com'},
        );
        final client = _RecordingClient();

        final result = await EmailNotificationService(
          auth: auth,
          firestore: firestore,
          httpClient: client,
        ).requestVerificationCode();

        expect(result.sent, isTrue);
        expect(
          client.postedBodies.single['action'],
          'request_verification_code',
        );
      },
    );

    test(
      'EmailNotificationService.queuePendingRewardEmail posts pending reward action',
      () async {
        await firestore.collection('users').doc('parent-uid').set(
          <String, dynamic>{'email': 'parent@example.com'},
        );
        final client = _RecordingClient();

        await EmailNotificationService(
          auth: auth,
          firestore: firestore,
          httpClient: client,
        ).queuePendingRewardEmail(
          childId: 'child-1',
          childName: 'Sara',
          rewardType: 'task_completion',
          description: 'Quran reading',
          coins: 5,
          rewardId: 'reward-1',
          approvalToken: 'approve-token',
          rejectionToken: 'reject-token',
          taskId: 'quran-reading',
        );

        expect(client.postedBodies.single['action'], 'send_event_email');
      },
    );
  });
}

Future<void> _selectChild(String uid, String childId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('selected_child_id_$uid', childId);
}

SelectedChildService _selectedChildService(FirebaseAuth auth) {
  return SelectedChildService(
    auth: auth,
    emailNotificationService: _NoopEmailNotificationService(
      auth: auth,
      firestore: _ReportFakeFirestore(),
    ),
  );
}

DocumentReference<Map<String, dynamic>> _childDoc(
  FakeFirebaseFirestore firestore,
) {
  return firestore
      .collection('users')
      .doc('parent-uid')
      .collection('children')
      .doc('child-1');
}

Future<void> _seedChildWallet(
  FakeFirebaseFirestore firestore, {
  List<Map<String, dynamic>> pendingRewards = const <Map<String, dynamic>>[],
}) async {
  await _childDoc(firestore).set(<String, dynamic>{
    'name': 'Sara',
    'coins': 0,
    'ownedMarketItemAssetPaths': const <String>[],
    'pendingRewards': pendingRewards,
    'levelState': ChildLevelState.defaults().toMap(),
  });
}
