# Development Acceleration Guide
**Version**: 1.0.0
**Date**: 2025-09-26
**Purpose**: Complete reference for accelerated development using SPARC + Claude-Flow

---

## 📚 Overview

本專案現已配備完整的 **SPARC 方法論** 和 **Claude-Flow 協作框架**，提供 **84.8% SWE-Bench 解決率** 和 **2.8-4.4x 速度提升**。

---

## 🎯 Key Components

### 1. SPARC Methodology (Systematic Development)

**5-Phase Workflow**:
```
Specification → Pseudocode → Architecture → Refinement → Completion
```

**Commands**:
```bash
# Complete TDD workflow
npx claude-flow sparc tdd "Add multi-site intent validation"

# Individual phases
npx claude-flow sparc run spec-pseudocode "Feature description"
npx claude-flow sparc run architect "System design"
npx claude-flow sparc run integration "Integrate components"

# Parallel batch execution (300% faster)
npx claude-flow sparc batch "spec-pseudocode,architect" "New feature"
npx claude-flow sparc pipeline "Complete implementation task"
```

### 2. Claude Code Agents (52 Specialized Agents)

**Location**: `.claude/agents/`

**Categories**:
- **Core Development**: `coder`, `reviewer`, `tester`, `planner`, `researcher`
- **O-RAN/Nephio Specific**:
  - `oran-network-functions-agent` - RIC/RAN deployment
  - `cu-du-config-agent` - CU/DU configuration
  - `slice-management-agent` - Network slice lifecycle
  - `configuration-management-agent` - Nephio R5 config
  - `performance-optimization-agent` - SMO integration optimization
- **Kubernetes**: `kubernetes-architect` - GitOps, multi-cluster
- **Testing**: `test-automator`, `tdd-london-swarm`, `production-validator`
- **Architecture**: `docs-architect`, `system-architect`, `base-template-generator`
- **DevOps**: `deployment-engineer`, `cicd-engineer`
- **Security**: `security-compliance-agent`, `security-auditor`
- **Specialized**: `golang-pro`, `python-pro`, `ai-engineer`

**Usage via Claude Code Task Tool**:
```javascript
// ✅ CORRECT: Spawn agents in parallel (single message)
[Single Message]:
  Task("Implement intent processor", "Build TMF921 adapter...", "coder")
  Task("Add unit tests", "90% coverage...", "tester")
  Task("Review code", "Check security...", "reviewer")
  Task("Document API", "Generate OpenAPI...", "docs-architect")

  // Batch all todos
  TodoWrite { todos: [
    {content: "Implement processor", status: "in_progress", activeForm: "Implementing processor"},
    {content: "Write tests", status: "pending", activeForm: "Writing tests"},
    {content: "Review code", status: "pending", activeForm: "Reviewing code"},
    ...
  ]}
```

### 3. MCP Tools (Coordination Only)

**Installed Servers** (from `.claude/settings.json`):
- `claude-flow` - Core SPARC and swarm coordination
- `ruv-swarm` - Enhanced swarm intelligence (optional)

**MCP Usage** (Coordination Setup):
```javascript
// MCP tools ONLY coordinate, Claude Code executes
[Coordination Setup]:
  mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 5 }
  mcp__claude-flow__agent_spawn { type: "coder" }
  mcp__claude-flow__agent_spawn { type: "tester" }

// Claude Code Task tool does actual work
[Execution]:
  Task("Coder agent", "Implement feature", "coder")
  Task("Tester agent", "Create tests", "tester")
```

### 4. Automated Hooks System

**Location**: `.claude/settings.json` - `hooks` section

**Pre-Tool Hooks** (Before operations):
- `PreToolUse[Bash]` - Validate safety, prepare resources
- `PreToolUse[Write|Edit]` - Auto-assign agents, load context
- `PreCompact` - Provide guidance before context compression

**Post-Tool Hooks** (After operations):
- `PostToolUse[Bash]` - Track metrics, store results
- `PostToolUse[Write|Edit]` - Auto-format code, update memory
- `Stop` - Generate summary, persist state on session end

