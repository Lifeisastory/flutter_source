# 架构索引

## 项目类型
- 推断: `Flutter 应用`
- 证据: `pubspec.yaml` 声明 `flutter` SDK 依赖，包含标准 Flutter 应用脚手架（`android/`、`ios/`、`linux/`、`macos/`、`windows/`、`web/`）
- 置信度: `高`
- 说明: 这是一个 Flutter 框架学习工程，而非生产应用。工程内包含多个独立的学习模块，每个模块针对 Flutter framework 的某一层或某一机制（渲染、widget、调度、手势等）进行动手练习。各模块自包含在 `lib/` 下。每个学习主题在 `_ARCHITECTURE/_FEATURE/` 下有一份独立的特性分析文档。

## 工程约定
- 每个学习模块是 `lib/` 下的一个独立目录，包含自己的 `main()` 入口
- 各模块通过其 `main.dart` 顶部的模块级 `isRun` 布尔标志控制自身是否运行
- [lib/main.dart](./lib/main.dart) 导入所有可用模块并依次调用各模块的 `main()`，无需修改 import 来切换
- 模块的详细分析在 [_ARCHITECTURE/_FEATURE/](./_FEATURE/) 下，中英文各一份
- 新增模块时，在 [_ARCHITECTURE/ARCHITECTURE.en.md](./ARCHITECTURE.en.md) 和 [ARCHITECTURE.md](./ARCHITECTURE.md) 中添加 `## Module: <name>` / `## 模块: <name>` 章节

## 共享入口
- [lib/main.dart](./lib/main.dart): 统一调度入口，导入所有可用模块并依次调用各模块的 `main()`
- [test/widget_test.dart](./test/widget_test.dart): 测试入口占位，目前仅含空的 `main()`

---

## 模块: min_framework

### 定位
最小渲染管线 — 演示如何绕过 widget/Element 层，直接组合 framework 渲染原语（binding mixin、PipelineOwner、RenderView、RenderBox）。

### 入口
- [lib/min_framework/main.dart](./lib/min_framework/main.dart): 模块入口，`isRun` 开关控制，委托到 `minimal_pipeline.dart::runMinimalPipeline()`

### 文件
- [lib/min_framework/main.dart](./lib/min_framework/main.dart): 模块入口，`isRun` 守卫 + 调用 `runMinimalPipeline()`
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart): 管线编排者，`runMinimalPipeline()` — 组装 8 步渲染管线从 binding 初始化到预热帧
- [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart): 自定义 RenderBox，定义 `MyColoredBox`，实现 `performLayout`（填满约束）和 `paint`（绘制纯色矩形）
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart): 自定义 binding 组合，`BindingBase` + `SchedulerBinding` + `SemanticsBinding` + `GestureBinding` + `ServicesBinding` + `RendererBinding`，复现了 `WidgetsFlutterBinding` 组合结构但去除了 widget 层

### 关系
- [lib/main.dart](./lib/main.dart) | depends_on | [lib/min_framework/main.dart](./lib/min_framework/main.dart) | 显式 | `import 'min_framework/main.dart'` | 高
- [lib/min_framework/main.dart](./lib/min_framework/main.dart) | depends_on | [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | 显式 | `import 'minimal_pipeline.dart'` | 高
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | depends_on | [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | 显式 | `import './my_rendering_binding.dart'` | 高
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | depends_on | [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) | 显式 | `import 'my_render.dart'` | 高
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | depends_on | `package:flutter/rendering.dart` | 显式 | 引入 `PipelineOwner`、`RenderView`、`Color` | 高
- [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) | depends_on | `package:flutter/rendering.dart` | 显式 | 继承 `RenderBox` | 高
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/foundation.dart` | 显式 | `BindingBase` mixin 目标 | 高
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/scheduler.dart` | 显式 | `SchedulerBinding` mixin | 高
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/services.dart` | 显式 | `ServicesBinding` mixin | 高
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/gestures.dart` | 显式 | `GestureBinding` mixin | 高
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/rendering.dart` | 显式 | `RendererBinding` mixin、`SemanticsBinding` mixin | 高
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/semantics.dart` | 推断 | `SemanticsBinding` 位于 rendering 包但可能需要单独的 semantics import | 中

### 流程
- `最小渲染管线`: `ensureInitialized → PipelineOwner → RenderView(MyColoredBox) → pipelineOwner.rootNode = renderView → binding.rootPipelineOwner.adoptChild → addRenderView → prepareInitialFrame → scheduleWarmUpFrame`
- `帧生产`: `scheduleWarmUpFrame → SchedulerBinding handleBeginFrame/handleDrawFrame → RendererBinding.drawFrame → flushLayout/flushCompositingBits/flushPaint/flushSemantics → MyColoredBox.performLayout/paint`

### 推荐阅读顺序
1. [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart): 理解 binding mixin 组合如何与 `WidgetsFlutterBinding` 对应
2. [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart): 理解自定义 RenderBox 的 layout/paint 生命周期
3. [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart): 理解手动组装渲染管线的完整流程

### 特性分析
- [min-rendering-pipeline.md](./_FEATURE/min-rendering-pipeline.md) — binding 组合、PipelineOwner/RenderView 组装、RenderBox 生命周期、帧调度

### 已知问题
- `SemanticsBinding 导入路径`: `SemanticsBinding` 的实际导入路径为推断 — rendering 包可能重新导出或内部包含它

## 风险与未知
- `空测试`: [test/widget_test.dart](./test/widget_test.dart) 尚未实现任何测试逻辑
- `未来模块`: `_framework_test` 项目预期会随学习进展增加更多学习模块
