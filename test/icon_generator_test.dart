import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Generate App Icon', (WidgetTester tester) async {
    const size = 1024.0;
    tester.view.physicalSize = const Size(size, size);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF0D0F14), // Dark background for the icon
          ),
          child: Center(
            child: Container(
              width: size * 0.85,
              height: size * 0.85,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF7A1E), Color(0xFFC94F00)],
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: CustomPaint(
                    painter: _ScaledMicPainter(color: Colors.white.withOpacity(0.95)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Give it a tiny bit to render
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Directionality).first,
      matchesGoldenFile('goldens/app_icon.png'),
    );

    // clear physical size overrides
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _ScaledMicPainter extends CustomPainter {
  _ScaledMicPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    // Mic capsule body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.38),
        width: size.width * 0.38,
        height: size.height * 0.46,
      ),
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(bodyRect, paint);

    // Arc beneath capsule
    // using 0 degrees as 3 o'clock, sweeping clockwise. 
    // Wait, original used 3.14, 3.14. Using 0, 3.14159 actually traces bottom from right to left in flutter.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.58),
        width: size.width * 0.56,
        height: size.height * 0.36,
      ),
      0,
      3.14159,
      false,
      paint,
    );

    // Vertical stem
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.76),
      Offset(size.width / 2, size.height * 0.92),
      paint,
    );

    // Horizontal base
    canvas.drawLine(
      Offset(size.width * 0.33, size.height * 0.92),
      Offset(size.width * 0.67, size.height * 0.92),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
