#Requires -Version 5.1
<#
.SYNOPSIS
    构建 examples/web_demo 的 JS 产物，并复制到 docs/demo/，供 GitHub Pages 直接托管。

.DESCRIPTION
    做三件事：
      1. 执行 moon build --target js examples/web_demo；
      2. 把生成的 web_demo.js（以及同名 .js.map，若存在）复制到 docs/demo/；
      3. 自检产物是否齐全、docs 下的页面有没有误引用构建输出目录。

    所有路径都基于脚本所在目录推导，因此在任意位置调用都可以：
        pwsh -File scripts/build-demo.ps1

.PARAMETER SkipBuild
    跳过 moon build，只做复制（已经构建过、只想刷新 docs/demo/ 时用）。

.EXAMPLE
    pwsh -File scripts/build-demo.ps1

.EXAMPLE
    pwsh -File scripts/build-demo.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

# ---------- 路径推导：一切基于脚本所在目录 ----------
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$repoRoot = Split-Path -Parent $scriptDir
$docsDemo = Join-Path $repoRoot 'docs\demo'

function Write-Step([string]$text) {
    Write-Host ''
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Write-Info([string]$text) {
    Write-Host "    $text" -ForegroundColor DarkGray
}

Write-Host 'moon-foc demo 打包' -ForegroundColor White
Write-Info "仓库根目录：$repoRoot"
Write-Info "输出目录  ：$docsDemo"

if (-not (Test-Path (Join-Path $repoRoot 'moon.mod'))) {
    throw "没找到 moon.mod：$repoRoot 看起来不是 moon-foc 仓库根目录（本脚本应放在 scripts/ 下）。"
}

if (-not (Test-Path $docsDemo)) {
    New-Item -ItemType Directory -Path $docsDemo -Force | Out-Null
    Write-Info "已创建目录 $docsDemo"
}

# ---------- 待处理的目标 ----------
$targets = @(
    [pscustomobject]@{
        Name    = 'web_demo'
        Package = 'examples/web_demo'
        Output  = 'web_demo.js'
    }
)

# ---------- 1. 构建 ----------
if ($SkipBuild) {
    Write-Step '跳过构建（-SkipBuild）'
}
else {
    $moon = Get-Command moon -ErrorAction SilentlyContinue
    if (-not $moon) {
        $fallback = Join-Path $env:USERPROFILE '.moon\bin\moon.exe'
        if (Test-Path $fallback) {
            $moonPath = $fallback
        }
        else {
            throw 'PATH 里找不到 moon 命令：先装 MoonBit 工具链，或加 -SkipBuild 只复制已有产物。'
        }
    }
    else {
        $moonPath = $moon.Source
    }
    Write-Info "moon：$moonPath"

    Push-Location $repoRoot
    try {
        foreach ($t in $targets) {
            Write-Step "moon build --target js $($t.Package)"
            & $moonPath build --target js $t.Package 2>&1 | ForEach-Object { Write-Info ([string]$_) }
            if ($LASTEXITCODE -ne 0) {
                throw "moon build 失败（$($t.Package)），退出码 $LASTEXITCODE。"
            }
        }
    }
    finally {
        Pop-Location
    }
}

# ---------- 2. 复制产物 ----------
$copied = @()

Push-Location $repoRoot
try {
    foreach ($t in $targets) {
        $candidates = @(
            (Join-Path $repoRoot ("_build\js\debug\build\{0}\{1}" -f $t.Package, $t.Output)),
            (Join-Path $repoRoot ("_build\js\release\build\{0}\{1}" -f $t.Package, $t.Output))
        )
        $src = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1

        # 兜底：在 _build\js 下按文件名搜一次，布局随 moon 版本变化时也能跑
        if (-not $src) {
            $buildRoot = Join-Path $repoRoot '_build\js'
            if (Test-Path $buildRoot) {
                $hit = Get-ChildItem -Path $buildRoot -Recurse -File -Filter $t.Output -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
                if ($hit) { $src = $hit.FullName }
            }
        }

        if (-not $src) {
            throw "找不到 $($t.Output)：先确认 'moon build --target js $($t.Package)' 成功，或去掉 -SkipBuild 重新构建。"
        }

        $dst = Join-Path $docsDemo $t.Output
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $size = (Get-Item -LiteralPath $dst).Length
        Write-Host ("    复制 {0} -> docs/demo/{1}（{2:N0} 字节）" -f $src.Replace($repoRoot + '\', ''), $t.Output, $size) -ForegroundColor Green
        $copied += [pscustomobject]@{
            File  = "docs/demo/$($t.Output)"
            Bytes = $size
        }

        # 产物尾部带 sourceMappingURL，存在同名 .map 就一起复制，少一个 devtools 404
        $mapSrc = "$src.map"
        if (Test-Path $mapSrc) {
            Copy-Item -LiteralPath $mapSrc -Destination (Join-Path $docsDemo "$($t.Output).map") -Force
            Write-Info "同时复制 docs/demo/$($t.Output).map（调试用）"
        }
    }
}
finally {
    Pop-Location
}

# ---------- 3. 自检 ----------
Write-Step '自检'

foreach ($name in @('web_demo.js')) {
    $p = Join-Path $docsDemo $name
    if (-not (Test-Path $p)) { throw "自检失败：缺少 docs/demo/$name" }
    if ((Get-Item -LiteralPath $p).Length -le 0) { throw "自检失败：docs/demo/$name 是空文件" }
    Write-Info "OK  docs/demo/$name"
}

# 页面里不允许出现构建输出目录的引用（以前就是这么 404 的）
$htmlFiles = @(Get-ChildItem -Path $docsDemo -Recurse -File -Filter '*.html')
foreach ($f in $htmlFiles) {
    if (Select-String -Path $f.FullName -Pattern '_build' -SimpleMatch -Quiet) {
        throw "自检失败：$($f.Name) 里仍然引用了构建输出目录（_build），GitHub Pages 上会 404。"
    }
}
Write-Info ("OK  {0} 个页面都只引用同目录产物" -f $htmlFiles.Count)

# ---------- 4. 摘要 ----------
Write-Host ''
Write-Host '完成。本次产物：' -ForegroundColor Green
$copied | Format-Table -AutoSize | Out-String | Write-Host

Write-Host '本地预览（在仓库根目录执行）：' -ForegroundColor White
Write-Host '    python -m http.server 8765'
Write-Host '    # demo 页   http://127.0.0.1:8765/docs/demo/'
