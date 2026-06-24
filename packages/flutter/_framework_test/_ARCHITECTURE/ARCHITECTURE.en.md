# Architecture Index

## Artifact Metadata
- Artifact: architecture-index
- Language: English
- Source: generated-from-project-scan
- Scope: `packages/flutter/_framework_test`

## Project Type
- Inference: `flutter-application`
- Evidence: `pubspec.yaml` declares `flutter` SDK dependency, contains standard Flutter app scaffold (`android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`)
- Confidence: `high`
- Note: This is a Flutter framework learning workspace — not a production app. It hosts multiple independent learning modules, each targeting a specific layer or mechanism of the Flutter framework (rendering, widgets, scheduler, gestures, etc.). Modules are self-contained under `lib/`. Each learning topic has its own feature analysis document in `_ARCHITECTURE/_FEATURE/`.

## Conventions
- Each learning module is a self-contained directory under `lib/` with its own `main()` entry
- Each module controls whether it runs via a module-level `isRun` boolean flag at the top of its `main.dart`
- [lib/main.dart](./lib/main.dart) imports all available modules and calls each module's `main()` — no import switching needed
- Detailed feature analysis lives under [_ARCHITECTURE/_FEATURE/](./_FEATURE/), one pair of Chinese+English docs per topic
- When adding a new module, add a `## Module: <name>` section to both [_ARCHITECTURE/ARCHITECTURE.en.md](./ARCHITECTURE.en.md) and [ARCHITECTURE.md](./ARCHITECTURE.md)

## Shared Entrypoints
- [lib/main.dart](./lib/main.dart) | unified dispatcher | imports all available modules and calls each module's `main()` | high
- [test/widget_test.dart](./test/widget_test.dart) | test entrypoint placeholder | currently contains only an empty `main()` | high

---

## Module: min_framework

### Role
Minimal rendering pipeline — demonstrates direct composition of framework rendering primitives (binding mixins, PipelineOwner, RenderView, RenderBox) without the widget/Element layer.

### Entrypoint
- [lib/min_framework/main.dart](./lib/min_framework/main.dart) | module entrypoint | `isRun` guard; delegates to `minimal_pipeline.dart::runMinimalPipeline()` | high

### Files
- [lib/min_framework/main.dart](./lib/min_framework/main.dart) | module entrypoint | `isRun` guard + calls `runMinimalPipeline()` | high
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | pipeline orchestrator | `runMinimalPipeline()` — assembles the 8-step rendering pipeline from binding init to warm-up frame | high
- [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) | custom RenderBox | defines `MyColoredBox` with `performLayout` (fill constraints) and `paint` (draw colored rect) | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | custom binding composition | `BindingBase` + `SchedulerBinding` + `SemanticsBinding` + `GestureBinding` + `ServicesBinding` + `RendererBinding` — replicates `WidgetsFlutterBinding` composition without widget layer | high

### Relationships
- [lib/main.dart](./lib/main.dart) | depends_on | [lib/min_framework/main.dart](./lib/min_framework/main.dart) | explicit | `import 'min_framework/main.dart'` | high
- [lib/min_framework/main.dart](./lib/min_framework/main.dart) | depends_on | [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | explicit | `import 'minimal_pipeline.dart'` | high
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | depends_on | [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | explicit | `import './my_rendering_binding.dart'` | high
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | depends_on | [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) | explicit | `import 'my_render.dart'` | high
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | depends_on | `package:flutter/rendering.dart` | explicit | imports `PipelineOwner`, `RenderView`, `Color` | high
- [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) | depends_on | `package:flutter/rendering.dart` | explicit | extends `RenderBox` | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/foundation.dart` | explicit | `BindingBase` mixin target | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/scheduler.dart` | explicit | `SchedulerBinding` mixin | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/services.dart` | explicit | `ServicesBinding` mixin | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/gestures.dart` | explicit | `GestureBinding` mixin | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/rendering.dart` | explicit | `RendererBinding` mixin, `SemanticsBinding` mixin | high
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | depends_on | `package:flutter/semantics.dart` | inferred | `SemanticsBinding` lives in rendering package but requires semantics import | medium

### Flows
- `min-rendering-pipeline` | `ensureInitialized → PipelineOwner → RenderView(MyColoredBox) → pipelineOwner.rootNode = renderView → binding.rootPipelineOwner.adoptChild → addRenderView → prepareInitialFrame → scheduleWarmUpFrame` | high
- `frame-production` | `scheduleWarmUpFrame → SchedulerBinding handleBeginFrame/handleDrawFrame → RendererBinding.drawFrame → flushLayout/flushCompositingBits/flushPaint/flushSemantics → MyColoredBox.performLayout/paint` | high

### Recommended Next Reads
- [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) | understand how binding mixin composition mirrors `WidgetsFlutterBinding`
- [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) | understand custom `RenderBox` layout/paint lifecycle
- [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) | understand the full manual rendering pipeline assembly

### Feature Analysis
- [min-rendering-pipeline.en.md](./_FEATURE/min-rendering-pipeline.en.md) — binding composition, PipelineOwner/RenderView assembly, RenderBox lifecycle, frame scheduling

### Known Issues
- `binding-semantics-import` | `SemanticsBinding` import path is inferred — the rendering package may re-export or contain it | `packages/flutter/lib/src/rendering/binding.dart`

## Risks And Unknowns
- `empty-test` | [test/widget_test.dart](./test/widget_test.dart) contains no actual test logic — yet to be implemented | [test/widget_test.dart](./test/widget_test.dart)
- `future-modules` | the `_framework_test` project is expected to grow with more learning modules over time | next user-added `lib/` directories
