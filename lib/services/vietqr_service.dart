class VietQrConfig {
  static const String defaultBankId = 'MB'; // MBBank - Ngân hàng Quân Đội
  static const String defaultBankName = 'Ngân hàng TMCP Quân Đội (MBBank)';
  static const String defaultAccountNumber = '0949614588';
  static const String defaultAccountName = 'NGUYEN SON NAM';

  /// Sinh link ảnh VietQR Napas 24/7 chuẩn ngân hàng
  static String generateQrImageUrl({
    required int amount,
    required String transferContent,
    String bankId = defaultBankId,
    String accountNumber = defaultAccountNumber,
    String accountName = defaultAccountName,
  }) {
    final encodedContent = Uri.encodeComponent(transferContent.trim());
    final encodedAccountName = Uri.encodeComponent(accountName.trim());
    return 'https://img.vietqr.io/image/$bankId-$accountNumber-compact2.png?amount=$amount&addInfo=$encodedContent&accountName=$encodedAccountName';
  }

  /// Sinh mã nội dung chuyển khoản duy nhất cho mỗi phiên thanh toán (VD: VIP ABCD 84729103)
  /// Đảm bảo độ dài <= 18 ký tự để không bao giờ bị cắt ngắn bởi giới hạn 20 ký tự của Napas 24/7 và App ngân hàng
  static String generateTransferContent({
    required String prefix,
    required String userId,
  }) {
    // Rút gọn tiền tố (loại bỏ 'GS ' nếu có để tiết kiệm ký tự: 'GS VIP' -> 'VIP', 'GS SHOP' -> 'SHOP')
    final cleanPrefix = prefix.replaceAll('GS ', '').trim();
    final cleanUser = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final shortUser = cleanUser.length > 4
        ? cleanUser.substring(cleanUser.length - 4)
        : (cleanUser.isEmpty ? 'USER' : cleanUser);
    // Sinh số ngẫu nhiên 8 chữ số (10000000 - 99999999) kết hợp timestamp để đảm bảo mỗi lần thanh toán có nội dung riêng biệt
    final randomSuffix = ((DateTime.now().millisecondsSinceEpoch) % 90000000 + 10000000).toString();
    return '$cleanPrefix $shortUser $randomSuffix'.toUpperCase();
  }
}
