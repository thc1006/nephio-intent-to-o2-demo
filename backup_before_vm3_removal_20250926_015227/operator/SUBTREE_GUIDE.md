# Operator Subtree 管理指南

## 🎯 設置完成

已成功將 `nephio-intent-operator` 作為 subtree 整合到主倉庫的 `/operator` 目錄。

## 📍 倉庫資訊

- **主倉庫**: https://github.com/thc1006/nephio-intent-to-o2-demo
- **Operator 倉庫**: https://github.com/thc1006/nephio-intent-operator
- **Subtree 路徑**: `/operator`
- **當前分支**: `feat/add-operator-subtree`

## 🔧 常用 Subtree 命令

### 從 Operator 倉庫拉取更新
```bash
# 拉取 operator 倉庫的最新更新
git subtree pull --prefix=operator operator main --squash
```

### 推送更改到 Operator 倉庫
```bash
# 將 operator/ 目錄的更改推送回獨立倉庫
git subtree push --prefix=operator operator main
```

### 查看 Subtree 相關的提交
```bash
# 查看 subtree 相關的歷史
git log --oneline --graph --decorate | grep -E "(Squashed|Merge|subtree)"
```

## 📝 開發流程

### 1. 在主倉庫開發 Operator
```bash
cd ~/nephio-intent-to-o2-demo/operator
# 進行開發...
git add .
git commit -m "feat(operator): your changes"
```

### 2. 推送到主倉庫
```bash
git push origin feat/add-operator-subtree
```

### 3. 同步到獨立 Operator 倉庫
```bash
git subtree push --prefix=operator operator main
```

### 4. 從獨立倉庫拉取更新
```bash
git subtree pull --prefix=operator operator main --squash
```

## 🚀 Kubebuilder 初始化 (下一步)

```bash
cd ~/nephio-intent-to-o2-demo/operator
export PATH="$HOME/go/bin:$PATH"

# 初始化 Kubebuilder 專案
kubebuilder init \
  --domain nephio.io \
  --repo github.com/thc1006/nephio-intent-operator \
  --project-name nephio-intent-operator

# 創建 API
kubebuilder create api \
  --group intent \
  --version v1alpha1 \
  --kind IntentConfig \
  --resource \
  --controller

# 創建 webhook
kubebuilder create webhook \
  --group intent \
  --version v1alpha1 \
  --kind IntentConfig \
  --defaulting \
  --programmatic-validation
```

## ⚠️ 注意事項

1. **不要直接在 operator/ 目錄執行 git 命令**
   - 所有 git 操作都應在主倉庫根目錄執行

2. **提交訊息規範**
   - 對 operator 的更改使用 `feat(operator):` 或 `fix(operator):` 前綴

3. **同步策略**
   - 定期將更改推送到獨立 operator 倉庫
   - 使用 `--squash` 保持歷史整潔

## 📋 已完成的步驟

- ✅ 備份主倉庫 (tag: `pre-operator-subtree-20250916`)
- ✅ 創建獨立 Operator 倉庫
- ✅ 初始化並推送到 GitHub
- ✅ 添加 subtree 到主倉庫
- ✅ 推送 feature branch
- ✅ 驗證 subtree 整合

## 🔗 相關連結

- [Git Subtree 文檔](https://github.com/git/git/blob/master/contrib/subtree/git-subtree.txt)
- [Kubebuilder 文檔](https://book.kubebuilder.io/)
- [Operator SDK](https://sdk.operatorframework.io/)