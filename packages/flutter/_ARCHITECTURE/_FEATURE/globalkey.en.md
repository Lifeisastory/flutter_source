# Feature Implementation Record: GlobalKey

## Metadata
- feature: GlobalKey — global element identification, cross-tree access, and reparenting
- project_root: packages/flutter/lib/src
- architecture_index: packages/flutter/_ARCHITECTURE/ARCHITECTURE.en.md
- analysis_scope: GlobalKey type hierarchy, BuildOwner global registry, element lifecycle registration/unregistration, reparenting via inflateWidget→_retakeInactiveElement→_activateWithParent, and debug-mode duplicate detection
- output_date: 2026-06-02
- confidence: high

## Entry Points
- symbol: `GlobalKey<T>`
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 159–200
  role: Abstract class; factory creates LabeledGlobalKey; provides currentContext/currentWidget/currentState accessors that query the global registry

- symbol: `LabeledGlobalKey<T>`
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 203–220
  role: Concrete GlobalKey with optional debug label; produced by `GlobalKey({debugLabel})` factory

- symbol: `GlobalObjectKey<T>`
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 245–261
  role: GlobalKey variant whose equality is based on `identical(value)`; useful when key identity must be tied to an external object

- symbol: `Key`
  file: [packages/flutter/lib/src/foundation/key.dart](../../lib/src/foundation/key.dart)
  lines: 30–50
  role: Base class for all keys; factory `Key(String)` produces `ValueKey<String>`

- symbol: `LocalKey`
  file: [packages/flutter/lib/src/foundation/key.dart](../../lib/src/foundation/key.dart)
  lines: 54–58
  role: Abstract base for non-global keys (ValueKey, ObjectKey, UniqueKey)

- symbol: `ValueKey<T>`
  file: [packages/flutter/lib/src/foundation/key.dart](../../lib/src/foundation/key.dart)
  lines: 78–113
  role: Locally-scoped key with value-based equality; used by Key factory

## Core Flow

### Flow: GlobalKey Registration on Element Mount

1. step: Element creation
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 4560–4590
   symbols: `Element.inflateWidget`
   summary: Called when a parent rebuilds with new widget children. If newWidget.key is GlobalKey, attempts `_retakeInactiveElement` first; if that returns null, creates new element via `newWidget.createElement()` and calls `mount`.
   evidence: L4571: `final Element? inactiveChild = key is GlobalKey ? _retakeInactiveElement(key, newWidget) : null;`

2. step: Element.mount registers GlobalKey
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 4354–4357
   symbols: `Element.mount`, `BuildOwner._registerGlobalKey`
   summary: After setting parent, slot, lifecycle=active, depth, owner: if widget.key is GlobalKey, calls `owner!._registerGlobalKey(key, this)` to insert into the global registry map.
   evidence: L4355: `if (key is GlobalKey) { owner!._registerGlobalKey(key, this); }`

3. step: _registerGlobalKey writes to map
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 3178–3188
   symbols: `BuildOwner._registerGlobalKey`, `BuildOwner._globalKeyRegistry`
   summary: In debug mode, checks for existing key in registry; if found with same widget type, adds old element to `_debugIllFatedElements`. Then unconditionally sets `_globalKeyRegistry[key] = element`.
   evidence: L3180–3187

### Flow: GlobalKey Cross-Tree Access

4. step: _currentElement getter queries registry
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 173
   symbols: `GlobalKey._currentElement`
   summary: Direct map lookup: `WidgetsBinding.instance.buildOwner!._globalKeyRegistry[this]`
   evidence: L173: `Element? get _currentElement => WidgetsBinding.instance.buildOwner!._globalKeyRegistry[this];`

5. step: currentState pattern-matches StatefulElement
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 196–199
   symbols: `GlobalKey.currentState`
   summary: Uses Dart 3 switch with record pattern: `StatefulElement(:final T state)` — only returns state if element is StatefulElement AND its State is subtype of T.
   evidence: L196–199

### Flow: GlobalKey Reparenting (Same Frame)

