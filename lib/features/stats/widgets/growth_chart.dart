import 'package:flutter/material.dart';

import 'package:kana_trainer/core/theme/app_theme.dart';
import 'package:kana_trainer/features/progress/vocab_history_notifier.dart';

/// 詞彙量成長折線（近 30 天）：池內總數（金）+ 已學會（綠）。自繪零依賴。
class GrowthChart extends StatelessWidget {
  final Map<String, VocabSnapshot> history;

  const GrowthChart({super.key, required this.history});

  static const days = 30;

  /// 近 [days] 天資料，按日期排序（缺日不補，線直接相連）。
  static List<(String, VocabSnapshot)> recent(
      Map<String, VocabSnapshot> history, String today) {
    final cutoff = DateTime.parse(today).subtract(Duration(days: days));
    final entries = history.entries
        .where((e) => DateTime.parse(e.key).isAfter(cutoff))
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final data = entries.length > days
        ? entries.sublist(entries.length - days)
        : entries;

    if (data.length < 2) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            '再練幾天就有成長曲線了 📈',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.indigoFaded,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: CustomPaint(
        size: Size.infinite,
        painter: _GrowthPainter(data),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  final List<(String, VocabSnapshot)> data;

  _GrowthPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = data
        .map((e) => e.$2.total)
        .fold<int>(1, (a, b) => a > b ? a : b)
        .toDouble();

    Offset point(int i, int value) {
      final x = data.length == 1
          ? 0.0
          : i / (data.length - 1) * (size.width - 44); // 右側留數字空間
      final y = size.height - (value / maxY) * (size.height - 16) - 4;
      return Offset(x, y);
    }

    void drawLine(int Function(VocabSnapshot) valueOf, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final p = point(i, valueOf(data[i].$2));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      // 右端標當前值
      final last = point(data.length - 1, valueOf(data.last.$2));
      final tp = TextPainter(
        text: TextSpan(
          text: '${valueOf(data.last.$2)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(last.dx + 6, last.dy - tp.height / 2));
    }

    drawLine((s) => s.total, AppColors.gold);
    drawLine((s) => s.learned, AppColors.green);
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter old) => old.data != data;
}
