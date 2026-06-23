# FLOW.md — Flutter 源码同步与开发工作流

## 仓库对应关系

```
本地 stable ──→ origin/stable ──→ upstream/stable
本地 dev    ──→ origin/dev
本地 main   ──→ origin/main
```

| 名称 | 地址 | 说明 |
|------|------|------|
| `origin` | https://github.com/Lifeisastory/flutter_source.git | 个人 GitHub 仓库 |
| `upstream` | https://github.com/flutter/flutter.git | Flutter 官方源码 |

---

## 一、从官方获取 stable 分支到本地

```bash
git fetch upstream --tags
git checkout stable
git reset --hard upstream/stable
```

命令说明：
- `git fetch upstream --tags` — 拉取官方最新代码和版本标签
- `git checkout stable` — 切换到本地 stable 分支
- `git reset --hard upstream/stable` — 强制对齐官方 stable 分支

验证版本：

```bash
git describe --tags
```

应输出类似 `3.44.3`，如果为空则说明 tag 未正确同步。

---

## 二、更新框架依赖

```bash
flutter update-packages
```

---

## 三、处理 0.0.0-unknown 版本问题

如果 `flutter doctor` 显示版本为 `0.0.0-unknown`，通常是因为 HEAD 不在 tag 链上或 tool 缓存未刷新。

修复步骤：

```bash
git clean -xfd
bin/flutter doctor
```

命令说明：
- `git clean -xfd` — 清理所有未跟踪文件和目录（包括被 .gitignore 忽略的）
- `bin/flutter doctor` — 重新构建 flutter tool 并生成正确版本

---

## 四、推送到 origin

### 推送 stable

```bash
git push origin stable
```

### 推送 dev / main

```bash
git push origin dev
git push origin main
```

---

## 五、日常同步工作流

每次官方有更新时：

```bash
# 1. 拉取上游最新代码和标签
git fetch upstream --tags

# 2. 对齐 stable
git checkout stable
git reset --hard upstream/stable

# 3. 更新依赖
flutter update-packages

# 4. 如果出现版本异常，执行修复
git clean -xfd
bin/flutter doctor

# 5. 推送到个人仓库
git push origin stable
```

---

## 六、开发分支工作流（dev 分支）

不要在 stable 上直接开发。创建 dev 分支进行修改：

```bash
git checkout -b dev
```

当 upstream/stable 更新后，将 dev 分支 rebase 到最新 stable：

```bash
git fetch upstream --tags
git checkout stable
git reset --hard upstream/stable
git checkout dev
git rebase stable
```

推送到个人仓库：

```bash
git push -u origin dev
```

---

## 七、快速参考

| 操作 | 命令 |
|------|------|
| 同步上游 | `git fetch upstream --tags` |
| 对齐 stable | `git reset --hard upstream/stable` |
| 更新依赖 | `flutter update-packages` |
| 修复版本 | `git clean -xfd && bin/flutter doctor` |
| 推送 stable | `git push origin stable` |
| 推送 dev | `git push origin dev` |
| 推送 main | `git push origin main` |
