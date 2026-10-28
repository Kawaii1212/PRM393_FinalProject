// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:convert';

import 'package:finalproject/data/hcm_shop_data.dart';
import 'package:finalproject/data/csv_shop_data.dart';
import 'package:finalproject/models/shop_model.dart';

void main() async {
  final client = HttpClient();
  const projectId = 'gearsports-prm393';
  const apiKey = 'AIzaSyANUCDBpjrZlB8nwHS-YLsIGUR7R7vGsaE';

  final List<Shop> allShops = [
    ...HcmShopData.shops,
    ...CsvShopData.shops,
  ];

  print('Bắt đầu tải ${allShops.length} cửa hàng lên Cloud Firestore...');
  print('- TP. Hồ Chí Minh: ${HcmShopData.shops.length} shop');
  print('- Hà Nội: ${CsvShopData.shops.length} shop\n');

  const int batchSize = 100;
  int successCount = 0;

  for (int i = 0; i < allShops.length; i += batchSize) {
    final chunk = allShops.sublist(
      i,
      i + batchSize > allShops.length ? allShops.length : i + batchSize,
    );

    final writes = chunk.map((shop) {
      return {
        "update": {
          "name": "projects/$projectId/databases/(default)/documents/shops/${shop.id}",
          "fields": {
            "id": {"stringValue": shop.id},
            "name": {"stringValue": shop.name},
            "address": {"stringValue": shop.address},
            "district": {"stringValue": shop.district},
            "city": {"stringValue": shop.city},
            "latitude": {"doubleValue": shop.latitude},
            "longitude": {"doubleValue": shop.longitude},
            "rating": {"doubleValue": shop.rating},
            "reviewCount": {"integerValue": "${shop.reviewCount}"},
            "machineModel": {"stringValue": shop.machineModel},
            "stringerCert": {"stringValue": shop.stringerCert},
            "phone": {"stringValue": shop.phone},
            "openHours": {"stringValue": shop.openHours},
            "imageUrl": {"stringValue": shop.imageUrl},
            "distanceKm": {"doubleValue": shop.distanceKm},
          }
        }
      };
    }).toList();

    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit?key=$apiKey',
    );

    final req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({"writes": writes}));
    final res = await req.close();
    final resBody = await res.transform(utf8.decoder).join();

    if (res.statusCode == 200) {
      successCount += chunk.length;
      print('✓ Đã tải Batch ${i ~/ batchSize + 1}: ${chunk.length} shop (Tổng: $successCount / ${allShops.length})');
    } else {
      print('✗ Lỗi tại batch ${i ~/ batchSize + 1}: HTTP ${res.statusCode}');
      print('Chi tiết lỗi: $resBody');
    }
  }

  print('\n🎉 THÀNH CÔNG RỰC RỠ: Toàn bộ $successCount shop đã được lưu lên Cloud Firestore (collection "shops")!');
  client.close();
}
