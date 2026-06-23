# Architecture Index

## Artifact Metadata
- Artifact: architecture-index
- Language: English
- Source: generated-from-project-scan
- Scope: `packages/flutter/lib/src`

## Project Type
- Inference: `library`
- Evidence: `packages/flutter/lib/*.dart` exports `packages/flutter/lib/src/*`; `src` is organized as internal framework layers rather than an app.
- Confidence: `high`

## Entrypoints
- `packages/flutter/lib/widgets.dart` | public widgets entrypoint | exports `src/widgets/*` directly | high
- `packages/flutter/lib/rendering.dart` | public rendering entrypoint | exports `src/rendering/*` and documents required bindings | high
- `packages/flutter/lib/material.dart` | public Material entrypoint | exports `src/material/*` and reuses widgets layer | high
- `packages/flutter/lib/cupertino.dart` | public Cupertino entrypoint | exports `src/cupertino/*` and reuses widgets layer | high
- `packages/flutter/lib/src/widgets/binding.dart` | framework bootstrap entrypoint | contains `runApp`, `WidgetsFlutterBinding.ensureInitialized`, `attachRootWidget` | high
- `packages/flutter/lib/src/widgets/framework.dart` | widget framework core entrypoint | contains `Widget`, `StatefulWidget`, `State`, `BuildContext`, `BuildOwner`, `Element` | high
- `packages/flutter/lib/src/rendering/binding.dart` | render pipeline entrypoint | contains `RendererBinding`, `rootPipelineOwner`, render-frame flushing | high

## Modules
- `packages/flutter/lib/src/foundation` | base utilities and binding root | contains `BindingBase` and shared diagnostics/types | high
- `packages/flutter/lib/src/scheduler` | frame scheduling and callback phases | contains `SchedulerBinding`, priorities, tickers | high
- `packages/flutter/lib/src/services` | engine/platform communication layer | contains platform channels, text input, assets, lifecycle handlers | high
- `packages/flutter/lib/src/gestures` | pointer dispatch and gesture recognition layer | contains hit testing, arena, recognizers, resampling | high
- `packages/flutter/lib/src/painting` | painting support layer | contains image cache, shaders, text/decoration helpers | high
- `packages/flutter/lib/src/semantics` | accessibility semantics layer | contains semantics tree and semantics services | high
- `packages/flutter/lib/src/rendering` | render tree and pipeline layer | contains `RenderObject`, layout/paint/compositing primitives, `RendererBinding` | high
- `packages/flutter/lib/src/widgets` | declarative widget framework layer | contains widget/element/state/build owner and app shell abstractions | high
- `packages/flutter/lib/src/animation` | time-based animation abstractions | contains `AnimationController`, tweens, curves | high
- `packages/flutter/lib/src/material` | Material design system layer | contains Material app shell, themes, components | high
- `packages/flutter/lib/src/cupertino` | Cupertino design system layer | contains Cupertino app shell, themes, components | high
- `packages/flutter/lib/src/physics` | simulation and scroll physics layer | naming and package layout indicate physics utilities | medium
- `packages/flutter/lib/src/widget_previews` | preview-support layer | currently contains a minimal preview entry file | medium

