# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与语义化版本。

## [0.1.3] - 2026-11-10

### Added

- `angle/` 补极对数边界（`pole_pairs = 0`）与负机械角度归一化用例；测试数 33 → 36。

### Changed

- `moon fmt` 全仓格式化；CI 增加 `moon fmt --check` 步骤。

## [0.1.2] - 2026-11-09

### Changed

- 英文 README 的夹具措辞与安装版本对齐到 0.1.2。
- `moon fmt` 全仓格式化；CI 增加 `moon fmt --check`。

## [0.1.1] - 2026-11-09

### Added

- `scripts/gen_fixtures.py`：20 组由 Python 按教材公式独立算出的数值基准，覆盖线性区与过调制区，期望值不取自本库输出。
- 六扇区全覆盖的扇区判断测试，以及 θ=π/6 的 T1/T2 与三相占空比手算绝对值基准。

### Changed

- 测试数 23 → 33；README 的测试命令补显式 `--target`。

## [0.1.0] - 2026-11-08

### Added

- 首次发布：`coord/` 的 Clarke / Park / 反变换，`svpwm/` 的扇区判断、T1/T2 与过调制限幅，`angle/` 的机械角度到电角度换算，`examples/demo`。
