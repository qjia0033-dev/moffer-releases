# Moffer Desktop（桌面伴侣）：一键安装 / 更新（Windows 64 位）
# 从公开发布仓库 qjia0033-dev/moffer-releases 下载，校验 SHA256 后运行安装程序
# 用法：
#   powershell -ExecutionPolicy Bypass -File install-win.ps1
#   powershell -ExecutionPolicy Bypass -File install-win.ps1 -NoRun   # 只下载校验，不运行
#   $env:MOFFER_VERSION="3.2.0"; .\install-win.ps1                    # 指定版本
# 退出码：0 成功；1 出错；2 应用正在运行
# 状态：尚未在真实 Windows 设备上验证（2026-10-29）
param([switch]$NoRun)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$AppName   = 'Moffer Desktop'
$GithubRepo = 'qjia0033-dev/moffer-releases'
$BaseUrl   = "https://github.com/$GithubRepo/releases"

# 1. 只支持 64 位 Windows
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Host '[X] 只支持 64 位 Windows。'
    exit 1
}

# 2. 版本与校验清单：优先用 MOFFER_VERSION，否则走 latest 重定向（不需要 GitHub API）
$Version = $env:MOFFER_VERSION
if ($Version) {
    if ($Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
        Write-Host "[X] MOFFER_VERSION 格式不对（只允许数字和点）：$Version"
        exit 1
    }
    $SumsUrl = "$BaseUrl/download/v$Version/SHA256SUMS.txt"
} else {
    $SumsUrl = "$BaseUrl/latest/download/SHA256SUMS.txt"
}

# 应用开着就先不下载（Windows 不能覆盖正在运行的程序）
if (Get-Process -Name $AppName -ErrorAction SilentlyContinue) {
    Write-Host "[!] $AppName 正在运行，请先在右下角托盘图标里选择「退出」，再重新运行本脚本。"
    exit 2
}

$TempDir = Join-Path $env:TEMP ("moffer-install-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    Write-Host '>> 正在获取校验清单…'
    $SumsPath = Join-Path $TempDir 'SHA256SUMS.txt'
    Invoke-WebRequest -UseBasicParsing -Uri $SumsUrl -OutFile $SumsPath

    # 只认 setup.exe 那一行；必须恰好一行
    $pattern = '^[0-9a-f]{64}  moffer-desktop-[0-9.]+-setup\.exe$'
    # 变量别叫 $matches：它和 PowerShell 自带的 $Matches 是同一个
    $sumLines = @(Get-Content -LiteralPath $SumsPath | Where-Object { $_ -cmatch $pattern })
    if ($sumLines.Count -ne 1) {
        Write-Host "[X] 校验清单里没有找到唯一的 setup.exe 条目（找到 $($sumLines.Count) 条）。"
        exit 1
    }
    $line = $sumLines[0]
    $ExpectedHash = $line.Substring(0, 64)
    $File = $line.Substring(66)
    if (-not ($File -cmatch '^moffer-desktop-([0-9.]+)-setup\.exe$')) {
        Write-Host '[X] 无法从文件名解析版本。'
        exit 1
    }
    $FileVersion = $Matches[1]
    if ($Version -and $FileVersion -ne $Version) {
        Write-Host "[X] 清单里的版本 $FileVersion 与指定的 $Version 不一致。"
        exit 1
    }

    # 3. 下载安装程序
    Write-Host ">> 正在下载 Moffer Desktop v$FileVersion…"
    $ExePath = Join-Path $TempDir $File
    $DownloadUrl = "$BaseUrl/download/v$FileVersion/$File"
    Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $ExePath

    # 4. 校验 SHA256
    $ActualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ExePath).Hash
    if ($ActualHash -ne $ExpectedHash) {
        Write-Host '[X] 校验失败，安装中止。'
        Write-Host "   期望：$ExpectedHash"
        Write-Host "   实际：$ActualHash"
        Remove-Item -LiteralPath $ExePath -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host '[OK] 校验通过'

    # 5. 下载期间用户又打开了应用：不动它
    if (Get-Process -Name $AppName -ErrorAction SilentlyContinue) {
        Write-Host "[!] $AppName 正在运行，请先在右下角托盘图标里选择「退出」，再重新运行本脚本。"
        exit 2
    }

    # 6. 运行安装程序（非静默，用户能看到安装窗口）
    if ($NoRun -or $env:MOFFER_NO_RUN -eq '1') {
        Write-Host ''
        Write-Host "[OK] 已下载并校验：$ExePath"
        Write-Host '   已按 -NoRun / MOFFER_NO_RUN 跳过运行，文件保留。'
        # 保留文件，不清理
        $TempDir = $null
        exit 0
    }

    Write-Host ''
    Write-Host '[i] 安装程序未签名，Windows SmartScreen 可能提示「Windows 已保护你的电脑」。'
    Write-Host '   是否点「更多信息 → 仍要运行」由你自己决定；本脚本不会绕过任何安全提示。'
    Write-Host '>> 正在启动安装程序…'
    # 不用 Start-Process -Wait：它会连安装完自动打开的 Moffer 一起等，脚本就一直不结束
    $installer = Start-Process -FilePath $ExePath -PassThru
    $installer.WaitForExit()
    if ($installer.ExitCode -ne 0) {
        Write-Host "[X] 安装程序没有完成（退出码 $($installer.ExitCode)），可能是被取消或被系统拦下。"
        exit 1
    }

    # 打开权限页（失败不影响结果）
    try {
        Start-Process 'moffer://settings/permissions' | Out-Null
    } catch {
        Write-Host '（未能自动打开权限页，可稍后在应用里手动打开。）'
    }

    # 7. 需要用户自己做的事
    Write-Host ''
    Write-Host '接下来请你自己完成：'
    Write-Host '  1. 在「设置 → 隐私 → 麦克风」里允许 Moffer。'
    Write-Host '  2. 在应用里点「用浏览器登录」，不要把密码告诉 AI。'
    exit 0
}
finally {
    if ($TempDir -and (Test-Path -LiteralPath $TempDir)) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
