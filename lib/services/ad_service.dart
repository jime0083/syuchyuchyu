import 'package:flutter/material.dart';

class AdService with ChangeNotifier {
  // 初期化
  Future<void> initialize() async {
    // 将来的に実際の広告SDKを初期化する場所
  }

  // ダミーの広告ウィジェット
  Widget getDummyBanner() {
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: const Text('広告バナー', style: TextStyle(color: Color(0xFF707070))),
    );
  }

  // 広告ウィジェットを取得（現在はダミーのみ）
  Widget getBannerWidget() {
    return getDummyBanner();
  }
}
