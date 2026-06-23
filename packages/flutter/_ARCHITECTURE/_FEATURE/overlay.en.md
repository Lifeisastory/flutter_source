# Feature Implementation Record: Overlay

## Metadata
- feature: Overlay — floating widget stack managed via OverlayEntry (classic API) and OverlayPortal (modern InheritedWidget-based API)
- project_root: packages/flutter/lib/src
- architecture_index: packages/flutter/_ARCHITECTURE/ARCHITECTURE.en.md
- analysis_scope: OverlayEntry lifecycle and properties, OverlayState entry management, _Theater/_RenderTheater custom Stack render object with opaque/maintainState optimization, Overlay.of lookup chain, OverlayPortal controller-based API architecture, _RenderDeferredLayoutBox deferred layout mechanism
- output_date: 2026-06-02
- confidence: high

## Entry Points
- symbol: `OverlayEntry`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: 108–292
  role: Classic API entry; Listenable with builder, opaque, maintainState, canSizeOverlay properties; provides remove(), markNeedsBuild(), dispose()

- symbol: `Overlay`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: 478–620
  role: StatefulWidget for Overlay configuration; provides Overlay.of() / Overlay.maybeOf() static lookup; Overlay.wrap() convenience

- symbol: `OverlayState`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: 626–623 (extends past 620, actually ~626 to end of class)
  role: State managing `List<OverlayEntry> _entries`; provides insert(), insertAll(), rearrange(); build() generates _Theater with opaque skip logic

- symbol: `_Theater`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~680
  role: MultiChildRenderObjectWidget; creates _RenderTheater; skipCount parameter separates onstage/offstage children

- symbol: `_RenderTheater`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~780-1700
  role: Custom Stack RenderBox via ContainerRenderObjectMixin + _RenderTheaterMixin; skipCount-based onstage/offstage; size-determining child for infinite constraints

- symbol: `OverlayPortal`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~1800
  role: Modern declarative API; overlayChildBuilder renders on ancestor Overlay; accesses parent's InheritedWidgets; controlled by OverlayPortalController

- symbol: `OverlayPortalController`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~1600
  role: Controls show/hide/toggle for OverlayPortal; uses global monotonic _wallTime counter for z-order

- symbol: `_OverlayEntryLocation`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~2100
  role: LinkedListEntry positioning OverlayPortal children in _RenderTheater's child model; zOrderIndex-based ordering

- symbol: `_RenderTheaterMarker`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~2150
  role: InheritedWidget injected by each _OverlayEntryWidget; enables OverlayPortal and Overlay.of to find target _RenderTheater

- symbol: `_RenderDeferredLayoutBox`
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  lines: ~2400
  role: Relayout boundary RenderBox for OverlayPortal overlay child; ensures layout happens after both _RenderTheater and _RenderLayoutSurrogateProxyBox complete

## Core Flow

### Flow: Classic API — Insert and Render an OverlayEntry

1. step: Create OverlayEntry with builder
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `OverlayEntry.OverlayEntry()`
   summary: Entry created with builder callback, opaque/maintainState/canSizeOverlay flags, and an internal GlobalKey for later communication.
   evidence: Constructor at `OverlayEntry({required this.builder, ...})`; `final GlobalKey<_OverlayEntryWidgetState> _key`

2. step: Find target OverlayState and call insert()
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `Overlay.of`, `OverlayState.insert`
   summary: `Overlay.of(context)` walks up ancestor tree via _RenderTheaterMarker InheritedWidget to find the nearest OverlayState. Then `insert()` sets `entry._overlay = this` and inserts into `_entries` at the computed index (above/below/default: end of list = topmost).
   evidence: `entry._overlay = this; setState(() { _entries.insert(_insertionIndex(below, above), entry); });`

3. step: OverlayState.build creates _OverlayEntryWidgets with opaque optimization
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `OverlayState.build`
   summary: Iterates `_entries.reversed` (top to bottom). Once an opaque entry is found, subsequent entries are offstage (unless maintainState). Builds `_Theater(skipCount: ..., children: ...)`. Offstage entries get `tickerEnabled: false`.
   evidence: `for (final OverlayEntry entry in _entries.reversed) { if (onstage) { ... } else if (entry.maintainState) { ... tickerEnabled: false } }`

