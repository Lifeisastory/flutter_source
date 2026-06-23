# GlobalKey 实现分析

## 1. 分析范围

- **本次只分析**：GlobalKey 的类型定义、全局注册表机制、元素生命周期中的注册/注销流程、跨树元素重定父（reparenting）机制、以及调试模式下的重复检测与安全校验。
- **不覆盖**：LocalKey / ValueKey / ObjectKey / UniqueKey 的具体差异细节（仅作为类型层次概述）；GlobalKey 在 Material / Cupertino 具体组件中的使用模式；GlobalKey 与 Navigator / Form 等特定子系统的交互（这些属于上层应用分析）。
- **项目总体索引入口**：[ARCHITECTURE.en.md](../ARCHITECTURE.en.md)

## 2. 功能概览

GlobalKey 是 Flutter 中唯一跨整个应用唯一的 Key 类型。它有三个核心能力：

1. **全局唯一标识**：在整个 Widget 树中，同一个 GlobalKey 只能与一个 Element 绑定。
2. **跨树访问**：通过 `currentState` / `currentContext` / `currentWidget` getter，可以从树外直接访问与 GlobalKey 关联的 Element 及其 State 对象。
3. **子树重定父（Reparenting）**：当持有相同 GlobalKey 的 Widget 在同一帧内从一个位置移动到另一个位置时，框架会自动将该 Widget 对应的整个 Element 子树从旧父节点迁移到新父节点，而不会销毁重建。

## 3. 关键源码入口

| 文件                                                | 符号                                            | 作用                                            |
| --------------------------------------------------- | ----------------------------------------------- | ----------------------------------------------- |
| [framework.dart](../../lib/src/widgets/framework.dart) | `GlobalKey<T>` (L159)                         | GlobalKey 抽象类定义及 registry 查询            |
| [framework.dart](../../lib/src/widgets/framework.dart) | `LabeledGlobalKey<T>` (L203)                  | 带调试标签的 GlobalKey 实现（factory 默认创建） |
| [framework.dart](../../lib/src/widgets/framework.dart) | `GlobalObjectKey<T>` (L245)                   | 基于对象 `identical` 判等的 GlobalKey         |
| [framework.dart](../../lib/src/widgets/framework.dart) | `BuildOwner._globalKeyRegistry` (L3148)       | GlobalKey → Element 的全局映射表               |
| [framework.dart](../../lib/src/widgets/framework.dart) | `BuildOwner._registerGlobalKey` (L3178)       | 注册 GlobalKey 到全局表                         |
| [framework.dart](../../lib/src/widgets/framework.dart) | `BuildOwner._unregisterGlobalKey` (L3190)     | 从全局表注销 GlobalKey                          |
| [framework.dart](../../lib/src/widgets/framework.dart) | `Element.mount` (L4355)                       | 元素挂载时调用注册                              |
| [framework.dart](../../lib/src/widgets/framework.dart) | `Element.unmount` (L4858)                     | 元素卸载时调用注销                              |
| [framework.dart](../../lib/src/widgets/framework.dart) | `Element._retakeInactiveElement` (L4481)      | GlobalKey 重定父核心逻辑：从旧父抢夺元素        |
| [framework.dart](../../lib/src/widgets/framework.dart) | `Element.inflateWidget` (L4560)               | 创建/复用元素入口，触发 GlobalKey 重定父        |
| [framework.dart](../../lib/src/widgets/framework.dart) | `Element._activateWithParent` (L4717)         | 将被抢夺的元素重新激活到新父节点下              |
| [framework.dart](../../lib/src/widgets/framework.dart) | `_InactiveElements` (L2099)                   | 非活跃元素集合管理                              |
| [framework.dart](../../lib/src/widgets/framework.dart) | `BuildOwner.finalizeTree` (L3335)             | 帧末清理，包含 GlobalKey 重复检测               |
| [key.dart](../../lib/src/foundation/key.dart)          | `Key` (L30)                                   | Key 基类，工厂构造创建 ValueKey`<String>`     |
| [key.dart](../../lib/src/foundation/key.dart)          | `LocalKey` (L54)                              | 非全局 Key 的抽象基类                           |
| [debug.dart](../../lib/src/widgets/debug.dart)         | `debugPrintGlobalKeyedWidgetLifecycle` (L107) | 控制 GlobalKey 生命周期日志开关                 |