## Files
- `packages/flutter/lib/src/foundation/binding.dart` | root binding base for the framework | defines `BindingBase` and binding initialization contract | high
- `packages/flutter/lib/src/scheduler/binding.dart` | frame scheduler hub | defines scheduler phases, frame callbacks, task queue semantics | high
- `packages/flutter/lib/src/services/binding.dart` | platform services hub | initializes binary messenger, lifecycle/system channels, keyboard and text input | high
- `packages/flutter/lib/src/gestures/binding.dart` | gesture ingestion hub | receives pointer data and coordinates resampling/dispatch | high
- `packages/flutter/lib/src/rendering/binding.dart` | render pipeline hub | owns `rootPipelineOwner`, render views, and flushes layout/paint/semantics | high
- `packages/flutter/lib/src/rendering/object.dart` | render object model hub | contains `RenderObject` and render-tree mechanics | high
- `packages/flutter/lib/src/widgets/framework.dart` | widget/element/state model hub | contains `Widget`, `Element`, `BuildContext`, `BuildOwner`, `State` | high
- `packages/flutter/lib/src/widgets/binding.dart` | top-level framework binding hub | bridges scheduler, services, rendering, and widget tree bootstrapping | high
- `packages/flutter/lib/src/widgets/app.dart` | base app shell | provides `WidgetsApp`-level application shell concerns | high
- `packages/flutter/lib/src/material/app.dart` | Material app shell | wraps `WidgetsApp` with Material-specific defaults and routing/theme behavior | high
- `packages/flutter/lib/src/material/theme.dart` | Material theme propagation hub | contains `Theme` and related theme propagation logic | high
- `packages/flutter/lib/src/cupertino/app.dart` | Cupertino app shell | wraps `WidgetsApp` with Cupertino-specific defaults and routing/theme behavior | high
- `packages/flutter/lib/src/cupertino/theme.dart` | Cupertino theme propagation hub | contains `CupertinoTheme` and `CupertinoThemeData` | high
- `packages/flutter/lib/src/services/platform_channel.dart` | platform channel API hub | contains `BasicMessageChannel`, `MethodChannel`, and `EventChannel` | high
- `packages/flutter/lib/src/services/system_channels.dart` | system channel registry | defines framework-known channel constants | high
- `packages/flutter/lib/src/gestures/recognizer.dart` | gesture recognizer base layer | contains `GestureRecognizer` base abstractions | high
- `packages/flutter/lib/src/widgets/gesture_detector.dart` | widget-facing gesture adapter | contains `GestureDetector` and recognizer factory wiring | high
- `packages/flutter/lib/src/animation/animation_controller.dart` | animation time controller hub | contains `AnimationController` and scheduler-driven timeline control | high

