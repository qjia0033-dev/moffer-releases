---
name: moffer-desktop-install
description: Install or update Moffer Desktop (the Moffer job-interview desktop companion) on macOS Apple Silicon or 64-bit Windows, then walk the user through permissions and sign-in. Use when the user asks to install, update or set up Moffer / Moffer Desktop / Moffer 桌面端.
license: Proprietary
compatibility: Needs a local shell on the user's own computer (Claude Code, Codex, Cursor or similar). Does not work in cloud sandboxes.
---

# Install Moffer Desktop

Talk to the user in the language they use. Keep sentences short.

## Rules

- Ask once before you start: say you will download Moffer Desktop from `github.com/qjia0033-dev/moffer-releases`, check its SHA256, install it, and open it. Wait for a yes.
- Download only through the scripts in `scripts/`. They take files only from that public repo and stop if the checksum does not match. Never download the app from anywhere else.
- Never use `sudo`, never ask for an admin password, never turn off Gatekeeper, SmartScreen, Smart App Control or Defender, never edit TCC, the registry or security settings, and never try to click system permission switches for the user.
- Never ask for, read or type the user's Moffer password. Sign-in happens in the user's browser.
- If a script fails, show the user its message. Do not work around a checksum failure.

## Steps

1. Check the platform.
   - macOS: `uname -m` must be `arm64`. Intel Mac → tell the user there is no Intel build yet and stop.
   - Windows: must be 64-bit. The Windows script has not yet been tested on a real Windows machine; tell the user so before running it, and if anything fails, point them to https://www.moffer.today/download for the manual installer.
   - Anything else → not supported, stop.
2. Run the installer script that sits next to this file.
   - macOS: `bash scripts/install-mac.sh`
   - Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-win.ps1` (the bypass applies to this one process only).
   - If this skill was given to you as a link and the scripts are not on disk, fetch the script from `https://raw.githubusercontent.com/qjia0033-dev/moffer-releases/main/plugins/moffer-desktop/skills/moffer-desktop-install/scripts/<name>`, show the user what it does in one or two lines, then run it.
   - Exit code 2 means Moffer Desktop is running. Ask the user to quit it (macOS: menu bar icon → 退出; Windows: tray icon → 退出) and run the script again.
   - Windows: the installer is not code-signed. SmartScreen may show "Windows 已保护你的电脑". Tell the user it is their choice to click 「更多信息 → 仍要运行」. Do not bypass it. The installer normally installs for the current user without admin rights; if Windows still shows an admin (UAC) prompt, the user decides. Never run anything elevated yourself.
   - On macOS the script prints where it installed the app; use that path in your report. On Windows the installer chooses the folder (normally under `%LOCALAPPDATA%\Programs`).
3. After it installs, the script opens the app and its permission page (`moffer://settings/permissions`). Tell the user what only they can do:
   - macOS: in System Settings → Privacy & Security, turn on **Screen Recording**, **Microphone** and **Accessibility** for Moffer Desktop, then quit and reopen Moffer.
   - macOS: if a Keychain prompt about "moffer-desktop Safe Storage" appears, click **Allow** (it can appear again after each update).
   - Windows: Settings → Privacy → Microphone, allow Moffer Desktop.
4. Sign-in: open `moffer://settings/connect` (macOS `open "moffer://settings/connect"`, Windows `Start-Process "moffer://settings/connect"`) and tell the user to click 「用浏览器登录」 and finish in the browser.
5. Report: the installed version, where it went, and which of the user steps are still open.

## Update

Same as install: run the script again. It installs the newest release over the old one. To install a specific version, set `MOFFER_VERSION`: macOS `MOFFER_VERSION=3.2.0 bash scripts/install-mac.sh`, Windows `$env:MOFFER_VERSION="3.2.0"` before running the PowerShell command.
