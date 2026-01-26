# arduino.nvim

A Neovim plugin for Arduino development, rewritten completely in Lua. It serves as a comprehensive wrapper around `arduino-cli`, providing commands for compiling, uploading, and debugging sketches directly from Neovim. It also integrates seamlessly with `arduino-language-server` for LSP support. It hasn't been tested in any other operating system than Linux, and it's optimised for use with [noice.nvim](https://github.com/folke/noice.nvim), as well as [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

## Requirements

1.  **Neovim 0.7+**
2.  **arduino-cli**: [Installation instructions](https://arduino.github.io/arduino-cli/latest/installation/)
3.  **arduino-language-server** (Optional, but recommended for LSP support): [Installation instructions](https://github.com/arduino/arduino-language-server)

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

Configure the plugin using the `setup` function. Defaults are shown below:

```lua
require('arduino').setup({
    -- Default board to use if no sketch.yaml is found.
    board = 'arduino:avr:uno', 
    
    -- Serial tool to use for the serial monitor. 
    -- Supported tool names: 'arduino-cli' (default), 'screen', 'minicom', 'picocom'
    -- Alternatively, provide a full command string like 'screen {port} {baud}'
    serial_cmd = 'arduino-cli',
    
    -- Baud rate for the internal serial monitor
    serial_baud = 9600,
    
    -- Automatically detect baud rate from `Serial.begin()` in sketch
    auto_baud = true,

    -- Fallback Library/Core Manager status icons (emoji/tick)
    manager_emoji = true, -- set false for tick/up-arrow fallback
    
    -- Use Telescope for selection menus if available
    use_telescope = true,
})
```

### Project Configuration & LSP

This plugin is designed to work hand-in-hand with `arduino-cli`, and it uses `sketch.yaml` for configuration persistence.

*   **Automatic Initialization:** When you open an Arduino sketch (`.ino`), the plugin checks for a `sketch.yaml` file. If one does not exist, it creates a default one to ensure the Language Server can attach immediately.
*   **Persistent Settings:** Commands `:ArduinoSelectBoard`, `:ArduinoSelectProgrammer` and `:ArduinoSelectPort` update the `sketch.yaml` file directly. This ensures your settings persist across sessions and are compatible with the CLI. The command `:ArduinoSetBaud`, however, can only persist its settings for the current session.
*   **LSP Integration:** When you change the board or port, the plugin automatically restarts the `arduino_language_server` to ensure diagnostics and completions are correct for your hardware.

## Commands

| Command | arg | description |
| :--- | :--- | :--- |
| `ArduinoSelectBoard` | [board] | Select board FQBN. Updates `sketch.yaml` and restarts LSP. |
| `ArduinoSelectProgrammer`| [prog] | Select programmer. |
| `ArduinoSelectPort` | [port] | Select serial port. Updates `sketch.yaml` and restarts LSP. |
| `ArduinoVerify` | | Compile the sketch. |
| `ArduinoUpload` | | Compile and upload the sketch. |
| `ArduinoMonitor` | | Open a serial monitor buffer. |
| `ArduinoUploadAndMonitor` | | Upload and then open serial monitor. |
| `ArduinoLibraryManager` | | Manage libraries (install/update/remove). |
| `ArduinoCoreManager` | | Manage cores (install/update/remove). |
| `ArduinoGetInfo` | | Display current configuration info. |
| `ArduinoSetBaud` | | Set the baud rate used by the serial monitor. |
| `ArduinoCheckLogs` | | Show the log buffer. |

## Status Line / Lualine

### Automatic Lualine Integration
If you use [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), this plugin **automatically** injects a status component into your statusline for Arduino files. It will appear in your `lualine_x` section as `[Board] (Port)`.

### Manual Integration
For other statuslines, use the provided status function:

```lua
local status = require('arduino.status').string()
```

## License

Everything is under the [MIT License](https://github.com/lindmeira/arduino.nvim/blob/master/LICENSE) except for the syntax file, which is under the [Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).
