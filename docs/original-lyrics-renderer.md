# 原版歌词渲染引擎移植

## 当前代码交付

- Android WebView 与 Flutter 播放器的时间轴桥接。
- 本机 127.0.0.1 随机端口的只读静态资源服务，WebGL、ES Module 和
  Worker 均通过 HTTP 同源加载，不要求 unsafe file:// 权限。
- 资源列表按构建产物生成 allowlist，拒绝任意文件路径；
  AndroidManifest 已对白名单回环域名单独放行，不需要扩大全局明文权限。
- 当前歌曲的原始毫秒时间戳转换为渲染器秒时间戳。
- 歌曲 / 歌词切换、暂停、拖动进度、主题色、五频段音频数据同步。
- Web 侧发起 seek 时回到 Flutter 的唯一播放器，不启动第二份音频。
- Flutter Native 模式默认保留；原版资源未打包或加载失败时自动降级。
- 原版效果沿用上游模式注册表：本项目 UI 不显示上游项目品牌或其英文内部 ID。

**需要特别说明：当前仓库仅包含桥接源码和打包脚本，
尚未包含编译后的原版 React/PixiJS/Three.js WebGL 资源。**
\`assets/web/folia_stage_ready.json\` 默认 \`available: false\`。
所以仓库直接编译出的 APK 目前仍然使用 Flutter 版简化渲染。
不得把这一阶段描述为已经完成 17 种原版特效的安装包。

## 构建原版视觉资源

前置要求：Node.js 24+、Git、足够存储空间、可访问 npm 和 GitHub 的环境。

在本项目仓库根目录执行：

\`\`\`bash
node scripts/folia_stage/build.mjs
\`\`\`

脚本从固定的上游版本
\`8e8009f76bbb37c932ea275f848a0a2a65171fe9\`
获取代码，安装锁定依赖，使用 Vite + React 构建**真实的上游渲染器**
及其 17 个模式。此过程只生成 Flutter 离线静态资源，
不启动任何 GitHub Actions，也不会修改播放引擎。

如果已经下载上游源码，可指定：

\`\`\`bash
FOLIA_SOURCE_DIR=/path/to/folia-major node scripts/folia_stage/build.mjs
\`\`\`

成功后才把 \`assets/web/folia_stage_ready.json\` 改成 true，并写入允许访问的文件清单。
生成的 HTML、JS、CSS、版权许可文件均放在 \`assets/web/\`，
与现有 \`pubspec.yaml\` 的资产目录配置一致。

若 Vite 构建失败，脚本会中断，*不会启用未完成的渲染资源*。
需要注意运行上游的包安装和构建属于执行第三方代码，应使用隔离构建环境。

## Android 实测优先检查

1. 检查本机回环 HTTP 静态服务能正常提供 WebView 所需的 HTML、ES 模块、
   CSS、字体及 WebGL 资源；检查网络安全配置未意外拦截 127.0.0.1。
2. 检查 17 个模式在横竖屏、播放暂停、进度跳转与切歌后是否有画面。
3. 用逐字 KRC/TTML 检查时间准确性，LRC 只提供行级时间，不编造逐字。
4. 用真机 GPU profiler 测 GPU 占用、WebGL 上下文丢失与低端机降级。
5. 检查原生模式与原版模式切换时，不重复创建多个后台 WebGL 场景。

未经成功的分析、打包、真机测试之前，不将其标记为稳定版。
之前 Actions 已经失败一次；下次启动必须得到维护者单独批准。

## 许可证

原版渲染器及其来源：
https://github.com/chthollyphile/folia-major

其 AGPL-3.0 许可证与对应版权告知，须随编译后源码与发行包保留；
打包脚本复制上游 LICENSE 到离线资源目录。
本项目 AGPL-3.0 许可证也保持不变。详见
\`docs/lyrics-animation-attribution.md\` 和 \`THIRD-PARTY-NOTICES.md\`。

## 手机端构建路径

你的 fork 的 `.github/workflows/three-style-validation.yml` 是**仅手动运行**的工作流。
获维护者批准后，可在 Actions 界面启动单次构建；流程先检查 Flutter 代码与测试，
再通过 Node 24 构建固定版本的原版渲染资源，最后将资源打入 Android APK。
如果任一步失败，该次运行会立即停止；不得在未重新获得授权时自动重跑。
