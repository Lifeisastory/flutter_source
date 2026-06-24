import 'package:flutter/rendering.dart';
import '../log.dart';

final _log = ModuleLogger('min_framework');

class MyColoredBox extends RenderBox {
  Color color;
  MyColoredBox({this.color = const Color(0xFF2196F3)});

  @override
  void performLayout() {
    _log.i('performLayout, constraints=$constraints', tag: 'MyColoredBox');
    size = constraints.biggest / 2;
    _log.i('size=$size', tag: 'MyColoredBox');
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    offset = Offset(
      (constraints.biggest.width - size.width) / 2,
      (constraints.biggest.height - size.height) / 2,
    );
    _log.i('paint called, offset=$offset, size=$size', tag: 'MyColoredBox');
    final Paint paint = Paint()..color = color;
    context.canvas.drawRect(offset & size, paint);
    _log.i(
      'painted rect: ${offset & size} with color $color',
      tag: 'MyColoredBox',
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Hello World',
        style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
    );
    _log.i(tag: 'MyColoredBox', 'textPainter.layout: ${size.width}');

    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      context.canvas,
      offset + Offset(size.width / 2, size.height / 2),
    );
  }
}