**Example**:
```bash
# When you run Bash, hooks automatically:
npx claude-flow@alpha hooks pre-command --validate-safety true
# ... execute command ...
npx claude-flow@alpha hooks post-command --track-metrics true
```

### 5. Command Categories (19 Types)

**Location**: `.claude/commands/`

**Available Categories**:
```
agents          - Agent management
analysis        - Code and system analysis
automation      - Workflow automation
coordination    - Swarm coordination
flow-nexus      - Cloud-based orchestration
github          - Repository operations
hive-mind       - Collective intelligence
hooks           - Lifecycle hooks
memory          - Context and state management
monitoring      - Performance tracking
optimization    - Performance tuning
pair            - Pair programming
sparc           - SPARC methodology
stream-chain    - Streaming workflows
swarm           - Swarm operations
training        - Neural pattern training
truth           - Verification and validation
verify          - Quality assurance
workflows       - Pipeline automation
```

---

## 🚀 Demo Resources

### Summit 2025 Materials

**Location**: `summit/`, `slides/`, `runbook/`

**Key Files**:
- `summit/SUMMIT_OVERVIEW_2025.md` - Complete demo overview
- `summit/POCKET_QA_V2.md` - Quick reference Q&A (42 questions)
- `slides/SUMMIT_DEMO_2025.md` - HackMD presentation slides
- `runbook/POCKET_QA.md` - Operational runbook

**Golden Intents** (Test Data):
```bash
ls summit/golden-intents/
# both-federated-learning.json  - Multi-site federated learning
# edge1-analytics.json          - Edge1 analytics workload
# edge2-ml-inference.json       - Edge2 ML inference
```

### Demo Scripts

**Location**: `scripts/`

**Key Scripts**:
```bash
# Complete LLM-driven demo (2,143 lines)
./scripts/demo_llm.sh --target edge1 --mode automated

# Multi-site orchestration demo
./scripts/demo_multisite.sh

# Rollback demonstration (841 lines)
./scripts/demo_rollback.sh

# Quick demo (8,223 lines)
./scripts/demo_quick.sh

# Orchestrator demo (678 lines)
./scripts/demo_orchestrator.sh
```

---

## 🎓 Development Workflow Examples

### Example 1: Add New Feature (Full SPARC)

```bash
# Use SPARC TDD workflow
npx claude-flow sparc tdd "Add intent validation for O2IMS provisioning requests"

# This automatically:
# 1. Generates specification
# 2. Creates pseudocode
# 3. Designs architecture
# 4. Implements with tests
# 5. Integrates and validates
```

### Example 2: Parallel Agent Development

**Single Message Pattern** (CRITICAL):
```javascript
// ✅ ALL operations in ONE message
[Message]:
  // Spawn all agents
  Task("Backend developer", "Implement TMF921 adapter with retry logic", "coder")
  Task("Test engineer", "Create integration tests for adapter", "tester")
  Task("DevOps engineer", "Setup CI/CD for adapter", "deployment-engineer")
  Task("Security auditor", "Review adapter security", "security-compliance-agent")

  // Batch ALL todos (8-10 minimum)
  TodoWrite { todos: [
    {content: "Implement TMF921 adapter", status: "in_progress", activeForm: "Implementing adapter"},
    {content: "Add retry mechanism", status: "pending", activeForm: "Adding retry mechanism"},
    {content: "Write unit tests", status: "pending", activeForm: "Writing tests"},
    {content: "Integration tests", status: "pending", activeForm: "Creating integration tests"},
    {content: "Setup Docker build", status: "pending", activeForm: "Setting up Docker"},
    {content: "Configure GitHub Actions", status: "pending", activeForm: "Configuring CI/CD"},
    {content: "Security audit", status: "pending", activeForm: "Auditing security"},
    {content: "Update documentation", status: "pending", activeForm: "Updating docs"}
  ]}

  // Batch file operations
  Write "adapter/tmf921_client.py"
  Write "adapter/tests/test_tmf921.py"
  Write ".github/workflows/adapter-ci.yml"
  Write "adapter/README.md"
```

### Example 3: O-RAN Specific Development

