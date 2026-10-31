import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vietqr_service.dart';

/// Kết quả kiểm tra giao dịch từ SePAY
class SepayCheckResult {
  final bool isSuccess;
  final String message;
  final String? transactionId;
  final double? amount;
  final String? transactionContent;
  final DateTime? transactionDate;

  const SepayCheckResult({
    required this.isSuccess,
    required this.message,
    this.transactionId,
    this.amount,
    this.transactionContent,
    this.transactionDate,
  });

  factory SepayCheckResult.notFound([String? message]) => SepayCheckResult(
        isSuccess: false,
        message: message ?? 'Hệ thống chưa tìm thấy giao dịch chuyển khoản phù hợp.',
      );

  factory SepayCheckResult.error(String error) => SepayCheckResult(
        isSuccess: false,
        message: 'Lỗi kết nối kiểm tra giao dịch: $error',
      );
}

class SepayService {
  static const String _prefTokenKey = 'gearsports_sepay_api_token';
  static const String _prefUsedTxIdsKey = 'gearsports_sepay_used_tx_ids';

  // Endpoint API chuẩn v2 của SePAY
  static const String primaryApiUrl = 'https://userapi.sepay.vn/v2/transactions';
  static const String fallbackApiUrl = 'https://my.sepay.vn/userapi/transactions/list';

  // API Token chính thức đã kích hoạt từ SePAY của bạn
  static const String fallbackDefaultToken = 'E9SCA5FNUP1H8EVNZHAKRAC2XKT4YFEJZTD7UJDTGK0PGWQRIXZGDVZMXVSO6WAL';

  static String? _cachedToken;