## Relationships
- `packages/flutter/lib/src/scheduler/binding.dart` | depended_on_by | `packages/flutter/lib/src/animation/animation_controller.dart` | explicit | animation controller documentation and scheduler/ticker design imply frame-timed control | high
- `packages/flutter/lib/src/foundation/binding.dart` | depended_on_by | `packages/flutter/lib/src/services/binding.dart` | explicit | `ServicesBinding` mixes on `BindingBase` | high
- `packages/flutter/lib/src/foundation/binding.dart` | depended_on_by | `packages/flutter/lib/src/painting/binding.dart` | explicit | `PaintingBinding` mixes on `BindingBase` | high
- `packages/flutter/lib/src/foundation/binding.dart` | depended_on_by | `packages/flutter/lib/src/rendering/binding.dart` | explicit | `RendererBinding` mixes on `BindingBase` | high
- `packages/flutter/lib/src/foundation/binding.dart` | depended_on_by | `packages/flutter/lib/src/widgets/binding.dart` | explicit | `WidgetsFlutterBinding` extends `BindingBase` through mixins | high
- `packages/flutter/lib/src/services/binding.dart` | depends_on | `packages/flutter/lib/src/services/platform_channel.dart` | explicit | imports and initializes channel handlers/binary messenger | high
- `packages/flutter/lib/src/services/binding.dart` | depends_on | `packages/flutter/lib/src/services/system_channels.dart` | explicit | sets message handlers for system/accessibility/lifecycle/platform channels | high
- `packages/flutter/lib/src/gestures/binding.dart` | depends_on | `packages/flutter/lib/src/scheduler/binding.dart` | explicit | imports scheduler and uses frame timing for resampling | high
- `packages/flutter/lib/src/rendering/binding.dart` | depends_on | `packages/flutter/lib/src/services/binding.dart` | explicit | mixin constraint `on BindingBase, ServicesBinding, SchedulerBinding, GestureBinding, SemanticsBinding, HitTestable` | high
- `packages/flutter/lib/src/rendering/binding.dart` | depends_on | `packages/flutter/lib/src/scheduler/binding.dart` | explicit | mixin constraint and frame callback registration | high
- `packages/flutter/lib/src/rendering/binding.dart` | depends_on | `packages/flutter/lib/src/gestures/binding.dart` | explicit | mixin constraint and hit testing integration | high
- `packages/flutter/lib/src/rendering/binding.dart` | depends_on | `packages/flutter/lib/src/rendering/object.dart` | explicit | imports object model and flushes pipeline owners/render views | high
- `packages/flutter/lib/src/widgets/framework.dart` | depends_on | `packages/flutter/lib/src/rendering.dart` | explicit | imports `package:flutter/rendering.dart` and exports `RenderObject`-related symbols | high
- `packages/flutter/lib/src/widgets/binding.dart` | depends_on | `packages/flutter/lib/src/widgets/framework.dart` | explicit | imports framework.dart and manages build owner/tree attachment | high
- `packages/flutter/lib/src/widgets/binding.dart` | depends_on | `packages/flutter/lib/src/rendering/binding.dart` | explicit | imports rendering and calls super `drawFrame` after widget build phases | high
- `packages/flutter/lib/src/widgets/binding.dart` | depends_on | `packages/flutter/lib/src/services/binding.dart` | explicit | imports `package:flutter/services.dart` and exposes observer/system integration | high
- `packages/flutter/lib/src/widgets/binding.dart` | depends_on | `packages/flutter/lib/src/gestures.dart` | explicit | imports `package:flutter/gestures.dart` for interaction and binding composition | high
- `packages/flutter/lib/src/material/app.dart` | depends_on | `packages/flutter/lib/src/widgets/app.dart` | inferred | `MaterialApp` documentation says it builds on `WidgetsApp`; source imports widgets-level types via public packages | high
- `packages/flutter/lib/src/material/app.dart` | depends_on | `packages/flutter/lib/src/material/theme.dart` | explicit | imports `theme.dart` and configures Material-specific defaults | high
- `packages/flutter/lib/src/cupertino/app.dart` | depends_on | `packages/flutter/lib/src/widgets/app.dart` | inferred | `CupertinoApp` documentation says it builds on `WidgetsApp` | high
- `packages/flutter/lib/src/cupertino/app.dart` | depends_on | `packages/flutter/lib/src/cupertino/theme.dart` | explicit | imports `theme.dart` and configures Cupertino defaults | high
- `packages/flutter/lib/src/widgets/gesture_detector.dart` | depends_on | `packages/flutter/lib/src/gestures/recognizer.dart` | explicit | widget gesture API is backed by recognizer factory/recognizer types | high
- `packages/flutter/lib/src/widgets/framework.dart` | impacts | `packages/flutter/lib/src/material` | inferred | all Material components sit on widget/element/state semantics | high
- `packages/flutter/lib/src/widgets/framework.dart` | impacts | `packages/flutter/lib/src/cupertino` | inferred | all Cupertino components sit on widget/element/state semantics | high
- `packages/flutter/lib/src/rendering/object.dart` | impacts | `packages/flutter/lib/src/widgets/framework.dart` | inferred | render object lifecycle and contracts constrain render-object widgets/elements | high
- `packages/flutter/lib/src/services/system_channels.dart` | influenced_by | engine channel protocol | inferred | channel names must match engine-side protocol and embedder expectations | medium
- `packages/flutter/lib/src/foundation/_platform_io.dart` | influenced_by | target platform selection | explicit | file split pattern indicates conditional platform-specific implementation | high
- `packages/flutter/lib/src/foundation/_platform_web.dart` | influenced_by | target platform selection | explicit | file split pattern indicates conditional platform-specific implementation | high

