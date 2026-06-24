# Feature Implementation Record: min-rendering-pipeline

## Metadata
- feature: min-rendering-pipeline
- project_root: packages/flutter/_framework_test
- architecture_index: _ARCHITECTURE/ARCHITECTURE.en.md
- analysis_scope: Manual assembly of a minimal Flutter rendering pipeline without the widget/Element layer, covering binding mixin composition, PipelineOwner/RenderView construction, RenderBox lifecycle, and frame scheduling.
- confidence: high

## Entry Points
- symbol: main()
  file: [lib/min_framework/main.dart](./lib/min_framework/main.dart)
  lines: 1-8
  role: Module entrypoint guarded by `isRun`; delegates to `runMinimalPipeline()`

- symbol: runMinimalPipeline()
  file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
  lines: 7-47
  role: Orchestrates the full manual rendering pipeline from binding init to warm-up frame

- symbol: MyRenderingBinding.ensureInitialized()
  file: [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart)
  lines: 19-24
  role: Singleton factory that triggers the full binding mixin initialization chain

- symbol: MyColoredBox
  file: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart)
  lines: 3-25
  role: Minimal RenderBox subclass demonstrating performLayout and paint lifecycle

## Core Flow
1. step: Binding initialization
   file: [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart)
   lines: 19-24
   symbols: MyRenderingBinding.ensureInitialized, initInstances
   summary: Singleton constructor triggers Dart mixin linearization: BindingBase → SchedulerBinding → SemanticsBinding → GestureBinding → ServicesBinding → RendererBinding, each calling initInstances() in order
   evidence: code-confirmed via class declaration with mixin list

2. step: PipelineOwner creation
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 12-15
   symbols: PipelineOwner, onNeedVisualUpdate
   summary: Creates local PipelineOwner with onNeedVisualUpdate callback bridging to binding.ensureVisualUpdate() → SchedulerBinding.ensureVisualUpdate()
   evidence: code-confirmed

3. step: RenderView construction
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 18-21
   symbols: RenderView, PlatformDispatcher.implicitView, MyColoredBox
   summary: Creates RenderView(root render node) with engine's default view and MyColoredBox as sole child; Color(0xFFFF5722) = deep orange
   evidence: code-confirmed

4. step: RenderView attachment to PipelineOwner
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 25
   symbols: pipelineOwner.rootNode
   summary: Sets rootNode which triggers renderView.attach(pipelineOwner), marking the node as needing layout/paint
   evidence: code-confirmed; attachment behavior is framework-backed

5. step: PipelineOwner adoption
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 28
   symbols: binding.rootPipelineOwner, adoptChild
   summary: Registers local PipelineOwner as child of binding's global rootPipelineOwner for frame scheduling coordination
   evidence: code-confirmed; framework API

6. step: RenderView registration
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 31
   symbols: binding.addRenderView
   summary: Registers RenderView with RendererBinding, configuring logicalConstraints and devicePixelRatio from the view
   evidence: code-confirmed

7. step: Initial layout
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 37-38
   symbols: renderView.prepareInitialFrame
   summary: Triggers initial layout pass; after this renderView.size is computed
   evidence: code-confirmed via logged output

8. step: Warm-up frame
   file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
   lines: 41
   symbols: binding.scheduleWarmUpFrame
   summary: Schedules and synchronously processes one frame: handleBeginFrame → handleDrawFrame → RendererBinding.drawFrame → flushLayout/flushCompositingBits/flushPaint/flushSemantics → triggers MyColoredBox.performLayout and MyColoredBox.paint
   evidence: code-confirmed; framework-backed

## Key Symbols
- symbol: runMinimalPipeline
  kind: function
  file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
  lines: 7-47
  role: Top-level function that assembles and runs the minimal rendering pipeline
  used_by: lib/min_framework/main.dart
  calls_into: MyRenderingBinding.ensureInitialized, PipelineOwner, RenderView, prepareInitialFrame, scheduleWarmUpFrame

- symbol: MyRenderingBinding
  kind: class
  file: [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart)
  lines: 7-25
  role: Custom binding that replicates WidgetsFlutterBinding composition minus WidgetsBinding
  used_by: lib/min_framework/minimal_pipeline.dart
  calls_into: BindingBase, SchedulerBinding, SemanticsBinding, GestureBinding, ServicesBinding, RendererBinding

- symbol: MyRenderingBinding.ensureInitialized()
  kind: method
  file: [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart)
  lines: 19-24
  role: Singleton accessor that constructs and returns the singleton binding instance
  used_by: lib/min_framework/minimal_pipeline.dart
  calls_into: MyRenderingBinding constructor → mixin initInstances chain

- symbol: MyColoredBox
  kind: class
  file: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart)
  lines: 3-25
  role: RenderBox subclass that fills constraints and paints solid color
  used_by: lib/min_framework/minimal_pipeline.dart as RenderView child
  calls_into: RenderBox (superclass)

- symbol: MyColoredBox.performLayout()
  kind: method
  file: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart)
  lines: 9-13
  role: Sets size = constraints.biggest; logs constraints and size
  used_by: RendererBinding.drawFrame → flushLayout pipeline
  calls_into: constraints.biggest

