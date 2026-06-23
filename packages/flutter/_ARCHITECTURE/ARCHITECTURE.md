## 项目类型

- 推断: `library`
- 证据: `packages/flutter/lib/*.dart` 公开导出 `packages/flutter/lib/src/*`；`packages/flutter/lib/src` 本身按层组织，明显是 Flutter framework 的内部实现区。
- 置信度: `high`

## 架构树

- `packages/flutter/lib/src/foundation`: 基础设施层，定义 `BindingBase`、诊断、键、通知、平台判断等全框架通用抽象。
- `packages/flutter/lib/src/scheduler`: 帧调度层，管理 transient/persistent/post-frame 回调与 `Ticker` 时间基准。
- `packages/flutter/lib/src/services`: 平台服务层，负责 `BinaryMessenger`、`SystemChannels`、文本输入、资产、平台消息。
- `packages/flutter/lib/src/gestures`: 输入与手势层，承接引擎指针事件、命中测试、手势竞技场与识别器。
- `packages/flutter/lib/src/painting`: 绘制辅助层，提供图片缓存、文本/装饰/渐变/阴影等画笔级能力。
- `packages/flutter/lib/src/semantics`: 可访问性语义层，对接语义树与系统辅助功能。
- `packages/flutter/lib/src/rendering`: 渲染树层，定义 `RenderObject`、`PipelineOwner`、布局/绘制/合成/语义刷新管线。
- `packages/flutter/lib/src/widgets`: 组件框架层，定义 `Widget` / `Element` / `BuildOwner` / `WidgetsBinding`，把声明式组件树映射到渲染树。
- `packages/flutter/lib/src/animation`: 动画抽象层，以 `AnimationController`、`Tween`、`Curves` 为主，依赖 scheduler 驱动时间推进。
- `packages/flutter/lib/src/material`: Material 设计系统实现层，基于 widgets/rendering/services 组合出完整组件与主题系统。
- `packages/flutter/lib/src/cupertino`: Cupertino 设计系统实现层，基于 widgets/rendering/services 组合出 iOS 风格组件与主题系统。
- `packages/flutter/lib/src/physics`: 滚动与仿真相关的物理模型。
- `packages/flutter/lib/src/widget_previews`: 预览支持层，当前规模很小，属于附加能力。
- `packages/flutter/lib/src/web.dart`: Web 相关辅助入口。
- `packages/flutter/lib/src/dart_plugin_registrant.dart`: 插件注册辅助入口，不属于典型 widgets/rendering 主链路。

## 核心入口

- `packages/flutter/lib/widgets.dart`: widgets 公开入口，直接导出 `src/widgets/*`，是框架层最常用入口之一。
- `packages/flutter/lib/rendering.dart`: rendering 公开入口，声明需要与 `ServicesBinding`、`GestureBinding`、`SchedulerBinding`、`PaintingBinding`、`RendererBinding` 配合使用。
- `packages/flutter/lib/material.dart`: Material 公开入口，导出 `src/material/*` 并复用 `widgets.dart`。
- `packages/flutter/lib/cupertino.dart`: Cupertino 公开入口，导出 `src/cupertino/*` 并复用 `widgets.dart`。
- `packages/flutter/lib/src/widgets/binding.dart`: `runApp` 与 `WidgetsFlutterBinding.ensureInitialized` 所在文件，是 framework 启动总入口。
- `packages/flutter/lib/src/widgets/framework.dart`: `Widget`、`StatefulWidget`、`State`、`BuildContext`、`Element`、`BuildOwner` 所在文件，是声明式 UI 框架核心。
- `packages/flutter/lib/src/rendering/binding.dart`: `RendererBinding` 所在文件，负责把帧回调推进到 layout/paint/semantics pipeline。

## 模块边界

