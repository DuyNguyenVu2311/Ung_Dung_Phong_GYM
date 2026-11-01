import 'dart:async';

import 'package:fit_gym/services/sync_request_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'requests during a sync run trigger a final pass before completion',
    () async {
      final coordinator = SyncRequestCoordinator();
      final firstPass = Completer<bool>();
      var passCount = 0;

      Future<bool> syncPass() {
        passCount++;
        if (passCount == 1) return firstPass.future;
        return Future.value(true);
      }

      final firstRequest = coordinator.run(syncPass);
      final overlappingRequest = coordinator.run(syncPass);

      expect(passCount, 1);
      firstPass.complete(true);

      expect(await firstRequest, isTrue);
      expect(await overlappingRequest, isTrue);
      expect(passCount, 2);
    },
  );

  test('latest sync result is returned after a requested retry', () async {
    final coordinator = SyncRequestCoordinator();
    final firstPass = Completer<bool>();
    var passCount = 0;

    Future<bool> syncPass() {
      passCount++;
      if (passCount == 1) return firstPass.future;
      return Future.value(false);
    }

    final request = coordinator.run(syncPass);
    coordinator.run(syncPass);
    firstPass.complete(true);

    expect(await request, isFalse);
    expect(passCount, 2);
  });
}
