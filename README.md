# MLX LoRA Studio 中文版

基于 [MLX LoRA Studio](https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio) 的非官方简体中文适配，适用于 Apple Silicon Mac。原作者：Gökdeniz Gülmez；中文适配维护账号：inothing-cyber。

当前已审定：**官方 v2.0.3**，汉化修订 **2026-10-21-console-usability**。不代表未来官方版本已兼容。

## 中文版包含什么

- 一般界面、帮助与算法指南的中文说明；参数采用“中文＋英文原名”，例如“学习率（Learning Rate）”。
- SFT、LoRA、DPO、token、tokens/s、模型 ID、JSON 字段、公式与提示词保留原文；Live memory 显示为“实时内存”。
- 常驻参数标签、数值输入提示、可换行图例，以及窄窗展开控制台时的上下布局。
- 独立审定的吞吐量显示修复：只修正读数和历史记录的显示，不重写已有日志或指标文件。

训练后端、模型权重、Python 环境与训练配置不会因汉化而更新。971 是审定的显示资源出现次数，不是翻译覆盖率百分比。

## 下载与使用

从 [Releases 下载中文版应用 ZIP](https://github.com/inothing-cyber/MLX-LoRA-Studio-zh-CN/releases/latest)，解压后将应用放入“应用程序”。`Source code` 和 `source` ZIP 是源码，需要自行构建。

支持 Apple Silicon / macOS 14 及以上。当前构建使用本地 ad-hoc 签名，**没有 Apple Developer ID 公证**；签名核对不等于已获得 Apple 公证。不要运行来源不明的重打包版本。

中文版保留原应用 Bundle ID 以沿用原配置；原版与中文版不要同时运行。更新前应等待 Studio 自己的任务结束，保留旧版以便回退。外部终端启动的 Python 任务不会自动出现在 Studio 的控制台。

## 官方更新后怎么办

本仓库每天检查官方最新稳定版，也可在 Actions 手动运行“检查官方版本”。新版本、同名标签指向变化或无法识别的版本号会提示需要审查。网络/API 失败会报告失败，不会被当成“没有更新”。

**检测 → 文案迁移报告 → 审查参数与补丁 → 回归检查 → 发布对应中文版。** 检查工作流只读官方信息，不会自动合并代码、替换本机软件、更新 Python 或发布未经验证的应用。完整步骤见 [版本维护说明](docs/UPDATES.md)。定时任务要在本仓库默认分支上启用 GitHub Actions 后才运行，不是本机后台服务。

## 构建

需要 Python 3.10+、Xcode 26+ 和对应版本的官方原版 `.app`。构建只读取官方应用，不安装或启动任何应用，也不执行上游的 `build_and_run.sh`。

```sh
# 下载锁定的官方源码，不执行其中的代码。
python3 tools/upstream.py fetch --output .cache/upstream

# 核对源码、译文、补丁与当前提交的中文源码一致。
python3 tools/localize.py verify --source .cache/upstream

# 路径换成已下载的官方 v2.0.3 应用；输出目录必须尚不存在。
python3 tools/build.py --original-app "/path/to/MLX LoRA Studio.app" --output dist
```

构建会核对官方应用内容与已审定清单，生成中文 `.app`、ZIP、SHA256SUMS 和构建报告。后端完整复制并逐项比较，不下载依赖或更换训练器。除了已逐字节审定的可选 Python 缓存，额外文件或内容变化会停止构建；建议使用新下载、未使用过的对应官方应用。不能靠修改版本号跳过审查。

## 验证与已知边界

见 [验证说明](docs/VALIDATION.md)。当前训练配置对照及原有测试通过，早期有限 SFT 检查的 loss 与 adapter 哈希一致；没有统计依据承诺所有模型／算法绝对零速度差异。

普通日志滚动、清空、折叠／展开已离线检查。特殊辅助功能滚动动作曾在 SwiftUI 内部异常；没有宣称所有辅助功能接口均通过。当前布局画面只覆盖已检查的窄窗／宽窗，未穷尽所有尺寸与系统版本。

## 源码组织

`Sources/` 是当前中文应用源码；`Backend/` 保持官方源码。`localization/` 保存独立译文、术语、精确补丁和版本清单。`tools/` 提供可重现汉化、版本检查与构建工具。缓存、安装包、模型和私人验收记录不进入源码仓库。

## 许可证与来源

主程序及本仓库汉化工具按 [MIT](LICENSE) 发布，保留原作者版权。原应用内置的 mlx-lm-lora 按 [Apache 2.0](licenses/mlx-lm-lora-Apache-2.0.txt) 发布，许可证随构建包保留。参见 [NOTICE](NOTICE) 与[第三方说明](docs/THIRD_PARTY.md)。本项目未附带模型／数据集，也不替其授权作保证。
