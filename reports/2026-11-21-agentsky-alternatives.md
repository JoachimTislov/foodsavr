# Market Research: Alternatives to AgentSky (agentsky.dev)

**Date:** 2026-11-21  
**Target Analyzed:** [AgentSky Pricing & Architecture](https://agentsky.dev/pricing)  
**Research Topic:** Alternatives to AgentSky's unified agent harness routing, cloud microVM execution, and pricing model.

---

## 1. Executive Summary & AgentSky Baseline

AgentSky positions itself as an "all-in-one" platform combining agent harness routing (Claude Code, OpenAI Codex, OpenClaw, Hermes), on-demand cloud execution with suspend/park features, and multi-channel communication (Slack, Discord, iMessage, WhatsApp).

### Current AgentSky Pricing Model (as of Nov 2026)
* **Cloud Compute:** `$0.461/hr` awake (2 vCPU, 8 GB RAM by default, billed per second; `$0` while parked/idle). Storage is 1 GiB free per workspace; `$0.04/GiB-month` thereafter.
* **Model Pricing:** 30% discount on Claude and GPT maker list price.
* **Pricing Changes (Effective Dec 12, 2026):**
  * Claude and GPT remain at 30% off maker list price.
  * DeepSeek shifts to maker's list price **+ 20%**.
  * All other models shift to **twice the listed price (2× / +100% markup)**.
  * Meeting recording: `$1.00/recorder hour` + `$0.30/recorded hour`.
  * Outbound agent email: `$0.0002/message`.

---

## 2. Categorized Alternatives

Depending on which architectural layer is being replaced, the market breaks down into four main alternatives:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        AGENT ECOSYSTEM LAYERS                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Unified Harness Routers   │ HarnessRouter (UHP), Opengeni, MatrixOS │
│ 2. Sandboxed MicroVM Compute │ E2B, Daytona, Modal Sandboxes, Fly.io   │
│ 3. Model Gateways & Token Hub│ OpenRouter, LiteLLM Proxy               │
│ 4. Open-Source Autonomous IDE│ OpenHands (OpenDevin), Hermes, OpenClaw │
└────────────────────────────────────────────────────────────────────────┘
```

### Layer 1: Unified Agent Harness Routers & Workspaces (Direct 1:1 Competitors)

These platforms provide a single unified API or workspace to execute coding agents (Claude Code, Codex, Hermes, OpenClaw) without locking into AgentSky's compute and marked-up token pricing.

| Platform | Primary Strength | Pricing Model | Key Features |
| :--- | :--- | :--- | :--- |
| **[HarnessRouter](https://harnessrouter.ai)** | Drop-in API for multiple agent harnesses | • **Community (OSS):** Free ($0) Apache-2.0<br>• **Cloud:** Freemium; BYOK + metered compute | Built on the open **Unified Harness Protocol (UHP)**. Drives Claude Code, Codex, Hermes, and 20+ other harnesses. Can be self-hosted to bypass SaaS fees entirely. |
| **[Matrix OS](https://matrixos.dev)** | Persistent cloud developer OS for agents | • **Starter:** $20/month (2 vCPU, 4 GB, 80 GB disk)<br>• **Builder:** $100/month (4 vCPU, 8 GB, 160 GB disk)<br>• **Model:** BYOK (0% token markup) | Replaces per-second billing with predictable monthly compute. Keeps persistent Git worktrees, dev servers, and port forwarding alive for CLI agents. |
| **[Opengeni](https://opengeni.ai)** | Enterprise agent runtime & governance | • **Open Source:** Free ($0) Apache-2.0<br>• **Cloud:** Model Cost + 5% markup (no seat fees) | Focuses on embedding agents into SaaS products with durable sessions, streaming telemetry, and human-in-the-loop review gates. |

### Layer 2: Dedicated Cloud Sandboxes & Agent MicroVMs

If AgentSky is primarily used for its isolated, per-second execution sandboxes with sleep/wake capabilities:

| Platform | Underlying Tech | Cost (2–4 vCPU, 4–8 GB RAM) | Features |
| :--- | :--- | :--- | :--- |
| **[E2B](https://e2b.dev)** | Firecracker microVMs | • Free tier: 20 concurrent sandboxes + $100 credits<br>• 2 vCPU / 4 GB: **~$0.166/hr**<br>• 4 vCPU / 8 GB: **~$0.331/hr** | Sub-second boot times (<200ms). Billed per second, halts billing on pause. **~28% to 64% cheaper** than AgentSky's compute. |
| **[Daytona](https://daytona.io)** | Secure container / microVM environments | • Free trial: $200 credits<br>• 2 vCPU / 4 GB: **~$0.165/hr**<br>• Paused: disk-only rates | Full dev environments with Git worktree isolation and VPC / Bring-Your-Own-Cloud (BYOC) support. |
| **[Modal](https://modal.com)** | Serverless container sandboxes | • Free tier: $30/month credit<br>• Billed per millisecond | Ideal for Python workloads, containerized agent loops, and workloads that require optional GPU acceleration. |
| **[Fly.io Machines](https://fly.io)** | Fast-resuming microVMs | • ~**$0.02 to $0.05/hr** active<br>• **$0** when suspended (RAM snapshot to disk) | Lowest cost for self-managed microVM setups. Wakes from cold suspend in ~300ms upon HTTP request. |

### Layer 3: Model Aggregators & Gateways (Token Cost Optimization)

AgentSky's upcoming price changes add up to 100% markups on non-core models. If multi-model routing is required:

* **[OpenRouter](https://openrouter.ai):** Routes to 200+ models at maker list price or below, with prompt-caching discounts, automated provider fallbacks, and $0 monthly platform/seat fees.
* **[LiteLLM Proxy](https://litellm.ai):** Free open-source OpenAI-compatible proxy gateway. Supports budget caps, rate limiting, and unified logging across Anthropic, OpenAI, DeepSeek, Vertex AI, and local Ollama/vLLM endpoints.

### Layer 4: Open-Source Autonomous Agent Runtimes

* **[OpenHands](https://github.com/All-Hands-AI/OpenHands)** *(formerly OpenDevin)*: Full autonomous software engineering environment running in Docker containers. Self-hosted is 100% free with BYOK.
* **[Hermes Agent](https://nousresearch.com)** (Nous Research): Open-source agent with long-term memory, subagent orchestration, and skill trees.
* **[OpenClaw](https://github.com/openclaw)**: Lightweight terminal-first agent runtime for scripting and tool execution.

---

## 3. Cost Comparison Matrix

**Benchmark Scenario:** 3 hours of active agent execution per day (~90 active hours/month) using Claude 3.5 / 3.7 Sonnet:

| Solution Architecture | Monthly Compute Rate | Token Markups | Platform / Seat Fees | Estimated Monthly Total |
| :--- | :--- | :--- | :--- | :--- |
| **AgentSky Cloud** | **$41.49** ($0.461/hr × 90h) | -30% on Claude/GPT; +20% to +100% on others | $0 | **~$60 – $75** |
| **Matrix OS (Starter)** | **$20.00** flat | 0% (BYOK directly from provider) | $0 | **~$45 – $55** |
| **E2B Sandboxes + BYOK** | **$14.94** ($0.166/hr × 90h) | 0% (BYOK directly from provider) | $0 | **~$40 – $50** |
| **HarnessRouter (OSS) on VPS**| **$6.00** (e.g. Hetzner/DigitalOcean) | 0% (BYOK directly from provider) | $0 | **~$31 – $41** |
| **OpenHands (Self-Hosted)** | **$0.00** (Local hardware) | 0% (BYOK directly from provider) | $0 | **Tokens Only (~$25 – $35)** |

---

## 4. Key Recommendations

1. **For Direct 1:1 Replacement without Vendor Lock-in:**  
   Adopt **[HarnessRouter](https://harnessrouter.ai)**. Its implementation of the Unified Harness Protocol (UHP) allows seamless orchestration across Claude Code, OpenAI Codex, and Hermes while keeping infrastructure choices open (Cloud or Self-Hosted).

2. **For Cheaper Compute Sandboxes:**  
   Migrate agent workloads to **[E2B](https://e2b.dev)** or **[Daytona](https://daytona.io)**. Both provide superior microVM startup latencies (<200ms) and cut compute costs by 30% to 65% compared to AgentSky's `$0.461/hr`.

3. **For High-Volume Daily Agent Usage:**  
   Adopt **[Matrix OS](https://matrixos.dev)** ($20/mo flat) or a dedicated cloud VPS to eliminate hourly metered awake costs entirely.