6. step: Old parent rebuild drops widget with GlobalKey
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 3982–3990
   symbols: `Element.updateChild`, `Element.deactivateChild`
   summary: `updateChild(child, null, slot)` → `deactivateChild(child)`: sets child._parent=null, detaches render object, adds to `_InactiveElements`. GlobalKey remains in registry.
   evidence: L3983–3986

7. step: deactivateChild adds to _InactiveElements
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 4625–4645
   symbols: `Element.deactivateChild`
   summary: child._parent=null, child.detachRenderObject(), owner!._inactiveElements.add(child) (which calls deactivate recursively), then debug logging.
   evidence: L4630–4633

8. step: _InactiveElements.add triggers recursive deactivate
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 2148–2164
   symbols: `_InactiveElements.add`, `_InactiveElements._deactivateRecursively`
   summary: Calls `_deactivateRecursively(element)` which calls `element.deactivate()` then visits children recursively. Element transitions active→inactive.
   evidence: L2155–2158

9. step: New parent's inflateWidget detects GlobalKey
   file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
   lines: 4570–4576
   symbols: `Element.inflateWidget`
   summary: Checks `key is GlobalKey` and calls `_retakeInactiveElement(key, newWidget)`.
   evidence: L4571

10. step: _retakeInactiveElement retrieves element
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 4481–4531
    symbols: `Element._retakeInactiveElement`, `GlobalKey._currentElement`
    summary: Queries `key._currentElement` (registry lookup). If null or `!Widget.canUpdate`, returns null. If element still has parent (parent!=null): asserts parent≠this, calls `parent.forgetChild(element)` + `parent.deactivateChild(element)`. Then `owner!._inactiveElements.remove(element)` and returns element.
    evidence: L4488–4531

11. step: forgetChild tracks for debug duplicate detection
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 4702–4714
    symbols: `Element.forgetChild`
    summary: In debug mode, if child.widget.key is GlobalKey, adds child to `_debugForgottenChildrenWithGlobalKey`. The actual child model removal happens as a side effect of the parent not seeing the child in its new widget list during its next update.
    evidence: L4710–4711

12. step: _activateWithParent reactivates under new parent
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 4717–4733
    symbols: `Element._activateWithParent`, `Element._activateRecursively`
    summary: Sets _parent and _owner; calls _updateDepth, _updateBuildScopeRecursively, _activateRecursively (calls activate() which sets lifecycle=active, clears deps, calls _updateInheritance, schedules rebuild if dirty), then attachRenderObject(newSlot).
    evidence: L4717–4733

13. step: updateChild syncs widget
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 4583–4585
    symbols: `Element.updateChild`, `Element.update`
    summary: `updateChild(inactiveChild, newWidget, newSlot)` finds Widget.canUpdate returns true, calls `child.update(newWidget)` which sets `_widget = newWidget` and clears debug forgotten children.
    evidence: L4583–4585; update method at L4375

### Flow: GlobalKey Unregistration on Element Destruction

14. step: finalizeTree triggers unmountAll
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 3335–3344
    symbols: `BuildOwner.finalizeTree`, `_InactiveElements._unmountAll`
    summary: Called after build phase by WidgetsBinding.drawFrame. Calls `_inactiveElements._unmountAll()` which sorts elements by depth (deepest first), then recursively calls `_unmount` on each.
    evidence: L3344

15. step: _unmountAll sorts and unmounts
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 2121–2131
    symbols: `_InactiveElements._unmountAll`, `_InactiveElements._unmount`
    summary: Locks, sorts elements, clears set, unmounts in reverse (deepest first). Each `_unmount` calls element.unmount() recursively on children.
    evidence: L2121–2131

16. step: Element.unmount unregisters GlobalKey
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 4851–4862
    symbols: `Element.unmount`, `BuildOwner._unregisterGlobalKey`
    summary: If key is GlobalKey, calls `owner!._unregisterGlobalKey(key, this)`. Then nulls out _widget, _dependencies, sets lifecycle=defunct.
    evidence: L4858–4859

17. step: _unregisterGlobalKey removes from map
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 3190–3201
    symbols: `BuildOwner._unregisterGlobalKey`
    summary: In debug mode, checks if registry has the key but with a different element. Only removes if `_globalKeyRegistry[key] == element` (guard against stale/duplicate references).
    evidence: L3198–3199

