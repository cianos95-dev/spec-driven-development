# Research Report: Cross-Tool Persona Injection Surfaces

This report details the mechanisms for injecting personas and custom instructions into four development tools: Cursor, GitHub Copilot, Codex CLI, and Gemini CLI. The goal is to understand how a canonical persona definition could be used to generate tool-specific instruction files.

---

## 1. Cursor

*   **(a) Instruction File Path and Format:**
    *   The primary instruction files are expected to be `.cursorrules` at the project root or a `rules` file within the `.cursor/` directory.
    *   The format is likely Markdown or a structured format like JSON/YAML, similar to other tools.
    *   A search of the current project did not locate these files, only a `.cursor/settings.json` which contains plugin configurations, not agent instructions. The file `AGENTS.md` references these files, suggesting they are the correct mechanism.

*   **(b) Persona Mapping:**
    *   Assuming a Markdown format, personas would be mapped through instructional text. Sections could define the agent's role, rules, and areas of focus (e.g., "You are a security-focused reviewer. Pay close attention to...").

*   **(c) Limitations:**
    *   No explicit limitations were found. Practical limits are likely dictated by the context window of the underlying model being used by Cursor.

*   **(d) Dynamic Injection:**
    *   The file-based approach suggests instructions are loaded at session start. It is unclear if there is a mechanism to dynamically reload or alter these instructions during an active session without restarting.

---

## 2. GitHub Copilot

*   **(a) Instruction File Path and Format:**
    *   **Path:** `.github/copilot-instructions.md`
    *   **Format:** Markdown. The file contains sections that guide the agent's behavior, particularly for code reviews.

*   **(b) Persona Mapping:**
    *   Personas are defined by the content within the markdown file. The instructions guide the agent on what to focus on (e.g., `Code Quality`, `Plugin Architecture`, `Security`). A persona is created by tailoring the emphasis and directives within these sections. For example, a "Security-first" persona would have an extensive `## Security` section with detailed rules.

*   **(c) Limitations:**
    *   The documentation does not specify a hard size limit. The effective limit is the context window of the model used by Copilot for the review or coding task.

*   **(d) Dynamic Injection:**
    *   The primary mechanism is the static `.github/copilot-instructions.md` file, which is loaded per-repository.
    *   The `AGENTS.md` file indicates that the Copilot coding agent can be triggered by being assigned a GitHub issue. This suggests that the issue body could serve as a form of dynamic, task-specific instruction or context injection.

---

## 3. Codex CLI

*   **(a) Instruction File Path and Format:**
    *   **Path:** `AGENTS.md`
    *   **Format:** Markdown. This is a comprehensive document that acts as a central rulebook for multiple agents in the ecosystem, including those used by the Codex CLI.

*   **(b) Persona Mapping:**
    *   `AGENTS.md` explicitly defines a catalog of agents with distinct roles, scopes, and triggers (e.g., `reviewer-security-skeptic`, `spec-author`). This provides a highly structured way to define and route to different personas.
    *   The file also details model routing based on task type and "Effort Level", allowing for nuanced persona behavior (e.g., a `high` effort level for critical tasks).

*   **(c) Limitations:**
    *   No explicit size limitations are mentioned. The main constraint is the context window of the agent processing the file.

*   **(d) Dynamic Injection:**
    *   The `AGENTS.md` file itself is static. However, it defines triggers for dynamic invocation of specific agents at runtime. For example, a user can delegate a task in Linear to a specific agent persona (`delegateId`), effectively injecting a persona dynamically for a given task.

---

## 4. Gemini CLI

*   **(a) Instruction File Path and Format:**
    *   **Path:** `GEMINI.md` at the project root.
    *   **Format:** Markdown. The `AGENTS.md` file confirms this is a Gemini-specific instruction file and that the Antigravity tool uses the same format.
    *   There is also a global instruction file at `~/.gemini/GEMINI.md` that provides base instructions.

*   **(b) Persona Mapping:**
    *   Personas are mapped through repository-specific rules and context provided in the `GEMINI.md` file. The content of this file instructs the agent on how to behave within the specific project, defining its persona as an expert on that codebase. For the `claude-command-centre` repo, the persona is a developer who understands the project's structure, testing requirements, and branch protection rules.

*   **(c) Limitations:**
    *   No specific limitations are documented, but they are likely bound by the model's context window size.

*   **(d) Dynamic Injection:**
    *   The instructions in `GEMINI.md` appear to be loaded at the start of a session. The `AGENTS.md` mentions session handoffs using `cli-continues`, which allows passing context between sessions, but does not explicitly describe a mechanism for injecting new persona instructions *during* a live session.

---

## Summary of Findings

This investigation reveals a common pattern of using repository-local Markdown files to provide instructions to various AI agents.

*   **(a) What was done:** Researched the instruction injection mechanisms for Cursor, GitHub Copilot, Codex CLI, and Gemini CLI by analyzing specified configuration files (`.cursor/settings.json`, `.github/copilot-instructions.md`, `AGENTS.md`, `GEMINI.md`) and the project structure.
*   **(b) Decisions made:** Based on the file contents and cross-references in `AGENTS.md`, I've documented the path, format, and persona mapping strategy for each tool. Where files were not present (like `.cursorrules`), I noted it and inferred the likely mechanism based on the available information.
*   **(c) Blockers:** The primary blocker was the absence of `.cursorrules` or `.cursor/rules` in the provided project structure, which prevented a direct analysis of Cursor's specific format. The conclusion for Cursor is therefore based on inference from other tools and documentation.
*   **(d) Next Steps:** To fully validate the findings, the next step would be to create a canonical persona definition in the `agents/` directory and then write a script to generate the corresponding `.cursorrules`, `.github/copilot-instructions.md`, `AGENTS.md` (or a file it imports), and `GEMINI.md` files. This would confirm the feasibility of the cross-tool persona injection strategy.