- `foundation`: 所有上层共享的根基。`BindingBase` 在这里定义，其他 binding mixin 都建立在它之上。
- `scheduler`: 提供统一帧时钟与任务优先级；动画、渲染、widgets 刷新都围绕它调度。
- `services`: 框架与 engine/platform 的消息桥。它不关心 widget 树，但决定文本输入、平台路由、系统消息如何进入 framework。
- `gestures`: 处理原始输入事件到语义化手势的转换，不直接负责 UI 结构。
- `painting`: 偏“绘图材料层”，为 rendering/widgets 提供图片缓存和画笔级工具，而不是管理 render tree 生命周期。
- `rendering`: 真正持有布局、绘制、命中测试、语义刷新等底层树结构。
- `widgets`: 声明式 API 和 diff/build 层，把 `Widget` 配置转换成 `Element` 树，并将其与 `RenderObject` 生命周期联动。
- `material` / `cupertino`: 设计系统层，不重新发明 framework 核心，而是在 widgets 基础上做组件规范、交互和主题封装。

## 高耦合枢纽文件

- `packages/flutter/lib/src/foundation/binding.dart`: 定义 `BindingBase`，是所有 binding mixin 的共同根。
- `packages/flutter/lib/src/scheduler/binding.dart`: 定义帧阶段、帧回调、任务调度，是动画和刷新节拍源。
- `packages/flutter/lib/src/services/binding.dart`: 绑定平台消息、键盘、生命周期、文本输入与系统 channel。
- `packages/flutter/lib/src/gestures/binding.dart`: 负责接住指针数据并驱动手势采样与分发。
- `packages/flutter/lib/src/rendering/binding.dart`: 维护 `rootPipelineOwner`、`RenderView` 注册与 `drawFrame` 渲染刷新。
- `packages/flutter/lib/src/widgets/framework.dart`: `Widget`/`Element`/`State` 三元关系与 build 生命周期全部集中在这里。
- `packages/flutter/lib/src/widgets/binding.dart`: 连接 scheduler、services、rendering、widgets，负责 `runApp` 和整帧 build 管线。
- `packages/flutter/lib/src/material/app.dart`: `MaterialApp` 封装 `WidgetsApp` 并接入 Material 主题、路由与默认行为。
- `packages/flutter/lib/src/cupertino/app.dart`: `CupertinoApp` 封装 `WidgetsApp` 并接入 iOS 风格默认行为。

## 关键配置

- `packages/flutter/lib/analysis_options.yaml`: 当前 package 的静态分析配置。
- `packages/flutter/lib/src/foundation/_platform_io.dart` / `_platform_web.dart`: 平台分流实现，影响同名 facade 的实际行为。
- `packages/flutter/lib/src/services/system_channels.dart`: 预定义 framework 与 engine 间的重要 channel 常量。
- `packages/flutter/lib/src/material/theme.dart`: Material 主题注入点，`Theme` 是设计系统向 widgets 树传播视觉 token 的核心。
- `packages/flutter/lib/src/cupertino/theme.dart`: Cupertino 主题注入点。

## 主流程骨架

- 应用启动链路: `packages/flutter/lib/src/widgets/binding.dart::runApp` -> `WidgetsFlutterBinding.ensureInitialized` -> `attachRootWidget` -> `BuildOwner` / `Element` 树建立 -> `drawFrame` -> `packages/flutter/lib/src/rendering/binding.dart` 刷新 render pipeline。
- Build/Render 链路: `packages/flutter/lib/src/widgets/framework.dart` 中的 `Widget` -> `Element` -> `RenderObjectWidget`/`RenderObjectElement` -> `packages/flutter/lib/src/rendering/object.dart::RenderObject`。
- 帧驱动链路: `packages/flutter/lib/src/scheduler/binding.dart` 处理 `onBeginFrame` / `onDrawFrame` -> `packages/flutter/lib/src/widgets/binding.dart::drawFrame` 推进 build -> `packages/flutter/lib/src/rendering/binding.dart::drawFrame` flush layout/compositing/paint/semantics。
- 输入链路: engine pointer packet -> `packages/flutter/lib/src/gestures/binding.dart` -> hit test / gesture arena -> `packages/flutter/lib/src/gestures/recognizer.dart` -> `packages/flutter/lib/src/widgets/gesture_detector.dart` 等 widgets 消费。
- 平台消息链路: engine channel message -> `packages/flutter/lib/src/services/binding.dart` -> `packages/flutter/lib/src/services/platform_channel.dart` / `system_channels.dart` -> widgets/material/cupertino 中的上层能力。
- 设计系统链路: `WidgetsApp` 提供基础 app 壳 -> `packages/flutter/lib/src/material/app.dart::MaterialApp` 或 `packages/flutter/lib/src/cupertino/app.dart::CupertinoApp` 注入主题、路由、滚动与平台风格。

