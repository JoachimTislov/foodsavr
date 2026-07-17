# Research: Gemini CLI Scripts for Skills and Agents

## Summary
Gemini CLI extends its functionality through **Agent Skills**, **Sub-agents**, and **Custom Commands**. 

### 1. Agent Skills
- **Definition:** Modular, on-demand expertise package.
- **Structure:** 
  - `SKILL.md`: Metadata (YAML frontmatter) and instructions.
  - `scripts/`: Executable scripts (Bash, Python, JS).
  - `references/`: Support documentation.
- **Activation:** `activate_skill` tool or automatic based on task description.
- **Commands:** `/skills list`, `/skills reload`.

### 2. Sub-agents
- **Definition:** Specialized agents for complex, delegated tasks in separate context.
- **Types:**
  - Built-in (e.g., `codebase_investigator`, `generalist`).
  - Local (defined in `.gemini/agents/*.md`).
  - Remote (via A2A protocol).
- **Configuration:** `experimental: { enableAgents: true }` in `settings.json`.
- **Management:** `/agents list`, `/agents reload`.

### 3. Custom Slash Commands
- **Definition:** Shortcuts for complex prompts defined in `.toml`.
- **Handling Arguments:** 
  - `{{args}}`: Injects user arguments.
  - `!{command}`: Executes shell command and injects output.
  - `@{path}`: Injects file content.
- **Location:** `.gemini/commands/*.toml` (project) or `~/.gemini/commands/*.toml` (user).

### 4. Scripting & Arguments
- **Execution:** Agent runs scripts via `run_shell_command`.
- **Arguments:** Passed via standard CLI arguments when the agent calls the script.
- **Piping:** `cat file | gemini "prompt"` is supported for general CLI usage.
- **Approval:** YOLO mode (`--yolo`) for auto-approval of tool/script calls.
- **Naming Conventions:** Scripts should be in the `scripts/` folder of a skill or agent directory. Standard executable naming (e.g., `audit.sh`, `lint.py`).