## Flows
- `app-bootstrap` | `packages/flutter/lib/src/widgets/binding.dart::runApp -> WidgetsFlutterBinding.ensureInitialized -> attachRootWidget -> BuildOwner/Element tree -> drawFrame -> packages/flutter/lib/src/rendering/binding.dart` | high
- `build-to-render` | `packages/flutter/lib/src/widgets/framework.dart::Widget -> Element -> RenderObjectWidget/RenderObjectElement -> packages/flutter/lib/src/rendering/object.dart::RenderObject` | high
- `frame-pipeline` | `packages/flutter/lib/src/scheduler/binding.dart -> packages/flutter/lib/src/widgets/binding.dart::drawFrame -> packages/flutter/lib/src/rendering/binding.dart::drawFrame -> flushLayout/flushCompositingBits/flushPaint/flushSemantics` | high
- `input-pipeline` | `engine pointer packet -> packages/flutter/lib/src/gestures/binding.dart -> packages/flutter/lib/src/gestures/recognizer.dart -> packages/flutter/lib/src/widgets/gesture_detector.dart` | medium
- `platform-message-pipeline` | `engine/system channel -> packages/flutter/lib/src/services/binding.dart -> packages/flutter/lib/src/services/platform_channel.dart or system_channels.dart -> upper widget/app layers` | high
- `design-system-layering` | `packages/flutter/lib/src/widgets/app.dart -> packages/flutter/lib/src/material/app.dart or packages/flutter/lib/src/cupertino/app.dart -> theme and route defaults` | high

## Recommended Next Reads
- `packages/flutter/lib/src/foundation/binding.dart` | understand the binding root before reading higher layers
- `packages/flutter/lib/src/scheduler/binding.dart` | understand the canonical Flutter frame lifecycle
- `packages/flutter/lib/src/services/binding.dart` | understand how platform and engine messages enter the framework
- `packages/flutter/lib/src/rendering/binding.dart` | understand how frame callbacks flush render state
- `packages/flutter/lib/src/rendering/object.dart` | understand the core render-tree object model
- `packages/flutter/lib/src/widgets/framework.dart` | understand widget/element/state/build owner mechanics
- `packages/flutter/lib/src/widgets/binding.dart` | understand how widget build phases attach to scheduler and rendering
- `packages/flutter/lib/src/widgets/app.dart` | understand the base application shell used by higher design systems
- `packages/flutter/lib/src/material/app.dart` | inspect how Material composes on top of WidgetsApp
- `packages/flutter/lib/src/cupertino/app.dart` | compare Cupertino composition against Material
- `packages/flutter/lib/src/gestures/recognizer.dart` | inspect recognizer abstractions behind widget-facing gestures
- `packages/flutter/lib/src/widgets/gesture_detector.dart` | inspect how widget APIs wire into gesture recognizers

## Feature Index
- Overlay floating widget stack analysis (classic API OverlayEntry, _Theater render mechanism, opaque/maintainState optimization, OverlayPortal declarative architecture, deferred layout mechanism), see [overlay.en.md](./_FEATURE/overlay.en.md)
- GlobalKey implementation analysis (type hierarchy, global registry, element lifecycle registration/unregistration, cross-tree reparenting, debug duplicate detection), see [globalkey.en.md](./_FEATURE/globalkey.en.md)

## Risks And Unknowns
- `painting-submodules` | detailed internal boundaries inside `packages/flutter/lib/src/painting` were not expanded file-by-file | `packages/flutter/lib/src/painting/binding.dart`
- `semantics-submodules` | semantics layer was mapped structurally but not expanded beyond top-level role | `packages/flutter/lib/src/semantics/semantics.dart`
- `physics-submodules` | physics role is inferred mainly from naming and package position, not deep file inspection | `packages/flutter/lib/src/physics/*`
- `platform-facade-mapping` | `_io`/`_web` split files were identified as platform facades, but full facade-to-caller mapping was not expanded | `packages/flutter/lib/src/foundation/_platform_io.dart`
- `function-level-call-graph` | large hubs such as `framework.dart` and `object.dart` were analyzed at type-and-flow level, not full method graph level | `packages/flutter/lib/src/widgets/framework.dart`
