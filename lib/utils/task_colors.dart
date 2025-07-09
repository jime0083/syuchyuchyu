import 'package:flutter/material.dart';

class TaskColors {
  // タスクの色の定義
  static const Color red = Color(0xFFE57373);       // 赤
  static const Color blue = Color(0xFF64B5F6);      // 青
  static const Color yellow = Color(0xFFFFD54F);    // 黄色
  static const Color green = Color(0xFF81C784);     // 緑
  static const Color pink = Color(0xFFF48FB1);      // ピンク
  static const Color purple = Color(0xFFB39DDB);    // 紫
  static const Color orange = Color(0xFFFFB74D);    // オレンジ (デフォルト)
  static const Color lightBlue = Color(0xFF4FC3F7); // 水色
  static const Color black = Color(0xFF757575);     // 黒 (実際は暗めのグレー)

  // 色の名前とColorオブジェクトのマッピング
  static final Map<String, Color> colorMap = {
    'red': red,
    'blue': blue,
    'yellow': yellow,
    'green': green,
    'pink': pink,
    'purple': purple,
    'orange': orange,
    'lightBlue': lightBlue,
    'black': black,
  };

  // 色の名前と日本語表示のマッピング
  static final Map<String, String> colorNameMap = {
    'red': '赤',
    'blue': '青',
    'yellow': '黄色',
    'green': '緑',
    'pink': 'ピンク',
    'purple': '紫',
    'orange': 'オレンジ',
    'lightBlue': '水色',
    'black': '黒',
  };

  // デフォルトの色のキー
  static const String defaultColorKey = 'orange';

  // 色のキーのリスト
  static final List<String> colorKeys = [
    'red',
    'blue',
    'yellow',
    'green',
    'pink',
    'purple',
    'orange',
    'lightBlue',
    'black',
  ];

  // 色のキーから色を取得
  static Color getColor(String? colorKey) {
    return colorMap[colorKey] ?? orange;
  }

  // 曜日の選択肢
  static const List<String> weekdays = [
    '毎日',
    '日曜',
    '月曜',
    '火曜',
    '水曜',
    '木曜',
    '金曜',
    '土曜',
  ];
}
