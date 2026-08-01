# DataCore

> **Your Data. Your AI. Your Control.**
>
> 开源的企业级 AI 数据平台 —— 把企业数据变成 AI 能力，让任何 AI 应用都能在你的合规边界内安全访问数据。

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)
[![Open Core](https://img.shields.io/badge/Model-Open--Core-green.svg)](https://github.com/dreamyshare/datacore)
[![MCP](https://img.shields.io/badge/Protocol-MCP-8B5CF6.svg)](https://modelcontextprotocol.io)

---

## 为什么需要 DataCore

企业的数据散落在数据库、数仓和业务系统里，而 Codex、Cursor、ChatGPT 等 AI 应用正在全面进入工作流。两者之间缺少一条**安全、可控、即插即用**的通道。

企业面临三个核心痛点：

- **断层**：AI 应用无法直接、安全地访问企业私有数据。
- **失控**：把数据库权限直接交给 AI 风险极高，缺少统一的权限与审计。
- **低效**：为每个 AI 场景手写接口成本高、口径乱、难以复用。

DataCore 的定位就是企业数据与 AI 应用之间的**安全连接层**：上传 SQL 或表结构，自动生成 AI 可直接调用的 MCP Tool，并叠加企业语义层（统一指标口径）与统一治理（权限、脱敏、审计）。

---

## 核心特性

| 能力 | 说明 |
| --- | --- |
| **AI 工具生成器** | 上传 SQL / 表结构，自动生成标准化、可被 AI 调用的 MCP Tool，无需手写接口。 |
| **企业语义层** | 统一管理指标定义、业务口径与字段含义，让不同 AI 应用"说同一种数据语言"。 |
| **MCP 注册中心** | 集中登记、发现与版本化管理所有 MCP Tool，供 Cursor / Codex / Claude 等客户端统一接入。 |
| **智能体中心** | 编排可复用的行业智能体与连接器，沉淀团队的数据 + AI 工作流资产。 |
| **权限治理** | 内置 RBAC / ABAC 权限模型、字段级脱敏与全链路审计，AI 访问始终在边界内。 |
| **在线调试台** | 可视化调试每个 MCP Tool 的输入输出，开发到上线一站完成。 |

---

## 快速开始

> 前置依赖：Docker 20.10+ / Node.js 18+

### 1. 克隆并启动

```bash
git clone https://github.com/dreamyshare/datacore.git
cd datacore
docker compose up -d
```

启动后访问 `http://localhost:8080`。

### 2. 连接你的数据源

在控制台「数据源」中填写数据库连接（MySQL / PostgreSQL / Oracle / SQL Server / MongoDB …），或通过上传 `.sql` 表结构文件完成接入。

### 3. 生成 AI 工具

进入「AI 工具生成器」→ 选择表或粘贴查询 → 点击 **生成**，DataCore 会自动产出对应的 MCP Tool 并注册到注册中心。

### 4. 在 AI 应用中使用

复制 MCP 接入地址，在 Cursor / Claude Desktop / Codex 等客户端中配置：

```json
{
  "mcpServers": {
    "datacore": {
      "url": "http://localhost:8080/mcp"
    }
  }
}
```

此后，你的 AI 助手即可在你的权限规则下安全查询企业数据。

---

## 架构概览

```
                  ┌─────────────────────────────────────┐
                  │            AI 应用层                  │
   Codex ──┐      │  Cursor / Claude / ChatGPT / 自研 Agent │
   Cursor ─┼────► │                                        │
   Claude ─┘      └───────────────────┬────────────────────┘
                                       │  MCP 协议
                  ┌────────────────────▼───────────────────┐
                  │            DataCore 平台                 │
                  │  ┌──────────┐  ┌──────────┐ ┌─────────┐ │
                  │  │ AI工具生成 │  │ 企业语义层 │ │智能体中心│ │
                  │  └──────────┘  └──────────┘ └─────────┘ │
                  │  ┌──────────┐  ┌──────────┐ ┌─────────┐ │
                  │  │MCP注册中心│  │ 权限治理  │ │在线调试台│ │
                  │  └──────────┘  └──────────┘ └─────────┘ │
                  └────────────────────┬───────────────────┘
                                       │  安全访问
                  ┌────────────────────▼───────────────────┐
                  │        企业数据源（受治理边界保护）       │
                  │  MySQL / Oracle / SQL Server / Mongo …  │
                  └─────────────────────────────────────────┘
```

---

## 使用场景

- **研发团队**：让 Codex / Cursor 直接基于真实数据库结构生成准确的代码与查询。
- **数据分析**：在对话式 AI 中安全查询指标，语义层保证口径统一。
- **售前 / 运营**：非技术人员也能通过 AI 助手获取标准化业务数据。
- **一人公司 / 小团队**：分钟级接入，免去自建数据 API 与权限系统的重活。

---

## Open-Core 模式

DataCore 采用 Open-Core 模式：

- **开源核心 + 私有部署**：社区版永久免费，可自托管，代码完全透明。
- **企业版**（付费）：高级治理能力（SSO / 细粒度 ABAC / 审计留存）、多租户、连接器市场、SLA 支持。

我们坚信，企业数据基础设施应当开源、可审计、可私有化 —— 这是"Your Control"承诺的底线。

---

## 路线图

- [x] AI 工具生成器 / MCP 注册中心
- [x] 企业语义层 / 在线调试台
- [ ] 权限治理增强（细粒度 ABAC、字段脱敏模板）
- [ ] 行业智能体模板与连接器市场
- [ ] 企业版：SSO、多租户、审计留存

---

## 贡献

欢迎参与！请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 了解开发流程与规范。

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/xxx`)
3. 提交变更 (`git commit -m 'feat: xxx'`)
4. 推送分支 (`git push origin feature/xxx`)
5. 发起 Pull Request

---

## 许可证

核心代码基于 [Apache-2.0](LICENSE) 开源。企业版功能以商业许可证提供，详见官网说明。

---

## 联系与社区

- GitHub Issues：https://github.com/dreamyshare/datacore/issues
- 文档：https://datacore.dreamyshare.com （建设中）
- 邮箱：dev@dreamyshare..com

---

*DataCore —— 让企业的每一份数据，都能安全地成为 AI 的能力。*
