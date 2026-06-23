# Overlay 实现分析

## 1. 分析范围

- **本次只分析**：Overlay / OverlayState / OverlayEntry 的经典 API、_Theater 渲染机制（onstage/offstage 优化）、OverlayPortal 的 InheritedWidget 架构、OverlayEntry.remove 在不同调度阶段的处理、Overlay.of 的查找链路。
- **不覆盖**：OverlayPortal.overlayChildLayoutBuilder 的 layout callback 细节（偏向渲染层）、Navigator / Route 如何使用 Overlay（属于 navigator 分析范畴）、MaterialApp/CupertinoApp 中 Overlay 的创建位置。
- **项目总体索引入口**：[ARCHITECTURE.en.md](../ARCHITECTURE.en.md)

## 2. 功能概览

Overlay 是 Flutter 中用于管理「浮动层」Widget 的栈式容器。它允许独立 Widget 通过 `OverlayEntry` 将内容插入到一个 Stack 布局中，浮在其他内容之上。典型使用场景包括：

1. **路由管理**：Navigator 使用 Overlay 管理 Route 页面及其过渡动画。
2. **弹窗/对话框**：`showDialog`、`showMenu` 等将内容插入 Overlay 实现浮层。
3. **拖拽跟随**：`Draggable` 通过 OverlayEntry 显示跟随手指的拖拽形象。
4. **工具提示**：`Tooltip`、`OverlayPortal` 将提示内容渲染在 Overlay 上。

Overlay 提供两套 API：
- **经典 API**（OverlayEntry + OverlayState.insert/remove）：手动管理 Entry 的生命周期。
- **现代 API**（OverlayPortal + OverlayPortalController）：基于 InheritedWidget 的声明式接口，overlay child 可以访问 OverlayPortal 所在子树的 InheritedWidget。

## 3. 关键源码入口

| 文件 | 符号 | 作用 |
|------|------|------|
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `OverlayEntry` | 经典 API 的 Entry，携带 builder、opaque/maintainState 等属性 |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `Overlay` | StatefulWidget，Overlay 的配置入口 |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `OverlayState` | Overlay 的 State，持有 `_entries` 列表，提供 insert/insertAll/rearrange |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `_Theater` | MultiChildRenderObjectWidget，Overlay 的内部渲染 Widget |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `_RenderTheater` | 自定义 Stack RenderBox，支持 skipCount 的 onstage/offstage 优化 |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `OverlayPortal` | 现代 API 的入口 Widget |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `OverlayPortalController` | 控制 OverlayPortal 的显示/隐藏/z-order |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `_OverlayEntryLocation` | LinkedListEntry，确定 OverlayPortal child 在 _RenderTheater 中的位置 |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `_RenderTheaterMarker` | InheritedWidget，让 OverlayPortal 查找目标 _RenderTheater |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `_RenderDeferredLayoutBox` | 延迟布局 RenderBox，确保 OverlayPortal child 不被重复 layout |
| [overlay.dart](../../lib/src/widgets/overlay.dart) | `_OverlayEntryWidget` / `_OverlayEntryWidgetState` | 包装单个 OverlayEntry 的 StatefulWidget |
| [binding.dart](../../lib/src/widgets/binding.dart) | `WidgetsBinding.drawFrame` | 触发 Overlay rebuild 和 finalizeTree 的帧驱动 |

## 4. 主流程详解

### 4.1 经典 API：OverlayEntry + OverlayState

#### OverlayEntry 的属性

`OverlayEntry` 是一个 `Listenable`，它的核心属性决定了 Overlay 如何对待它：

```dart
// packages/flutter/lib/src/widgets/overlay.dart

class OverlayEntry implements Listenable {
  OverlayEntry({
    required this.builder,
    bool opaque = false,
    bool maintainState = false,
    this.canSizeOverlay = false,
  });
  final WidgetBuilder builder;
  bool get opaque => _opaque;         // 是否完全不透明
  bool get maintainState => _maintainState;  // 被遮挡时是否仍保持 State
  final bool canSizeOverlay;          // 是否可用于确定 Overlay 尺寸
  OverlayState? _overlay;             // 所属 Overlay
  final GlobalKey<_OverlayEntryWidgetState> _key = GlobalKey();
}
```

