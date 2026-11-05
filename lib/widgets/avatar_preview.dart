import 'package:flutter/material.dart';
import 'package:mingle_protocol/mingle_protocol.dart';

import '../game/avatar_painter.dart';

/// Static preview of a character, e.g. in the lobby.
class AvatarPreview extends StatelessWidget {
  const AvatarPreview({
    super.key,
    required this.color,
    required this.hat,
    this.scale = 2.5,
  });

  final int color;
  final Hat hat;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AvatarPainter.size.width * scale,
      height: AvatarPainter.size.height * scale,
      child: CustomPaint(
        painter: _Painter(AvatarPainter(color: Color(color), hat: hat), scale),
      ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.avatar, this.scale);
  final AvatarPainter avatar;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    avatar.paint(canvas);
  }

  @override
  bool shouldRepaint(_Painter old) =>
      old.avatar.hat != avatar.hat ||
      old.avatar.color != avatar.color ||
      old.scale != scale;
}
