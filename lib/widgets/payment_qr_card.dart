import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/app_localization.dart';
import '../services/payment_format.dart';
import '../theme/app_theme.dart';

class PaymentQrCard extends StatelessWidget {
  final String data;
  final String method;
  final int amount;
  final String reference;
  const PaymentQrCard({
    super.key,
    required this.data,
    required this.method,
    required this.amount,
    required this.reference,
  });

  Widget _qr(double size) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(20),
    child: QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    ),
  );

  void _zoom(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xff142033),
          title: LocalizedText('Quét mã thanh toán'),
          actions: [
            IconButton(
              tooltip: tr('Đóng'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = math
                .max(
                  120.0,
                  math.min(
                    constraints.maxWidth - 64,
                    constraints.maxHeight - 230,
                  ),
                )
                .clamp(120.0, 760.0);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      method,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff142033),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatVnd(amount),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff142033),
                      ),
                    ),
                    InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: _qr(size),
                    ),
                    const Text(
                      'NGUYEN VU DUY',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xff142033),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      reference,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xff475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        LocalizedText(
          'Quét mã để thanh toán',
          style: AppTextTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(method, style: AppTextTheme.caption),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => Semantics(
            label: tr('Mã QR thanh toán'),
            button: true,
            child: InkWell(
              onTap: () => _zoom(context),
              child: _qr(
                math.min(360.0, math.max(120.0, constraints.maxWidth - 40)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(formatVnd(amount), style: AppTextTheme.headlineLarge),
        const SizedBox(height: 6),
        const Text('NGUYEN VU DUY'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _zoom(context),
          icon: const Icon(Icons.zoom_in),
          label: LocalizedText('Phóng to mã QR'),
        ),
        const SizedBox(height: 8),
        LocalizedText(
          'Kiểm tra tên người nhận và số tiền trong ứng dụng trước khi xác nhận.',
          style: AppTextTheme.caption,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
