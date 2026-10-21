# 验证范围

已审定版本：官方 v2.0.3，汉化修订 2026-10-21-console-usability。

本仓库不附带个人日志、模型或环境备份。维护者保留的本机证据不能直接当成任意用户环境的性能保证。

## 可重复检查

```sh
python3 -B tools/check_public.py
python3 -B -m unittest discover -s tool_tests -v
python3 -B tools/localize.py verify --source .cache/upstream
python3 -B tools/document_sources.py --check
python3 -B tools/validate.py --source .cache/upstream --python /path/to/python
```

- 重新生成的中文源码应与提交的源码逐字节一致，Backend 源码与官方版本一致。
- [译文来源索引](translation_sources/README.md)核对 971 处资源与原文／译文位置、参考编号和生成文档一致；引用用于概念核对，不等同于所有说明得到论文证明。
- 原版／中文版 170 组训练配置相同；13 项显示合同、13 项数值编辑合同。
- 官方 11 项 Swift 测试及 9 项 Python 测试；5 项指标读数测试含 13 个参数化用例。
- 维护工具检查稳定版本识别、同名标签变动、旧版本不降级、归档越界／链接／重复条目、隐私检查与原版应用内容变动拒绝。工具不绕过 TLS 证书或主机名校验。
- 构建逐项核对官方应用清单，复制原 Backend/vendor 后再比较其完整内容；本次对应 89 个文件，包含官方应用已有的 bytecode。

Python 测试模拟 MLX 等训练依赖，不加载模型，但仍需 NumPy。可用 `--python` 指定已有 NumPy 环境；工具不安装本机依赖。CI 在临时独立环境安装 `validation/test-requirements.txt`，不使用训练环境。无需安装 `Backend/requirements.txt`；该文件按上游原样保留，不要为了测试修改正在使用的环境。

## 已有的界面与数值观察

已检查训练页双语标签、参数输入、图例、Online DPO 页面、控制台摘要，以及窄窗展开控制台后的上下布局。正式窗口曾取得 880 pt 窄窗与放大宽窗的清晰截图；设置区滚动时控制台保持显示。个人窗口截图不随仓库发布。

离线控制台样例的普通上／下滚动、清空、折叠／展开与日志保留已检查。五个原本位于底部时的日志追加布局检查点通过；原来的滚动实现未因此改写。

早期有限 SFT 对照的 loss 和 adapter 哈希一致；计时受同机负载与缓存影响，不足以得出统计速度等价结论。本次公开发布整理不新增模型训练。

## 已知边界

- 未穷尽所有模型、算法、窗口尺寸、macOS 版本、长时间运行或辅助功能。
- 特殊辅助功能“滚到末尾”动作曾在离线样例中触发 SwiftUI 内部异常；之后普通滚动通过。保留原版日志列表实现，未把特殊辅助功能路径记为通过。
- 一次坐标拖动分隔线未观察到位置变化，不将其计为拖动验收通过；自动切换布局、折叠／展开及独立设置滚动已有对应观察。
- 构建的本地 ad-hoc 签名不等于 Apple Developer ID 签名或公证。
- GitHub Actions 的远端运行结果应以实际工作流为准；仅在本机跑通不代表远端 CI 已运行。
