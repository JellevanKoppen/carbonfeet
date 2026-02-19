part of 'package:carbonfeet/main.dart';

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({required this.data, super.key});

  final List<CategoryDisplayData> data;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PiePainter(data));
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.data);

  final List<CategoryDisplayData> data;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<double>(0, (sum, item) => sum + item.valueKg);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()..style = PaintingStyle.fill;

    var startAngle = -math.pi / 2;
    for (final item in data) {
      final sweep = total <= 0 ? 0.0 : (item.valueKg / total) * math.pi * 2;
      basePaint.color = item.color;
      canvas.drawArc(rect, startAngle, sweep, true, basePaint);
      startAngle += sweep;
    }

    final centerCutPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.54, centerCutPaint);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class TrendChart extends StatelessWidget {
  const TrendChart({required this.points, super.key});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(points: points),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points});

  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (var i = 0; i < 5; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) {
      return;
    }

    final maxValue = points.reduce(math.max);
    final minValue = points.reduce(math.min);
    final range = math.max(maxValue - minValue, 1);

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final normalized = (points[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF2A9D8F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF1D3557);
    for (var i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final normalized = (points[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