- **opaque**：当设为 true，Overlay 会跳过其下方所有 Entry 的构建（除非它们设置了 maintainState）。这是性能优化的关键机制。
- **maintainState**：即使被 opaque 的 Entry 遮挡，此 Entry 仍然保留在 Widget 树中（但 Ticker 被禁用）。这是 Navigator 保留后台 Route 状态的机制。
- **canSizeOverlay**：当 Overlay 接收无限约束时，使用此 Entry 来确定 Overlay 的尺寸。

#### OverlayState：Entry 的管理者

```dart
// packages/flutter/lib/src/widgets/overlay.dart

class OverlayState extends State<Overlay> with TickerProviderStateMixin {
  final List<OverlayEntry> _entries = <OverlayEntry>[];

  void insert(OverlayEntry entry, {OverlayEntry? below, OverlayEntry? above}) {
    entry._overlay = this;
    setState(() {
      _entries.insert(_insertionIndex(below, above), entry);
    });
  }

  void insertAll(Iterable<OverlayEntry> entries, {...}) { ... }

  void rearrange(Iterable<OverlayEntry> newEntries, {...}) { ... }
}
```

`_entries` 是一个有序列表，列表越靠后表示渲染越靠前（更接近用户）。`insert` 支持 `above` 和 `below` 参数精确控制插入位置。

**`_insertionIndex` 的位置计算**：

```dart
int _insertionIndex(OverlayEntry? below, OverlayEntry? above) {
  assert(above == null || below == null);
  if (below != null) return _entries.indexOf(below);
  if (above != null) return _entries.indexOf(above) + 1;
  return _entries.length;  // 默认插到最顶层
}
```

#### OverlayState.build：生成 _Theater 的优化逻辑

```dart
@override
Widget build(BuildContext context) {
  final children = <_OverlayEntryWidget>[];
  var onstage = true;
  var onstageCount = 0;
  for (final OverlayEntry entry in _entries.reversed) {
    if (onstage) {
      onstageCount += 1;
      children.add(_OverlayEntryWidget(
        key: entry._key, overlayState: this, entry: entry,
      ));
      if (entry.opaque) {
        onstage = false;  // 从此处开始，下面的 Entry 不再 onstage
      }
    } else if (entry.maintainState) {
      children.add(_OverlayEntryWidget(
        key: entry._key, overlayState: this, entry: entry,
        tickerEnabled: false,  // 禁用 Ticker，避免无谓驱动
      ));
    }
  }
  return _Theater(
    skipCount: children.length - onstageCount,
    children: children.reversed.toList(growable: false),
  );
}
```

这个 build 方法包含了两个重要的优化：

1. **opaque 裁剪**：从栈顶向下遍历（`_entries.reversed`），遇到第一个 opaque 的 Entry 后，后续 Entry 不再出现在 onstage 区域，也不会被构建（除非 maintainState）。

2. **skipCount 分离**：`_Theater` 接收一个 `skipCount` 参数。前 `skipCount` 个 children 被认为是 offstage 的——它们存在于 Widget 树中但不参与 layout 和 paint。这样 maintainState 的 Entry 虽然保留但不会渲染。

### 4.2 _Theater：自定义栈渲染

Overlay 没有直接使用 `Stack` 或 `IndexedStack`，而是使用了一个自定义的 RenderObject——`_RenderTheater`。

```dart
// packages/flutter/lib/src/widgets/overlay.dart

class _Theater extends MultiChildRenderObjectWidget {
  const _Theater({
    this.skipCount = 0,
    this.clipBehavior = Clip.hardEdge,
    required List<_OverlayEntryWidget> super.children,
  });
}
```

`_RenderTheater` 使用 Stack 布局算法（通过 `_RenderTheaterMixin` mixin），但核心区别在于它对「onstage」和「offstage」子节点的处理：

```dart
RenderBox? get _firstOnstageChild {
  if (skipCount == super.childCount) return null;
  RenderBox? child = super.firstChild;
  for (int toSkip = skipCount; toSkip > 0; toSkip--) {
    child = child!.parentData!.nextSibling;
  }
  return child;
}
```

在 `performLayout` 中，只有 onstage 的子节点参与布局和尺寸计算。offstage 子节点的 RenderObject 虽然有 parentData 但不会被 layout。

**无限约束下的尺寸确定**：

