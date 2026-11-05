import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import 'world_layout.dart';

/// The walkable floor: grass, paths, plaza, fountain, pond and flowers.
/// Painted once into a [Picture]. Reports taps in world coordinates.
class Ground extends PositionComponent with TapCallbacks {
  Ground({required this.onTap})
    : super(
        size: Vector2(Limits.worldWidth, Limits.worldHeight),
        priority: -1 << 20,
      );

  final void Function(Vector2 worldPosition) onTap;
  late final Picture _picture;

  @override
  Future<void> onLoad() async {
    final recorder = PictureRecorder();
    _paint(Canvas(recorder), WorldLayout.instance);
    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) => canvas.drawPicture(_picture);

  @override
  void onTapUp(TapUpEvent event) => onTap(event.localPosition);

  @override
  void onRemove() {
    _picture.dispose();
    super.onRemove();
  }

  void _paint(Canvas canvas, WorldLayout layout) {
    // Grass with a subtle checker so movement reads clearly.
    const tile = 80.0;
    final light = Paint()..color = const Color(0xFF8BC34A);
    final dark = Paint()..color = const Color(0xFF84BC45);
    for (var y = 0.0; y < size.y; y += tile) {
      for (var x = 0.0; x < size.x; x += tile) {
        final odd = ((x + y) / tile).round().isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), odd ? dark : light);
      }
    }

    // Paths crossing at the plaza.
    final c = WorldLayout.center;
    const half = WorldLayout.pathHalfWidth;
    final path = Paint()..color = const Color(0xFFE8D5A9);
    final pathEdge = Paint()
      ..color = const Color(0xFFD4BE8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final r in [
      Rect.fromLTRB(0, c.y - half, size.x, c.y + half),
      Rect.fromLTRB(c.x - half, 0, c.x + half, size.y),
    ]) {
      canvas
        ..drawRect(r, path)
        ..drawRect(r, pathEdge);
    }

    // Plaza with a fountain.
    final center = Offset(c.x, c.y);
    canvas
      ..drawCircle(
        center,
        WorldLayout.plazaRadius,
        Paint()..color = const Color(0xFFD7CCC8),
      )
      ..drawCircle(
        center,
        WorldLayout.plazaRadius,
        Paint()
          ..color = const Color(0xFFBCAAA4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      )
      ..drawCircle(
        center,
        WorldLayout.plazaRadius * 0.6,
        Paint()
          ..color = const Color(0x22000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..drawCircle(
        center,
        WorldLayout.fountainRadius,
        Paint()..color = const Color(0xFF90A4AE),
      )
      ..drawCircle(
        center,
        WorldLayout.fountainRadius - 9,
        Paint()..color = const Color(0xFF4FC3F7),
      )
      ..drawCircle(center, 10, Paint()..color = const Color(0xFFB3E5FC));

    // Pond.
    final pond = Rect.fromCenter(
      center: Offset(WorldLayout.pondCenter.x, WorldLayout.pondCenter.y),
      width: WorldLayout.pondRadii.x * 2,
      height: WorldLayout.pondRadii.y * 2,
    );
    canvas
      ..drawOval(pond.inflate(8), Paint()..color = const Color(0xFFA1887F))
      ..drawOval(pond, Paint()..color = const Color(0xFF29B6F6))
      ..drawOval(
        pond.deflate(30).shift(const Offset(-20, -15)),
        Paint()..color = const Color(0x334FC3F7),
      )
      ..drawOval(
        Rect.fromCenter(
          center: pond.center.translate(-50, -30),
          width: 40,
          height: 10,
        ),
        Paint()..color = const Color(0x66FFFFFF),
      );

    // Flowers.
    final stem = Paint()..color = const Color(0xFF558B2F);
    final pollen = Paint()..color = const Color(0xFFFFEB3B);
    for (final (p, color) in layout.flowers) {
      final o = Offset(p.x, p.y);
      final petal = Paint()..color = color;
      canvas.drawCircle(o.translate(0, 3), 2, stem);
      for (final d in const [
        Offset(-3, 0),
        Offset(3, 0),
        Offset(0, -3),
        Offset(0, 3),
      ]) {
        canvas.drawCircle(o + d, 2.6, petal);
      }
      canvas.drawCircle(o, 1.8, pollen);
    }
  }
}