### Flow: Debug Duplicate Detection (finalizeTree)

18. step: _debugVerifyGlobalKeyReservation
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 3211–3283
    symbols: `BuildOwner._debugVerifyGlobalKeyReservation`
    summary: Iterates `_debugGlobalKeyReservations`, builds a keyToParent map. If same key reserved by two different parents, throws FlutterError("Multiple widgets used the same GlobalKey").
    evidence: L3231–3277

19. step: _debugVerifyIllFatedPopulation
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 3285–3328
    symbols: `BuildOwner._debugVerifyIllFatedPopulation`
    summary: Checks `_debugIllFatedElements` for non-defunct elements whose GlobalKey was overwritten by another element of different widget type. Throws FlutterError if duplicates detected.
    evidence: L3289–3326

20. step: Shenanigans detection (parents not rebuilt after children taken)
    file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
    lines: 3349–3433
    symbols: `BuildOwner.finalizeTree`
    summary: Checks `_debugElementsThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans`. If a parent whose child was retaken via GlobalKey never rebuilt this frame, it still thinks it has that child → duplicate GlobalKey error.
    evidence: L3349–3431

## Key Symbols

- symbol: `GlobalKey<T>`
  kind: class (abstract)
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 159–200
  role: Abstract base for app-global keys; provides registry-backed accessors
  used_by: All widgets that need cross-tree element access or reparenting
  calls_into: `WidgetsBinding.instance.buildOwner!._globalKeyRegistry`

- symbol: `BuildOwner._globalKeyRegistry`
  kind: field
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 3148
  role: `Map<GlobalKey, Element>` — the single source of truth mapping GlobalKeys to Elements
  used_by: `GlobalKey._currentElement`, `_registerGlobalKey`, `_unregisterGlobalKey`
  calls_into: N/A (data structure)

- symbol: `BuildOwner._registerGlobalKey`
  kind: method
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 3178–3188
  role: Inserts (key, element) into registry; debug checks for duplicates
  used_by: `Element.mount`
  calls_into: `_globalKeyRegistry`, `_debugIllFatedElements`

- symbol: `BuildOwner._unregisterGlobalKey`
  kind: method
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 3190–3201
  role: Removes key from registry if element matches
  used_by: `Element.unmount`
  calls_into: `_globalKeyRegistry`

- symbol: `Element._retakeInactiveElement`
  kind: method
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 4481–4531
  role: Core reparenting logic: retrieves element from registry, severs from old parent, removes from inactive set
  used_by: `Element.inflateWidget`
  calls_into: `GlobalKey._currentElement`, `parent.forgetChild`, `parent.deactivateChild`, `_inactiveElements.remove`

- symbol: `Element._activateWithParent`
  kind: method
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 4717–4733
  role: Re-binds an inactive element to a new parent and reactivates its subtree
  used_by: `Element.inflateWidget`
  calls_into: `_updateDepth`, `_updateBuildScopeRecursively`, `_activateRecursively`, `attachRenderObject`

- symbol: `_InactiveElements`
  kind: class
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 2099–2183
  role: Manages the set of inactive (deactivated but not yet unmounted) elements
  used_by: `BuildOwner`
  calls_into: `Element.deactivate`, `Element.unmount`

- symbol: `BuildOwner.finalizeTree`
  kind: method
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 3335–3445
  role: End-of-frame cleanup: unmounts inactive elements, runs debug GlobalKey duplicate checks
  used_by: `WidgetsBinding.drawFrame`
  calls_into: `_inactiveElements._unmountAll`, `_debugVerifyGlobalKeyReservation`, `_debugVerifyIllFatedPopulation`

- symbol: `Element.deactivateChild`
  kind: method
  file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  lines: 4625–4645
  role: Detaches child element from parent, adds to inactive elements
  used_by: `Element.updateChild`, `Element._retakeInactiveElement`
  calls_into: `_inactiveElements.add`, `detachRenderObject`

- symbol: `debugPrintGlobalKeyedWidgetLifecycle`
  kind: field (bool)
  file: [packages/flutter/lib/src/widgets/debug.dart](../../lib/src/widgets/debug.dart)
  lines: 107
  role: Debug flag enabling verbose GlobalKey lifecycle logging
  used_by: `_InactiveElements._unmount`, `Element._retakeInactiveElement`, `Element.deactivateChild`, `Element._activateWithParent`