```dart
void performLayout() {
  if (constraints.biggest.isFinite) {
    size = constraints.biggest;  // 正常情况：充满约束
  } else {
    sizeDeterminingChild = _findSizeDeterminingChild();  // 找到 canSizeOverlay 的 child
    layoutChild(sizeDeterminingChild, constraints);
    size = sizeDeterminingChild.size;
  }
  // 对其他 onstage 子节点，使用 tight(size) 约束
  for (final child in _childrenInPaintOrder()) {
    if (child != sizeDeterminingChild) {
      layoutChild(child, BoxConstraints.tight(size));
    }
  }
}

RenderBox _findSizeDeterminingChild() {
  // 从栈顶向下找到第一个 canSizeOverlay=true 的非 Positioned 子节点
  RenderBox? child = _lastOnstageChild;
  while (child != null) {
    if ((childParentData.overlayEntry?.canSizeOverlay ?? false) &&
        !childParentData.isPositioned) {
      return child;
    }
    child = childParentData.previousSibling;
  }
  throw FlutterError('...cannot be sized by a suitable child.');
}
```

### 4.3 OverlayEntry.remove() 的调度敏感性

`OverlayEntry.remove()` 有一个精妙的细节——它在 `persistentCallbacks` 阶段有不同的处理：

```dart
void remove() {
  assert(_overlay != null);
  final OverlayState overlay = _overlay!;
  _overlay = null;
  if (!overlay.mounted) return;

  overlay._entries.remove(this);
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    // 如果当前正在 layout/paint 阶段，延迟 markDirty 到 post-frame
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      overlay._markDirty();
    });
  } else {
    overlay._markDirty();
  }
}
```

**为什么需要这个判断？** `SchedulerPhase.persistentCallbacks` 是 `WidgetsBinding.drawFrame` 调用 `super.drawFrame()` 时（layout → paint）所处的阶段。如果在这个阶段直接调用 `setState`（`_markDirty` 内部），会触发 build 阶段的 setState 检查失败。因此延迟到 `addPostFrameCallback` 执行。

### 4.4 Overlay.of 的查找链路

```dart
static OverlayState of(BuildContext context, {bool rootOverlay = false, ...}) {
  final OverlayState? result = maybeOf(context, rootOverlay: rootOverlay);
  // debug 模式下抛详细异常
  return result!;
}

static OverlayState? maybeOf(BuildContext context, {bool rootOverlay = false}) {
  return _RenderTheaterMarker.maybeOf(
    context,
    targetRootOverlay: rootOverlay,
    createDependency: false,
  )?.overlayEntryWidgetState.widget.overlayState;
}
```

Overlay.of 实际上通过 `_RenderTheaterMarker`（一个 InheritedWidget）来查找 Overlay。查找链路：

```
Overlay.of(context)
  → Overlay.maybeOf(context)
    → _RenderTheaterMarker.maybeOf(context)
      → LookupBoundary.dependOnInheritedWidgetOfExactType<_RenderTheaterMarker>(context)
        → 遍历 ancestor 找到最近的 _RenderTheaterMarker
          → .overlayEntryWidgetState.widget.overlayState
```

`_RenderTheaterMarker` 是由每个 `_OverlayEntryWidget` 的 build 方法注入的：

```dart
// _OverlayEntryWidgetState.build
Widget build(BuildContext context) {
  return TickerMode(
    enabled: widget.tickerEnabled,
    child: _RenderTheaterMarker(
      theater: _theater,
      overlayEntryWidgetState: this,
      child: Builder(builder: widget.entry.builder),
    ),
  );
}
```

这意味着 `Overlay.of` 查找的是**当前 Entry 所在**的 Overlay——即该 Entry 是通过哪个 Overlay 的 OverlayState.insert 插入的。

`rootOverlay` 参数通过 `LookupBoundary` 的 `visitAncestorElements` 递归查找最远的 `_RenderTheaterMarker`，这在 Navigator 的 route overlay 嵌套中很常用——比如 `showDialog(rootOverlay: true)` 确保对话框显示在最外层 Overlay 上。

### 4.5 OverlayPortal：现代声明式 API

`OverlayPortal` 解决了经典 API 的主要痛点：OverlayEntry 的 builder 构建在 Entry 所在的子树上，无法访问 `OverlayPortal` 周围子树的 InheritedWidget（如 Theme、MediaQuery）。

#### 架构概览

```
OverlayPortal (StatefulWidget)
  ├── controller: OverlayPortalController
  ├── overlayChildBuilder: WidgetBuilder  → 渲染到祖先 Overlay 上
  └── child: Widget?                     → 正常渲染在父 Widget 树中
```

其实现的 render tree 结构：

