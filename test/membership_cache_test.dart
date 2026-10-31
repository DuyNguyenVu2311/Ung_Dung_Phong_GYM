import 'dart:async';

import 'package:fit_gym/models/data_models.dart';
import 'package:fit_gym/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService.instance;
  final row = <String, dynamic>{
    'id': 'contract',
    'name': 'Gói tháng',
    'branch_name': 'Thủ Đức',
    'start_date': '2020-01-01',
    'end_date': '2099-01-01',
    'used_sessions': 0,
    'total_sessions': 0,
    'price': 299000,
    'active': true,
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await storage.init();
    await storage.bindUser('alice');
    await storage.saveMembership(
      MembershipPlan(
        id: 'old',
        name: 'Cũ',
        branchName: 'Quận 1',
        startDate: DateTime(2020),
        endDate: DateTime(2099),
        usedSessions: 0,
        totalSessions: 0,
        price: 299000,
      ),
    );
  });

  test(
    'successful empty response invalidates cached contract and notices',
    () async {
      await storage.addNotice(
        AppNotice(
          id: 'expiry_old',
          title: 'Cũ',
          message: 'Cũ',
          createdAt: DateTime.now(),
          type: 'expiry',
        ),
      );
      await storage.refreshMembership(() async => [], userId: 'alice');
      await storage.ensureMembershipNotices();
      expect(storage.loadMembership().active, isFalse);
      expect(storage.loadMembership().branchName, isEmpty);
      expect(storage.loadNotices(), isEmpty);
    },
  );

  test('query error retains usable cached contract', () async {
    await expectLater(
      storage.refreshMembership(
        () async => throw StateError('offline'),
        userId: 'alice',
      ),
      throwsStateError,
    );
    expect(storage.loadMembership().id, 'old');
  });

  test('inactive and expired rows cannot become an active cache', () async {
    for (final invalid in [
      {...row, 'active': false},
      {...row, 'end_date': '2020-01-01'},
    ]) {
      await storage.refreshMembership(() async => [invalid], userId: 'alice');
      expect(storage.loadMembership().active, isFalse);
    }
    await storage.refreshMembership(() async => [row], userId: 'alice');
    expect(storage.loadMembership().id, 'contract');
  });

  test('late response cannot overwrite another account membership', () async {
    final response = Completer<List<Map<String, dynamic>>>();
    final pending = storage.refreshMembership(
      () => response.future,
      userId: 'alice',
    );
    await storage.bindUser('bob');
    response.complete([row]);
    await pending;
    expect(storage.loadMembership().id, isEmpty);
    await storage.bindUser('alice');
    expect(storage.loadMembership().id, 'old');
  });

  test('inactive cached contract cannot generate expiry notice', () async {
    await storage.saveMembership(
      MembershipPlan(
        id: 'disabled',
        name: 'Cũ',
        branchName: 'Quận 1',
        startDate: DateTime(2020),
        endDate: DateTime(2020),
        usedSessions: 0,
        totalSessions: 0,
        price: 299000,
        active: false,
      ),
    );
    await storage.ensureMembershipNotices();
    expect(storage.loadNotices(), isEmpty);
  });
}