```bash
# Use specialized O-RAN agents
[Message]:
  Task("Deploy RIC platform", "Setup Near-RT RIC with xApps", "ric-deployment-agent")
  Task("Configure CU/DU", "Setup gNB with F1 interface", "cu-du-config-agent")
  Task("Manage slices", "Create eMBB and URLLC slices", "slice-management-agent")
  Task("Optimize performance", "Tune SMO integration", "performance-optimization-agent")
```

### Example 4: Testing and Validation

```bash
# Use testing agents in parallel
[Message]:
  Task("Unit testing", "90% coverage for intent processor", "test-automator")
  Task("Integration testing", "E2E GitOps workflow", "production-validator")
  Task("Security testing", "WG11 compliance validation", "security-compliance-agent")
  Task("Performance testing", "Load test SLO gates", "performance-optimization-agent")
```

---

## ⚡ Performance Optimization

### Golden Rules

**1️⃣ ONE MESSAGE = ALL OPERATIONS**
```javascript
// ✅ CORRECT: Everything in single message
[Single Message]:
  Task(agent1), Task(agent2), Task(agent3)
  TodoWrite { todos: [8+ todos] }
  Bash "cmd1"; Bash "cmd2"; Bash "cmd3"
  Write file1, Write file2, Write file3

// ❌ WRONG: Multiple messages
Message 1: Task(agent1)
Message 2: TodoWrite { todos: [todo1] }
Message 3: Write file1
```

**2️⃣ BATCH ALL TODOS (5-10+ minimum)**
```javascript
// ✅ CORRECT: Batch all todos
TodoWrite { todos: [
  {content: "Task 1", status: "in_progress", activeForm: "Doing task 1"},
  {content: "Task 2", status: "pending", activeForm: "Doing task 2"},
  {content: "Task 3", status: "pending", activeForm: "Doing task 3"},
  ...8-10 total tasks...
]}

// ❌ WRONG: One todo at a time
TodoWrite { todos: [{content: "Task 1", status: "in_progress"}] }
```

**3️⃣ FILE ORGANIZATION**
- ❌ NEVER save to root folder
- ✅ ALWAYS use subdirectories: `/src`, `/tests`, `/docs`, `/config`, `/scripts`

### Performance Gains

With proper parallel execution:
- **84.8%** SWE-Bench solve rate
- **32.3%** token reduction
- **2.8-4.4x** speed improvement
- **27+** neural models available

---

## 📁 File Organization Rules

**CRITICAL**: Never save working files to root folder!

**Correct Structure**:
```
/src/              - Source code
/tests/            - Test files
/docs/             - Documentation
/config/           - Configuration
/scripts/          - Utility scripts
/examples/         - Example code
/operator/         - Operator code
/tools/            - Development tools
```

**Wrong**:
```
❌ /my-feature.md      - Don't save to root
❌ /test.py           - Don't save to root
❌ /notes.txt         - Don't save to root
```

---

## 🔧 Setup and Configuration

### Initialize SPARC (Optional, if not already done)

```bash
# Initialize SPARC configuration
npx claude-flow@latest init --sparc

# This creates:
# - .roomodes file (17+ SPARC modes)
# - .roo/ directory (templates and workflows)
# - Enhanced CLAUDE.md
```

### Verify Setup

```bash
# Check available SPARC modes
npx claude-flow sparc modes

# List all agents
ls .claude/agents/*.md

# Check commands
ls .claude/commands/

# Verify MCP servers
cat .claude/settings.json | jq '.enabledMcpjsonServers'
```

---

## 🎯 Quick Start Examples

### Scenario 1: Fix Bug

```bash
npx claude-flow sparc batch "analysis,refinement" "Fix intent validation bug in TMF921 adapter"
```

### Scenario 2: Add Feature

```bash
npx claude-flow sparc tdd "Add support for mMTC network slices"
```

### Scenario 3: Refactor Code

```javascript
[Message]:
  Task("Analyze code structure", "Identify refactoring opportunities", "code-analyzer")
  Task("Apply refactoring", "Improve modularity", "coder")
  Task("Update tests", "Maintain 90% coverage", "tester")
  Task("Review changes", "Verify correctness", "reviewer")
```

### Scenario 4: Multi-Site Deployment