```
Render Tree:
  _RenderTheater (祖先 Overlay 的 Render Box)
    ├── _TheaterParentData[0] → _OverlayEntryWidget N 的 RenderBox
    │     └── (overlayEntry.paintOrderIterator → OverlayPortal children)
    ├── _TheaterParentData[1] → _OverlayEntryWidget N+1 的 RenderBox
    │     └── (OverlayPortal overlayChild RenderBox 在此)
    └── ...
```

#### OverlayPortalController：z-order 时间戳

```dart
class OverlayPortalController {
  void show() {
    if (state != null) {
      state.show(_now());  // 全局单调递增的时间戳作为 z-order
    } else {
      _zOrderIndex = _now();
    }
  }

  void hide() { ... }
  bool get isShowing { ... }
  void toggle() => isShowing ? hide() : show();
}

int _now() {
  return _wallTime += 1;  // 每次调用 +1，全局唯一
}
```

z-order 使用一个全局单调递增的 `_wallTime` 计数器。每次调用 `show()` 都会获得一个比之前更大的时间戳，保证最近显示的 OverlayPortal 在最顶层。这也体现了 `show()` 的「bring-to-top」语义——即使 `isShowing` 已经是 true，调用 `show()` 会将 overlay child 提升到最顶层。

#### _OverlayEntryLocation：在 _RenderTheater 子模型中的定位

`_OverlayEntryLocation` 是一个 `LinkedListEntry`，它指向特定 `_RenderTheater` 中特定 `_OverlayEntryWidgetState` 子模型中的特定位置：

```dart
final class _OverlayEntryLocation extends LinkedListEntry<_OverlayEntryLocation> {
  _OverlayEntryLocation(this._zOrderIndex, this._childModel, this._theater);
  final int _zOrderIndex;                    // 排序依据
  final _OverlayEntryWidgetState _childModel; // 属于哪个 Entry 的子模型
  final _RenderTheater _theater;             // 属于哪个 Theater
}
```

它在 `_OverlayEntryWidgetState` 的 `_sortedTheaterSiblings` 链表中按 `_zOrderIndex` 降序排列。这样每个 Entry 的下方可以挂载多个 OverlayPortal 的 overlay child，按调用 `show()` 的时间顺序排列。

#### _RenderDeferredLayoutBox：延迟 layout 机制

这是 OverlayPortal 实现中最精巧的部分。OverlayPortal 的 overlay child 的 RenderBox 需要同时满足：

1. 作为 `_RenderTheater` 的子节点参与 Stack 布局。
2. 在 `_RenderLayoutSurrogateProxyBox`（OverlayPortal 自己的 RenderBox）完成 layout 之后才能 layout（因为它需要读取 layoutSurrogate 到 theater 之间的 paint transform）。

`_RenderDeferredLayoutBox` 通过以下方式解决这个问题：

```dart
// 核心思路：
// 1. 它是 relayout boundary
// 2. 当 _RenderTheater 对其调用 layout() 时，只做 resize（performResize），
//    不做 performLayout（由 _doingLayoutFromTreeWalk 标志跳过）
// 3. 相反，在 _layoutSurrogate 的 performLayout 中重新将它加入 dirty list
//    由于它的 depth 更大，会在 theater 和 layoutSurrogate 之后被 layout
```

```dart
void performLayout() {
  if (_doingLayoutFromTreeWalk) {
    _needsLayout = false;  // 被 theater 调用时跳过
    return;
  }
  // 被 PipelineOwner.flushLayout 调用时才真正 layout
  final RenderBox? child = this.child;
  if (child != null) {
    layoutChild(child, constraints);
  }
  _needsLayout = false;
}
```

这个设计确保了 OverlayPortal 的 overlay child 在 layout 时总能读到已完成的 paint transform。

## 5. 相关文件关系

### 主路径文件

| 文件 | 角色 |
|------|------|
| [overlay.dart](../../lib/src/widgets/overlay.dart) (2868 行) | **全部核心代码**：OverlayEntry、Overlay、OverlayState、_Theater、_RenderTheater、OverlayPortal |

### 支撑文件（非主路径）

