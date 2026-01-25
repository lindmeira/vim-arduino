# AGENTS.md

> **Repository:** vim-arduino (Neovim plugin for Arduino integration)
> 
> **Purpose:** This guide is for software/code-writing AGENTS (human or machine) working in this repository. It summarizes build/test workflows, coding conventions, error handling, agent best-practices, and expected style, based on analysis of this codebase and its documentation.

---

## Library Manager Fallback UI Status Symbols

Starting in 2026-01, the fallback Arduino Library Manager UI (used when Telescope is disabled or unavailable) visually marks search results with status indicators as follows:

| Status     | Emoji   | Fallback Symbol |
|------------|---------|----------------|
| Installed  | 🟢      | ✓              |
| Outdated   | 🟠      | ↑              |
| Available  |  (none) | (none)         |

- By default, emoji are shown at the END of each line in the library list menu ("🟢" for installed, "🟠" for outdated).
- If emoji are disabled (see `library_manager_emoji` config option) or the terminal does not support emojis, the manager uses a tick "✓" for installed and up-arrow "↑" for outdated.
- No visual mark is added for libraries that are available but not currently installed/outdated.
- These symbols are explained in both this AGENTS.md and the README.

**Config:**
- To disable emoji indicators, set `library_manager_emoji = false` in your plugin configuration table for `require('arduino').setup()`.

- To enable persistent, multi-selection behavior in the Library Manager (so the results window stays open after each install/uninstall/update and you can take repeated actions in one session), set `library_manager_multiselect = true` in your configuration. When enabled, pressing <Esc> twice from the results window returns you to the search prompt (rather than exiting). Default is `false` for single-action workflow.

- Example:

```lua
require('arduino').setup({
  library_manager_emoji = false,
  library_manager_multiselect = true, -- NEW: persistent multi-action mode
})
```

This makes the fallback list render tick (✓) and up-arrow (↑) ASCII symbols instead. When `library_manager_multiselect=true`, the menu is persistent for repeated install operations (see README for workflow details).

---

## 1. Build, Lint & Test Instructions

