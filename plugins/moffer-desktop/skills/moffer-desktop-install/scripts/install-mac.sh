#!/bin/bash
# Moffer Desktop（桌面伴侣）：一键安装 / 更新（macOS Apple 芯片）
# 从公开发布仓库 qjia0033-dev/moffer-releases 下载，校验 SHA256 后装进 /Applications
# 用法：
#   bash install-mac.sh            # 安装并打开
#   bash install-mac.sh --no-open  # 只安装，不打开
#   MOFFER_VERSION=3.2.0 bash install-mac.sh   # 指定版本
# 退出码：0 成功；1 出错；2 应用正在运行
set -euo pipefail

APP_NAME="Moffer Desktop"
GITHUB_REPO="qjia0033-dev/moffer-releases"
BASE_URL="https://github.com/${GITHUB_REPO}/releases"

# 1. 平台检查：只支持 macOS + Apple 芯片，绝不回退到别的架构
if [ "$(uname -s)" != "Darwin" ]; then
  echo "❌ 这个脚本只支持 macOS。Windows 请用 install-win.ps1。"
  exit 1
fi
if [ "$(uname -m)" != "arm64" ]; then
  echo "❌ Intel Mac 暂无安装包（当前只提供 Apple 芯片版）。"
  exit 1
fi

# 2. 版本与校验清单：优先用 MOFFER_VERSION，否则走 latest 重定向（不需要 GitHub API）
if [ -n "${MOFFER_VERSION:-}" ]; then
  if ! printf '%s' "${MOFFER_VERSION}" | grep -Eq '^[0-9]+(\.[0-9]+)*$'; then
    echo "❌ MOFFER_VERSION 格式不对（只允许数字和点）：${MOFFER_VERSION}"
    exit 1
  fi
  SUMS_URL="${BASE_URL}/download/v${MOFFER_VERSION}/SHA256SUMS.txt"
else
  SUMS_URL="${BASE_URL}/latest/download/SHA256SUMS.txt"
fi

# 应用开着就先不下载，省得白等（替换前还会再查一次）
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  echo "⚠️  ${APP_NAME} 正在运行，请先从菜单栏图标选择「退出」，再重新运行本脚本。"
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "⬇️  正在获取校验清单…"
# -sS：不刷进度条（AI 读输出时几百行进度是噪音），出错仍会显示
curl -fsSL --retry 2 --connect-timeout 20 --proto '=https' --tlsv1.2 \
  -o "${TMP}/SHA256SUMS.txt" "${SUMS_URL}" \
  || { echo "❌ 拿不到校验清单（网络问题，或这个版本不存在）。"; exit 1; }

# 只认 arm64-mac.zip 那一行；必须恰好一行
MATCHES="$(grep -E '^[0-9a-f]{64}  moffer-desktop-[0-9.]+-arm64-mac\.zip$' "${TMP}/SHA256SUMS.txt" || true)"
COUNT="$(printf '%s' "${MATCHES}" | grep -c . || true)"
if [ "${COUNT}" != "1" ]; then
  echo "❌ 校验清单里没有找到唯一的 arm64-mac.zip 条目（找到 ${COUNT} 条）。"
  exit 1
fi
EXPECTED_HASH="${MATCHES%%  *}"
FILE="${MATCHES##*  }"
VERSION="$(printf '%s' "${FILE}" | sed -E 's/^moffer-desktop-([0-9.]+)-arm64-mac\.zip$/\1/')"
if [ -n "${MOFFER_VERSION:-}" ] && [ "${VERSION}" != "${MOFFER_VERSION}" ]; then
  echo "❌ 清单里的版本 ${VERSION} 与指定的 ${MOFFER_VERSION} 不一致。"
  exit 1
fi

# 3. 下载 zip
echo "⬇️  正在下载 Moffer Desktop v${VERSION}（约 360 MB，一般一两分钟）…"
curl -fsSL --retry 2 --connect-timeout 20 --proto '=https' --tlsv1.2 \
  -o "${TMP}/${FILE}" "${BASE_URL}/download/v${VERSION}/${FILE}" \
  || { echo "❌ 下载失败，可能是网络问题，稍后再试。"; exit 1; }

# 4. 校验 SHA256
ACTUAL_HASH="$(shasum -a 256 "${TMP}/${FILE}" | awk '{print $1}')"
if [ "${ACTUAL_HASH}" != "${EXPECTED_HASH}" ]; then
  echo "❌ 校验失败，安装中止。"
  echo "   期望：${EXPECTED_HASH}"
  echo "   实际：${ACTUAL_HASH}"
  rm -f "${TMP}/${FILE}"
  exit 1
fi
echo "✅ 校验通过"

# 5. 解压（ditto 比 unzip 更能保留签名），要求顶层恰好是 Moffer Desktop.app
ditto -x -k "${TMP}/${FILE}" "${TMP}/x"
APP_SRC="${TMP}/x/${APP_NAME}.app"
if [ ! -d "${APP_SRC}" ]; then
  echo "❌ 压缩包里没有找到 ${APP_NAME}.app，安装中止。"
  exit 1
fi

# 6. 应用正在运行就不动它，让用户自己退出
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  echo "⚠️  ${APP_NAME} 正在运行，请先从菜单栏图标选择「退出」，再重新运行本脚本。"
  exit 2
fi

# 7. 目标目录：优先 /Applications，不可写则 ~/Applications
if [ -n "${MOFFER_INSTALL_DIR:-}" ]; then
  DEST_DIR="${MOFFER_INSTALL_DIR}"
  mkdir -p "${DEST_DIR}"
elif [ -w "/Applications" ]; then
  DEST_DIR="/Applications"
else
  DEST_DIR="${HOME}/Applications"
  mkdir -p "${DEST_DIR}"
  if [ -d "/Applications/${APP_NAME}.app" ]; then
    echo "⚠️  /Applications 里已有一份旧版本，本次装到 ${DEST_DIR}，现在会有两份，建议手动删掉旧的。"
  fi
fi
DEST="${DEST_DIR}/${APP_NAME}.app"

# 8. 尽量原子地替换：先拷到 .new，再删旧的，再改名（先清掉上次失败留下的 .new）
rm -rf "${DEST_DIR}/.${APP_NAME}.app.new"
ditto "${APP_SRC}" "${DEST_DIR}/.${APP_NAME}.app.new"
rm -rf "${DEST}"
mv "${DEST_DIR}/.${APP_NAME}.app.new" "${DEST}"

# 摘掉下载隔离属性：命令行装的应用不触发「无法验证开发者」拦截
# （安装包暂无苹果签名与公证；浏览器下载 .dmg 的用户仍需到「系统设置 → 隐私与安全性」放行一次）
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

echo ""
echo "✅ 已安装 Moffer Desktop v${VERSION} 到：${DEST}"

# 9. 打开应用并跳到权限页（可用 --no-open 或 MOFFER_NO_OPEN=1 跳过）
if [ "${1:-}" != "--no-open" ] && [ "${MOFFER_NO_OPEN:-0}" != "1" ]; then
  open "${DEST}" 2>/dev/null || true
  sleep 3
  open "moffer://settings/permissions" 2>/dev/null || true
fi

# 10. 需要用户自己做的事
echo ""
echo "接下来请你自己完成："
echo "  1. 在「系统设置 → 隐私与安全性」里打开 屏幕录制、麦克风、辅助功能，然后重启 Moffer。"
echo "  2. 钥匙串弹窗点「允许」。"
echo "  3. 在应用里点「用浏览器登录」，不要把密码告诉 AI。"
exit 0