4. step: _Theater creates _RenderTheater
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `_Theater.createElement`, `_Theater.createRenderObject`
   summary: Creates `_TheaterElement` and `_RenderTheater(skipCount:, textDirection:, clipBehavior:)`.

5. step: _RenderTheater performs Stack layout with skipCount
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `_RenderTheater.performLayout`
   summary: If constraints are finite, size = constraints.biggest. Otherwise finds size-determining child (topmost canSizeOverlay=true non-positioned entry). All other onstage children get `BoxConstraints.tight(size)`. Offstage children (first skipCount) are never laid out.
   evidence: `_findSizeDeterminingChild()` traverses from `_lastOnstageChild` upward.

6. step: _RenderTheater paints children in order
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `_RenderTheaterMixin.paint`, `_childrenInPaintOrder()`
   summary: Iterates onstage children first-to-last (bottom to top in paint order). Each child painted with its StackParentData.offset.
   evidence: `for (final RenderBox child in _childrenInPaintOrder()) { context.paintChild(child, childParentData.offset + offset); }`

### Flow: Classic API — Remove an OverlayEntry

7. step: Call entry.remove()
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `OverlayEntry.remove`
   summary: Sets `_overlay = null`. Removes entry from `overlay._entries`. If currently in `SchedulerPhase.persistentCallbacks` (during layout/paint), defers `_markDirty()` via `addPostFrameCallback` to avoid setState during build. Otherwise calls `_markDirty()` immediately.
   evidence: `if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) { ... addPostFrameCallback(...) } else { overlay._markDirty(); }`

8. step: OverlayState rebuilds without the removed entry
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `OverlayState._markDirty`, `OverlayState.build`
   summary: `_markDirty()` calls `setState(() {})`, triggering rebuild. The removed entry's _OverlayEntryWidget is no longer in the children list.

9. step: Old _OverlayEntryWidgetState.dispose() cleans up
   file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
   symbols: `_OverlayEntryWidgetState.dispose`
   summary: Sets `entry._overlayEntryStateNotifier.value = null` (notifies listeners of unmount), then calls `entry._didUnmount()`. If entry was already `_disposedByOwner`, the Notifier is disposed now.
   evidence: `widget.entry._overlayEntryStateNotifier?.value = null; widget.entry._didUnmount();`

10. step: OverlayEntry._didUnmount handles deferred disposal
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `OverlayEntry._didUnmount`
    summary: If `_disposedByOwner` was true when dispose() was called (but widget was still mounted), disposes the Notifier now that the widget has finally unmounted.
    evidence: `if (_disposedByOwner) { _overlayEntryStateNotifier?.dispose(); _overlayEntryStateNotifier = null; }`

### Flow: Overlay.of Lookup

11. step: Overlay.of / Overlay.maybeOf
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `Overlay.of`, `Overlay.maybeOf`
    summary: Delegates to `_RenderTheaterMarker.maybeOf(context, ...).overlayEntryWidgetState.widget.overlayState`. The marker is an InheritedWidget injected by each `_OverlayEntryWidget`'s build.
    evidence: `_RenderTheaterMarker.maybeOf(context, targetRootOverlay: rootOverlay, createDependency: false)?.overlayEntryWidgetState.widget.overlayState`

12. step: _RenderTheaterMarker.of / .maybeOf
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `_RenderTheaterMarker.of`, `_RenderTheaterMarker.maybeOf`
    summary: Uses `LookupBoundary.dependOnInheritedWidgetOfExactType<_RenderTheaterMarker>(context)` for nearest overlay. For `rootOverlay`, uses `_rootRenderTheaterMarkerOf` which recursively finds the furthest ancestor marker via `visitAncestorElements`.
    evidence: `LookupBoundary.dependOnInheritedWidgetOfExactType<_RenderTheaterMarker>(context)`

### Flow: OverlayPortal Insert & Render

13. step: controller.show() sets zOrderIndex
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `OverlayPortalController.show`, `OverlayPortalController._now`
    summary: Asserts not in `SchedulerPhase.persistentCallbacks`. Delegates to `_OverlayPortalState.show(zOrderIndex)` where zOrderIndex is from a globally monotonic `_wallTime` counter. Sets `_zOrderIndex` via setState, triggering rebuild.
    evidence: `state.show(_now());` where `_now() => _wallTime += 1`

