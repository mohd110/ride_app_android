import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class EarningsChart extends StatelessWidget {
  final String chartType;
  final double todayEarnings;
  final double weeklyEarnings;

  const EarningsChart({
    Key? key,
    required this.chartType,
    required this.todayEarnings,
    required this.weeklyEarnings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<double> dataPoints = [];
    List<String> labels = [];

    if (chartType == 'daily') {
      dataPoints = [12.50, 42.80, 22.10, 50.60, todayEarnings];
      labels = ['08:00', '12:00', '16:00', '20:00', 'Now'];
    } else if (chartType == 'weekly') {
      dataPoints = [180.50, 240.20, 165.00, 290.40, 150.00, todayEarnings, 0];
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else {
      dataPoints = [380.00, 420.50, 310.20, weeklyEarnings];
      labels = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
    }

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: CustomPaint(
        painter: _ChartPainter(
          dataPoints: dataPoints,
          labels: labels,
          chartType: chartType,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> labels;
  final String chartType;

  _ChartPainter({
    required this.dataPoints,
    required this.labels,
    required this.chartType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double maxVal = dataPoints.fold(100.0, (prev, element) => element > prev ? element : prev);
    final int count = dataPoints.length;
    final double colWidth = size.width / (count * 1.8);
    final double spacing = (size.width - (colWidth * count)) / (count + 1);

    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height - 20), Offset(size.width, size.height - 20), linePaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);

    for (int i = 0; i < count; i++) {
      final double val = dataPoints[i];
      final double colHeight = (val / maxVal) * (size.height - 45);
      final double x = spacing + i * (colWidth + spacing);
      final double y = (size.height - 20) - colHeight;

      final bool isPeak = chartType == 'daily' && labels[i] == '12:00';
      final barRect = Rect.fromLTWH(x, y, colWidth, colHeight);
      final rrect = RRect.fromRectAndRadius(barRect, const Radius.circular(6));

      final barPaint = Paint()
        ..color = isPeak ? AppColors.chartBarActive : AppColors.chartBar;

      canvas.drawRRect(rrect, barPaint);

      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w600),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (colWidth - textPainter.width) / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints ||
        oldDelegate.labels != labels ||
        oldDelegate.chartType != chartType;
  }
}
