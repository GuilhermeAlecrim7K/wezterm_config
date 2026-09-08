# WezTerm Configuration

A modular, extensible [WezTerm](https://wezterm.org/) configuration with dynamic background switching and centralized state management.

## Features

### 🎨 Dynamic Background Switcher
- **Keyboard shortcut**: Press `Ctrl+Shift+B` to change background images
- **Command palette**: Access via `Ctrl+Shift+P` → "Switch background image"
- **Fuzzy search**: Quickly find images by typing
- **Persistent**: Your selection is saved across WezTerm restarts
- **Disable option**: Choose "None" to disable background entirely
- Automatically discovers all `.png`, `.jpg`, and `.jpeg` files in `images/` directory

### 💼 Session Restore
- **Automatic**: the layout you left behind is reopened the next time WezTerm starts
- **Windows and tabs**: each window is restored with its tabs, working directories, manually assigned tab names and active tab
- **Periodic snapshots**: the live layout is sampled every 30 seconds, so directories that change from day to day are picked up on their own
- **History**: the last 5 distinct layouts are kept, so a snapshot taken while you were closing windows never costs you the good one
- **Command palette**: "Save session now", "Restore session", "Toggle session restore on startup"

WezTerm exposes no window-closed or application-exit event, which is why the layout is
sampled periodically instead of being written on the way out. Window position and size
are not restored: the Lua API can set a window position but cannot read one, so there is
nothing to capture.

### 🏗️ Modular Architecture
Configuration is split into logical modules:
- **wezterm.lua** - Main entry point that orchestrates all modules
- **appearance.lua** - Visual settings (color scheme, fonts, padding, scrollbar)
- **background_switcher.lua** - Background image management
- **command_palette.lua** - Command palette customizations
- **initialization.lua** - Platform-specific startup (e.g., PowerShell on Windows)
- **keymaps.lua** - Keyboard shortcuts and leader key configuration
- **general_options.lua** - General behavior (animations, cursor, tabs)
- **tab_titles.lua** - Automatic and manually assigned tab titles
- **session_manager.lua** - Window/tab session capture and restore
- **state_manager.lua** - Centralized state persistence system

### 💾 Centralized State Management
All persistent configuration is stored in `config_state.lua`, which is gitignored so each
machine keeps its own setup:
```lua
{
  ["background"] = {
    ["current_image"] = "triple-ryoiki-tenkai.png",
  },
  ["session"] = {
    ["enabled"] = true,
    ["history"] = {
      [1] = {
        ["saved_at"] = "2026-08-14 11:30:56",
        ["windows"] = {
          [1] = {
            ["active_tab"] = 2,
            ["workspace"] = "default",
            ["tabs"] = {
              [1] = { ["cwd"] = "C:\\Projetos", ["tab_title"] = "" },
              [2] = { ["cwd"] = "C:\\Users\\you", ["tab_title"] = "home" },
            },
          },
        },
      },
      -- newest first, up to 5 entries
    },
  },
  -- Future modules can add their own state here
}
```

Values are serialized with `%q`, so Windows paths and quotes round-trip safely, and keys
are emitted in a stable order to keep the file diffable.

Easy for new features to add state without conflicts:
```lua
local state_manager = require("state_manager")
state_manager.set("my_module", "my_key", "my_value")
local value = state_manager.get("my_module", "my_key")
```

## Installation

1. **Clone/copy this repository** to your WezTerm config directory:
   ```bash
   # Linux/macOS
   cd ~/.config/wezterm
   
   # Windows
   cd %USERPROFILE%\.config\wezterm
   ```

2. **Add fonts** (optional):
   - Place `.ttf` font files in the `fonts/` directory
   - Current fallback chain: Iosevka Nerd Font → UbuntuMono Nerd Font → Hack → Hasklig → Lilex Nerd Font → Fira Code

3. **Add background images**:
   - Place image files (`.png`, `.jpg`, `.jpeg`) in the `images/` directory
   - Press `Ctrl+Shift+B` to select them

4. **Restart WezTerm** or reload configuration

## Usage

### Switching Background Images

**Method 1: Keyboard Shortcut**
1. Press `Ctrl+Shift+B`
2. Select an image from the fuzzy-finding menu
3. Config reloads automatically with your selection

**Method 2: Command Palette**
1. Press `Ctrl+Shift+P` to open command palette
2. Type "background" or "image"
3. Select "Switch background image"
4. Choose your image

**Method 3: Programmatically**
```lua
local state_manager = require("state_manager")
state_manager.set("background", "current_image", "starry-night-sky.jpg")
```

### Restoring Sessions

Nothing has to be done for the common case: WezTerm reopens the last saved layout on
startup. The snapshot timer keeps the saved layout in sync while you work, so a plain
restart brings back the windows and tabs you had.

**Reopening an older layout**
1. Press `Ctrl+Shift+P` to open the command palette
2. Select "Restore session"
3. Pick an entry from the list (timestamp, window count, tab count)

The chosen layout is opened alongside the windows you already have, it does not replace
them.

**Forcing a snapshot** - select "Save session now" from the command palette when you want
the current layout recorded immediately instead of waiting for the next 30 second tick.

**Turning startup restore off** - select "Toggle session restore on startup". With it off,
WezTerm opens a single window as usual and snapshots keep being taken, so you can turn it
back on later without having lost anything.

Startup restore is also skipped when you ask for something specific on the command line,
such as `wezterm start -- pwsh` or `wezterm start --cwd C:\Projetos`.

A stored directory that no longer exists (deleted project, unmounted drive) does not break
the restore: that single tab opens at the default directory and everything else is
unaffected.

### Customizing Appearance

Edit `appearance.lua` to change:
- Color scheme (default: "Tokyo Night Moon")
- Font family and size
- Window padding
- Scrollbar visibility
- Tab bar settings

### Adding Keyboard Shortcuts

Edit `keymaps.lua`:
```lua
config.keys = {
  {
    key = "YourKey",
    mods = "CTRL|SHIFT",
    action = wezterm.action.YourAction,
  },
  -- Add more keybindings here
}
```

### Platform-Specific Configuration

Edit `initialization.lua` to customize shell selection and launch menu based on OS.

## File Structure

```
.
|-- wezterm.lua                 # Main entry point
|-- appearance.lua              # Visual settings
|-- background_switcher.lua     # Background management
|-- command_palette.lua         # Command palette integration
|-- general_options.lua         # General behavior
|-- initialization.lua          # Platform-specific setup
|-- keymaps.lua                 # Keyboard shortcuts
|-- tab_titles.lua              # Automatic and manual tab titles
|-- session_manager.lua         # Window/tab session capture and restore
|-- state_manager.lua           # State persistence system
|-- config_state.lua            # Generated state file (auto-created, gitignored)
|-- fonts/                      # Local font directory
|   `-- *.ttf                   # Font files
`-- images/                     # Background images
    |-- starry-night-sky.jpg
    `-- triple-ryoiki-tenkai.png
```

## Module Pattern

All modules follow this pattern:

```lua
local wezterm = require("wezterm")
local module = {}

function module.apply_to_config(config)
  -- Modify config here
  config.your_setting = "value"
end

return module
```

Modules are loaded and applied in `wezterm.lua`:
```lua
local my_module = require("my_module")
local config = wezterm.config_builder()
my_module.apply_to_config(config)
return config
```

## Adding New Features

### Example: Add a theme switcher

1. **Create the module** (`theme_switcher.lua`):
```lua
local wezterm = require("wezterm")
local state_manager = require("state_manager")
local module = {}

function module.apply_to_config(config)
  local theme = state_manager.get("theme", "name") or "Tokyo Night Moon"
  config.color_scheme = theme
end

return module
```

2. **Register in wezterm.lua**:
```lua
local theme_switcher = require("theme_switcher")
theme_switcher.apply_to_config(config)
```

3. **Use state manager** to persist choices:
```lua
state_manager.set("theme", "name", "Dracula")
```

## State Management API

```lua
local state_manager = require("state_manager")

-- Get a value
local value = state_manager.get("module_name", "key")

-- Set a value
state_manager.set("module_name", "key", "value")

-- Get entire module state
local module_state = state_manager.get_module_state("module_name")

-- Set entire module state
state_manager.set_module_state("module_name", { key1 = "val1", key2 = "val2" })

-- Get all state (debugging)
local all = state_manager.get_all()
```

## Configuration Details

### Font Loading
Fonts are loaded exclusively from the local `fonts/` directory:
```lua
config.font_dirs = { "fonts" }
config.font_locator = "ConfigDirsOnly"
```

### Background Image Brightness
All backgrounds use a brightness filter for readability:
```lua
hsb = { brightness = 0.006 }
```

### Platform Detection
Uses `wezterm.target_triple` to detect OS:
```lua
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
end
```

## Troubleshooting

### Configuration not loading?
Check WezTerm logs:
- Press `Ctrl+Shift+L` to open debug overlay
- Or check: `~/.local/share/wezterm/` (Linux/macOS)

### Background not changing?
1. Verify image is in `images/` directory
2. Check `config_state.lua` for current setting
3. Look for errors in debug overlay (`Ctrl+Shift+L`)

### Fonts not working?
1. Ensure `.ttf` files are in `fonts/` directory
2. Check font names match exactly
3. Restart WezTerm after adding fonts

## Contributing

This is a personal configuration, but feel free to:
- Use as a template for your own config
- Suggest improvements via issues/PRs
- Share your own modules

## License

This configuration is provided as-is for personal use.

## Resources

- [WezTerm Documentation](https://wezterm.org/)
- [WezTerm Lua API Reference](https://wezterm.org/config/lua/general.html)
- [Nerd Fonts](https://www.nerdfonts.com/) for programming ligatures and icons