14. step: _OverlayPortalState.build creates location and overlayChild
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `_OverlayPortalState.build`, `_OverlayPortalState._getLocation`
    summary: If `_zOrderIndex != null`, creates an `_OverlayEntryLocation(zOrderIndex, overlayEntryWidgetState, theater)`. The location is cached and reused if the child model hasn't changed. Builds `_OverlayPortal(overlayLocation:, overlayChild: _DeferredLayout(child: Builder(builder: overlayChildBuilder)), child:)`.
    evidence: `_getLocation(zOrderIndex, widget.overlayLocation)` finds/caches the location.

15. step: _OverlayPortalElement.insertRenderObjectChild adds to _RenderTheater
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `_OverlayPortalElement.insertRenderObjectChild`
    summary: For the overlay child (slot != null): sets `renderObject._deferredLayoutChild`, then calls `slot._addChild(child)` which adds the RenderBox to the _RenderTheater via `_theater._addDeferredChild`.
    evidence: `slot._addChild(child as _RenderDeferredLayoutBox);`

16. step: _RenderTheater._addDeferredChild adopts the child
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `_RenderTheater._addDeferredChild`
    summary: Sets `_skipMarkNeedsLayout = true` to suppress markNeedsLayout on the theater itself, calls `adoptChild(child)`, marks paint and semantics as dirty. Then calls `child._layoutSurrogate.markNeedsLayout()` to ensure the deferred child is scheduled for layout.
    evidence: `_skipMarkNeedsLayout = true; adoptChild(child); ... _skipMarkNeedsLayout = false; child._layoutSurrogate.markNeedsLayout();`

17. step: _RenderDeferredLayoutBox handles deferred layout
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `_RenderDeferredLayoutBox.layout`, `_RenderDeferredLayoutBox.performLayout`
    summary: When layout() is called by the theater during treewalk, `_doingLayoutFromTreeWalk` is true: only resize happens (performResize), performLayout is skipped. When `_layoutSurrogate.performLayout` runs, it calls `_doLayoutFrom(this, constraints:)` which adds this box to the dirty list with proper depth ordering. Later `PipelineOwner.flushLayout` calls `performLayout` for real.
    evidence: `if (_doingLayoutFromTreeWalk) { _needsLayout = false; return; }`

### Flow: OverlayEntry.rearrange

18. step: rearrange reorders entries
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `OverlayState.rearrange`
    summary: Saves old entries as `LinkedHashSet<OverlayEntry>.of(_entries)`. Clears `_entries` and adds `newEntriesList` in order. Removes new entries from old set. Inserts remaining old entries at position specified by above/below parameters.
    evidence: `old.removeAll(newEntriesList); _entries.insertAll(_insertionIndex(below, above), old);`

### Flow: opaque/maintainState Property Change

19. step: Setter triggers _didChangeEntryOpacity
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `OverlayEntry.opaque=`, `OverlayEntry.maintainState=`
    summary: Each setter guards against no-op, then calls `_overlay?._didChangeEntryOpacity()`.
    evidence: `_overlay?._didChangeEntryOpacity();`

20. step: _didChangeEntryOpacity calls setState
    file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
    symbols: `OverlayState._didChangeEntryOpacity`
    summary: Calls `setState(() {})` — the comment explains "We use the opacity of the entry in our build function, which means our state has changed." The rebuild recalculates skipCount and which entries are onstage.
    evidence: `setState(() { });`

## Key Symbols

- symbol: `OverlayEntry`
  kind: class (implements Listenable)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Classic API entry point. Holds builder, opaque, maintainState, canSizeOverlay, internal GlobalKey, reference to OverlayState. Provides remove(), markNeedsBuild(), dispose().
  used_by: Navigator, Draggable, showDialog, Tooltip, etc.
  calls_into: `OverlayState._entries`, `_OverlayEntryWidgetState._markNeedsBuild`

- symbol: `OverlayState`
  kind: class (State<Overlay> with TickerProviderStateMixin)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Manages `List<OverlayEntry> _entries`. Provides insert(), insertAll(), rearrange(). build() creates _Theater.
  used_by: Overlay (parent widget), OverlayEntry.remove
  calls_into: `setState`, `_Theater`

