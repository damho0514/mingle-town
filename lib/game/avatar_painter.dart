import 'dart:math' as math;
import 'dart:ui';

import 'package:mingle_protocol/mingle_protocol.dart';

/// Draws a character into a 36×52 box whose bottom-centre is the feet.
///
/// Shared by the in-game [Character] and the lobby preview so both always
/// look the same.
class AvatarPainter {
  AvatarPainter({required this.color, required this.hat})
    : _body = Paint()..color = color,
      _hair = Paint()
        ..color = Color.lerp(color, const Color(0xFF000000), 0.45)!;

  static const Size size = Size(36, 52);

  final Color color;
  final Hat hat;
  final Paint _body;
  final Paint _hair;

  static final _skin = Paint()..color = const Color(0xFFFFDDB8);
  static final _legs = Paint()..color = const Color(0xFF37474F);
  static final _eyes = Paint()..color = const Color(0xFF263238);
  static final _blush = Paint()..color = const Color(0x55FF8A80);
  static final _shadow = Paint()..color = const Color(0x33000000);
  static final _selfRing = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  static final _itRing = Paint()
    ..color = const Color(0xFFFF1744)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;

  /// [phase] drives the walk cycle; [facing] is -1 (left) or 1 (right).
  void paint(
    Canvas canvas, {
    double phase = 0,
    double facing = 1,
    bool selfRing = false,
    bool itRing = false,
  }) {
    const cx = 18.0;
    const feet = 50.0;
    final swing = math.sin(phase);
    final bob = -swing.abs() * 2;

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, feet), width: 30, height: 10),
      _shadow,
    );
    if (itRing) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(cx, feet), width: 46, height: 17),
        _itRing,
      );
    } else if (selfRing) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(cx, feet), width: 42, height: 15),
        _selfRing,
      );
    }

    // Legs swing opposite each other.
    for (final (dx, s) in [(-6.0, swing), (6.0, -swing)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + dx - 3, feet - 13 + s * 2.5, 6, 11 - s * 2.5),
          const Radius.circular(3),
        ),
        _legs,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 12, feet - 30 + bob, 24, 20),
        const Radius.circular(9),
      ),
      _body,
    );

    final head = Offset(cx, feet - 40 + bob);
    const r = 13.0;
    canvas
      ..drawCircle(head, r, _skin)
      ..drawArc(
        Rect.fromCircle(center: head.translate(0, -1), radius: r + 1),
        math.pi,
        math.pi,
        true,
        _hair,
      );
    final look = facing * 3;
    for (final ex in [-4.5, 4.5]) {
      canvas.drawCircle(head.translate(ex + look, 3), 1.9, _eyes);
    }
    canvas.drawCircle(head.translate(facing * 8, 7), 2.6, _blush);

    _paintHat(canvas, head, r, facing);
  }

  void _paintHat(Canvas canvas, Offset head, double r, double facing) {
    switch (hat) {
      case Hat.none:
        return;
      case Hat.cap:
        final cap = Paint()..color = const Color(0xFFE53935);
        canvas
          ..drawArc(
            Rect.fromCircle(center: head.translate(0, -2), radius: r + 1),
            math.pi,
            math.pi,
            true,
            cap,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: head.translate(facing * 10, -2),
                width: 16,
                height: 4,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = const Color(0xFFB71C1C),
          );
      case Hat.beanie:
        final knit = Paint()..color = const Color(0xFF5C6BC0);
        canvas
          ..drawArc(
            Rect.fromCircle(center: head.translate(0, -3), radius: r + 1),
            math.pi,
            math.pi,
            true,
            knit,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: head.translate(0, -3),
                width: 30,
                height: 6,
              ),
              const Radius.circular(3),
            ),
            Paint()..color = const Color(0xFF3949AB),
          )
          ..drawCircle(
            head.translate(0, -r - 5),
            4,
            Paint()..color = const Color(0xFFFFFFFF),
          );
      case Hat.crown:
        final gold = Paint()..color = const Color(0xFFFFC107);
        final base = head.translate(0, -r + 1);
        final path = Path()
          ..moveTo(base.dx - 10, base.dy)
          ..lineTo(base.dx - 10, base.dy - 9)
          ..lineTo(base.dx - 5, base.dy - 4)
          ..lineTo(base.dx, base.dy - 11)
          ..lineTo(base.dx + 5, base.dy - 4)
          ..lineTo(base.dx + 10, base.dy - 9)
          ..lineTo(base.dx + 10, base.dy)
          ..close();
        canvas
          ..drawPath(path, gold)
          ..drawCircle(
            base.translate(0, -3),
            1.8,
            Paint()..color = const Color(0xFFE91E63),
          );
      case Hat.bow:
        final pink = Paint()..color = const Color(0xFFFF4081);
        final c = head.translate(-facing * 8, -r + 2);
        canvas
          ..drawPath(
            Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(c.dx - 9, c.dy - 6)
              ..lineTo(c.dx - 9, c.dy + 6)
              ..close(),
            pink,
          )
          ..drawPath(
            Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(c.dx + 9, c.dy - 6)
              ..lineTo(c.dx + 9, c.dy + 6)
              ..close(),
            pink,
          )
          ..drawCircle(c, 3, Paint()..color = const Color(0xFFC51162));
      case Hat.flower:
        final c = head.translate(-facing * 7, -r + 1);
        final petal = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5;
          canvas.drawCircle(
            c.translate(math.cos(a) * 4.5, math.sin(a) * 4.5),
            3.4,
            petal,
          );
        }
        canvas.drawCircle(c, 3, Paint()..color = const Color(0xFFFFC107));
    }
  }
}