## State and Data Changes

- location: `BuildOwner._globalKeyRegistry`
  mutation: Insert `(key, element)` pair
  purpose: Track the active element for each GlobalKey
  triggered_by: `Element.mount` → `_registerGlobalKey`; `_retakeInactiveElement` does NOT mutate (reuses existing entry)

- location: `BuildOwner._globalKeyRegistry`
  mutation: Remove entry for key
  purpose: Clean up destroyed element's GlobalKey binding
  triggered_by: `Element.unmount` → `_unregisterGlobalKey` (during `finalizeTree`)

- location: `_InactiveElements._elements`
  mutation: Add element
  purpose: Buffer deactivated elements for potential reparenting within frame
  triggered_by: `Element.deactivateChild` → `_inactiveElements.add`

- location: `_InactiveElements._elements`
  mutation: Remove element
  purpose: Take element out of inactive pool for reparenting
  triggered_by: `Element._retakeInactiveElement` → `_inactiveElements.remove`

- location: `Element._lifecycleState`
  mutation: active → inactive → active (reparenting) OR active → inactive → defunct (destruction)
  purpose: Track element lifecycle for state-dependent behavior
  triggered_by: `deactivate` (→ inactive), `activate` (→ active), `unmount` (→ defunct)

- location: `Element._parent`
  mutation: Set to old parent → null → new parent (reparenting) OR old parent → null (deactivation)
  purpose: Tree topology management; null parent signals inactive element
  triggered_by: `deactivateChild` (→ null), `_activateWithParent` (→ new parent)

## Decision Points

