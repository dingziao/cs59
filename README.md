# Elm Demo — 美观的计数器与任务示例

这是一个更完整的 Elm 前端示例，包含：

- 计数器（增减按钮）
- 任务输入与列表（添加、切换完成、清除已完成）
- 响应式与现代暗色风格（`styles.css`）

快速开始（Windows PowerShell）：

1. 安装依赖：

```powershell
npm install
```

2. 构建 Elm（输出为 `elm.js`）：

```powershell
npm run build
```

3. 启动本地静态服务器：

```powershell
npm run serve
# 然后在浏览器打开 http://localhost:8000
```

提示：`package.json` 使用 `npx` 来调用本地/远程工具。如果你已经全局安装了 `elm`，可以直接运行：

```powershell
elm make src/Main.elm --output=elm.js
```

主要文件：
- `src/Main.elm`：应用逻辑与视图（计数器 + 任务）。
- `styles.css`：应用样式（暗色、响应式布局）。
- `index.html`：页面入口，加载 `styles.css` 与 `elm.js` 并挂载 Elm 应用。
- `elm.json`：Elm 项目描述。

如果你想我做的事情：
- 帮你运行 `npm install` 并构建（我可以生成 PowerShell 命令）。
- 把项目初始化为 git 仓库并创建首次提交。
- 增加持久化（例如把任务保存在 localStorage）。

告诉我你想要哪个，我来继续。 

Elm + WebLLM integration (ports)
--------------------------------

This workspace now includes a minimal Elm → JS integration using Elm ports.

- `src/Main.elm` uses `port sendToJs : String -> Cmd msg` to send user messages to JS,
	and an incoming port `fromJs` to receive model replies.
- `webllm-ports.js` (loaded as an ES module from `index.html`) imports `@mlc-ai/web-llm` via CDN
	and creates a `CreateMLCEngine(MODEL_ID)` instance. It subscribes to `app.ports.sendToJs`
	and forwards model responses back to Elm with `app.ports.fromJs.send(...)`.

Important:
- `webllm-ports.js` uses a placeholder `MODEL_ID = "Qwen-0.5b"`. Replace this with your actual
	model id or hosted model path if you have one. Loading and instantiating a real model may
	require downloading weights and can be slow.
- For local development you can keep the placeholder; the JS will report initialization errors
	in the browser console if the engine cannot be created.

How to run the demo (PowerShell):

```powershell
npm install
npm run build
npm run serve
# Open http://localhost:8000 in your browser
```

If you want, I can:
- Replace the placeholder `MODEL_ID` with a specific model URL you provide.
- Improve UI/UX (loading state, streaming responses, error handling).
- Remove the CDN import and wire a local npm build workflow for WebLLM (heavier setup).
