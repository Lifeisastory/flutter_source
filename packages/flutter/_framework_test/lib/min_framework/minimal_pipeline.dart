import 'package:flutter/rendering.dart';
import '../log.dart';

import './my_rendering_binding.dart';
import 'my_render.dart';

final _log = ModuleLogger('min_framework');

void runMinimalPipeline() {
  final MyRenderingBinding binding = MyRenderingBinding.ensureInitialized();

  //  a. 创建 PipelineOwner 管理本页面的渲染
  //     只有 onNeedVisualUpdate 是必需的（触发帧调度）
  final PipelineOwner pipelineOwner = PipelineOwner(
    onNeedVisualUpdate: () => binding.ensureVisualUpdate(),
  );

  //  b. 创建 RenderView（渲染树的根）
  final RenderView renderView = RenderView(
    view: binding.platformDispatcher.implicitView!,
    child: MyColoredBox(color: const Color(0xFFFF5722)),
  );

  //  c. 将 RenderView 挂到 PipelineOwner 上
  //     rootNode setter 会自动调用 renderView.attach(pipelineOwner)
  pipelineOwner.rootNode = renderView;

  //  d. 将子 PipelineOwner 挂到根 PipelineOwner 上
  binding.rootPipelineOwner.adoptChild(pipelineOwner);

  //  e. 注册到 RendererBinding（配置约束 + 参与帧生产）
  binding.addRenderView(renderView);
  _log.i('logicalConstraints: ${renderView.configuration.logicalConstraints}');
  _log.i('devicePixelRatio: ${renderView.configuration.devicePixelRatio}');

  //  f. 首次引导布局/绘制
  renderView.prepareInitialFrame();
  _log.i('prepareInitialFrame done, renderView.size=${renderView.size}');

  //  g. 启动帧循环
  binding.scheduleWarmUpFrame();
  _log.i('scheduleWarmUpFrame called, waiting for frame...');
}
