# vim-arduino

Neovim plugin for compiling, uploading, and debugging arduino sketches, completely rewritten in Lua. It uses
[arduino-cli](https://arduino.github.io/arduino-cli/latest/) (recommended) and integrates seamlessly with `arduino-language-server` for a robust development environment.

## Installation

vim-arduino requires **Neovim 0.7+** and `arduino-cli`.

<details>
  <summary>lazy.nvim</summary>

```lua
{
    "lindmeira/vim-arduino",
    config = function()
        require("arduino").setup({
            -- Optional: default configuration overrides
        })
    end,
}
```

</details>

<details>
  <summary>packer.nvim</summary>

```lua
use {
    'lindmeira/vim-arduino',
    config = function()
        require('arduino').setup()
    end
}
```

</details>

## Requirements

1.  **Neovim 0.7+**
2.  **arduino-cli**: [Installation instructions](https://arduino.github.io/arduino-cli/latest/installation/)
    *   Ensure `arduino-cli` is in your PATH.
3.  **arduino-language-server** (Optional, but recommended for LSP support): [Installation instructions](https://github.com/arduino/arduino-language-server)

## Configuration

Configure the plugin using the `setup` function. Defaults are shown below:

```lua
require('arduino').setup({
    -- Default board to use if no sketch.yaml is found.
    -- Set to nil to force explicit selection, but 'arduino:avr:uno' is safer for LSP startup.
    board = 'arduino:avr:uno', 
    
    -- Serial port globs to search for
    serial_port_globs = { "/dev/ttyACM*", "/dev/ttyUSB*" },
    
    -- Baud rate for the internal serial monitor
    serial_baud = 9600,
    
    -- Automatically detect baud rate from `Serial.begin()` in sketch
    auto_baud = true,
    
    -- Use arduino-cli (strongly recommended)
    use_cli = true,

    -- Fallback Library/Core Manager status icons (emoji/tick)
     manager_emoji = true, -- set false for tick/up-arrow fallback

     -- When true, the Library Manager results window remains open after install/update/uninstall.
     -- Repeated actions are possible without leaving the menu. Press <Esc> twice to return to search.
     -- Default: false (window closes after every action).
     library_manager_multiselect = false,  
})
```

### Project Configuration & LSP

This plugin is designed to work hand-in-hand with `arduino-cli` and `arduino-language-server` by strictly using `sketch.yaml` for project configuration.

*   **Automatic Initialization:** When you open an Arduino sketch (`.ino`), the plugin automatically checks for a `sketch.yaml` file. If one does not exist, it creates a default one (using `arduino:avr:uno` and `/dev/ttyUSB0`) to ensure the Language Server can attach immediately without crashing.
*   **Persistent Settings:** Commands like `:ArduinoChooseBoard`, `:ArduinoChoosePort`, and `:ArduinoChooseProgrammer` update the `sketch.yaml` file directly (using `default_fqbn`, `default_port`, and `default_programmer` keys). This ensures your board, port, and programmer selections persist across sessions.
*   **LSP Integration:** When you change the board or port, the plugin automatically restarts the `arduino_language_server`. This ensures that diagnostics, completions, and code analysis are always correct for your selected hardware.

## Commands

| Command                   | arg          | description                                                                 |
| ------------------------- | ------------ | --------------------------------------------------------------------------- |
| `ArduinoAttach`           | [port]       | Attach to a board via `arduino-cli board attach`. Updates `sketch.yaml`.    |
| `ArduinoChooseBoard`      | [board]      | Select board FQBN. Updates `sketch.yaml` and restarts LSP.                  |
| `ArduinoChooseProgrammer` | [programmer] | Select programmer.                                                          |
| `ArduinoChoosePort`       | [port]       | Select serial port. Updates `sketch.yaml` and restarts LSP.                 |
| `ArduinoVerify`           |              | Compile the sketch.                                                         |
| `ArduinoUpload`           |              | Compile and upload the sketch.                                              |
| `ArduinoSerial`           |              | Open a serial monitor buffer.                                               |
| `ArduinoUploadAndSerial`  |              | Upload and then open serial monitor.                                        |
| `ArduinoInfo`             |              | Display current configuration info.                                         |

## Keymappings

The plugin does not set keymappings by default. You can add them in your config or `ftplugin/arduino.lua`:

```lua
local map = vim.keymap.set
map('n', '<leader>aa', '<cmd>ArduinoAttach<CR>', { desc = "Arduino Attach" })
map('n', '<leader>av', '<cmd>ArduinoVerify<CR>', { desc = "Arduino Verify" })
map('n', '<leader>au', '<cmd>ArduinoUpload<CR>', { desc = "Arduino Upload" })
map('n', '<leader>aus', '<cmd>ArduinoUploadAndSerial<CR>', { desc = "Upload & Serial" })
map('n', '<leader>as', '<cmd>ArduinoSerial<CR>', { desc = "Arduino Serial" })
map('n', '<leader>ab', '<cmd>ArduinoChooseBoard<CR>', { desc = "Choose Board" })
map('n', '<leader>ap', '<cmd>ArduinoChoosePort<CR>', { desc = "Choose Port" })
```

## Status Line / Lualine

### Automatic Lualine Integration
If you use [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), this plugin **automatically** injects a status component into your statusline for Arduino files. It will appear in your `lualine_x` section (usually the right side) as `[Board] (Port)`. No manual configuration is required.

### Manual Integration
If you use a different statusline or want to customize the component, you can use the provided status function:

```lua
-- Returns a string like "[arduino:avr:uno] (/dev/ttyUSB0)"
local status = require('arduino.status').string()
```

Example for a custom statusline:
```lua
function MyStatusLine()
  return require('arduino.status').string()
end
```

## License

Everything is under the [MIT License](https://github.com/lindmeira/vim-arduino/blob/master/LICENSE) except for the syntax file, which is under the [Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).