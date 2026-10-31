# BuildLight 2.1 缺陷修复方案

> 依据：2026-10-31 全量代码审查（28 条）
> 原则：每条独立修复、可验证、不互相耦合；纯逻辑抽成可测单元。

## 阶段划分

| 批次 | 范围 | 目标 |
|---|---|---|
| A | P0 正确性 8 条 | 不再骗人、不再卡死 |
| B | P1 性能/一致性 5 条 | 掉帧、慢刷新、状态错乱 |
| C | P2 交互 7 条 | 操作可用、反馈真实 |
| D | P3 工程 8 条 | 可维护、可扩展、无障碍 |
| E | 单测 | 覆盖所有抽取出的纯逻辑 |

---

## A · P0 正确性

### A1 通知冷启动丢跳转
**现状** `BuildLightApp.swift` 在 `.task` 里设 `UNUserNotificationCenter.delegate`。
**根因** 从通知点进 App 时，系统在启动阶段就投递 response，`.task` 尚未执行。
**方案** 移到 `BuildLightApp.init()`（App 结构体初始化，早于任何 Scene 生命周期）。
**验收** 冷启动点通知能进详情。

### A2 深链依赖本地已有数据
**现状** `RootTabView` 用 `runs.first(where: id)`，找不到就丢弃。
**根因** 冷启动时 SwiftData 还没同步到目标 run。
**方案**
1. 通知 `userInfo` 带上 `repoFullName`（现有代码只有 runID）。
2. `DeepLinkRouter` 正式接线：`pendingRunID + repoFullName`。
3. 找不到时走 API 拉单条 run（`GET /repos/{o}/{r}/actions/runs/{id}`），落库后跳转。
4. 落库失败给一次 toast，不静默。
**验收** 冷启动/热启动都能进；数据缺失时能补拉。

### A3 暂停后立刻继续导致双下载
**现状** `PackageService.tasks[id]` 被 pause 和旧 Task 的 `defer` 双重清理。
**方案** 引入 generation token：
```swift
private var generations: [Int: UUID] = [:]
// start 时生成 token，defer 只在 token 仍匹配时清理
```
pause 立即作废旧 token。
**验收** 连续 暂停→继续→暂停→继续 只存在一个数据流。

### A4 失败步骤自动定位反复抢滚动
**现状** `.onChange(of: jobs)` 每次轮询（3s）都触发。
**方案** `@State private var didAutoScroll = false`，只在首次 `jobs` 非空且存在失败步骤时滚一次；换 run 时重置。
**验收** 滚动后能自由往上翻，不被拽回。

### A5 Step id 跨 job 冲突
**现状** `WorkflowStep.id = number`，每个 job 都从 1 开始。
**方案** `WorkflowStep` 保留 `id`，但视图层用 `.id("\(job.id)-\(step.number)")` 作为滚动锚点。
**验收** 多 job 各自失败时能定位到正确步骤。

### A6 旧 run 的产物永远空
**现状** 只对 `runs.prefix(2)` 拉 artifacts。
**方案** `RunDetailView` 打开时若 `run.artifacts` 为空则按需拉取并落库（带内存去重，避免重复请求）。
**验收** 任意历史 run 都能看到产物。

### A7 摘要数字跟着筛选变
**现状** `readyCount/runningCount` 取自 `filteredRepos`。
**方案** 摘要卡改读全量 `visibleRepos`，筛选只影响下方列表。
**验收** 切「失败」时顶部数字不变。

### A8 通知开关状态撒谎
**现状** `@AppStorage` 默认 true，但系统可能未授权。
**方案** 开关真实值 = `isEnabled && isAuthorized`；未授权时显示「未授权」并可一键跳设置；打开开关立即请求授权。
**验收** 状态与系统设置一致。

---

## B · P1 性能与一致性

### B1 `state(for:)` 在 body 里做磁盘 IO
**方案**
- `PackageService` 维护 `progressCache: [Int: Double]`，启动时一次性从磁盘预热。
- `state(for:)` 只读内存。
- 下载器完成后更新缓存。
**验收** 首页滚动无磁盘读（Instruments 验证点：无 `Data(contentsOf:)` 热路径）。

### B2 刷新串行
**方案** `withTaskGroup`，并发上限 4，结果回主线程应用。
**注意** `RepoRecord` 是 `@Model`，只在 MainActor 上改动 → 网络请求并发，落库串行。

### B3 轮询空转
**方案** `start()` 按最近的 `nextPollAt` 计算睡眠时长（上限 5s、下限 0.5s），无任务时睡到下一个到期点。

### B4 历史页首次不展开
**方案** 用 `.task(id: groups.count)`，数据到位后再初始化一次。

### B5 `RepoService.move` 不处理隐藏仓库
**方案** 抽纯函数 `reindex(visible:all:)`，可见仓库按新顺序占 0..n，隐藏仓库追加到末尾保持相对顺序。

---

## C · P2 交互

### C1 仓库拖动排序不可用
**方案** 加 `EditButton`（编辑时才显示拖动）；非编辑态隐藏手柄。

### C2 RepoDetail 丢失重跑/取消
**方案** 恢复 `.swipeActions`（运行中=取消，已完成=重跑），并加二次确认（取消/重跑是不可逆远端操作）。

### C3 两套缓存 UI
**方案** 删除 `CacheView` 路由，设置页「已下载的包」改为跳转/切换到「产物」Tab。

### C4 错误条只显示一条、无重试
**方案** 显示「N 个仓库刷新失败」+ 第一条原因；加「重试」按钮触发 `refreshAll()`。

### C5 刷新提示误伤
**方案** 每次提示生成 token，延迟清理时校验 token。

