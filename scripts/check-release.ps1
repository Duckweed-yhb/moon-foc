# scripts/check-release.ps1 — 发布一致性检查（CI 里跑，本地也能手跑）。
#
# 起因：这个仓库有多处各自写着「当前版本」——moon.mod 的 version、CHANGELOG
# 的第一段标题、README 里的 `moon add ...@x.y.z` 与 `Latest x.y.z`。发布时
# 漏改任何一处都不会报错，只是文档慢慢变成谎话。脚本把它们对齐。
#
# 英文 README（README.en.md）一起查：它不参与编译、不参与测试，是最容易长期
# 漂移的一份。moon-foc 就曾经停在 0.1.3 而实际已发 0.1.13，差了十个小版本
# 没人发现——README.md 有检查、README.en.md 没有，漏的就是这一半。
#
# 用法（仓库根目录）：
#   pwsh scripts/check-release.ps1
#   或 Windows PowerShell: powershell -File scripts/check-release.ps1
#
# 检查项：
#   1. moon.mod 有且只有一个 version，且是 x.y.z；
#   2. CHANGELOG 最新版本段标题 == moon.mod 的 version；
#   3. CHANGELOG 没有重复版本段；
#   4. README.md（必需）与 README.en.md（存在才查）里所有 `<模块名>@x.y.z`
#      与 `Latest x.y.z` 都等于当前版本。

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$modPath = Join-Path $root 'moon.mod'
$clPath = Join-Path $root 'CHANGELOG.md'
$readmePath = Join-Path $root 'README.md'
$readmeEnPath = Join-Path $root 'README.en.md'

foreach ($p in @($modPath, $clPath, $readmePath)) {
  if (-not (Test-Path $p)) { throw ('missing file: ' + $p) }
}

$mod = Get-Content $modPath -Raw
$nameMatch = [regex]::Match($mod, '(?m)^\s*name\s*=\s*"([^"]+)"')
if (-not $nameMatch.Success) { throw 'moon.mod: no name field' }
$moduleName = $nameMatch.Groups[1].Value

$verMatch = [regex]::Match($mod, '(?m)^\s*version\s*=\s*"([^"]+)"')
if (-not $verMatch.Success) { throw 'moon.mod: no version field' }
$version = $verMatch.Groups[1].Value
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
  throw ('moon.mod: version is not x.y.z: ' + $version)
}

$cl = Get-Content $clPath -Raw
$heads = @()
foreach ($m in [regex]::Matches($cl, '(?m)^##\s+\[([0-9]+\.[0-9]+\.[0-9]+)\]')) {
  $heads += $m.Groups[1].Value
}
if ($heads.Count -eq 0) {
  throw 'CHANGELOG.md: no "[x.y.z] - date" section (entries stuck under [Unreleased]?)'
}

if ($heads[0] -ne $version) {
  $msg = 'CHANGELOG newest section is ' + $heads[0] +
    ' but moon.mod says ' + $version +
    ' (forgot to rename [Unreleased] after release?)'
  throw $msg
}

$dup = @($heads | Group-Object | Where-Object { $_.Count -gt 1 })
if ($dup.Count -gt 0) {
  $names = @($dup | ForEach-Object { $_.Name })
  throw ('CHANGELOG has duplicate version sections: ' + ($names -join ', '))
}

# README.md 与 README.en.md 用同一套规则；英文版是可选文件，有才查。
$problems = @()
$checked = @()
$escaped = [regex]::Escape($moduleName)

foreach ($readme in @(
    @{ path = $readmePath; name = 'README.md' },
    @{ path = $readmeEnPath; name = 'README.en.md' }
  )) {
  if (-not (Test-Path $readme.path)) { continue }
  $text = Get-Content $readme.path -Raw
  $checked += $readme.name

  $pattern = '{0}@([0-9]+\.[0-9]+\.[0-9]+)' -f $escaped
  foreach ($m in [regex]::Matches($text, $pattern)) {
    if ($m.Groups[1].Value -ne $version) {
      $problems += ($readme.name + ' references ' + $moduleName + '@' + $m.Groups[1].Value +
        ', current version is ' + $version)
    }
  }

  foreach ($m in [regex]::Matches($text, 'Latest\s+([0-9]+\.[0-9]+\.[0-9]+)')) {
    if ($m.Groups[1].Value -ne $version) {
      $problems += ($readme.name + ' says Latest ' + $m.Groups[1].Value +
        ', current version is ' + $version)
    }
  }
}

if ($problems.Count -gt 0) {
  throw ('release metadata mismatch:' + [Environment]::NewLine + '  - ' +
    ($problems -join ([Environment]::NewLine + '  - ')))
}

Write-Output ('release consistency OK: ' + $moduleName + '@' + $version +
  ' [' + ($checked -join ', ') + ']')
