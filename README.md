# BuildLight

盯着自己的几个仓库看构建：一屏知道谁在跑、跑到第几步、有没有包可以取；包好了点一下就交给签名工具。

## 它解决什么

- 打开就是构建看板，不用等 github.com 首屏
- Step 级进度，不是"构建中"三个字
- `upload-artifact` 一结束就能取包，不用等整个 run 完成
- 下载 → 解压 → 交给全能签/AltStore，全程不碰剪贴板

## 状态

| 模块 | 状态 |
|---|---|
| GitHub 数据层（runs / jobs / artifacts / ETag） | 已完成 |
| 总览列表 | 骨架 |
| PAT 配置 / 添加仓库 | 已完成 |
| Run 详情（步骤流 + 产物） | 待做 |
| 历史与耗时回归 | 待做 |
| 通知规则（Bark） | 待做 |

## 开发

工程用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成，仓库里不放 `.xcodeproj`：

```bash
brew install xcodegen
xcodegen generate
open BuildLight.xcodeproj
```

CI 在 `.github/workflows/ci.yml`：单元测试 + 无签名 IPA，产物为 `BuildLight-unsigned-ipa`。

## 设计

两套配色（深夜 / 纸白），跟随系统外观。衬线标题用系统内置 New York（中文回落宋体），不嵌字体。

- 深色：纯黑底 + `#141416` 卡片 + 暖橙红渐变
- 浅色：暖纸白 `#F4F2EE` + 纯白卡片 + 加深一档的渐变
- 颜色只给「正在发生」和「出事了」；成功的构建是安静的

## 凭据

PAT 只存在 Keychain。需要的权限：`Actions: Read`、`Contents: Read`、`Metadata: Read`。