### 1.1 Requirements
- **Neovim 0.7+** (required, as this is a Neovim plugin)
- **arduino-cli** (https://arduino.github.io/arduino-cli/latest/installation/)
- (Recommended) **arduino-language-server** (for LSP integration)

### 1.2 Building/Installing the Plugin
- This repository is a pure Lua plugin; there is no build process. To install:
  - Place in your `runtimepath` (as per `README.md`).
  - For development, reload your plugin using Neovim’s `:luafile` or `:PackerCompile`/`lazy.nvim` equivalent.

### 1.3 Linting
- There is **no automatic linter/config** present (e.g., no `.luacheckrc`).
- Agents should **self-enforce Lua idioms** as outlined in Section 2.
- (Optional) Use [`luacheck`](https://github.com/mpeterv/luacheck) or [`stylua`](https://github.com/JohnnyMorganz/StyLua) with default settings for error/warning catching and formatting.

### 1.4 Testing & Verification
- **No automated test suite.**
- To manually test the plugin:
  1. Launch Neovim with this plugin loaded (via packer.nvim, lazy.nvim, or manual `runtimepath`).
  2. Open an Arduino sketch (`.ino` file or folder containing one). The plugin auto-initializes and creates `sketch.yaml` as needed.
  3. Use the following EX commands to trigger plugin features:
     - `:ArduinoVerify` — Compile sketch
     - `:ArduinoUpload` — Compile & upload
     - `:ArduinoSerial` — Open serial monitor
     - `:ArduinoAttach [port]` — Board attach
     - `:ArduinoChooseBoard` — Board FQBN select
     - `:ArduinoChoosePort` — Serial port select
     - `:ArduinoUploadAndSerial` — Upload then open serial
  4. Check the status line or plugin messages for results.

#### Running a "Single Test/Feature In Isolation"
- Each command above can be run individually to check a feature. There are no test files or test runners. Agents should:
  - Reload code (using e.g. `:luafile %` for modified module, or `:PackerCompile`/`lazy reload` as appropriate)
  - Open `.ino` file, then run a specific command interactively in Neovim.
  - Inspect LSP or command feedback in Neovim for errors or correctness.
- For deeper debugging, print/log messages via `vim.notify` or `vim.api.nvim_out_write` in modules.

#### CI/Automation
- Agents may wish to spin up a Neovim headless session with the plugin loaded to script some checks. There is no headless test harness included yet.

#### Fallback Library Manager UI (2026-01+)
- When Telescope is not available, invoking the Library Manager opens a results window showing all libraries found by `arduino-cli lib search ""`.
- Type to filter the list and pick a library.
- When a library is selected and <Enter> is pressed, the appropriate install/update/uninstall action is triggered asynchronously. The picker window closes immediately and a notification will indicate result (success/failure).
- Multi-selection mode is not available in fallback mode at this time.

---

## 2. Coding Style Guidelines

### 2.1 Imports
- Use `require 'modulename'` for all imports.
- Module-local state should always use `local` unless explicitly exporting, e.g.:
  ```lua
  local config = require 'arduino.config'
  ```

### 2.2 Module Definition
- Define all modules as follows:
  ```lua
  local M = {}
  -- ...
  return M
  ```
- Public functions should be attached to `M`.
- Private helpers should use plain `local function ...`.

### 2.3 Formatting
- **Indentation:** Use 2 spaces, NO tabs.
- **Line length:** Aim for <= 100 chars, 80 is optimal.
- **Brace style:** Control blocks and function definitions open on the same line.
- **Whitespace:** Use blank lines to separate logical blocks.
- **Semicolons:** Do not use semicolons.
- **Commas:** Always include trailing commas for multiline tables.

### 2.4 Naming Conventions
- Variables, functions: **snake_case**
  - `function my_helper_function()`
- Module table: `M`
- Constants & tables: `ALL_CAPS` or CamelCase OK if widespread (e.g. `VALID_BAUD_RATES`)
- File names: snake_case or all lowercase.

### 2.5 Types/Annotations
- No explicit types in Lua. Use clear docstrings or comments for parameter expectations.
- Prefer doc comments for key module exports and public APIs.
- Use `---@param`/`---@return` style for compatibility with LSP-aware tools.

### 2.6 Error Handling
- Use `pcall` for potentially erroring function calls (e.g., JSON parse, require, IO).
- Plugin and user feedback:
  - Prefer `vim.notify(msg, level, {title=...})` for major errors/warnings/info.
  - For return-value errors, return `nil` or `false`, log the error, and document behavior.
- Do NOT swallow errors unless silence is critical; notify user or caller (agent/human) in all other cases.

### 2.7 Table Manipulation
- Use `vim.tbl_deep_extend` for merging tables/options.
- Avoid mutating shared tables unless clearly documented.

### 2.8 Comments & Documentation
- Use single-line double dash `--` for comments.
- Block docs and public symbols use docstring style:
  ```lua
  --- @param foo string: the foo parameter
  function M.bar(foo)
  ```

---

## 3. Agent Operation Best Practices

- When making changes, **reload the plugin** in Neovim and CHECK for errors via the command line or requiring the module.
- Each feature can be checked by invoking its command from Neovim (see 1.4 above).
- Use the commands in the table from README.md for interactive validation.
- When automating, prefer Neovim’s RPC, command-line interface, or API.
- No test directory: if adding new functionality, consider adding minimal regression or smoke tests as `.lua` scripts suitable for Neovim’s `busted` or as helper commands.
- Changes should **never break Neovim startup or cause global side effects**—check for proper use of `if vim.g.loaded_... then return end` guards.

### 3.1 Anti-patterns to Avoid
- Global variable pollution: always prefer locals and module tables.
- Huge functions: break up logic for readability.
- Hardcoded, magic values: use config or documented constants.
- Silence on error: ensure issues are surfaced to user/human/agent.
- UI or OS-specific hacks: encapsulate and document or guard by platform.

---

## 4. Human and Agent Collaboration
- AGENTS.md should be kept up to date. If you add CI/test harness, linter config, or major new conventions, **update this file**.
- If you automate something not covered here, please document the pattern and commands used, for future agent coders.

---

This AGENTS.md was generated via codebase and README.md analysis on 2026-01-23. Revisit and improve as project workflows evolve!
