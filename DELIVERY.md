# 发布与验证

在 MoonBit 工程中运行 `moon add Duckweed/moon-foc@0.1.17` 安装此版本。

## 从源码复现

在仓库根目录运行以下命令。

```sh
moon fmt --check
moon check --target native --deny-warn
moon test --target native
moon run examples/speed_loop --target native
```

示例在同一电机模型中施加 1 N·m 负载阶跃，比较 20 Hz 与 40 Hz 速度外环的转速跌落和恢复时间。读数来自单向旋转的离线仿真。

[使用说明](README.md) · [版本记录](CHANGELOG.md) · [代码与数据来源](PROVENANCE.md)
