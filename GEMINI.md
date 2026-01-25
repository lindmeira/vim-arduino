# vim-arduino Context for Gemini

## Project Overview
`vim-arduino` is a Neovim plugin for Arduino development, rewritten completely in Lua. It serves as a comprehensive wrapper around `arduino-cli`, providing commands for compiling, uploading, and debugging sketches directly from Neovim. It also integrates with `arduino-language-server` for LSP support.

## Key Features
- **Pure Lua**: fast and easy to configure.
- **`arduino-cli` Integration**: Uses the official CLI for all core operations.
- **LSP Support**: Automatically restarts the language server when board/port configuration changes.
- **UI**: Supports `telescope.nvim` for selection menus, with robust pure-Lua fallbacks if Telescope is missing.
- **Statusline**: Automatic integration with `lualine.nvim`.

## Architecture & Codebase Structure
The plugin source is located in `lua/arduino/`.
- **`init.lua`**: The main entry point. Handles `setup()`, command definitions, and UI logic (including the Library Manager fallback).
- **`config.lua`**: Manages configuration defaults and user overrides.
- **`core.lua`**: Logic for the Core Manager (install/upgrade/remove Arduino cores).
- **`lib.lua`**: Logic for the Library Manager (install/upgrade/remove libraries).
- **`cli.lua`**: Wrappers for `arduino-cli` commands.
- **`boards.lua`**: Handling of board and programmer lists.
- **`term.lua`**: Terminal and job handling for running CLI commands.
- **`util.lua`**: Utility functions (notifications, file I/O, etc.).
- **`status.lua`**: Statusline component generation.

## Development Workflow
- **No Build Step**: The project is interpreted Lua. Changes take effect on plugin reload.
- **Testing**:
  - There is currently no automated test suite.
  - Testing is manual: Open an Arduino sketch (`.ino`), run commands like `:ArduinoVerify` or `:ArduinoUpload`, and verify the output.
  - See `AGENTS.md` for specific "single test" workflows.
- **Linting/Style**:
  - Follow Lua idioms (snake_case for functions/vars).
  - Use `vim.notify` for user feedback.
  - Error handling: Use `pcall` for risky operations; do not fail silently.

## Installation & Configuration
**Requirements**:
- Neovim 0.7+
- `arduino-cli` installed and in PATH.
- `arduino-language-server` (optional, for LSP).

**Setup**:
```lua
require('arduino').setup({
    -- See lua/arduino/config.lua for full defaults
    auto_baud = true,
    serial_baud = 9600,
})
```

## Key Commands
| Command | Description |
| :--- | :--- |
| `:ArduinoAttach` | Attach to a board/port (updates `sketch.yaml`). |
| `:ArduinoChooseBoard` | Select board FQBN. |
| `:ArduinoChoosePort` | Select serial port. |
| `:ArduinoVerify` | Compile the sketch. |
| `:ArduinoUpload` | Compile and upload. |
| `:ArduinoSerial` | Open serial monitor. |
| `:ArduinoLibraryManager` | Manage libraries (install/update/remove). |
| `:ArduinoCoreManager` | Manage cores (install/update/remove). |

## Agent Guidelines
Refer to **`AGENTS.md`** for detailed instructions on:
- Coding style (imports, formatting, naming).
- Error handling patterns.
- Specifics on the fallback UI status symbols (Library Manager).
