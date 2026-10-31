import 'package:flutter/material.dart';

import '../services/app_localization.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'checkout_screen.dart';
import '../services/payment_format.dart';
import '../services/storage_service.dart';
import '../services/app_clock.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  Map<String, dynamic>? _contract;
  List<Map<String, dynamic>> _packages = [], _requests = [];
  bool _loading = true;
  String? _error;
  String? _branch;
  @override
  void initState() {
    super.initState();
    final cached = StorageService.instance.loadMembership();
    if (cached.isCurrent) {
      _contract = {
        'id': cached.id,
        'name': cached.name,
        'branch_name': cached.branchName,
        'end_date': cached.endDate.toIso8601String().split('T').first,
      };
    }
    _load();
  }

  Future<void> _load() async {
    final client = SupabaseService.client, user = SupabaseService.currentUser;
    if (client == null || user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final contract = await StorageService.instance.refreshMembership(
        () async => await client
            .from('memberships')
            .select()
            .eq('user_id', user.id)
            .eq('active', true)
            .gte('end_date', AppClock.today.toIso8601String().split('T').first)
            .lte(
              'start_date',
              AppClock.today.toIso8601String().split('T').first,
            )
            .order('end_date', ascending: false)
            .limit(1),
        userId: user.id,
      );
      if (!mounted || SupabaseService.currentUser?.id != user.id) return;
      setState(() => _contract = contract);
      final packages = await client
          .from('gym_packages')
          .select()
          .eq('active', true)
          .order('price');
      final requests = await client
          .from('membership_renewal_requests')
          .select('*,gym_packages(name)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted || SupabaseService.currentUser?.id != user.id) return;
      setState(() {
        _packages = packages;
        final branches = packages
            .map((p) => p['branch_name'] as String)
            .toSet();
        if (!branches.contains(_branch)) {
          _branch = branches.isEmpty ? null : branches.first;
        }
        _requests = requests;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> package) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => CheckoutScreen(package: package)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final contract = _contract;
    final pending = _requests.any((r) => r['status'] == 'pending');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: LocalizedText('Gói tập & hợp đồng')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    LocalizedText('Không tải được dữ liệu: $_error'),
                    TextButton(
                      onPressed: _load,
                      child: LocalizedText('Thử lại'),
                    ),
                  ],
                  if (contract == null)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: LocalizedText(
                          'Bạn chưa có gói tập đang hoạt động. Chọn gói do phòng tập cung cấp bên dưới.',
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalizedText(
                              contract['name'] as String,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            LocalizedText(contract['branch_name'] as String),
                            SizedBox(height: 16),
                            LocalizedText('Hết hạn: ${contract['end_date']}'),
                            LocalizedText(
                              'Còn ${DateTime.parse(contract['end_date'] as String).difference(AppClock.today).inDays.clamp(0, 99999)} ngày',
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 24),
                  LocalizedText(
                    'Đăng ký / gia hạn gói tập',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_packages.isNotEmpty) ...[
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _branch,
                      decoration: InputDecoration(labelText: tr('Chi nhánh')),
                      items: _packages
                          .map((p) => p['branch_name'] as String)
                          .toSet()
                          .map(
                            (branch) => DropdownMenuItem(
                              value: branch,
                              child: LocalizedText(branch),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _branch = value),
                    ),
                    SizedBox(height: 12),
                    LocalizedText(
                      'Gói 3 tháng giảm 10% so với mua 3 gói 1 tháng.',
                    ),
                  ],
                  if (pending)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LocalizedText(
                        _requests.any(
                              (r) =>
                                  r['status'] == 'pending' &&
                                  [
                                    'momo_business',
                                    'legacy_review',
                                  ].contains(r['payment_provider']),
                            )
                            ? 'Bạn có đơn MoMo đang chờ xử lý. Mở đơn trong lịch sử để tiếp tục hoặc kiểm tra trạng thái.'
                            : 'Yêu cầu gia hạn đang chờ phòng tập xác nhận thanh toán.',
                      ),
                    ),
                  if (_packages.isEmpty && _error == null)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LocalizedText(
                        'Phòng tập chưa công bố gói tập. Vui lòng liên hệ quầy lễ tân.',
                      ),
                    ),
                  ..._packages
                      .where((package) => package['branch_name'] == _branch)
                      .map(
                        (package) => Card(
                          child: ListTile(
                            title: LocalizedText(package['name'] as String),
                            subtitle: LocalizedText(
                              '${packageTerm(package)} • ${formatVnd(package['price'])}\n${package['branch_name']}',
                            ),
                            trailing: FilledButton(
                              onPressed: pending
                                  ? null
                                  : () => _request(package),
                              child: LocalizedText('Chọn gói'),
                            ),
                          ),
                        ),
                      ),
                  SizedBox(height: 24),
                  LocalizedText(
                    'Lịch sử đăng ký / gia hạn',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ..._requests.map(
                    (request) => ListTile(
                      onTap:
                          request['status'] != 'pending' &&
                              ![
                                'momo_business',
                                'legacy_review',
                              ].contains(request['payment_provider'])
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => CheckoutScreen(
                                    package: {
                                      'id': request['package_id'],
                                      'name': request['package_name'],
                                      'price': request['amount'],
                                      'duration_days': request['duration_days'],
                                      'duration_months':
                                          request['duration_months'],
                                    },
                                    existingRequest: request,
                                  ),
                                ),
                              );
                              await _load();
                            },
                      leading: Icon(Icons.receipt_long),
                      title: LocalizedText(
                        (request['gym_packages'] as Map?)?['name'] as String? ??
                            'Gói tập',
                      ),
                      subtitle: LocalizedText('${request['created_at']}'),
                      trailing: LocalizedText(switch (request['status']) {
                        'approved' => 'Đã xác nhận',
                        'rejected' => 'Từ chối',
                        'expired' => 'Đã hết hạn',
                        'cancelled' => 'Đã hủy',
                        'pending'
                            when request['payment_provider'] ==
                                'legacy_review' =>
                          'Cần phòng tập xác minh',
                        'pending'
                            when request['payment_provider'] ==
                                'momo_business' =>
                          'Chờ MoMo xác nhận',
                        _ => 'Chờ xác nhận',
                      }),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
