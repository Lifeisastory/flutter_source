import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

class MyRenderingBinding extends BindingBase
    with
        SchedulerBinding,
        SemanticsBinding,
        GestureBinding,
        ServicesBinding,
        RendererBinding
    implements HitTestable {
      
  static MyRenderingBinding? _instance;

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  static MyRenderingBinding ensureInitialized() {
    if (_instance == null) {
      // 构造函数链: BindingBase → 各 mixin 的 initInstances()
      MyRenderingBinding();
    }
    return _instance!;
  }
}
