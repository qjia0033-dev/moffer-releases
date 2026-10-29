# Moffer Desktop releases

This public repository distributes Moffer Desktop installers. Product source remains in the private source repository.

The manually dispatched Windows workflow builds an exact reviewed source commit on a standard Windows x64 runner. It uses a repository-scoped, read-only deploy key, performs native speech and packaged file-dialog checks, and retains only installers and validation evidence for three days. It does not publish a release automatically.

Official downloads: https://www.moffer.today/download/

## 让 AI 帮你装 Moffer 桌面端

把下面这句话发给你电脑上的 AI 助手（Claude Code、Codex、Cursor 都行）：

> 帮我安装 Moffer 桌面端，按这个说明做：https://github.com/qjia0033-dev/moffer-releases/blob/main/plugins/moffer-desktop/skills/moffer-desktop-install/SKILL.md

AI 会先问你一次，你同意后它会：

1. 从 Moffer 的公开发布页下载安装包
2. 核对安装包的 SHA256，对不上就停
3. 装好并打开 Moffer，跳到权限页

下面三件事要你自己点，AI 不会也不该替你做：

- 打开系统权限（Mac：屏幕录制、麦克风、辅助功能；Windows：麦克风）
- 钥匙串弹窗点「允许」（只有 Mac）
- 在 Moffer 里点「用浏览器登录」。不要把密码发给 AI。

支持：Apple 芯片的 Mac、64 位 Windows。Intel Mac 暂时没有安装包。

**Windows 版安装脚本还没在真机上验证过。** 装不上就去官网下载页手动安装：https://www.moffer.today/download

### 想以后一句话就能用

- **Claude Code**：`claude plugin install moffer-desktop --marketplace qjia0033-dev/moffer-releases`，以后说「帮我装/更新 Moffer」就行。
- **Codex / Cursor**：把 `plugins/moffer-desktop/skills/moffer-desktop-install` 这个文件夹复制到 `~/.agents/skills/` 下面。

### 不用 AI

Mac 终端里运行：

    curl -fsSL https://raw.githubusercontent.com/qjia0033-dev/moffer-releases/main/plugins/moffer-desktop/skills/moffer-desktop-install/scripts/install-mac.sh | bash

Windows 和其他方式见 https://www.moffer.today/download
