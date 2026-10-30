import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_localization.dart';
import '../services/supabase_service.dart';
import '../services/payment_format.dart';
import '../services/payment_qr_service.dart';
import '../widgets/payment_qr_card.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> package;
  final Map<String, dynamic>? existingRequest;
  const CheckoutScreen({
    super.key,
    required this.package,
    this.existingRequest,
  });
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Map<String, dynamic>? _settings, _order;
  String _method = 'cash';
  String? _error, _paymentUrl;
  bool _busy = false, _loading = true;
  Timer? _statusTimer;
  RealtimeChannel? _statusChannel;
  bool _refreshing = false;
  bool get _hasBank =>
      (_settings?['bank_account_number'] as String? ?? '').isNotEmpty &&
      (_settings?['bank_name'] as String? ?? '').isNotEmpty &&
      (_settings?['bank_account_holder'] as String? ?? '').isNotEmpty;
  @override
  void initState() {
    super.initState();
    _order = widget.existingRequest;
    _method = _order?['payment_method'] as String? ?? 'cash';
    _loadSettings();
    if (_order != null) _watchStatus();
  }

  void _watchStatus() {
    _statusTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(),
    );
    final client = SupabaseService.client;
    if (client == null || _order == null || _statusChannel != null) return;
    _statusChannel = client
        .channel('checkout_${_order!['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'membership_renewal_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _order!['id'] as String,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    final channel = _statusChannel;
    if (channel != null) SupabaseService.client?.removeChannel(channel);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      _settings = await SupabaseService.client!
          .from('payment_settings')
          .select()
          .eq('id', true)
          .maybeSingle();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _order ??= await SupabaseService.client!
          .from('membership_renewal_requests')
          .insert({
            'user_id': SupabaseService.currentUser!.id,
            'package_id': widget.package['id'],
            'payment_method': _method,
          })
          .select()
          .single();
      _watchStatus();
      if (_method == 'online' && _settings?['online_enabled'] == true) {
        final response = await SupabaseService.client!.functions.invoke(
          'membership-payment',
          body: {'request_id': _order!['id']},
        );
        final data = response.data as Map;
        if (data['payment_url'] is! String) {
          throw StateError(
            data['error'] as String? ?? 'Không tạo được phiên thanh toán',
          );
        }
        final uri = Uri.parse(data['payment_url'] as String);
        if (uri.scheme != 'https') {
          throw StateError('Đường dẫn thanh toán không hợp lệ');
        }
        _paymentUrl = uri.toString();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    if (_order == null) return;
    try {
      await SupabaseService.client!.rpc(
        'cancel_own_membership_request',
        params: {'request_id': _order!['id']},
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _refresh() async {
    if (_order == null || _refreshing || !mounted) return;
    _refreshing = true;
    try {
      final order = await SupabaseService.client!
          .from('membership_renewal_requests')
          .select()
          .eq('id', _order!['id'])
          .single();
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _refreshing = false;
      if (_order?['status'] != 'pending') _statusTimer?.cancel();
    }
  }

  Widget _copy(String label, String value) => ListTile(
    title: LocalizedText(label),
    subtitle: SelectableText(value),
    trailing: IconButton(
      tooltip: tr('Sao chép'),
      icon: const Icon(Icons.copy_outlined),
      onPressed: () => Clipboard.setData(ClipboardData(text: value)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    AppSettingsScope.watch(context);
    final order = _order;
    final reference = order == null
        ? ''
        : 'FP${(order['id'] as String).replaceAll('-', '').toUpperCase()}';
    final approved = order?['status'] == 'approved';
    final rejected = order?['status'] == 'rejected';
    return Scaffold(
      appBar: AppBar(title: LocalizedText('Thanh toán gói tập')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    LocalizedText(
                      (order?['package_name'] ?? widget.package['name'])
                          as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    LocalizedText(
                      '${formatVnd(order?['amount'] ?? widget.package['price'])} • ${packageTerm(order ?? widget.package)}',
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      LocalizedText('Không thể xử lý thanh toán: $_error'),
                    if (order == null) ...[
                      LocalizedText(
                        'Chọn phương thức thanh toán',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      RadioGroup<String>(
                        groupValue: _method,
                        onChanged: (value) {
                          if (value != null) setState(() => _method = value);
                        },
                        child: Column(
                          children: [
                            RadioListTile(
                              value: 'cash',
                              title: LocalizedText('Thanh toán tại quầy'),
                              subtitle: LocalizedText(
                                'Phòng tập xác nhận sau khi nhận tiền.',
                              ),
                            ),
                            RadioListTile(
                              value: 'bank_transfer',
                              enabled: _hasBank,
                              title: LocalizedText('Chuyển khoản ngân hàng'),
                              subtitle: LocalizedText(
                                _hasBank
                                    ? 'Chuyển đúng số tiền và nội dung giao dịch.'
                                    : 'Phòng tập chưa cấu hình tài khoản nhận tiền.',
                              ),
                            ),
                            RadioListTile(
                              value: 'online',
                              enabled:
                                  _settings?['online_enabled'] == true ||
                                  (_settings?['momo_phone'] as String? ?? '')
                                      .isNotEmpty,
                              title: LocalizedText('Thanh toán MoMo'),
                              subtitle: LocalizedText(
                                _settings?['online_enabled'] == true
                                    ? '${_settings?['gateway_name'] ?? 'MoMo'}'
                                    : 'Chuyển MoMo và chờ phòng tập xác nhận.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: LocalizedText(
                          _busy ? 'Đang xử lý...' : 'Xác nhận phương thức',
                        ),
                      ),
                    ] else if (approved) ...[
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green,
                      ),
                      LocalizedText('Gia hạn thành công'),
                      LocalizedText(
                        'Gói tập đã được kích hoạt. Bạn có thể quay lại xem hợp đồng.',
                      ),
                    ] else if (rejected)
                      LocalizedText(
                        'Yêu cầu đã đóng. Hãy quay lại và chọn gói tập để tạo yêu cầu mới.',
                      )
                    else ...[
                      _copy('Mã yêu cầu', reference),
                      if (_method == 'cash')
                        LocalizedText(
                          'Đưa mã yêu cầu cho quầy lễ tân và thanh toán để kích hoạt gói tập.',
                        ),
                      if (_method == 'bank_transfer' && _hasBank) ...[
                        if (_settings!['bank_account_number'] == '1042362758')
                          PaymentQrCard(
                            data: PaymentQrService.forOrder(
                              momo: false,
                              amount: (order['amount'] as num).toInt(),
                              reference: reference,
                            ),
                            method: 'Vietcombank · 1042362758',
                            amount: (order['amount'] as num).toInt(),
                            reference: reference,
                          ),
                        _copy('Ngân hàng', _settings!['bank_name'] as String),
                        _copy(
                          'Số tài khoản',
                          _settings!['bank_account_number'] as String,
                        ),
                        _copy(
                          'Tên chủ tài khoản',
                          _settings!['bank_account_holder'] as String,
                        ),
                        _copy('Số tiền', '${order['amount']} VND'),
                        _copy('Nội dung chuyển khoản', reference),
                        LocalizedText(
                          'Phòng tập sẽ đối chiếu giao dịch và gửi thông báo sau khi xác nhận.',
                        ),
                      ],
                      if (_method == 'online' &&
                          _settings?['online_enabled'] != true) ...[
                        if (_settings?['momo_phone'] == '0775571311')
                          PaymentQrCard(
                            data: PaymentQrService.forOrder(
                              momo: true,
                              amount: (order['amount'] as num).toInt(),
                              reference: reference,
                            ),
                            method: 'MoMo · Tài khoản đuôi 026',
                            amount: (order['amount'] as num).toInt(),
                            reference: reference,
                          ),
                        _copy(
                          'Số MoMo',
                          _settings?['momo_phone'] as String? ?? '',
                        ),
                        _copy(
                          'Tên người nhận',
                          _settings?['bank_account_holder'] as String? ?? '',
                        ),
                        _copy('Số tiền', '${order['amount']} VND'),
                        _copy('Nội dung chuyển khoản', reference),
                        LocalizedText(
                          'Phòng tập sẽ đối chiếu giao dịch và gửi thông báo sau khi xác nhận.',
                        ),
                      ],
                      if (_method == 'online' &&
                          _settings?['online_enabled'] == true) ...[
                        if (_paymentUrl == null)
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: LocalizedText('Tạo phiên thanh toán online'),
                          ),
                        if (_paymentUrl != null)
                          FilledButton.icon(
                            onPressed: () async {
                              final opened = await launchUrl(
                                Uri.parse(_paymentUrl!),
                                mode: LaunchMode.externalApplication,
                              );
                              if (!opened && mounted) {
                                setState(
                                  () =>
                                      _error = 'Không mở được cổng thanh toán',
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: LocalizedText('Mở cổng thanh toán'),
                          ),
                        LocalizedText(
                          'Sau khi thanh toán, quay lại đây và kiểm tra trạng thái.',
                        ),
                      ],
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: LocalizedText('Kiểm tra trạng thái'),
                      ),
                      if (_method != 'online' ||
                          _settings?['online_enabled'] != true)
                        TextButton(
                          onPressed: _cancel,
                          child: LocalizedText('Hủy yêu cầu'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