## 4. 主流程详解

### 4.1 起点：Key 类型层次

[`key.dart`](../../lib/src/foundation/key.dart) 定义了 Key 的基类体系：

```
Key (abstract, factory → ValueKey<String>)
├── LocalKey (abstract)
│   ├── ValueKey<T>     —— 基于值判等
│   ├── ObjectKey       —— 基于 identityHashCode 判等
│   └── UniqueKey       —— 每个实例唯一（禁用 const）
└── GlobalKey<T>        —— 在 framework.dart 中定义
    ├── LabeledGlobalKey<T>  —— factory 默认产物
    └── GlobalObjectKey<T>   —— 基于 identical 判等
```

关键设计点：

- `Key` 的 factory 构造器 `Key(String value)` 产出 `ValueKey<String>`，这是最简单的用法。
- **GlobalKey 本身是抽象类**，`GlobalKey({debugLabel})` factory 实际创建的是 `LabeledGlobalKey<T>`。
- GlobalKey 的相等性默认使用**对象标识**（Dart 默认 `==`），即同一个 Dart 对象实例才相等。`GlobalObjectKey` 是个例外——它基于 `identical` 对 value 进行判等，允许多个 `GlobalObjectKey` 实例共享同一 identity。

### 4.2 核心：全局注册表（GlobalKey Registry）

BuildOwner 维护一个核心数据结构：

```dart
// framework.dart L3148
final Map<GlobalKey, Element> _globalKeyRegistry = <GlobalKey, Element>{};
```

这是一个 `Map<GlobalKey, Element>` —— 每个 GlobalKey 最多映射到一个 Element。所有 GlobalKey 的查询和竞争都通过这个 map 进行。

GlobalKey 的 `_currentElement` getter（L173）直接读取这个 map：

```dart
Element? get _currentElement => WidgetsBinding.instance.buildOwner!._globalKeyRegistry[this];
```

而 `currentContext`、`currentWidget`、`currentState` 都间接依赖 `_currentElement`：

- `currentContext` → `_currentElement`（返回 Element，Element implements BuildContext）
- `currentWidget` → `_currentElement?.widget`
- `currentState` → 通过 Dart 3 的模式匹配，只有当 `_currentElement` 是 `StatefulElement` 且其 State 类型匹配 `T` 时才返回 State，否则返回 `null`

### 4.3 注册与注销：GlobalKey 的完整生命周期

GlobalKey 与 Element 的绑定/解绑贯穿 Element 的整个生命周期：

```
Element 创建
  │
  ├─ inflateWidget (L4560)
  │    │  检查 newWidget.key 是否为 GlobalKey
  │    │  若是，先尝试 _retakeInactiveElement (可能重用已有 Element)
  │    │
  │    ├─ 找到可重用 Element → _activateWithParent → updateChild
  │    └─ 未找到 → newWidget.createElement() → mount
  │
  ▼
Element.mount (L4355)
  │  if (key is GlobalKey) → owner!._registerGlobalKey(key, this)
  │  将 (key, this) 写入 _globalKeyRegistry
  │
  ▼
Element 处于 active 状态（正常工作）
  │  GlobalKey._currentElement 可查询到
  │
  ▼
Element.deactivate (父节点 rebuild 不再需要该 child，或 reparenting 被抢夺)
  │  注意：deactivate 不注销 GlobalKey！只是将元素标记为 inactive
  │  元素被添加到 _InactiveElements
  │
  ├─ 情况 A：在同一帧内被新的 GlobalKey 引用触发 _retakeInactiveElement
  │     │  从 _InactiveElements 中移除
  │     │  _activateWithParent → 绑定到新父节点
  │     │  保持 _globalKeyRegistry 中的映射不变
  │     └─ 元素回到 active 状态
  │
  └─ 情况 B：帧末 finalizeTree 时仍在 _InactiveElements 中
        │  _InactiveElements._unmountAll → Element.unmount
        │  Element.unmount (L4858):
        │    if (key is GlobalKey) → owner!._unregisterGlobalKey(key, this)
        │    从 _globalKeyRegistry 中移除
        └─ Element 进入 defunct 状态（不可逆）
```

**关键洞察**：

