import 'package:flutter/rendering.dart';

class MyColoredBox extends RenderBox {
  Color color;
  MyColoredBox({this.color = const Color(0xFF2196F3)});

  @override
  void performLayout() {
    print('[MyColoredBox] performLayout, constraints=$constraints');
    size = constraints.biggest;
    print('[MyColoredBox] size=$size');
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    print('[MyColoredBox] paint called, offset=$offset, size=$size');
    final Paint paint = Paint()..color = color;
    context.canvas.drawRect(offset & size, paint);
    print('[MyColoredBox] painted rect: ${offset & size} with color $color');
  }
}
