# 创建 GitHub 仓库

当前使用的仓库名：

```text
live-analysis
```

仓库地址：

```text
https://github.com/xxxxxxuan666/live-analysis
```

## 方式 A：网页创建

1. 打开 GitHub。
2. New repository。
3. Repository name 填：

```text
live-analysis
```

4. 选择 Public 或 Private。
5. 不要勾选 README、.gitignore、License，因为本地仓库已经有这些文件。
6. 创建完成后，回到 Codex 让我继续推送。

## 方式 B：GitHub CLI 创建

如果本机已安装并登录 `gh`：

```powershell
gh repo create xxxxxxuan666/live-analysis --public --source . --remote origin --push
```

如果希望私有仓库，把 `--public` 改成 `--private`。

## 创建后推送命令

在本目录运行：

```powershell
git push -u origin main
```