- symbol: `OverlayState._entries`
  kind: field
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: `List<OverlayEntry>` — the ordered stack of entries. Later indices = painted on top.
  used_by: insert, insertAll, rearrange, remove, build, debugIsVisible

- symbol: `_Theater`
  kind: class (MultiChildRenderObjectWidget)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Custom Stack widget used by Overlay. skipCount parameter separates onstage from offstage children.
  used_by: OverlayState.build

- symbol: `_RenderTheater`
  kind: class (RenderBox with ContainerRenderObjectMixin, _RenderTheaterMixin)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Custom Stack render object. Uses Stack layout via _RenderTheaterMixin. skipCount property controls which children are onstage. Size-determining child for infinite constraints. Supports _addDeferredChild/_removeDeferredChild for OverlayPortal.
  used_by: _Theater.createRenderObject
  calls_into: `_findSizeDeterminingChild`, `_childrenInPaintOrder`, `_childrenInHitTestOrder`

- symbol: `_RenderTheaterMixin`
  kind: mixin (on RenderBox)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Shared Stack layout algorithm: setupParentData (StackParentData), layoutChild, paint, hitTest, computeDistanceToActualBaseline. Used by both _RenderTheater and _RenderDeferredLayoutBox.
  used_by: `_RenderTheater`, `_RenderDeferredLayoutBox`

- symbol: `_OverlayEntryWidget`
  kind: class (StatefulWidget)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Widget wrapping a single OverlayEntry. Injected into the widget tree by OverlayState.build.
  used_by: OverlayState.build

- symbol: `_OverlayEntryWidgetState`
  kind: class (State<_OverlayEntryWidget>)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Manages _sortedTheaterSiblings LinkedList for OverlayPortal children under this entry. Holds reference to _RenderTheater. Injects _RenderTheaterMarker InheritedWidget in build.
  used_by: _OverlayEntryWidget.createState
  calls_into: `_RenderTheaterMarker.of`, `_add/_remove` (for OverlayPortal children)

- symbol: `OverlayPortal`
  kind: class (StatefulWidget)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Modern API widget. overlayChildBuilder renders on ancestor Overlay. Can access InheritedWidgets from parent subtree.
  used_by: App-level overlay child insertion (tooltips, dropdowns, etc.)

- symbol: `OverlayPortalController`
  kind: class
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Controller with show(), hide(), toggle(), isShowing. Uses global `_wallTime` monotonic counter for z-order.
  used_by: OverlayPortal
  calls_into: `_OverlayPortalState.show/hide`

- symbol: `_OverlayEntryLocation`
  kind: class (extends LinkedListEntry)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Position cursor in _RenderTheater's child model. Links to specific _OverlayEntryWidgetState and _RenderTheater. Manages _addChild/_removeChild/_moveChild for the _RenderDeferredLayoutBox.
  used_by: _OverlayPortalState (as Element slot), _OverlayPortalElement

- symbol: `_RenderTheaterMarker`
  kind: class (InheritedWidget)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Injected by each _OverlayEntryWidgetState.build. Enables Overlay.of and OverlayPortal to find the target _RenderTheater and associated OverlayEntryWidgetState.
  used_by: Overlay.maybeOf, _OverlayPortalState._getLocation

- symbol: `_RenderDeferredLayoutBox`
  kind: class (RenderProxyBox with _RenderTheaterMixin, LinkedListEntry)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: Relayout boundary that defers its layout until after both _RenderTheater and _RenderLayoutSurrogateProxyBox complete. Prevents double layout of OverlayPortal's overlay child.
  used_by: _DeferredLayout.createRenderObject

- symbol: `_RenderLayoutSurrogateProxyBox`
  kind: class (RenderProxyBox)
  file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  role: RenderObject for the OverlayPortal's own position in the widget tree. Its performLayout ensures _RenderDeferredLayoutBox is in the dirty list with correct depth ordering.
  used_by: _OverlayPortal.createRenderObject

## State and Data Changes

- location: `OverlayState._entries`
  mutation: Insert entry at computed position
  purpose: Add a new OverlayEntry to the overlay stack
  triggered_by: `OverlayState.insert()`, `insertAll()`

- location: `OverlayState._entries`
  mutation: Remove entry
  purpose: Stop rendering and eventually dispose an OverlayEntry
  triggered_by: `OverlayEntry.remove()`