```javascript
[Message]:
  Task("Edge1 deployment", "Deploy eMBB slice to edge1", "oran-network-functions-agent")
  Task("Edge2 deployment", "Deploy URLLC slice to edge2", "oran-network-functions-agent")
  Task("GitOps sync", "Configure Config Sync", "kubernetes-architect")
  Task("Monitoring setup", "Setup Prometheus/Grafana", "monitoring-analytics-agent")
```

---

## 📊 Agent Coordination Protocol

Every agent spawned via Task tool MUST follow:

### Before Work
```bash
npx claude-flow@alpha hooks pre-task --description "task description"
npx claude-flow@alpha hooks session-restore --session-id "swarm-[id]"
```

### During Work
```bash
npx claude-flow@alpha hooks post-edit --file "[file]" --memory-key "swarm/[agent]/[step]"
npx claude-flow@alpha hooks notify --message "what was done"
```

### After Work
```bash
npx claude-flow@alpha hooks post-task --task-id "[task]"
npx claude-flow@alpha hooks session-end --export-metrics true
```

---

## 🚨 Common Pitfalls

### ❌ Wrong Patterns

1. **Multiple Messages for Related Operations**
```javascript
Message 1: Task("agent1")
Message 2: Task("agent2")  // ❌ Should be in Message 1
```

2. **Single Todo at a Time**
```javascript
TodoWrite { todos: [{content: "one task"}] }  // ❌ Batch 8-10 todos
```

3. **Files in Root Folder**
```javascript
Write "/test.md"  // ❌ Use /docs/test.md or /tests/test.md
```

4. **Using MCP for Execution**
```javascript
mcp__claude-flow__task_orchestrate  // ❌ Use Claude Code Task tool instead
```

### ✅ Correct Patterns

1. **Batch Everything**
```javascript
[Single Message]:
  Task(agent1), Task(agent2), Task(agent3)
  TodoWrite { todos: [8+ todos] }
  Bash cmd1, Bash cmd2
  Write file1, Write file2
```

2. **Proper File Organization**
```javascript
Write "/src/feature.py"
Write "/tests/test_feature.py"
Write "/docs/feature.md"
```

3. **Claude Code for Execution, MCP for Coordination**
```javascript
// Optional: Setup coordination
mcp__claude-flow__swarm_init { topology: "mesh" }

// Required: Execute with Claude Code
Task("agent", "do work", "agent-type")
```

---

## 📚 Additional Resources

### Documentation
- **CLAUDE.md** - Complete development guidelines
- **docs/architecture/** - System architecture docs
- **docs/network/** - Network configuration
- **docs/operations/** - Operational guides
- **docs/summit-demo/** - Demo materials

### Scripts
- **scripts/demo_*.sh** - Various demo scripts
- **scripts/setup/*.sh** - Setup automation
- **summit/runbook.sh** - Complete runbook

### Configuration
- **.claude/settings.json** - Claude Code configuration
- **.claude/agents/** - All agent definitions
- **.claude/commands/** - Command categories

---

## 🎓 Learning Path

1. **Beginner**: Start with `npx claude-flow sparc tdd "simple feature"`
2. **Intermediate**: Use specialized agents via Task tool
3. **Advanced**: Orchestrate parallel swarms with coordination
4. **Expert**: Create custom agents and workflows

---

## 💡 Tips for Maximum Productivity

1. **Always batch operations** - Single message = all related operations
2. **Use specialized agents** - 52 agents for specific tasks
3. **Follow file organization** - Never save to root
4. **Leverage SPARC** - Systematic TDD workflow
5. **Monitor hooks** - Automatic formatting and validation
6. **Check demos** - Learn from working examples
7. **Read CLAUDE.md** - Complete reference guide

---

**Remember**:
- **MCP coordinates** (topology, strategy)
- **Claude Code executes** (Task tool spawns real agents)
- **SPARC systematizes** (TDD workflow)
- **Hooks automate** (formatting, validation, metrics)

---

**Status**: ✅ Ready for accelerated development
**Performance**: 2.8-4.4x faster with 84.8% solve rate
**Agents Available**: 52 specialized agents
**Commands Available**: 19 categories

**Next Steps**: See examples above and start using `Task` tool with parallel agents!