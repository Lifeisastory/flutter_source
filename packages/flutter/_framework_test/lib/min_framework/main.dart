import 'package:flutter/rendering.dart';

import './my_rendering_binding.dart';
import 'my_render.dart';

bool isRun = true;

void main() {
  if (isRun) {
    final MyRenderingBinding binding = MyRenderingBinding.ensureInitialized();

    // 3a. 创建 PipelineOwner 管理本页面的渲染
    //     只有 onNeedVisualUpdate 是必需的（触发帧调度）
    final PipelineOwner pipelineOwner = PipelineOwner(
      onNeedVisualUpdate: () => binding.ensureVisualUpdate(),
    );

    // 3b. 创建 RenderView（渲染树的根）
    final RenderView renderView = RenderView(
      view: binding.platformDispatcher.implicitView!,
      child: MyColoredBox(color: const Color(0xFFFF5722)),
    );

    // 3c. 将 RenderView 挂到 PipelineOwner 上
    //     rootNode setter 会自动调用 renderView.attach(pipelineOwner)
    pipelineOwner.rootNode = renderView;

    // 3d. 将子 PipelineOwner 挂到根 PipelineOwner 上
    binding.rootPipelineOwner.adoptChild(pipelineOwner);

    // 3e. 注册到 RendererBinding（配置约束 + 参与帧生产）
    binding.addRenderView(renderView);
    print(
      '☆ logicalConstraints: ${renderView.configuration.logicalConstraints}',
    );
    print('☆ devicePixelRatio: ${renderView.configuration.devicePixelRatio}');

    // 3f. 首次引导布局/绘制
    renderView.prepareInitialFrame();
    print('☆ prepareInitialFrame done, renderView.size=${renderView.size}');

    // 3g. 启动帧循环
    binding.scheduleWarmUpFrame();
    print('☆ scheduleWarmUpFrame called, waiting for frame...');
  }
}
