# CodeAgent

macOS / iOS 原生客户端，Agent Execution Runtime 的图形界面。

## 架构

六层事件溯源运行时：

```
AgentWire (SSE)           ← agent-wire v1 协议，不修改
        │
        ▼
RuntimeEngine (Actor)     ← 唯一状态持有者，单点 ingest
        │
        ▼
ExecutionReducer          ← AgentEvent → Graph 变更（纯逻辑）
        │
        ▼
ExecutionGraph            ← Runtime Truth（节点 + 有向边）
        │
        ├──────────────────┐
        ▼                  ▼
TimelineProjection    InspectorProjection   (未来: Statistics, Cost…)
        │                  │
        └────────┬─────────┘
                 ▼
ExecutionPresentation     ← UI 模型：主题、紧凑、无障碍
                 │
                 ▼
SwiftUI                   ← 消费 Presentation，不接触原始 Graph
```

### 关键约束

1. `ExecutionGraph` 是 Runtime 层唯一的可变状态。`RuntimeSnapshot` 不可变。
2. `ConversationViewModel` 只订阅，不 reduce。只有 `await engine.ingest(event)`。
3. `ExecutionNode` 不存储在 `ExecutionGraph` 中。它是 Projection 的输出。
4. `ReducerInternal`（流式缓冲区）不在 `RuntimeSnapshot` 中。它对 `ExecutionReducer` 私有。
5. `MergePolicy` 注入到 `TimelineProjection`，不硬编码在 Reducer 里。
6. SwiftUI 消费 `ExecutionPresentation`，不消费原始 `ExecutionNode`。

## GUI 设计原则

目标：**Claude Code GUI 的感觉** — Thinking 是叙事主线，工具是叙事中的行动插入。

### Thinking 卡

- 永远展开，**不折叠**。它是 agent 在对你说话。
- 紫色左边框 + 斜体文字，视觉上区别于工具，但有连续的叙事感。
- Streaming 时边框更亮，带 pulse spinner。
- 思考文字先于工具调用出现 — 用户在工具执行前就知道 agent 为什么这样做。

### Tool 卡

- 彩色状态图标（🔵 运行中 / ✅ 完成 / ❌ 失败 / ⚡ 自动审批）。
- 运行时自动展开，完成后默认折叠。
- 展开时显示参数、输出、Artifact→Inspector 链接。
- 工具卡和前面的 Thinking 卡视觉上紧密相连（间距 6px）。

### Observation / Reflection 卡

- **永远展开**。这是 agent 的 "我看到什么" 和 "我怎么想的"。
- Observation → 蓝色左边框，Reflection → 紫色左边框。
- 它们是思考→行动→观察→反思循环中的关键环节。

### 视觉节奏

```
┃ 🤔 THINKING
┃ I need to check the project structure first…
└─────────────────────────────────────────────
      ↓ 6px
┌─────────────────────────────────────────────┐
│ 📁 list_files                       running │
└─────────────────────────────────────────────┘
      ↓
┃ 👁 OBSERVED
┃ Found 12 files in src/
└─────────────────────────────────────────────
      ↓
┃ 🤔 THINKING
┃ Now let me read the main entry point…
└─────────────────────────────────────────────
      ↓
┌─────────────────────────────────────────────┐
│ 📄 read_file      main.swift      ✓        │
└─────────────────────────────────────────────┘
      ↓
┌─────────────────────────────────────────────┐
│ Your project uses async/await pattern…      │  ← 最终答案
└─────────────────────────────────────────────┘
```

### Agent 感的核心

不是漂亮的 UI，而是 **思考 → 行动 → 观察 → 反思** 的循环被完整呈现：

- 用户在工具执行前就知道 **为什么**。
- 用户在工具执行后看到 agent **观察到了什么**。
- 用户看到 agent 对观察结果的 **反思**。
- 所有这一切按时间顺序自然流淌，不折叠、不隐藏。

## 包结构

```
Packages/
├── CoreKit/       — 基础层：JSON、WebSocket、网络、持久化
├── CodeAgentUI/   — UI + Runtime Engine
│   └── Sources/CodeAgentUI/
│       ├── Core/
│       │   ├── AgentEvent.swift        — v1 事件协议（不改）
│       │   ├── AgentWireSocket.swift   — WebSocket 封装
│       │   ├── RuntimeClient.swift     — HTTP + WS 协议
│       │   └── RuntimeEngine/          — v2 事件溯源引擎
│       │       ├── ExecutionGraph.swift
│       │       ├── ExecutionReducer.swift
│       │       ├── ExecutionNode.swift
│       │       ├── TimelineProjection.swift
│       │       ├── MergePolicy.swift
│       │       ├── ExecutionPresentation.swift
│       │       └── RuntimeEngine.swift
│       └── Features/
│           └── Conversation/
│               ├── Components/         — ThinkingCard, ToolCard, TodoCard, MessageBubble
│               ├── Views/              — ChronologicalTimelineView, ExecutionNodeViews
│               ├── ViewModels/         — ConversationViewModel (薄订阅者)
│               └── Models/             — ConversationState (过渡期保留)
└── DesignKit/     — 设计系统
```

## 开发

```bash
# 启动开发服务
codeagent serve

# 构建 macOS 客户端
xcodebuild -scheme CodeAgent -sdk macosx -destination 'platform=macOS' build
```
