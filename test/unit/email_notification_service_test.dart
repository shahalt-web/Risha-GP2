import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:risha_v01/shared/services/email_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockUser extends Mock implements User {}

class _RecordingClient extends http.BaseClient {
  String? requestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      requestBody = request.body;
    }
    final response = jsonEncode(<String, dynamic>{
      'ok': true,
      'data': <String, dynamic>{
        'sent': true,
        'email': 'basemmunassar@gmail.com',
      },
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response)),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}

class _SequenceRecordingClient extends http.BaseClient {
  _SequenceRecordingClient(this.responses);

  final List<Map<String, dynamic>> responses;
  final List<Map<String, dynamic>> postedBodies = <Map<String, dynamic>>[];
  int _responseIndex = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      postedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
    }
    final response = _responseIndex < responses.length
        ? responses[_responseIndex]
        : responses.last;
    _responseIndex++;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(response))),
      200,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }
}

void main() {
  test(
    'sendScheduledReportTestEmail posts test action without login',
    () async {
      final client = _RecordingClient();
      final service = EmailNotificationService(
        auth: _MockFirebaseAuth(),
        firestore: _MockFirebaseFirestore(),
        httpClient: client,
      );

      final result = await service.sendScheduledReportTestEmail(
        email: '  basemmunassar@gmail.com  ',
      );

      final body = jsonDecode(client.requestBody!) as Map<String, dynamic>;
      final payload = body['payload'] as Map<String, dynamic>;

      expect(body['action'], 'send_scheduled_report_test_email');
      expect(payload['email'], 'basemmunassar@gmail.com');
      expect(result['sent'], true);
    },
  );

  test(
    'sendCompletedTasksReportPipelineTest posts aggregation test action',
    () async {
      final client = _RecordingClient();
      final service = EmailNotificationService(
        auth: _MockFirebaseAuth(),
        firestore: _MockFirebaseFirestore(),
        httpClient: client,
      );

      final result = await service.sendCompletedTasksReportPipelineTest(
        email: '  basemmunassar@gmail.com  ',
      );

      final body = jsonDecode(client.requestBody!) as Map<String, dynamic>;
      final payload = body['payload'] as Map<String, dynamic>;

      expect(body['action'], 'send_completed_tasks_report_pipeline_test');
      expect(payload['email'], 'basemmunassar@gmail.com');
      expect(result['sent'], true);
    },
  );

  test(
    'queuePendingRewardEmail falls back to outbox when direct send is skipped',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final auth = _MockFirebaseAuth();
      final firestore = _MockFirebaseFirestore();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('parent-uid');
      when(() => user.email).thenReturn('parent@example.com');
      when(() => user.emailVerified).thenReturn(true);
      final client = _SequenceRecordingClient(<Map<String, dynamic>>[
        <String, dynamic>{
          'ok': true,
          'data': <String, dynamic>{
            'sent': false,
            'skipped': true,
            'reason': 'dedup',
          },
        },
        <String, dynamic>{
          'ok': true,
          'data': <String, dynamic>{'enqueued': true},
        },
      ]);

      final service = EmailNotificationService(
        auth: auth,
        firestore: firestore,
        httpClient: client,
      );

      await service.queuePendingRewardEmail(
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
      await Future<void>.delayed(Duration.zero);
      await service.flushDurableOutbox();

      expect(client.postedBodies, hasLength(2));
      expect(client.postedBodies.first['action'], 'send_event_email');
      expect(client.postedBodies.last['action'], 'enqueue_operation');
      final payload =
          client.postedBodies.last['payload'] as Map<String, dynamic>;
      expect(payload['operationType'], 'pending_reward_email');
    },
  );

  test(
    'queueChildAddedEmail posts direct event email before queue fallback',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final auth = _MockFirebaseAuth();
      final firestore = _MockFirebaseFirestore();
      final user = _MockUser();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('parent-uid');
      when(() => user.email).thenReturn('parent@example.com');
      when(() => user.emailVerified).thenReturn(true);
      final client = _SequenceRecordingClient(<Map<String, dynamic>>[
        <String, dynamic>{
          'ok': true,
          'data': <String, dynamic>{'sent': true},
        },
      ]);

      final service = EmailNotificationService(
        auth: auth,
        firestore: firestore,
        httpClient: client,
      );

      await service.queueChildAddedEmail(childId: 'child-1', childName: 'Sara');
      await Future<void>.delayed(Duration.zero);

      expect(client.postedBodies, hasLength(1));
      expect(client.postedBodies.single['action'], 'send_event_email');
      final payload =
          client.postedBodies.single['payload'] as Map<String, dynamic>;
      expect(payload['eventType'], 'child_added');
    },
  );
}
