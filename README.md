# dsh-ops — DeepSeek Harness 运维工具箱

**版本：v1.1.3** · [更新日志](CHANGELOG.md) · [MIT](LICENSE) · [English](README.en.md)

> **给 AI 代理**：如果你正在协助维护 dsh（DeepSeek Harness）部署，请先读
> [`runbook.md`](runbook.md) 和 [`docs/diagnosis-table.md`](docs/diagnosis-table.md)，
> 优先使用 `scripts/` 里的脚本，而不是从头探索式排查。
> 如果所有工具调用都在约 1 毫秒内崩溃（`prepare` / undefined），那是**宿主级故障**：
> **立即停止在 dsh 内部排查**，改用独立脚本（见 runbook 第 3 节）。

面向 [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness) Windows 部署的
独立运维工具集，**无需 AI、纯本地脚本、0 token**。

诞生于一次真实事故（2026-08-15）：一个损坏的第三方主题 + 重复的插件行 + 重复安装的核心包，
导致**所有** dsh 会话崩溃（宿主级 `prepare` 崩溃），而 dsh 自身无法自诊断。

**核心认知**：宿主级故障会让每个 dsh 会话全部倒下，所以工具必须**不依赖 dsh 就能运行**——
纯 PowerShell，零 token，零 AI。

## 功能

| 工具 | 作用 | 成本 |
|---|---|---|
| `check-health.ps1` | 8 项体检：端口、HTTP、启动清单中的期望包、组合树重复行、核心包双份、备份纪律、静态 lint（`main` 引用浏览器全局的包）。每次运行都会追加到 `<dsh>/logs/health-history.log` | 0 token |
| `backup-config.ps1` | 快照 profile 配置（cordis.yml / cordis.patch.yml / package.json / pnpm-workspace.yaml / settings.yaml）+ 包清单 → `<dsh>/backups/<时间戳>/` | 0 token |
| `restore-snapshot.ps1` | 从快照还原配置（带确认） | 0 token |
| `list-snapshots.ps1` | 列出快照（文件数、创建时间） | 0 token |
| `diff-snapshot.ps1` | 对比两个快照的配置差异（审计"改了什么"） | 0 token |
| `restart-service.ps1` | 服务未运行则启动；验证端口**和** HTTP 200 | 0 token |
| `watchdog.ps1` | 计划任务用静默看门狗；配置健康才重启（连续 2 次失败停止重试并提示还原快照） | 0 token |
| `watch-config.ps1` | 配置一变就自动快照（轮询+防抖）+ 审计日志 `<dsh>/logs/config-watch.log` | 0 token |
| `runbook.md` | 铁律、标准流程、症状→排查对照表 | — |

双击友好的 `.cmd` 入口在 `cmd/` 目录。

## 安装与部署

dsh-ops 刻意**免安装**：克隆到任意位置直接运行（所有路径自动探测）。唯一可选的安装是
**配置监听自动启动**：

```powershell
# 1. 克隆到任意位置（推荐 %USERPROFILE%\.dsh\ops\）
git clone https://github.com/MiraculousGarfield/dsh-ops.git

# 2. （可选）注册 watch-config 登录自启 —— 零窗口（VBS）
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

# 卸载
powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

说明：
- `install.ps1` 通过**用户 Startup 文件夹**注册自启（无需管理员权限、VBS 零窗口包装、无控制台闪烁），并立即启动监听；`-Uninstall` 移除
- `watch-config.ps1` 只保留最近 **20** 份自动快照（`-MaxAutoSnapshots`）；手动快照（`known-good-*`、带时间戳备份）永不清理
- 系统级**看门狗刻意不安装**：大多数场景不需要 dsh 服务 24 小时常驻——桌面壳或手动 `restart-service.ps1` 已足够；如确实需要，可自行把 `scripts\watchdog.ps1` 注册为计划任务（它静默运行、只写日志）

## 快速开始

```powershell
# 一键体检
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-health.ps1

# 自定义 profile / 端口 / 期望主题包
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-health.ps1 -Profile web -Port 3080 -ExpectTheme <你的主题包名>

# 任何配置改动前先备份
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\backup-config.ps1

# 从快照还原
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\restore-snapshot.ps1 -Snapshot known-good-20260815

# 服务未运行则重启
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\restart-service.ps1
```

## 自动发现（无需配置）

- **DSH home**：`$env:DSH_HOME` 或 `%USERPROFILE%\.dsh`
- **dsh 启动器**：`$env:DSH_BIN` 覆盖，其次 `%LOCALAPPDATA%\npm-cache\_npx` 下的 npx 缓存，再其次 `<dsh>\profiles\node_modules`
- **node.exe**：`PATH`，其次标准安装位置

## 安全铁律（完整版见 `runbook.md`）

1. **永远不要**在 dsh profile 里 `pnpm add` 随意包——可能拉入重复核心包，让所有会话崩溃。
2. **永远不要** `insert` 一个已经在 `dsh.profile.bundles` 里的插件行（重复条目）。
3. 主题/插件包：`main` 必须是合法的服务端入口；浏览器代码只能通过 `exports["./client"]` + `dsh.client` 元数据暴露。**绝不要把 `main` 指向浏览器脚本**。
4. 每次改动前备份（`backup-config.ps1`），改动后体检（`check-health.ps1`）。

## 环境要求

- Windows（PowerShell 5.1+、`netstat`、`powershell.exe`）
- Node.js 在 PATH 上（仅组合树查重和重启服务需要）

## 文档

- `runbook.md` — 铁律与标准流程
- `docs/diagnosis-table.md` — 症状 → 先查什么
- `docs/case-study-2026-08-15.md` — 事故复盘（匿名化），也是本工具的缘起

## License

MIT