- **注册发生在 `mount`**：元素首次挂载或从 inactive 重新激活（`_activateWithParent` → `_activateRecursively` → `activate`）时，`activate` 不重新注册 GlobalKey，因为注册表映射在 deactivate 期间保持不变。
- **注销发生在 `unmount`**：只有当元素真正被销毁（进入 defunct）时才注销。
- **inactive 状态保留 GlobalKey 绑定**：这是 reparenting 机制能工作的基础——被 deactivate 的元素虽然不在活跃树中，但其 GlobalKey 映射仍然有效，新位置可以通过查询注册表找到它。

### 4.4 核心机制：GlobalKey 重定父（Reparenting）

这是 GlobalKey 最复杂的机制。当同一个 GlobalKey 的 Widget 从旧位置消失并出现在新位置时（在同一帧内），框架执行以下步骤：

#### Step 1: inflateWidget 检测 GlobalKey

```dart
// framework.dart L4570
final Element? inactiveChild = key is GlobalKey
    ? _retakeInactiveElement(key, newWidget)
    : null;
```

当 `inflateWidget` 被调用时，它检查新 Widget 的 key 是否 GlobalKey。如果是，在创建新 Element 之前，先尝试抢夺已有的 Element。

#### Step 2: _retakeInactiveElement —— 抢夺逻辑

```dart
// framework.dart L4481
Element? _retakeInactiveElement(GlobalKey key, Widget newWidget) {
    final Element? element = key._currentElement;
    if (element == null) return null;             // ① 无已有元素
    if (!Widget.canUpdate(element.widget, newWidget))
      return null;                                // ② 类型不兼容
    final Element? parent = element._parent;
    if (parent != null) {
      // ③ 元素仍挂在旧父节点下
      if (parent == this) throw ...;             // 同一父节点的重复 GlobalKey 是错误
      parent.forgetChild(element);               // ④ 从旧父节点的子模型移除
      parent.deactivateChild(element);           // ⑤ 从旧父节点 detach 并移入 inactive
    }
    owner!._inactiveElements.remove(element);    // ⑥ 从 inactive 集合取出
    return element;
}
```

步骤详解：

- **①** 通过 `key._currentElement` 查询注册表。若为 null，说明没有已有的 Element 与之关联。
- **②** `Widget.canUpdate` 检查 oldWidget 和 newWidget 是否同 `runtimeType` 且 key 相同。GlobalKey 的 identity 比较保证这里的 key 相同。
- **③** 如果 element 仍有父节点（`_parent != null`），说明它还在旧位置的活跃树中。
- **④** `forgetChild(element)`：通知旧父节点"忘记"这个子节点。旧父节点在 debug 模式下记录到 `_debugForgottenChildrenWithGlobalKey`，用于后续重复检测。旧父节点在下次 `update` 时清除这些记录。
- **⑤** `deactivateChild(element)`：将 element 的 `_parent` 设为 null，detach 其 render object，并将其加入 `_InactiveElements`。
- **⑥** 立即从 `_InactiveElements` 中取回——element 只是"路过" inactive 集合。

步骤 ⑤ 和 ⑥ 之间，element 会被 `deactivateChild` 递归调用 `deactivate()`，触发 `State.deactivate()` 回调，并使其所有子节点也进入 inactive。

#### Step 3: _activateWithParent —— 绑定到新父节点

```dart
// framework.dart L4582
inactiveChild._activateWithParent(this, newSlot);
```

`_activateWithParent`（L4717）执行：

1. 设置 `_parent`、`_owner` 为新父节点
2. `_updateDepth` 递归更新深度
3. `_updateBuildScopeRecursively` 更新构建作用域
4. `_activateRecursively` 递归调用 `activate()`：
   - 生命周期状态改为 active
   - 清除依赖列表
   - `_updateInheritance()` 重新建立 InheritedWidget 依赖
   - 如果之前标记为 dirty，重新调度构建
   - 如果有依赖，标记需要重建
5. `attachRenderObject(newSlot)` —— 将 render object 挂载到新的渲染树位置

#### Step 4: updateChild —— 确保 Widget 同步

```dart
// framework.dart L4583
final Element? updatedChild = updateChild(inactiveChild, newWidget, newSlot);
```

`updateChild` 检测到 `Widget.canUpdate` 返回 true（已在 _retakeInactiveElement 中验证），所以直接调用 `child.update(newWidget)` 更新配置，不创建新 Element。

#### 时序总结

