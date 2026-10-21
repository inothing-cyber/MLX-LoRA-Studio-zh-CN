# 跟随官方版本维护

本仓库当前只审定官方 v2.0.3，commit `69e34a31aca717b6d5a0a4f5306e25cf7c0b18f1`。译文、显示补丁、读数修复与官方版本锁分开保存。官方更新不会自动覆盖本机中文版；旧中文版也不会自动获得新版功能。

## 发现新版

GitHub Actions 的“检查官方版本”每天运行一次，也支持手动运行。需要仓库默认分支存在该工作流，且 GitHub Actions 已启用。GitHub 的定时任务可能延迟；长期无活动的公开仓库可能需要重新启用，不能把它当作保证准点的通知服务。

```sh
python3 tools/upstream.py check
```

工具只读取官方最新稳定 Release，并解析标签实际指向的 commit。同一标签指向变动也会要求审查。旧版本不会引发降级；预发布版不自动纳入稳定版适配。

检测结果写入 `.build/upstream-review.json`。工作流在有待适配版本时显示失败／需要处理，并保存报告；这表示需要维护者介入，不是应用自行更新。API、网络或证书失败会让检查失败，不会报告“已是最新”。不会自动提交 Issue、向他人发送消息或改变仓库代码。

## 生成迁移报告

从报告取得新版本完整 commit，下载到新的目录。这里的值应替换为实际的 40 位 commit SHA；下载过程不执行源码。

```sh
python3 tools/upstream.py fetch --commit NEW_COMMIT_SHA --output .cache/candidate
python3 tools/localize.py migrate --source .cache/candidate > .build/migration-report.json
```

报告会列出可找到的既有原文、消失／变化的原文、新增候选文案、需要重新审查的补丁文件，以及发生变化的模型／后端文件。词法扫描的候选并不都是用户界面文本；“原文仍存在”也不等于该补丁已兼容，需结合上下文核对。

取得对应官方应用后，可生成候选源码、字符串及应用清单，减少手工整理。输出目录必须全新，源代码和应用不会被修改；候选清单明确标记为“未审定”，不会替换当前版本锁。

```sh
python3 tools/review_candidate.py --source .cache/candidate --commit NEW_COMMIT_SHA --original-app "/path/to/official.app" --output .build/candidate-review
```

## 审查与重新建立版本锁

1. 对比官方变更。保留新版官方训练逻辑，中文改动只作用于显示；如果官方更新训练算法，要以同一新版官方代码作为对照，不拿旧版配置值强行覆盖新版。
2. 重新审查术语、原文位置、插值表达式与新增说明。SFT、LoRA、token、tokens/s、模型 ID、字段、公式及用户提示词保持原文。参数标签继续采用中文＋英文原名。
3. 审查候选清单后，更新 `source-baseline.json` 的官方 commit／文件哈希与 `string-candidates.json`。重新审定 TSV 选择器、补丁边界与最小必要的 native 显示辅助代码；不要全局替换用户数据或协议值。
4. 用该版本官方应用重新生成 `original-app-manifest.json`，核对官方应用与源代码、内置训练器版本。更新 `reviewed-upstream.json` 的版本、commit、清单哈希和汉化修订。这些是维护者审查后提交的版本锁，检测脚本不会替你改写或批准。
5. 执行 `localize.py catalog` 重新生成审定词条，再用 `prepare --output` 生成到全新目录。核对生成的 `Sources/MLXLoRAStudio`、`Backend`、`Tests`，再同步当前仓库源码。不要把生成目录里的官方发布工作流或构建脚本复制到本仓库工作流。
6. 核对[译文来源与论文关系](TRANSLATION_SOURCES.md)，按新官方 commit 重新审查 `document_sources.py` 的指南区段和引用范围，更新书目后生成、检查来源索引。检测到原文位置仍存在不代表论文支持范围自动成立。

```sh
python3 tools/localize.py catalog --source .cache/candidate
python3 tools/localize.py prepare --source .cache/candidate --output .build/candidate-zh
```

更新目录和源码并完成上述引用审查后，运行 `python3 tools/document_sources.py --write` 与 `--check`。来源工具按 `.cache/upstream` 中已审定的源码核对；先把审定源准备到该位置，不用未批准候选替换版本锁。

版本锁是受版本控制的审查记录，不是外部签名认证；不能把“改了哈希后能构建”当成已经完成审查。首次迁移应在独立分支上进行，所有检查通过后再合入默认分支。

## 验证与发布

```sh
python3 tools/check_public.py
python3 tools/validate.py --source .cache/candidate --python /path/to/python
python3 tools/build.py --source .cache/candidate --original-app "/path/to/official.app" --output dist
```

核对对应版本的配置／命令、原有测试、读数与输入显示、代表性界面、窄窗及日志操作。必要时另行安排小规模真实训练；训练模型、数据与输出留在本地，不进入仓库。改动测试后应重新核对脚本中的预期数量，不能只改测试数量以掩盖失败。

发布标签应同时包含官方版本和汉化修订，例如 `v2.0.3-zh.20261021`。在 Releases 上传应用 ZIP、SHA256SUMS 和说明，明确“非官方”、适配版本、修改范围、签名／公证状态与已知边界。仓库没有自动公开发布安装包的工作流。

用户安装前等待 Studio 自己的任务结束，保存原版本，再正常替换中文版。构建工具不结束进程、不安装应用，也不更新 Python 环境。出现问题可以退出空闲 Studio 后恢复保留的旧应用；不要清空训练目录或用户配置作为常规回退方式。

参考：[GitHub 定时工作流](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)、[Release API](https://docs.github.com/en/rest/releases/releases)、[最小化工作流权限](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token)。