| 文件 | 角色 |
|------|------|
| [framework.dart](../../lib/src/widgets/framework.dart) | StatefulWidget / State 基类、GlobalKey 机制 |
| [basic.dart](../../lib/src/widgets/basic.dart) | Stack、Positioned 等基础布局组件 |
| [lookup_boundary.dart](../../lib/src/widgets/lookup_boundary.dart) | LookupBoundary（Overlay.of 依赖的查找边界） |
| [ticker_provider.dart](../../lib/src/widgets/ticker_provider.dart) | TickerProviderStateMixin（OverlayState 用到的） |
| [binding.dart](../../lib/src/widgets/binding.dart) | WidgetsBinding.drawFrame（触发 Overlay rebuild） |
| [scheduler.dart](../../lib/src/scheduler/binding.dart) | SchedulerPhase（remove() 的分支判断依据） |

## 6. 关键实现细节

### 6.1 opaque / maintainState 的状态变更传播

当 `opaque` 或 `maintainState` 属性被修改时：

```dart
set opaque(bool value) {
  if (_opaque == value) return;
  _opaque = value;
  _overlay?._didChangeEntryOpacity();  // 触发 OverlayState.setState
}

// OverlayState 中
void _didChangeEntryOpacity() {
  setState(() {});  // 强制 rebuild，重新计算 skipCount
}
```

`setState(() {})` 的注释也很诚实：「We use the opacity of the entry in our build function, which means our state has changed.」——因为 `build` 方法中使用 `entry.opaque` 来决定是否继续遍历后续 Entry，所以不透度的变化必须触发 rebuild。

### 6.2 markNeedsBuild 通过 GlobalKey 定位

```dart
void markNeedsBuild() {
  _key.currentState?._markNeedsBuild();
}

// _OverlayEntryWidgetState 中
void _markNeedsBuild() {
  setState(() { /* the state that changed is in the builder */ });
}
```

OverlayEntry 持有 `_OverlayEntryWidgetState` 的 GlobalKey，通过 `_key.currentState` 定位到 State 对象，然后触发 `setState`。这是一个典型的 GlobalKey 跨树调用场景——Entry 本身不在 Widget 树中，但需要触发其 Widget 的 rebuild。

### 6.3 dispose / _didUnmount 的分离

```dart
void dispose() {
  _disposedByOwner = true;
  if (!mounted) {
    _overlayEntryStateNotifier?.dispose();
    _overlayEntryStateNotifier = null;
  }
}

void _didUnmount() {
  if (_disposedByOwner) {
    _overlayEntryStateNotifier?.dispose();
    _overlayEntryStateNotifier = null;
  }
}
```

`dispose()` 由业务代码调用，`_didUnmount()` 在 Entry 的 Widget 从树中移除时由框架调用。如果 dispose 时 Widget 还在树中，则延迟到 Widget 真正 unmount 时释放 Notifier——这样 Listener 可以持续收到通知直到 Widget 移除。

### 6.4 rearrange 的算法

```dart
void rearrange(Iterable<OverlayEntry> newEntries, {OverlayEntry? below, OverlayEntry? above}) {
  // 1. 保存旧列表
  final old = LinkedHashSet<OverlayEntry>.of(_entries);
  // 2. 先放新 entries（按开发者的顺序）
  _entries.clear();
  _entries.addAll(newEntriesList);
  // 3. 从旧列表中移除新 entries
  old.removeAll(newEntriesList);
  // 4. 剩余旧 entries 插入到指定位置
  _entries.insertAll(_insertionIndex(below, above), old);
}
```

这个算法让开发者可以精确控制一组 Entry 的排列，而不需要逐个 remove/insert。Navigator 的 Route 管理重度依赖这个 API。

## 7. 时序总结

### 经典 API：插入 Entry 的完整流程

1. `OverlayEntryOverlayEntry()` 创建 Entry
2. `Overlay.of(context).insert(entry)` 或 `OverlayState.insert(entry)`
3. `entry._overlay = this`（绑定到 OverlayState）
4. `setState(() { _entries.insert(index, entry); })` 触发 rebuild
5. OverlayState.build 根据 opaque/maintainState 生成 `_OverlayEntryWidget` 列表
6. 每个 `_OverlayEntryWidget` 挂载到 Widget 树，`initState` 中设置 `entry._overlayEntryStateNotifier.value = this`
7. `_RenderTheater` 作为渲染根，执行 Stack 布局

### 经典 API：移除 Entry 的完整流程

