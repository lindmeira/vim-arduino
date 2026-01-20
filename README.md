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
})
```

### Project Configuration & LSP

This plugin is designed to work hand-in-hand with `arduino-cli` and `arduino-language-server` by strictly using `sketch.yaml` for project configuration.

*   **Automatic Initialization:** When you open an Arduino sketch (`.ino`), the plugin automatically checks for a `sketch.yaml` file. If one does not exist, it creates a default one (using `arduino:avr:uno` and `/dev/ttyUSB0`) to ensure the Language Server can attach immediately without crashing.
*   **Persistent Settings:** Commands like `:ArduinoChooseBoard` and `:ArduinoChoosePort` update the `sketch.yaml` file directly (using `default_fqbn` and `default_port` keys). This ensures your board selection persists across sessions.
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

You can access plugin status via global variables or utility functions.
For `lualine.nvim`:

```lua
local function arduino_status()
  if vim.bo.filetype ~= "arduino" then return "" end
  
  -- Use the internal config or globals
  local config = require('arduino.config')
  local board = config.options.board or "Unknown"
  local port = require('arduino.cli').get_port() or "No Port"
  
  return string.format(" [%s] (%s)", board, port)
end

require('lualine').setup {
  sections = {
    lualine_x = { arduino_status, 'encoding', 'fileformat', 'filetype' },
  }
}
```

## License

Everything is under the [MIT License](https://github.com/lindmeira/vim-arduino/blob/master/LICENSE) except for the syntax file, which is under the [Vim License](http://vimdoc.sourceforge.net/htmldoc/uganda.html).