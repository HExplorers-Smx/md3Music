# MD3Music 手动自选打包

入口：GitHub 仓库 → **Actions** → **MD3Music 自选打包** →
**Run workflow**，先选择目标分支，再选择构建选项，最后按一次绿色按钮。

本功能参考 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
手动构建工作流的交互方式，但仅启用 md3Music 仓库实际支持的平台。
目前**没有** iOS、macOS、Linux 构建选项，Windows 只提供 x64 便携 ZIP。
新工作流仅有 `workflow_dispatch`：push、PR、tag 都不会自动运行它。
工作流安装在默认分支 `rust-local-force` 以确保 Actions 页面出现运行入口，
并同步至 `ui/three-style-overhaul` 开发分支。

## 可选项

| 选项 | 用途 |
|---|---|
| build_android | 构建 Android，默认开 |
| build_windows | 同时或单独构建 Windows x64 便携 ZIP，默认关 |
| android_variant | standard 标准版 / depth3d 内置 3D 封面 / tv 遥控版 / apple-music 随身听兼容包 |
| android_format | apk-split 按 CPU 拆分 / apk-universal 全 ABI 单 APK / aab 商店包 |
| android_abi | arm64 / arm32 / x64 / all（arm64、arm32、x86_64） |
| android_mode | debug / release |
| android_renderer | skia / impeller |
| original_lyrics | 构建并内置原版 WebGL 歌词资源，实验性，默认关 |
| run_checks | Flutter 静态检查及当前分支存在的专项测试，默认开 |

**推荐初次构建**：Android=true，Windows=false，
standard + apk-split + arm64 + release + skia，
original_lyrics=false，run_checks=true。单次只构建一个 Android 组合。

**ABI 注意事项**：
- apk-split：all 一次构建三份 APK，分别上传；也可单选某架构。
- apk-universal：始终内置 arm64+arm32+x86_64；ABI 下拉选项会被忽略。
- aab：只允许 release，使用 ABI 下拉框指定目标平台。
- depth3d 和 apple-music 目前只允许 arm64；不能使用 apk-universal。
- 3D 封面版需要分支里已经提交模型资源。
- tv 版使用 `tv` flavor 和 `MD3_TV=true`。
- 随身听兼容版使用 standard flavor 并覆盖 Android applicationId，
  不会修改 Java/Kotlin 包名或音频引擎，请避免与具有同一包名的 App 冲突。

**原版歌词**仅作用于 Android。开启后，CI 会执行
`scripts/folia_stage/build.mjs`，从锁定版本构建原版视觉资源。
此模块尚未经过完整 APK 真机验证，因此可能暴露编译或 WebGL 错误。
普通用户应关闭它；未完成资源构建时流程会立即失败，而不是打一个缺特效的包。

## 签名与下载

正式构建可在仓库 **Settings → Secrets and variables → Actions** 配置：
`SIGN_KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、
`KEY_PASSWORD`、`KEY_ALIAS`。
未配置时 Android Gradle 使用 **debug 签名**作为后备，
即使构建模式为 release 也不等于可上传应用商店的正式签名包。
签名秘密不会写进仓库，也不会在 Actions 日志中打印。

编译成功后打开该次 Actions 运行页面最下方的 **Artifacts**。
架构拆分 APK 分别上传，通用 APK/AAB 单独上传，Windows 为便携 ZIP；
Android 另附 SHA256 文件。产物保留 14 天。
工作流不会创建 GitHub Release，也不会自动推送任何构建产物到代码仓库。

## 编译失败处理规则

单次手动运行中任一关键步骤失败即停止对应构建；
**没有自动重跑、自动纠错、失败后再次触发等机制**。
如果用户把失败日志交给开发者，修复源码后**必须再次询问用户**，
取得明确许可才可以再次启动 Actions。此前的 CI 失败不等于
授权自动进行下一次验证。

与旧的 debug-build、build-windows 及标签发布工作流并存，
不擅自更改它们的行为。