- condition: `Widget.canUpdate(element.widget, newWidget)` in `_retakeInactiveElement`
  location: [framework.dart L4493](../../lib/src/widgets/framework.dart#L4493)
  effect_if_true: Element is reused via reparenting
  effect_if_false: Returns null; old element will be unmounted, new element created from scratch

- condition: `element._parent != null` in `_retakeInactiveElement`
  location: [framework.dart L4505](../../lib/src/widgets/framework.dart#L4505)
  effect_if_true: Element still has old parent → must call forgetChild + deactivateChild to sever
  effect_if_false: Element already inactive → directly remove from _inactiveElements

- condition: `parent == this` in `_retakeInactiveElement`
  location: [framework.dart L4506](../../lib/src/widgets/framework.dart#L4506)
  effect_if_true: Throws FlutterError — duplicate GlobalKey within same parent
  effect_if_false: Proceeds with reparenting

- condition: `_globalKeyRegistry[key] == element` in `_unregisterGlobalKey`
  location: [framework.dart L3198](../../lib/src/widgets/framework.dart#L3198)
  effect_if_true: Removes key from registry
  effect_if_false: No-op (guard against stale/double-unregister)

- condition: `key is GlobalKey` in `Element.mount` / `Element.unmount` / `inflateWidget`
  location: [framework.dart L4355, L4858, L4571](../../lib/src/widgets/framework.dart#L4355)
  effect_if_true: Invoke GlobalKey-specific behavior (register/unregister/reparent)
  effect_if_false: No GlobalKey behavior (standard key or no key)

## Side Effects

- effect: `State.deactivate()` called on StatefulWidget subtree
  location: [framework.dart](../../lib/src/widgets/framework.dart)
  when: During reparenting: old parent's `deactivateChild` → `_InactiveElements.add` → `_deactivateRecursively` → `element.deactivate()`
  note: This is called even when element will be reactivated in same frame — documented as a performance cost of reparenting

- effect: All InheritedWidget dependencies marked for rebuild
  location: [framework.dart](../../lib/src/widgets/framework.dart)
  when: `Element._activateRecursively` → `activate()` → `_updateInheritance()` + marking dependents
  note: This forces widgets depending on inherited data to rebuild after reparenting

- effect: Dirty element re-scheduled for build
  location: [framework.dart L4760](../../lib/src/widgets/framework.dart#L4760)
  when: `Element.activate()` — if element was dirty when deactivated, schedules rebuild on new owner
  note: Ensures pending updates are not lost during reparenting

- effect: RenderObject detached and re-attached
  location: [framework.dart](../../lib/src/widgets/framework.dart)
  when: `deactivateChild` → `detachRenderObject`; later `_activateWithParent` → `attachRenderObject(newSlot)`
  note: The RenderObject moves to new position in render tree

## Related Files

- file: [packages/flutter/lib/src/widgets/framework.dart](../../lib/src/widgets/framework.dart)
  relevance: primary
  reason: Contains GlobalKey class, BuildOwner. _globalKeyRegistry, Element lifecycle methods, _InactiveElements, finalizeTree

- file: [packages/flutter/lib/src/foundation/key.dart](../../lib/src/foundation/key.dart)
  relevance: secondary
  reason: Contains Key base class, LocalKey, ValueKey, ObjectKey, UniqueKey — the type hierarchy that GlobalKey extends

- file: [packages/flutter/lib/src/widgets/binding.dart](../../lib/src/widgets/binding.dart)
  relevance: context-only
  reason: WidgetsFlutterBinding holds BuildOwner instance that hosts _globalKeyRegistry; drawFrame calls finalizeTree

- file: [packages/flutter/lib/src/widgets/debug.dart](../../lib/src/widgets/debug.dart)
  relevance: context-only
  reason: Defines `debugPrintGlobalKeyedWidgetLifecycle` flag controlling GlobalKey lifecycle debug logging

## Open Questions

- question: What happens in release mode when two different widgets in different parts of the tree use the same GlobalKey?
  status: partially-answered
  note: The second `_registerGlobalKey` call overwrites the first in `_globalKeyRegistry`. The old element becomes unreachable via the key but is not immediately cleaned up. Behavior is undefined and should be avoided.

- question: Can GlobalKey reparenting cause issues with widgets that have side effects in deactivate/activate?
  status: unresolved
  note: `State.deactivate()` and `State.activate()` are called during reparenting. Widgets with non-idempotent side effects (e.g., disposing controllers in deactivate) may behave incorrectly. This is documented at GlobalKey class doc.

## Inferences

- statement: GlobalKey is defined in framework.dart rather than key.dart because it depends on WidgetsBinding.instance.buildOwner, which requires the widgets layer.
  basis: Code at L173 shows `WidgetsBinding.instance.buildOwner!._globalKeyRegistry[this]`; key.dart is in foundation layer which should not depend on widgets.

- statement: The guard `_globalKeyRegistry[key] == element` in _unregisterGlobalKey exists to prevent accidentally removing a GlobalKey that has been re-registered to a different element during reparenting error states.
  basis: L3198: `if (_globalKeyRegistry[key] == element)` — only removes when the element matches. Without this, an error path could leave the registry in inconsistent state.

- statement: Reparenting fails silently across frames because finalizeTree unmounts all inactive elements at end of frame.
  basis: L3344: `_inactiveElements._unmountAll` runs in finalizeTree at end of every frame. If the new position appears in the next frame, the element is already defunct.

## Retrieval Hints
- If asked "How does GlobalKey.currentState work?", start from [GlobalKey.currentState at framework.dart L196](../../lib/src/widgets/framework.dart#L196).
- If asked "How does GlobalKey reparenting work?", start from [_retakeInactiveElement at framework.dart L4481](../../lib/src/widgets/framework.dart#L4481).
- If asked "When are GlobalKeys registered/unregistered?", trace [Element.mount at L4355](../../lib/src/widgets/framework.dart#L4355) and [Element.unmount at L4858](../../lib/src/widgets/framework.dart#L4858).
- If asked "How does Flutter detect duplicate GlobalKeys?", start from [finalizeTree at L3345](../../lib/src/widgets/framework.dart#L3345).
- If asked "Where is the GlobalKey registry stored?", see [BuildOwner._globalKeyRegistry at L3148](../../lib/src/widgets/framework.dart#L3148).
- If asked "What's the difference between GlobalKey and LocalKey?", see [key.dart](../../lib/src/foundation/key.dart) for LocalKey and [framework.dart L159](../../lib/src/widgets/framework.dart#L159) for GlobalKey.