  /// Chuẩn hóa chuỗi (bỏ dấu cách, ký tự đặc biệt, viết hoa) để so khớp chính xác
  static String normalizeCode(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  /// Lấy SePAY API Token hiện tại từ cấu hình hoặc SharedPreferences
  static Future<String> getApiToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_prefTokenKey);
      if (savedToken != null && savedToken.trim().isNotEmpty) {
        _cachedToken = savedToken.trim();
        return _cachedToken!;
      }
    } catch (e) {
      debugPrint('Lỗi đọc SePAY token từ bộ nhớ: $e');
    }
    return fallbackDefaultToken;
  }

  /// Lưu SePAY API Token vào SharedPreferences (chỉ dùng bởi Admin)
  static Future<void> saveApiToken(String token) async {
    _cachedToken = token.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefTokenKey, _cachedToken!);
    } catch (e) {
      debugPrint('Lỗi lưu SePAY token: $e');
    }
  }

  /// Xóa Token (reset về mặc định)
  static Future<void> clearApiToken() async {
    _cachedToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
    } catch (_) {}
  }

  /// Kiểm tra xem người dùng đã thiết lập Token hay chưa
  static Future<bool> hasConfiguredToken() async {
    final token = await getApiToken();
    return token.isNotEmpty;
  }

  /// Lấy danh sách ID các giao dịch ngân hàng đã từng được kích hoạt thành công để chống dùng lại
  static Future<Set<String>> getPersistedUsedTransactionIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefUsedTxIdsKey);
      if (list != null) {
        return list.toSet();
      }
    } catch (e) {
      debugPrint('Lỗi đọc used tx ids: $e');
    }
    return <String>{};
  }

  /// Đánh dấu ID giao dịch ngân hàng đã được sử dụng
  static Future<void> markTransactionAsUsed(String txId) async {
    final cleanId = txId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = (prefs.getStringList(_prefUsedTxIdsKey) ?? []).toSet();
      existing.add(cleanId);
      await prefs.setStringList(_prefUsedTxIdsKey, existing.toList());
    } catch (e) {
      debugPrint('Lỗi lưu used tx id: $e');
    }
  }

  /// Gọi API SePAY để kiểm tra xem đã có giao dịch nào khớp với mã chuyển khoản và số tiền chưa
  /// [usedTransactionIds]: Danh sách các ID giao dịch SePAY ĐÃ ĐƯỢC KÍCH HOẠT trước đó để chống dùng lại 1 giao dịch nhiều lần!
  /// [usedTransferCodes]: Danh sách các mã chuyển khoản đã hoàn tất trước đó
  /// [sessionStartTime]: Thời điểm người dùng mở phiên thanh toán (giao dịch trong quá khứ sẽ bị bỏ qua)
  static Future<SepayCheckResult> checkPayment({
    required String transferCode,
    required int expectedAmount,
    String? accountNumber,
    Set<String>? usedTransactionIds,
    Set<String>? usedTransferCodes,
    DateTime? sessionStartTime,
  }) async {
    final token = await getApiToken();
    if (token.isEmpty) {
      return const SepayCheckResult(
        isSuccess: false,
        message: 'Chưa cấu hình SePAY API Token trên hệ thống Admin.',
      );
    }

    final acc = accountNumber ?? VietQrConfig.defaultAccountNumber;

    // Đọc danh sách ID giao dịch đã kích hoạt từ SharedPreferences để chặn ngay cả khi Provider chưa load xong
    final persistedUsedIds = await getPersistedUsedTransactionIds();
    final allUsedIds = <String>{
      ...persistedUsedIds,
      ...?usedTransactionIds,
    };

    // Thử gọi API v2 trước, nếu gặp lỗi thử fallback sang API v1
    for (final baseUrl in [primaryApiUrl, fallbackApiUrl]) {
      try {
        final uri = Uri.parse('$baseUrl?account_number=$acc&limit=30');

        final response = await http.get(
          uri,
          headers: {
            // Header chuẩn của SePAY là Bearer
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) {
          debugPrint('SePAY $baseUrl returned status ${response.statusCode}');
          continue; // thử endpoint tiếp theo
        }

        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final dynamic rawList = body['data'] ?? body['transactions'];

        if (rawList is! List || rawList.isEmpty) {
          continue;
        }

        // Mã phiên thanh toán được chuẩn hóa (bao gồm cả tiền tố + user + 8 chữ số phiên duy nhất)
        final normalizedExpectedCode = normalizeCode(transferCode);

        for (final item in rawList) {
          final tx = item as Map<String, dynamic>;
          final txId = (tx['id'] ?? '').toString().trim();
          final referenceNum = (tx['reference_number'] ?? '').toString().trim();

          // 1. CHỐNG GIAN LẬN DÙNG LẠI GIAO DỊCH CŨ (Replay Attack Prevention):
          // Nếu ID giao dịch SePAY hoặc reference_number đã từng được kích hoạt -> BỎ QUA NGAY!
          if (txId.isNotEmpty && allUsedIds.contains(txId)) {
            continue;
          }
          if (referenceNum.isNotEmpty && allUsedIds.contains(referenceNum)) {
            continue;
          }

          final rawContent = (tx['transaction_content'] ?? '').toString();
          final normalizedContent = normalizeCode(rawContent);

          if (usedTransferCodes != null && usedTransferCodes.isNotEmpty) {
            if (usedTransferCodes.contains(normalizedContent)) {
              continue;
            }
          }

          // 2. KIỂM TRA THỜI GIAN GIAO DỊCH:
          // Nếu giao dịch ngân hàng xảy ra trước thời điểm tạo phiên thanh toán quá 15 phút -> Bỏ qua
          DateTime? txDate;
          if (tx['transaction_date'] != null) {
            txDate = DateTime.tryParse(tx['transaction_date'].toString());
          }
          if (sessionStartTime != null && txDate != null) {
            final minValidTime = sessionStartTime.subtract(const Duration(minutes: 15));
            if (txDate.isBefore(minValidTime)) {
              continue;
            }
          }

          // 3. Đọc số tiền vào (amount_in)
          final rawAmountIn = tx['amount_in'];
          double amountIn = 0;
          if (rawAmountIn is num) {
            amountIn = rawAmountIn.toDouble();
          } else if (rawAmountIn is String) {
            amountIn = double.tryParse(rawAmountIn.replaceAll(',', '')) ?? 0;
          }

          // 4. KIỂM TRA ĐIỀU KIỆN CHÍNH XÁC:
          // - Số tiền nhận được >= số tiền yêu cầu
          // - Nội dung giao dịch ngân hàng PHẢI chứa đúng mã phiên của lần thanh toán này!
          final isAmountMatch = amountIn >= expectedAmount;
          final isCodeMatch = normalizedContent.contains(normalizedExpectedCode);

          if (isAmountMatch && isCodeMatch) {
            final validTxId = txId.isNotEmpty
                ? txId
                : (referenceNum.isNotEmpty ? referenceNum : 'SEPAY_${DateTime.now().millisecondsSinceEpoch}');

            // Lưu ngay vào SharedPreferences để chặn lập tức mọi lần bấm kiểm tra tiếp theo
            await markTransactionAsUsed(validTxId);
            if (referenceNum.isNotEmpty) {
              await markTransactionAsUsed(referenceNum);
            }

            return SepayCheckResult(
              isSuccess: true,
              message: 'Đã xác nhận nhận thành công ${amountIn.toInt()}đ vào STK MBBank!',
              transactionId: validTxId,
              amount: amountIn,
              transactionContent: rawContent,
              transactionDate: txDate ?? DateTime.now(),
            );
          }
        }

        return SepayCheckResult.notFound(
          'Đã kiểm tra sao kê nhưng chưa tìm thấy giao dịch chuyển khoản mới khớp với mã "$transferCode" và số tiền $expectedAmountđ.',
        );
      } catch (e) {
        debugPrint('Lỗi gọi API SePAY ($baseUrl): $e');
      }
    }

    return SepayCheckResult.notFound(
      'Hệ thống chưa tìm thấy giao dịch chuyển khoản mới cho nội dung này. Vui lòng hoàn tất chuyển tiền trên ứng dụng ngân hàng rồi thử lại!',
    );
  }
}