### C6 引导页登录后不同步仓库
**方案** 登录成功后自动 `syncAll()`，带进度文案；失败不阻断进入主界面。

### C7 角标口径不一致
**方案** 角标改为「在跑的仓库数」，与首页一致。

---

## D · P3 工程与规范

### D1 DeepLinkRouter 死代码
**方案** 正式接线（见 A2），删除重复的 `pendingRunID` 通道。

### D2 68 处硬编码字号
**方案** 全部迁移到 `Type` token；`Type` 内改用语义字号 + `.scaled(by:)`。

### D3 无障碍标注缺失
**方案** 状态点/进度环/图标按钮补 `accessibilityLabel`；卡片合并朗读。

### D4 缓存无上限
**方案** 上限 2 GB / 30 天，LRU 淘汰；超限时在产物页提示。

### D5 无后台刷新
**方案** 注册 `BGAppRefreshTask`（15 分钟最早），只刷新「有在跑」的仓库；无权限时静默跳过。

### D6 无主屏小组件
**方案** 新增 `StaticConfiguration` 小组件：小号=在跑数+最近一次结果；中号=3 条最近。

### D7 文件名双扩展名
**方案** `friendlyFileName` 先剥掉 `name` 的 `.ipa` 后缀再拼。

### D8 死代码/未使用 token
**方案** 清理 `DeepLinkRouter` 重复通道、未引用常量。

---

## E · 单测（新增）

| 文件 | 用例 |
|---|---|
| `PackageTargetTests` | 正常命名、空字段、双扩展名、非法字符、超长分支、同名去重 |
| `HomeSectionsTests` | 分组优先级（ready > available > running > idle）、筛选不影响计数 |
| `MonitorIssueTrackerTests` | 失败后成功→错误消失；成功后失败→错误出现；取消不计错；仓库移除后清空 |
| `RepoTests` | reindex 保持隐藏仓库相对顺序、无重复 sortIndex |
| `AppErrorTests` | CancellationError / URLError.cancelled → .cancelled；5xx → server |
| `CacheNamingTests` | 唯一文件名递增、扩展名保留、非法字符清洗 |

**门槛**：`xcodebuild test` 全绿，新增用例 ≥ 25 条。

---

## 交付顺序

A → 构建验证 → B → 验证 → C → 验证 → D → 验证 → E → 验证

每个批次独立 commit，CI 绿再进下一批。


---

# 交付结果（2026-10-31）

CI run 41124729643 · commit 6f8943f · 编译 / 单元测试 / IPA 全绿。

| 编号 | 状态 | 说明 |
|---|---|---|
| A1 | 完成 | delegate 移到 `App.init()` |
| A2 | 完成 | `DeepLinkRouter` 带 repoFullName；缺数据时 `ensureRun` 补拉；失败弹提示 |
| A3 | 完成 | generation token；旧任务不再覆盖新任务状态 |
| A4 | 完成 | `didAutoScroll` 只滚一次 |
| A5 | 完成 | 锚点 `step-<jobID>-<number>` |
| A6 | 完成 | `ensureArtifacts` 打开详情时补拉 |
| A7 | 完成 | 摘要读 `allSections`，筛选不影响 |
| A8 | 完成 | 开关真实值 = 意愿 && 系统授权 |
| B1 | 完成 | `diskProgress` 内存快照，启动预热 |
| B2 | 完成 | 网络并发（4/波），落库主线程串行；`RepoFetchResult` 为 Sendable |
| B3 | 完成 | 按最近 `nextPollAt` 计算睡眠（0.5–5s） |
| B4 | 完成 | `.task(id: groups.count)` |
| B5 | 完成 | `RepoOrdering.assign` 纯函数，隐藏仓库追加在后 |
| C1 | 完成 | 加 `EditButton`，页脚文案对齐真实行为 |
| C2 | 完成 | 恢复 swipeActions + 二次确认（`PendingAction`） |
| C3 | 完成 | 删除 `CacheView`，设置页跳「产物」Tab |
| C4 | 完成 | 错误条显示数量 + 重试按钮 + 按严重度选代表 |
| C5 | 完成 | `toastToken` 防止旧定时器误清 |
| C6 | 完成 | 登录后自动 `syncAll` + 首刷 |
| C7 | 完成 | 角标 = 在跑仓库数（按 repoFullName 去重） |
| D1 | 完成 | 单一 `DeepLinkRouter.shared`，旧 `pendingRunID` 通道已删 |
| D2 | 完成 | 63 处改用 `scaledFont`，覆盖 Dynamic Type 12 档 |
| D3 | 完成 | 卡片合并朗读 + 下载按钮输入标签 |
| D4 | 完成 | 2 GB 上限 + LRU 淘汰到 1.6 GB |
| D5 | 完成 | BGAppRefreshTask，仅在跑时联网 |
| D6 | **撤回** | 自签包无 App Group entitlement，组件读不到 App 数据；交付只会永远显示占位符，故不做半成品。等有正式签名再上 |
| D7 | 完成 | 剥离原 `.ipa` 后缀 |
| D8 | 完成 | 删除未使用的 `Type.display` / `Type.metric` / 重复通道 |
| E | 完成 | 新增 6 个测试文件、35 条用例（总 39 条），全部通过 |

## 已知遗留（不在本轮范围）

1. **主屏小组件**：受 App Group 限制，需正式签名。
2. **远程推送**：自签无 APNs，仍依赖服务器 `buildlight-watch` 发 Bark。
3. **历史分页**：每仓库仍只保留最近 30 条。
4. **iOS 26 玻璃在低端机上的滚动开销**：卡片数量 < 50 时未观察到掉帧，暂不做降级。
