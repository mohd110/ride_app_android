import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';

const _monthAbbrev = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class EarningsChart extends StatelessWidget {
  final String chartType;
  final List<DailyEarningsPoint> dailyEarnings;

  const EarningsChart({
    Key? key,
    required this.chartType,
    required this.dailyEarnings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<double> dataPoints;
    List<String> labels;

    if (chartType == 'daily') {
      final days = _lastN(dailyEarnings, 7);
      dataPoints = days.map((d) => d.total).toList();
      labels = days.map((d) => _weekdayAbbrev[d.day.weekday - 1]).toList();
    } else if (chartType == 'weekly') {
      final weeks = _bucketByWeek(dailyEarnings, 7);
      dataPoints = weeks.map((w) => w.total).toList();
      labels = weeks.map((w) => w.label).toList();
    } else {
      final months = _bucketByMonth(dailyEarnings, 6);
      dataPoints = months.map((m) => m.total).toList();
      labels = months.map((m) => m.label).toList();
    }

    if (dataPoints.isEmpty) {
      dataPoints = [0];
      labels = [''];
    }

    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: CustomPaint(
        painter: _ChartPainter(
          dataPoints: dataPoints,
          labels: labels,
        ),
      ),
    );
  }

  List<DailyEarningsPoint> _lastN(List<DailyEarningsPoint> source, int n) {
    if (source.length <= n) return source;
    return source.sublist(source.length - n);
  }

  List<_Bucket> _bucketByWeek(List<DailyEarningsPoint> source, int weekCount) {
    final days = _lastN(source, weekCount * 7);
    final buckets = <_Bucket>[];
    for (var i = 0; i < days.length; i += 7) {
      final chunk = days.sublist(i, i + 7 > days.length ? days.length : i + 7);
      final total = chunk.fold(0.0, (sum, d) => sum + d.total);
      final end = chunk.last.day;
      buckets.add(_Bucket(total: total, label: '${end.day}/${end.month}'));
    }
    return buckets;
  }

  List<_Bucket> _bucketByMonth(List<DailyEarningsPoint> source, int monthCount) {
    final byMonth = <String, double>{};
    for (final d in source) {
      final key = '${d.day.year}-${d.day.month}';
      byMonth[key] = (byMonth[key] ?? 0) + d.total;
    }
    final keys = byMonth.keys.toList()
      ..sort((a, b) {
        final ap = a.split('-').map(int.parse).toList();
        final bp = b.split('-').map(int.parse).toList();
        return DateTime(ap[0], ap[1]).compareTo(DateTime(bp[0], bp[1]));
      });
    final lastKeys = keys.length <= monthCount ? keys : keys.sublist(keys.length - monthCount);
    return lastKeys.map((key) {
      final month = int.parse(key.split('-')[1]);
      return _Bucket(total: byMonth[key]!, label: _monthAbbrev[month - 1]);
    }).toList();
  }
}

class _Bucket {
  final double total;
  final String label;
  const _Bucket({required this.total, required this.label});
}

class _ChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final List<String> labels;

  _ChartPainter({
    required this.dataPoints,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double maxVal = dataPoints.fold(1.0, (prev, element) => element > prev ? element : prev);
    final int count = dataPoints.length;
    final double colWidth = size.width / (count * 1.8);
    final double spacing = (size.width - (colWidth * count)) / (count + 1);

    final linePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height - 20), Offset(size.width, size.height - 20), linePaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    final double peak = dataPoints.reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < count; i++) {
      final double val = dataPoints[i];
      final double colHeight = (val / maxVal) * (size.height - 45);
      final double x = spacing + i * (colWidth + spacing);
      final double y = (size.height - 20) - colHeight;

      final bool isPeak = val == peak && val > 0;
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
    return oldDelegate.dataPoints != dataPoints || oldDelegate.labels != labels;
  }
}