整个 reparenting 在同一帧内的时序：

```
帧 N 开始
  │
  旧父 rebuild → newWidget 列表不含原 GlobalKey widget
    └─ updateChild: child != null, newWidget == null
         └─ deactivateChild(element)
              └─ element._parent = null
              └─ element 加入 _InactiveElements
              └─ GlobalKey 注册表不变！
  │
  新父 rebuild → newWidget 列表含相同 GlobalKey widget
    └─ updateChild: child == null, newWidget != null
         └─ inflateWidget(newWidget, newSlot)
              ├─ _retakeInactiveElement(key, newWidget)
              │    ├─ key._currentElement → 找到 element（注册表中！）
              │    ├─ element._parent 为 null（已被旧父 deactivate）
              │    └─ 直接从 _InactiveElements 取出
              └─ _activateWithParent → 绑定到新父
  │
  finalizeTree
    └─ _unmountAll → 清理未被重用的 inactive 元素
```

**推断**：如果旧父在新父之前 rebuild，reparenting 路径是"旧父 deactivate → 新父 retake → 激活"。如果新父先 rebuild，`_retakeInactiveElement` 中 element 仍有 `_parent`（第 ③ 步），则会主动调用 `parent.forgetChild` + `parent.deactivateChild`，结果相同。

### 4.5 帧末清理：finalizeTree