- location: `OverlayState._entries`
  mutation: Reorder entries (clear + addAll + insertAll old)
  purpose: Atomic reordering of multiple entries (used by Navigator)
  triggered_by: `OverlayState.rearrange()`

- location: `OverlayEntry._overlay`
  mutation: Set to OverlayState (insert) / set to null (remove)
  purpose: Track which overlay owns this entry; assert for correct usage
  triggered_by: `OverlayState.insert()` / `OverlayEntry.remove()`

- location: `OverlayEntry._overlayEntryStateNotifier.value`
  mutation: Set to _OverlayEntryWidgetState (mount) / null (unmount)
  purpose: Notify listeners when entry widget is mounted/unmounted
  triggered_by: `_OverlayEntryWidgetState.initState()` / `dispose()`

- location: `OverlayPortalController._attachTarget`
  mutation: Set to _OverlayPortalState (attach) / null (detach)
  purpose: Bind controller to exactly one OverlayPortal at a time
  triggered_by: `_OverlayPortalState.initState()` / `dispose()`

- location: `_OverlayPortalState._zOrderIndex`
  mutation: Set to wall-time (show) / null (hide)
  purpose: Control overlay child visibility and z-order
  triggered_by: `OverlayPortalController.show()` / `hide()`

- location: `_RenderTheater._firstOnstageChild` (computed)
  mutation: Changes when skipCount changes
  purpose: Determine which render children participate in layout/paint
  triggered_by: OverlayState.build (new skipCount value)

## Decision Points

- condition: `SchedulerPhase == persistentCallbacks` in OverlayEntry.remove()
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  effect_if_true: Defer `_markDirty()` to postFrameCallback (avoid setState during build)
  effect_if_false: Call `_markDirty()` immediately

- condition: `entry.opaque == true` in OverlayState.build
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  effect_if_true: `onstage = false` — subsequent entries are offstage (unless maintainState)
  effect_if_false: Continue adding entries as onstage

- condition: `entry.maintainState == true` (when offstage) in OverlayState.build
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  effect_if_true: Entry widget is created but with `tickerEnabled: false`
  effect_if_false: Entry widget is not created at all (not in children list)

- condition: `constraints.biggest.isFinite` in _RenderTheater.performLayout
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  effect_if_true: `size = constraints.biggest` (fill all available space)
  effect_if_false: Find `_sizeDeterminingChild` and use its size

- condition: `overlay.mounted` in OverlayEntry.remove()
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  effect_if_true: Proceed with removal and markDirty
  effect_if_false: Return early (overlay already disposed)

- condition: `!_childModelMayHaveChanged && _isTheSameLocation(...)` in _getLocation
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  effect_if_true: Return cached `_OverlayEntryLocation`
  effect_if_false: Invalidate cache, create new location

## Side Effects

- effect: `State.setState` triggered on OverlayState
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  when: insert(), insertAll(), rearrange(), _markDirty(), _didChangeEntryOpacity()
  note: Triggers rebuild of entire Overlay subtree

- effect: `_OverlayEntryWidgetState` created/destroyed
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  when: Entry inserted/removed from overlay
  note: initState sets `entry._overlayEntryStateNotifier.value`; dispose nulls it

- effect: RenderBox added/removed from _RenderTheater
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  when: Overlay rebuild or OverlayPortal show/hide
  note: `_RenderTheater._addDeferredChild` / `_removeDeferredChild` for OverlayPortal; `_TheaterElement.insertRenderObjectChild` for classic entries

- effect: TickerMode disabled for offstage entries
  location: [overlay.dart](../../lib/src/widgets/overlay.dart)
  when: OverlayState.build creates _OverlayEntryWidget with `tickerEnabled: false`
  note: Prevents background routes from driving animations unnecessarily

## Related Files

- file: [packages/flutter/lib/src/widgets/overlay.dart](../../lib/src/widgets/overlay.dart)
  relevance: primary
  reason: Contains all overlay code: OverlayEntry, Overlay, OverlayState, _Theater, _RenderTheater, OverlayPortal, _RenderDeferredLayoutBox

- file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  relevance: secondary
  reason: StatefulWidget/State base classes, GlobalKey used by OverlayEntry._key, BuildContext used by Overlay.of

