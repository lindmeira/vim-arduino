# arduino.nvim

A Neovim plugin for Arduino development, fully rewritten in Lua. It serves as a
comprehensive wrapper around `arduino-cli`, providing commands for compiling,
uploading, and debugging sketches directly from Neovim. It also integrates
seamlessly with `arduino-language-server` for LSP support. It hasn't been tested
in any other operating system than Linux, and it's optimised for use with
[noice.nvim](https://github.com/folke/noice.nvim), as well as
[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

## Requirements

1. **Neovim 0.8+**
1. **arduino-cli**: [Installation instructions](https://arduino.github.io/arduino-cli/latest/installation/)
1. **arduino-language-server** (Optional, but recommended for LSP support): [Installation instructions](https://github.com/arduino/arduino-language-server)
1. **telescope.nvim** (Optional, but recommended for better UI): [Installation
   instructions](https://github.com/nvim-telescope/telescope.nvim)
1. **noice.nvim** (Optional, but recommended for better UI): [Installation
   instructions](https://github.com/folke/noice.nvim)
1. **simavr** (Optional, provides AVR simulation support)
1. **avr-gdb** (Optional, provides software-based debugging support)

## Installation

### lazy.nvim

```lua
{
    "lindmeira/arduino.nvim",
    ft = "arduino",
    config = function()
        require("arduino").setup({
            -- Optional: default configuration overrides
        })
    end,
}
```

## Configuration

Configure the plugin using the `setup` function. Defaults are shown below (check
out file `lazy_setup.lua` for additional examples):

```lua
require('arduino').setup({
    -- Default board to use if no sketch.yaml is found.
    -- board = 'arduino:avr:uno',

    -- Serial tool to use for the serial monitor.
    -- Supported tool names: 'arduino-cli' (default), 'screen', 'minicom', 'picocom'
    -- Alternatively, provide a full command string like 'screen {port} {baud}'
    -- serial_cmd = 'screen',

    -- Automatically detect baud rate from `Serial.begin()` in sketch
    -- auto_baud = false,

    -- Baud rate for the internal serial monitor
    serial_baud = 57600,

    -- Fallback Library/Core Manager status icons (emoji/tick)
    -- manager_emoji = false, -- set false for tick/up-arrow fallback

    -- Use Telescope for selection menus if available
    -- use_telescope = false, -- defaults to true

    -- Simulation debug UI options
    -- fullscreen_debug = true, -- Set to true to open GDB in fullscreen
})
```

### Project Configuration & LSP

This plugin is designed to work hand-in-hand with `arduino-cli`, and it uses
`sketch.yaml` and `.arduino.nvim.json` for configuration persistence.

- **Automatic Initialization:** When you open an Arduino sketch (`.ino`), the
  plugin checks for a `sketch.yaml` file. If one does not exist, it creates a
  default one to ensure the Language Server can attach immediately.
- **Persistent Settings:** Commands `:ArduinoSelectBoard`,
  `:ArduinoSelectProgrammer` and `:ArduinoSelectPort` update the `sketch.yaml`
  file directly. This ensures your settings persist across sessions and are
  compatible with the CLI. The commands `:ArduinoSelectPort` and `:ArduinoSetBaud`
  may be used to lock in port/baud settings, as these parameters are automatically
  set when not locked, although baudrate can only persist for the current
  session.
- **LSP Integration:** When you change the board or port, the plugin
  automatically restarts the `arduino_language_server` to ensure diagnostics and
  completions are correct for your hardware.
- **Smart Compilation:** To save time, the plugin automatically detects if a
  full recompile is needed by checking file timestamps and the board configuration
  (FQBN) used for the previous build (`.arduino.nvim.json`). If nothing has
  changed, it skips compilation and proceeds directly to upload or simulation.
- **Auto-Save Prompt:** Before any build or upload, the plugin checks if your
  buffer has unsaved changes and prompts you to save, ensuring you always flash
  the latest code.

## Commands

| Command | Arg | Description |
| :--- | :--- | :--- |
| `ArduinoSelectBoard` | [board] | Select board FQBN. Updates `sketch.yaml` and restarts LSP. |
| `ArduinoSelectProgrammer`| [prog] | Select programmer. |
| `ArduinoSelectPort` | [port] | Select serial port. Updates `sketch.yaml` and restarts LSP. |
| `ArduinoVerify` | | Compile the sketch. |
| `ArduinoUpload` | | Compile and upload the sketch. |
| `ArduinoMonitor` | | Open hardware serial monitor buffer. |
| `ArduinoUploadAndMonitor` | | Upload and then open hardware serial monitor. |
| `ArduinoSimulateAndMonitor` | | Launch a hardware simulator (e.g. SimAVR) and view pseudo-serial output. |
| `ArduinoSimulateAndDebug` | | Compile with debug flags and launch simulator with GDB attached. |
| `ArduinoSelectSimulator` | | Choose which simulator to use. |
| `ArduinoResetSimulation` | | Reset simulation parameters (MCU & frequency). |
| `ArduinoLibraryManager` | | Manage libraries (install/update/remove). |
| `ArduinoCoreManager` | | Manage cores (install/update/remove). |
| `ArduinoGetInfo` | | Display current configuration info. |
| `ArduinoSetBaud` | | Set the baud rate used by the serial monitor. |
| `ArduinoCheckLogs` | | Show the log buffer. |

## Simulation & Debugging

This plugin includes a framework for hardware simulation, with built-in support
for **SimAVR**.

- **:ArduinoSimulateAndMonitor**: Runs your sketch in the simulator and displays
  the serial output. It is build-mode agnostic and will use a standard release
  build unless a debug build is already present.
- **:ArduinoSimulateAndDebug**: Forces a compilation with debug symbols (`-g`,
  `-Og`), launches the simulator in debug mode, and connects an integrated GDB
  session in a floating window.

When you run a simulation for the first time, the plugin attempts to guess the
correct MCU and frequency from your board configuration. If it can't, it will
prompt you to select them. These settings are saved in your build directory for
future runs.

**Debug Window Controls:**

- **Terminal Mode:** Press `<Esc><Esc>` to kill the GDB session and close the
  window.
- **Normal Mode:** Press `<Esc>` or `q` to close the window.

## Status Line / Lualine

### Automatic Lualine Integration

If you use [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), this
plugin **automatically** injects a status component into your statusline for
Arduino files. It will appear in your `lualine_x` section as `[Board] [Programmer] (Port)`.

### Manual Integration

For other statuslines, use the provided status function:

```lua
local status = require('arduino.status').string()
```

## License

Everything is under the [MIT License](https://github.com/lindmeira/arduino.nvim/blob/master/LICENSE).