1. `entry.remove()` 被调用
2. `entry._overlay` 设为 null
3. 从 `overlay._entries` 中移除
4. 根据 `SchedulerPhase` 决定立即或延迟调用 `_markDirty()`
5. OverlayState rebuild，Entry 对应的 `_OverlayEntryWidget` 不再构建
6. 旧 Widget 的 `_OverlayEntryWidgetState.dispose()` 被调用
7. `entry._overlayEntryStateNotifier.value = null`（通知 Listener）
8. `entry._didUnmount()` 被调用，如果已 disposed 则释放 Notifier

### OverlayPortal 显示流程

1. `controller.show()` 被调用 → 通过 `SchedulerBinding` 检查不在 persistentCallbacks 阶段
2. `_OverlayPortalState.show(zOrderIndex)` → `setState(() { _zOrderIndex = zOrderIndex; })`
3. `_OverlayPortalState.build()` 创建 `_OverlayPortal` Widget
4. `_OverlayPortalElement.mount/update` 调用 `insertRenderObjectChild`
5. `_OverlayEntryLocation._addChild` 将 RenderBox 加入 `_RenderTheater`
6. `_RenderDeferredLayoutBox` 通过延迟 layout 机制正确布局

## 8. 边界情况与注意点

| 情况 | 行为 |
|------|------|
| 在 persistentCallbacks 阶段 remove | 延迟到 postFrameCallback 执行 markDirty |
| 在 build 阶段插入/移除 | 直接调用 setState（合法） |
| after dispose 调用 remove | assert 失败 |
| 未 remove 就 dispose | assert 失败（`_overlay == null` 检查） |
| Overlay 已 unmount 后 remove | 直接返回（`if (!overlay.mounted) return;`） |
| 同一个 Entry 插入两个不同 Overlay | `_debugCanInsertEntry` 抛异常 |
| 同一个 Entry 重复插入同一 Overlay | `_debugCanInsertEntry` 抛异常 |
| 无限约束且无 canSizeOverlay child | `_findSizeDeterminingChild` 抛异常 |
| rootOverlay 查找 | 通过 `LookupBoundary` 递归到最远祖先 |

### 易误解点

- **Overlay 不是全局单例**：一个应用可以有多个 Overlay（每个 Navigator 创建一个），`Overlay.of(context)` 找到的是最近的祖先 Overlay。
- **opaque 只影响构建，不影响渲染**：opaque 是性能优化提示，不实际裁剪像素。clipBehavior 才控制像素裁剪。
- **overlayChildBuilder 在 layout 阶段被调用**（OverlayPortal.overlayChildLayoutBuilder）：这是唯一在 layout 阶段调用 builder 的机制，允许基于 overlayPortal child 的 paint transform 来构建 overlay child。

## 9. 关键证据

- OverlayEntry 类定义：`packages/flutter/lib/src/widgets/overlay.dart` 中的 `class OverlayEntry`
- opaque/maintainState setter 触发 `_didChangeEntryOpacity`：overlay.dart 中的 `set opaque` / `set maintainState`
- OverlayState._entries 列表：overlay.dart 中的 `final List<OverlayEntry> _entries`
- OverlayState.build 的 opaque skip 逻辑：overlay.dart 中的 `for (final OverlayEntry entry in _entries.reversed)`
- _Theater skipCount 机制：overlay.dart 中的 `class _Theater`
- _RenderTheater.performLayout 的 size-determining child：overlay.dart 中的 `_findSizeDeterminingChild`
- OverlayEntry.remove 的调度阶段判断：overlay.dart 中的 `SchedulerPhase.persistentCallbacks` 分支
- OverlayEntry.markNeedsBuild 通过 GlobalKey 通信：overlay.dart 中的 `_key.currentState?._markNeedsBuild()`
- _OverlayEntryWidgetState.build 注入 _RenderTheaterMarker：overlay.dart 中的 `_RenderTheaterMarker(theater: _theater, ...)`
- Overlay.of → maybeOf → _RenderTheaterMarker.maybeOf 链路：overlay.dart 中的 `static OverlayState? maybeOf`
- OverlayPortalController._now() 全局计数器：overlay.dart 中的 `static int _wallTime`
- _RenderDeferredLayoutBox 的延迟 layout：overlay.dart 中的 `_doingLayoutFromTreeWalk` 标志
- _OverlayEntryLocation._addChild / _removeChild：overlay.dart 中对 `_theater._addDeferredChild` / `_removeDeferredChild` 的调用
- rearrange 的旧列表合并算法：overlay.dart 中的 `final old = LinkedHashSet<OverlayEntry>.of(_entries)`