- file: [packages/flutter/lib/src/widgets/basic.dart](../../lib/src/widgets/basic.dart)
  relevance: context-only
  reason: Stack/Positioned are conceptually similar; Overlay uses its own _Theater instead for skipCount optimization

- file: [packages/flutter/lib/src/widgets/lookup_boundary.dart](../../lib/src/widgets/lookup_boundary.dart)
  relevance: context-only
  reason: LookupBoundary used by _RenderTheaterMarker for overlay ancestor lookup

- file: [packages/flutter/lib/src/widgets/ticker_provider.dart](../../lib/src/widgets/ticker_provider.dart)
  relevance: context-only
  reason: TickerProviderStateMixin used by OverlayState; TickerMode used to disable offstage entry tickers

- file: [packages/flutter/lib/src/widgets/binding.dart](../../lib/src/widgets/binding.dart)
  relevance: context-only
  reason: WidgetsBinding.drawFrame triggers buildScope (causing Overlay rebuilds) and finalizeTree

- file: [packages/flutter/lib/src/scheduler/binding.dart](../../lib/src/scheduler/binding.dart)
  relevance: context-only
  reason: SchedulerPhase checked in OverlayEntry.remove() for safe setState timing

## Open Questions

- question: Why is OverlayEntry's _overlayEntryStateNotifier a nullable ValueNotifier that can be disposed independently of the OverlayEntry?
  status: partially-answered
  note: The nullable pattern allows dispose() to be called before the widget is unmounted — the Notifier is disposed in _didUnmount if _disposedByOwner was set. This supports the case where the owner calls dispose() before the widget tree has finished unmounting.

- question: Can OverlayPortal overlayChildBuilder be called during build if OverlayPortal rebuilds while the overlay child is showing?
  status: resolved
  note: No. The `overlayChildBuilder` is wrapped in a `Builder(builder: widget.overlayChildBuilder)` inside `_DeferredLayout`. It is only called when the overlay child's Element builds, not during OverlayPortal's own build.

## Inferences

- statement: The `sync*` generators used for `_childrenInPaintOrder` and `_childrenInHitTestOrder` inside `_RenderTheater` are designed to allow concurrent modification during iteration because overlay children can be added/removed during layout or hit-test phases.
  basis: The code uses `sync*` with `while (child != null) { ... child = childParentData.nextSibling }` pattern and parent data iterators instead of caching child lists. Comment in `_OverlayEntryWidgetState` states: "LinkedList as a Iterable doesn't support concurrent modification" — `sync*` avoids this issue.

- statement: OverlayEntry.remove() checks for `persistentCallbacks` phase because calling setState during this phase would violate the invariant that no new frames are scheduled during layout/paint. The `addPostFrameCallback` workaround ensures the UI update happens in the next frame at the latest.
  basis: `SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks` check followed by `addPostFrameCallback`. The phase enum documents that persistentCallbacks is the phase for `WidgetsBinding.drawFrame` and `SchedulerBinding.handleDrawFrame`.

## Retrieval Hints
- If asked "How does OverlayEntry.insert work?", start from [OverlayState.insert in overlay.dart](../../lib/src/widgets/overlay.dart).
- If asked "How does opaque optimization work?", start from [OverlayState.build in overlay.dart](../../lib/src/widgets/overlay.dart) — the `onstage` flag loop.
- If asked "How does Overlay.of find the overlay?", trace [Overlay.maybeOf → _RenderTheaterMarker.maybeOf in overlay.dart](../../lib/src/widgets/overlay.dart).
- If asked "How does OverlayPortal render its child on an ancestor Overlay?", start from [_OverlayPortalElement.insertRenderObjectChild in overlay.dart](../../lib/src/widgets/overlay.dart).
- If asked "How does _RenderDeferredLayoutBox prevent double layout?", see its [performLayout in overlay.dart](../../lib/src/widgets/overlay.dart) — the `_doingLayoutFromTreeWalk` flag.
- If asked "How does OverlayPortalController z-order work?", see [_now() method in overlay.dart](../../lib/src/widgets/overlay.dart) — global monotonic counter.
- If asked "How does rearrange work?", see [OverlayState.rearrange in overlay.dart](../../lib/src/widgets/overlay.dart) — LinkedHashSet algorithm.
