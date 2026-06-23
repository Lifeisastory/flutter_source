# flutter_source

Flutter 官方源码跟踪仓库，上游为 [flutter/flutter](https://github.com/flutter/flutter) 的 `stable` 分支。

## 远程仓库

| 名称 | 地址 | 说明 |
|------|------|------|
| `origin` | https://github.com/Lifeisastory/flutter_source.git | 个人 GitHub 仓库 |
| `upstream` | https://github.com/flutter/flutter.git | Flutter 官方源码 |

## 从 upstream 更新 stable 分支

```bash
# 拉取上游最新代码
git fetch upstream stable

# 合并到本地 stable 分支
git merge upstream/stable
```

## 将本地更新推送到 origin

```bash
git push origin stable
```
