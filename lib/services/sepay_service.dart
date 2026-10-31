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

/// Phiên thanh toán chuyển khoản đang chờ xử lý (giúp người dùng không bị mất mã phiên khi chuyển app sang ngân hàng)
class PendingPaymentSession {
  final String targetId; // userId hoặc shopId
  final String targetType; // 'vip' hoặc 'shop'
  final String planId;
  final int expectedAmount;
  final String transferContent;
  final String qrImageUrl;
  final DateTime sessionStartTime;

  const PendingPaymentSession({
    required this.targetId,
    required this.targetType,
    required this.planId,
    required this.expectedAmount,
    required this.transferContent,
    required this.qrImageUrl,
    required this.sessionStartTime,
  });

  Map<String, dynamic> toJson() => {
        'targetId': targetId,
        'targetType': targetType,
        'planId': planId,
        'expectedAmount': expectedAmount,
        'transferContent': transferContent,
        'qrImageUrl': qrImageUrl,
        'sessionStartTime': sessionStartTime.toIso8601String(),
      };

  factory PendingPaymentSession.fromJson(Map<String, dynamic> json) => PendingPaymentSession(
        targetId: json['targetId'] as String? ?? '',
        targetType: json['targetType'] as String? ?? 'vip',
        planId: json['planId'] as String? ?? '',
        expectedAmount: (json['expectedAmount'] as num?)?.toInt() ?? 0,
        transferContent: json['transferContent'] as String? ?? '',
        qrImageUrl: json['qrImageUrl'] as String? ?? '',
        sessionStartTime: DateTime.tryParse(json['sessionStartTime'] as String? ?? '') ?? DateTime.now(),
      );

  /// Phiên hợp lệ trong vòng 20 phút kể từ lúc mở
  bool get isValid {
    final diff = DateTime.now().difference(sessionStartTime);
    return diff.inMinutes >= 0 && diff.inMinutes < 20;
  }

  /// Số giây còn lại cho bộ đếm 15 phút
  int get remainingCountdownSeconds {
    final elapsed = DateTime.now().difference(sessionStartTime).inSeconds;
    final remain = (15 * 60) - elapsed;
    return remain > 0 ? remain : 0;
  }
}

class SepayService {
  static const String _prefTokenKey = 'gearsports_sepay_api_token';
  static const String _prefUsedTxIdsKey = 'gearsports_sepay_used_tx_ids';
  static String _pendingKey(String targetId) => 'gearsports_pending_session_$targetId';

  /// Lưu phiên thanh toán đang chờ xử lý vào bộ nhớ máy
  static Future<void> savePendingSession(PendingPaymentSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingKey(session.targetId);
      await prefs.setString(key, jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('Lỗi lưu pending payment session: $e');
    }
  }

  /// Lấy phiên thanh toán đang chờ xử lý nếu còn hiệu lực trong vòng 20 phút
  static Future<PendingPaymentSession?> getPendingSession(String targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingKey(targetId);
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final session = PendingPaymentSession.fromJson(map);
      if (session.isValid) {
        return session;
      } else {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Lỗi đọc pending payment session: $e');
    }
    return null;
  }

  /// Xóa phiên thanh toán đang chờ xử lý khi hoàn tất hoặc người dùng chủ động hủy
  static Future<void> clearPendingSession(String targetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKey(targetId));
    } catch (e) {
      debugPrint('Lỗi xóa pending payment session: $e');
    }
  }

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

  /// Chuyển đổi ngày giờ từ SePAY (luôn theo giờ chuẩn Việt Nam GMT+7) thành DateTime UTC chuẩn
  /// để tránh lỗi lệch múi giờ trên các thiết bị đặt timezone khác (Emulator, điện thoại ở nước ngoài,...)
  static DateTime? parseSepayDate(dynamic rawDate) {
    if (rawDate == null) return null;
    final str = rawDate.toString().trim();
    if (str.isEmpty) return null;

    try {
      // Nếu chuỗi đã có offset múi giờ (+07:00 hoặc Z)
      if (str.contains('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(str)) {
        return DateTime.tryParse(str)?.toUtc();
      }

      // SePAY trả về "yyyy-MM-dd HH:mm:ss" hoặc "yyyy-MM-ddTHH:mm:ss"
      final normalized = str.replaceAll(' ', 'T');
      // Thêm offset +07:00 của giờ Việt Nam để parse tuyệt đối chính xác
      final withOffset = '$normalized+07:00';
      final parsed = DateTime.tryParse(withOffset);
      if (parsed != null) {
        return parsed.toUtc();
      }
      return DateTime.tryParse(str)?.toUtc();
    } catch (_) {
      return null;
    }
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
        // Tăng limit=100 để bao quát đầy đủ danh sách giao dịch, tránh sót giao dịch khi tài khoản có biến động lớn
        final uri = Uri.parse('$baseUrl?account_number=$acc&limit=100');

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

          // 2. KIỂM TRA THỜI GIAN GIAO DỊCH CHUẨN UTC:
          // Parse ngày giờ SePAY theo múi giờ chuẩn Việt Nam (UTC+7) rồi so sánh theo UTC.
          // Vì nội dung chuyển khoản đã có mã 8 số ngẫu nhiên độc nhất và đã chặn giao dịch đã dùng,
          // nên chỉ bỏ qua nếu giao dịch cũ hơn 12 tiếng trước khi mở phiên để chống lỗi lệch đồng hồ/timezone client.
          final txDateUtc = parseSepayDate(tx['transaction_date']);
          if (sessionStartTime != null && txDateUtc != null) {
            final sessionStartUtc = sessionStartTime.toUtc();
            final minValidTimeUtc = sessionStartUtc.subtract(const Duration(hours: 12));
            if (txDateUtc.isBefore(minValidTimeUtc)) {
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
              transactionDate: txDateUtc?.toLocal() ?? DateTime.now(),
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