- symbol: MyColoredBox.paint()
  kind: method
  file: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart)
  lines: 16-20
  role: Draws filled rectangle at offset with configured color on provided canvas
  used_by: RendererBinding.drawFrame → flushPaint pipeline
  calls_into: PaintingContext.canvas, Paint, canvas.drawRect

- symbol: isRun
  kind: field
  file: [lib/min_framework/main.dart](./lib/min_framework/main.dart)
  lines: 3
  role: Global toggle flag to enable/disable the manual rendering pipeline
  used_by: main() guard condition

## State and Data Changes
- location: MyRenderingBinding._instance
  mutation: Set from null to singleton instance during ensureInitialized()
  purpose: Singleton access pattern
  triggered_by: MyRenderingBinding.ensureInitialized()

- location: pipelineOwner.rootNode
  mutation: Set to renderView, which triggers renderView.attach(pipelineOwner)
  purpose: Establish the render tree root managed by this PipelineOwner
  triggered_by: Explicit assignment in runMinimalPipeline()

- location: renderView.size
  mutation: Computed during prepareInitialFrame() → initial layout pass
  purpose: RenderView now has a concrete size before first paint
  triggered_by: renderView.prepareInitialFrame()

- location: MyColoredBox.size
  mutation: Set to constraints.biggest during performLayout()
  purpose: Compute render box size from parent constraints
  triggered_by: scheduleWarmUpFrame → drawFrame → flushLayout

## Decision Points
- condition: if (isRun) at main.dart line 6
  location: [lib/min_framework/main.dart](./lib/min_framework/main.dart)
  effect_if_true: Call runMinimalPipeline()
  effect_if_false: Skip everything (no-op)

## Side Effects
- effect: Console logging of layout/paint details
  location: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) lines 11-12, 18, 20
  when: During performLayout() and paint() execution

- effect: Frame callback scheduling
  location: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) lines 14, 41
  when: PipelineOwner.onNeedVisualUpdate and scheduleWarmUpFrame() register callbacks with SchedulerBinding

- effect: Visual output on screen
  location: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart) line 19
  when: canvas.drawRect paints a colored rectangle during flushPaint phase

## Related Files
- file: [lib/min_framework/main.dart](./lib/min_framework/main.dart)
  relevance: primary
  reason: Module entrypoint with `isRun` guard

- file: [lib/min_framework/minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart)
  relevance: primary
  reason: Orchestrates the 8-step pipeline assembly and frame scheduling

- file: [lib/min_framework/my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart)
  relevance: primary
  reason: Defines the binding class that enables the entire pipeline

- file: [lib/min_framework/my_render.dart](./lib/min_framework/my_render.dart)
  relevance: primary
  reason: Implements the custom RenderBox that serves as the render tree content

- file: [lib/main.dart](./lib/main.dart)
  relevance: secondary
  reason: Thin entrypoint that delegates to min_framework

- file: packages/flutter/lib/src/rendering/binding.dart
  relevance: context-only
  reason: Framework source for RendererBinding whose drawFrame is exercised

- file: packages/flutter/lib/src/rendering/object.dart
  relevance: context-only
  reason: Framework source for RenderBox/PipelineOwner lifecycle

## Open Questions
- question: What happens when the frame scheduler naturally triggers subsequent frames after the warm-up frame?
  status: unresolved
  note: The demo only shows initial warm-up frame; continuous frame loop behavior is unexplored

- question: How would this pipeline handle multi-view scenarios?
  status: unresolved
  note: Only PlatformDispatcher.implicitView is used; multi-view requires additional RenderViews and PipelineOwners

- question: How would hit testing interact with MyColoredBox?
  status: partially-answered
  note: MyColoredBox does not override hitTest/hitTestSelf, so all pointer events would pass through to ancestor/parent

## Inferences
- statement: SemanticsBinding is imported via package:flutter/rendering.dart rather than a separate semantics import
  basis: The rendering package likely re-exports or contains SemanticsBinding; this is inferred from the import list in my_rendering_binding.dart

- statement: The mixin order in MyRenderingBinding must satisfy RendererBinding's `on` constraints
  basis: RendererBinding declares mixin constraint `on BindingBase, ServicesBinding, SchedulerBinding, GestureBinding, SemanticsBinding, HitTestable` — MyRenderingBinding includes all required mixins as a direct class

## Retrieval Hints
- If asked "How is the binding initialized?", start from [my_rendering_binding.dart](./lib/min_framework/my_rendering_binding.dart) ensureInitialized() and class declaration mixin list.
- If asked "How does the RenderBox get painted?", start from [my_render.dart](./lib/min_framework/my_render.dart) paint() and trace back through flushPaint in RendererBinding.
- If asked "What triggers the first frame?", start from [minimal_pipeline.dart](./lib/min_framework/minimal_pipeline.dart) scheduleWarmUpFrame() and trace through SchedulerBinding frame callbacks.
- If asked "How does this relate to runApp?", compare the manual 8-step flow in minimal_pipeline.dart to WidgetsFlutterBinding internals in packages/flutter/lib/src/widgets/binding.dart.
