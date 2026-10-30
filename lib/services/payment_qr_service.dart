import 'dart:convert';

/// Exact recipient payloads decoded from the owner's two original QR photos.
/// No payment URI or receiving account is inferred from a phone number.
class PaymentQrService {
  PaymentQrService._();
  static const bankOriginal =
      '00020101021138540010A00000072701240006970436011010423627580208QRIBFTTA53037045802VN6304B057';
  static const momoOriginal =
      '00020101021138630010A000000727013300069710250119PSP26147170000000260208QRIBFTTA53037045802VN62190515MOMOW2W8282600163040231';

  static Map<String, String> parse(String payload) {
    final result = <String, String>{};
    var offset = 0;
    while (offset < payload.length) {
      if (offset + 4 > payload.length) {
        throw const FormatException('Invalid QR field');
      }
      final id = payload.substring(offset, offset + 2);
      final length = int.parse(payload.substring(offset + 2, offset + 4));
      offset += 4;
      if (offset + length > payload.length || result.containsKey(id)) {
        throw const FormatException('Invalid QR length');
      }
      result[id] = payload.substring(offset, offset + length);
      offset += length;
    }
    return result;
  }

  static String _field(String id, String value) {
    final length = utf8.encode(value).length;
    if (length > 99) throw const FormatException('QR field too long');
    return '$id${length.toString().padLeft(2, '0')}$value';
  }

  static String _fields(Map<String, String> fields) {
    final ids = fields.keys.toList()..sort();
    return ids.map((id) => _field(id, fields[id]!)).join();
  }

  static String checksum(String value) {
    var crc = 0xffff;
    for (final byte in utf8.encode(value)) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xffff
            : (crc << 1) & 0xffff;
      }
    }
    return crc.toRadixString(16).padLeft(4, '0').toUpperCase();
  }

  static bool isValid(String payload) {
    try {
      final fields = parse(payload);
      return fields['63'] == checksum(payload.substring(0, payload.length - 4));
    } catch (_) {
      return false;
    }
  }

  static String forOrder({
    required bool momo,
    required int amount,
    required String reference,
  }) {
    if (amount <= 0 || !RegExp(r'^[A-Z0-9]{1,40}$').hasMatch(reference)) {
      throw const FormatException('Invalid payment details');
    }
    final source = momo ? momoOriginal : bankOriginal;
    if (!isValid(source)) {
      throw const FormatException('Invalid original QR checksum');
    }
    final fields = parse(source)..remove('63');
    fields['01'] = '12';
    fields['54'] = amount.toString();
    final additional = fields['62'] == null
        ? <String, String>{}
        : parse(fields['62']!);
    // Preserve MoMo's original routing reference (05), append transfer purpose (08).
    additional['08'] = reference;
    fields['62'] = _fields(additional);
    final content = '${_fields(fields)}6304';
    return '$content${checksum(content)}';
  }
}