## 目录级观察

- `widgets` 与 `material` 是当前 `src` 中体量最大的两个目录（都在 180 个文件左右），说明“通用组件框架”和“Material 设计系统”是框架层源码的阅读重心。
- `rendering`、`painting`、`services`、`foundation` 的文件数中等，但这些目录的单文件耦合度更高，属于“理解机制必须读”的底层层次。
- `scheduler`、`semantics`、`physics` 文件数不多，但都位于关键横切面上，规模小不代表影响小。

## 推荐阅读顺序

- `packages/flutter/lib/src/foundation/binding.dart`: 先理解 binding 体系的根。
- `packages/flutter/lib/src/scheduler/binding.dart`: 再理解 Flutter 如何定义一帧的生命周期。
- `packages/flutter/lib/src/services/binding.dart`: 接着补齐平台消息如何进入 framework。
- `packages/flutter/lib/src/rendering/binding.dart`: 看渲染管线如何被帧调度驱动。
- `packages/flutter/lib/src/rendering/object.dart`: 理解 render tree 的核心对象模型。
- `packages/flutter/lib/src/widgets/framework.dart`: 再进入 `Widget`/`Element`/`State` 核心机制。
- `packages/flutter/lib/src/widgets/binding.dart`: 回看 widgets 如何把 build 流程接到 rendering 和 scheduler 上。
- `packages/flutter/lib/src/widgets/app.dart`: 理解 `WidgetsApp` 这个基础 app 壳。
- `packages/flutter/lib/src/material/app.dart`: 从 framework 过渡到 Material 应用层。
- `packages/flutter/lib/src/material/theme.dart`: 理解 Material 主题传播。
- `packages/flutter/lib/src/cupertino/app.dart`: 对照理解 Cupertino 的 app 封装。
- `packages/flutter/lib/src/gestures/recognizer.dart` 与 `packages/flutter/lib/src/widgets/gesture_detector.dart`: 如果后续要看输入交互，这是最短入口。

## 功能索引

- Overlay 浮层栈实现分析（经典 API OverlayEntry、_Theater 渲染机制、opaque/maintainState 优化、OverlayPortal 声明式架构、延迟布局机制），详见 [overlay.md](./_FEATURE/overlay.md)
- GlobalKey 全局键实现分析（类型层次、全局注册表、元素生命周期注册/注销、跨树重定父机制、调试重复检测），详见 [globalkey.md](./_FEATURE/globalkey.md)

## 风险与未知点

- 未逐文件展开 `painting`、`semantics`、`physics` 的内部子模块职责: 可继续读 `packages/flutter/lib/src/painting/*`、`packages/flutter/lib/src/semantics/semantics.dart`、`packages/flutter/lib/src/physics/*` 确认更细边界。
- `widgets/framework.dart` 与 `rendering/object.dart` 都是超大文件: 当前分析只抓了核心类型锚点，未做函数级调用图。
- `web.dart` 与多组 `_io` / `_web` 文件属于平台分流点: 已确认其存在和作用模式，但未完整展开所有 facade 到实现的映射。
- 本次范围限定在 `lib/src`: 对外 API 的组织方式只参考了 `lib/widgets.dart`、`lib/material.dart`、`lib/cupertino.dart`、`lib/rendering.dart` 四个入口，没有继续扩展到 package 外部。