[`BuildOwner.finalizeTree`](../../lib/src/widgets/framework.dart#L3335) 在每帧 widget 构建阶段结束后被调用（由 `WidgetsBinding.drawFrame` 触发）：

1. **`_inactiveElements._unmountAll()`**：按深度排序（从深到浅），递归 unmount 所有未被重用的 inactive 元素。`unmount` 中执行 `_unregisterGlobalKey`。
2. **Debug 校验**（仅在 debug 模式）：
   - `_debugVerifyGlobalKeyReservation()`：检查是否有两个父节点同时声称拥有同一个 GlobalKey 的子节点
   - `_debugVerifyIllFatedPopulation()`：检查 `_globalKeyRegistry` 中是否存在同一 key 对应多个不同类型 Widget 的情况
   - 检查 `_debugElementsThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans`：检查被抢夺了子节点后未 rebuild 的父节点——如果父节点不知道子节点被移走，说明存在重复 GlobalKey

## 5. 关键实现细节

### 5.1 重要字段

| 字段                                                                          | 位置  | 说明                                                                                                 |
| ----------------------------------------------------------------------------- | ----- | ---------------------------------------------------------------------------------------------------- |
| `BuildOwner._globalKeyRegistry`                                             | L3148 | `Map<GlobalKey, Element>`，全局唯一的 key→element 映射                                            |
| `BuildOwner.globalKeyCount`                                                 | L3169 | 当前已注册 GlobalKey 数量                                                                            |
| `BuildOwner._debugIllFatedElements`                                         | L3153 | Debug 模式：记录被覆盖注册的旧 Element                                                               |
| `BuildOwner._debugGlobalKeyReservations`                                    | L3163 | Debug 模式：`Map<父Element, Map<子Element, GlobalKey>>`，追踪每个父节点对子节点 GlobalKey 的"预留" |
| `BuildOwner._debugElementsThatWillNeedToBeRebuiltDueToGlobalKeyShenanigans` | L3131 | Debug 模式：记录因子节点被抢夺而需要 rebuild 的父节点                                                |
| `Element._debugForgottenChildrenWithGlobalKey`                              | L4685 | Debug 模式：记录被 forgetChild 的 GlobalKey 子节点                                                   |
| `_InactiveElements._elements`                                               | L2101 | `HashSet<Element>`，存储所有 inactive 状态的元素                                                   |
| `_InactiveElements._locked`                                                 | L2100 | 防止在 unmountAll 期间修改集合                                                                       |

### 5.2 重要条件分支

- **`Widget.canUpdate` 守卫**（L4493）：`_retakeInactiveElement` 中，只有 oldWidget 和 newWidget 类型兼容时才允许重用。不兼容则返回 null，走创建新 Element 路径。
- **`_parent` 为空判断**（L4505）：如果 element 的 `_parent != null`，说明它仍在旧父节点下，需要主动抢夺（forgetChild + deactivateChild）；如果 `_parent == null`，说明已经在 inactive 列表中了。
- **`parent == this` 检测**（L4506）：同一个父节点下同时出现两个相同 GlobalKey 的 widget 是严重错误，直接抛异常。
- **unmount 中的安全守卫**（L3198）：`_unregisterGlobalKey` 中 `_globalKeyRegistry[key] == element` 的检查防止在异常状态下错误注销其他 element 的 key。

### 5.3 集合、缓存、注册表

| 数据结构                                 | 生命周期                   | 用途                                    |
| ---------------------------------------- | -------------------------- | --------------------------------------- |
| `_globalKeyRegistry`                   | BuildOwner 生命周期        | 核心映射：key → element                |
| `_InactiveElements._elements`          | 每帧 reset                 | 暂存被 deactivate 但尚未 unmount 的元素 |
| `_debugGlobalKeyReservations`          | 每帧 clear（finalizeTree） | 调试用：检测重复 key                    |
| `_debugForgottenChildrenWithGlobalKey` | 父节点 update 时 clear     | 调试用：追踪被抢夺的子节点              |

### 5.4 为什么这样设计

1. **GlobalKey 定义在 framework.dart 而非 key.dart**：因为 GlobalKey 需要访问 `WidgetsBinding.instance.buildOwner!._globalKeyRegistry`，这引入了对 widgets 层的依赖。key.dart 位于 foundation 层，不应依赖 widgets 层。
2. **inactive 状态保留 GlobalKey 映射**：如果 deactivate 时立即注销 key，那么当新位置尝试通过 GlobalKey 查找 element 时就会失败，必须创建新 Element 并重建整个子树。保留映射使得 reparenting 成为可能。
3. **_InactiveElements 作为中间缓冲**：不是所有 deactivate 的元素都会被 reparent。有些是真的不再需要了。_InactiveElements 提供了"宽限期"——在帧末统一清理，使得 reparenting 在同一帧内有机会发生。
4. **debug 模式的多重校验**：由于 GlobalKey 重复是一个常见且难调试的问题，debug 模式提供了三层检测：reservation 检测（同一父节点不同子节点用同一 key）、illFated 检测（注册表覆盖）、以及 shenanigans 检测（被抢夺后父节点未重建）。

## 6. 相关文件关系

### 主路径文件

| 文件                                                | 角色                                                                                      |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| [framework.dart](../../lib/src/widgets/framework.dart) | **核心**：GlobalKey 定义、BuildOwner 注册表、Element 生命周期集成、reparenting 逻辑 |
| [key.dart](../../lib/src/foundation/key.dart)          | **支撑**：Key / LocalKey / ValueKey / ObjectKey / UniqueKey 基类层次                |

### 支撑文件（非主路径）

| 文件                                            | 角色                                                                                 |
| ----------------------------------------------- | ------------------------------------------------------------------------------------ |
| [debug.dart](../../lib/src/widgets/debug.dart)     | 定义 `debugPrintGlobalKeyedWidgetLifecycle` 调试开关                               |
| [binding.dart](../../lib/src/widgets/binding.dart) | `WidgetsFlutterBinding` 持有 `BuildOwner` 实例，是 `_globalKeyRegistry` 的宿主 |

## 7. 时序总结

**GlobalKey 从创建到销毁的完整链路**（共 10 步）：

1. 开发者创建 `GlobalKey<T>()` → 实际得到 `LabeledGlobalKey<T>` 实例
2. 将该 key 赋值给某个 Widget 的 `key` 属性
3. 父 Element rebuild 时，`inflateWidget` 检测到 key 是 GlobalKey
4. `_retakeInactiveElement` 查询 `_globalKeyRegistry` —— 首次使用返回 null
5. 创建新 Element，调用 `element.mount(this, newSlot)`
6. `mount` 中：`owner!._registerGlobalKey(key, this)` → key 写入注册表
7. `currentState` / `currentContext` / `currentWidget` 现在可以访问
8. 当 Widget 树变化，元素被 `deactivateChild` 移入 `_InactiveElements`
9. **分岔**：
   - 若同帧内新位置引用相同 GlobalKey → `_retakeInactiveElement` 抢夺 → `_activateWithParent` 激活 → 保持注册表映射
   - 若帧末仍 inactive → `finalizeTree` → `_unmountAll` → `unmount` → `_unregisterGlobalKey` → 元素 defunct
10. 开发者丢弃 GlobalKey 引用或元素最终 defunct → GC 回收

## 8. 边界情况与注意点

| 情况                                              | 行为                                                                                                                         |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **同一父节点下重复 GlobalKey**              | 抛出 `FlutterError`：`"A GlobalKey was used multiple times inside one widget's child list."`                             |
| **不同父节点下重复 GlobalKey**              | Debug 模式抛出异常；release 模式行为未定义（第一个注册的可能会被覆盖）                                                       |
| **新 Widget 类型与旧 Element 不兼容**       | `_retakeInactiveElement` 返回 null，旧 Element 被 unmount，创建新 Element                                                  |
| **GlobalKey 在 build 中重新创建**           | 每次 rebuild 获得不同的 Dart 对象实例，旧 key 对应的 Element 被标记为 inactive 并在帧末销毁，子树状态丢失                    |
| **跨帧 reparenting**                        | **不工作**——旧元素在帧末 finalizeTree 时被 unmount，下一帧新位置创建全新 Element                                     |
| **GlobalKey 查询时 BuildOwner 未初始化**    | `WidgetsBinding.instance.buildOwner` 可能为 null（在 `runApp` 之前），需要 `WidgetsFlutterBinding.ensureInitialized()` |
| **非 StatefulWidget 使用 `GlobalKey<T>`** | `currentState` 返回 null（不是 StatefulElement），但 `currentContext` 和 `currentWidget` 仍可用                        |
| **renderObject.attached 为 false 的父节点** | `_debugVerifyGlobalKeyReservation` 跳过这类父节点的检测                                                                    |

### 易误解点

- **GlobalKey 的相等性基于对象标识**：`GlobalKey()` 每次调用创建不同的对象实例。如果将其放在 build 方法中，每次 rebuild 都会创建新 key。
- **deactivate 不注销 GlobalKey**：这是一个常见的误解。GlobalKey 只在 `unmount` 时注销。
- **reparenting 必须在同一帧内**：跨帧的移动不会触发 reparenting，旧元素会被销毁。

### 推断（未经确认）

- **推断**：当 `GlobalObjectKey` 与普通的 `GlobalKey` 混合使用时，如果它们碰巧通过不同的 `value` 对象，则不会冲突；但由于 GlobalKey 默认使用 identity 判等，`GlobalObjectKey` 的语义需要开发者自行保证 value 对象的 identity 在整个应用生命周期内的正确性。

## 9. 关键证据

- GlobalKey 类定义：[framework.dart L159](../../lib/src/widgets/framework.dart#L159)
- `_currentElement` getter 读取注册表：[framework.dart L173](../../lib/src/widgets/framework.dart#L173)
- `_globalKeyRegistry` 字段：[framework.dart L3148](../../lib/src/widgets/framework.dart#L3148)
- `_registerGlobalKey`：[framework.dart L3178](../../lib/src/widgets/framework.dart#L3178)
- `_unregisterGlobalKey`：[framework.dart L3190](../../lib/src/widgets/framework.dart#L3190)
- `Element.mount` 中注册 key：[framework.dart L4355](../../lib/src/widgets/framework.dart#L4355)
- `Element.unmount` 中注销 key：[framework.dart L4858](../../lib/src/widgets/framework.dart#L4858)
- `_retakeInactiveElement` 核心逻辑：[framework.dart L4481](../../lib/src/widgets/framework.dart#L4481)
- `inflateWidget` 调用 retake：[framework.dart L4571](../../lib/src/widgets/framework.dart#L4571)
- `_activateWithParent`：[framework.dart L4717](../../lib/src/widgets/framework.dart#L4717)
- `deactivateChild` 将元素加入 inactive：[framework.dart L4625](../../lib/src/widgets/framework.dart#L4625)
- `finalizeTree` 帧末清理：[framework.dart L3335](../../lib/src/widgets/framework.dart#L3335)
- `_InactiveElements` 类：[framework.dart L2099](../../lib/src/widgets/framework.dart#L2099)
- `Key` 基类：[key.dart L30](../../lib/src/foundation/key.dart#L30)
- `LocalKey`：[key.dart L54](../../lib/src/foundation/key.dart#L54)
- `debugPrintGlobalKeyedWidgetLifecycle`：[debug.dart L107](../../lib/src/widgets/debug.dart#L107)
