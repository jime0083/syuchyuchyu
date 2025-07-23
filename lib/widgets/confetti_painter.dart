import 'package:flutter/material.dart';

/// 紙吹雪の1つの粒子を表現するクラス
class ConfettiPiece {
  /// 紙吹雪の現在位置
  Offset position;
  
  /// 紙吹雪の色
  final Color color;
  
  /// 紙吹雪のサイズ（ピクセル）
  final double size;
  
  /// 紙吹雪の落下速度
  final double speed;
  
  /// 紙吹雪の左右の揺れ（ラジアン）
  final double angle;
  
  /// コンストラクタ - すべてのプロパティを初期化
  ConfettiPiece({
    required this.position,
    required this.color,
    required this.size,
    required this.speed,
    required this.angle,
  });
}

/// 紙吹雪を描画するCustomPainter
class ConfettiPainter extends CustomPainter {
  /// 描画する紙吹雪粒子のリスト
  final List<ConfettiPiece> confettiPieces;
  
  /// コンストラクタ
  ConfettiPainter(this.confettiPieces);
  
  @override
  void paint(Canvas canvas, Size size) {
    // すべての紙吹雪粒子を描画
    for (final piece in confettiPieces) {
      final paint = Paint()
        ..color = piece.color
        ..style = PaintingStyle.fill;
      
      // 紙吹雪の形（小さな長方形）を描画
      canvas.drawRect(
        Rect.fromCenter(
          center: piece.position,
          width: piece.size,
          height: piece.size * 1.5, // 少し縦長に
        ),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}
