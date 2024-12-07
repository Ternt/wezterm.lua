local wezterm = require("wezterm")
local action = wezterm.action

local config = {}

-- launch configurations
local function get_platform()
    local function is_found(str, pattern)
        return string.find(str, pattern) ~= nil
    end

    local is_win32 = is_found(wezterm.target_triple, "windows")
    local is_macOS = is_found(wezterm.target_triple, "apple")
    local is_linux = is_found(wezterm.target_triple, "linux")

    return {
        is_win32 = is_win32,
        is_macOS = is_macOS,
        is_linux = is_linux,
    }
end


-- startup gui
wezterm.on("gui-startup", function()
    local mux = wezterm.mux
    local tab, pane, mux_window = mux.spawn_window {
        workspace = 'default'
    }

    local window = mux_window:gui_window()

    window:toggle_fullscreen()
end)

-- show current active key table in the status area
wezterm.on('update-right-status', function(window)
    local name = window:active_key_table()
    if name then
        name = 'KEYTABLE: ' .. name
    end
    window:set_right_status(name or '')
end)

wezterm.on("update-status", function(window)
    wezterm.emit('update-left-status', window, window:active_workspace())
end)

-- show current workspace
wezterm.on('update-left-status', function(window, label)
    local workspace = wezterm.format {
        { Attribute = { Intensity = "Bold" } },
        { Text = "  " .. string.upper(label) .. " " }
    }
    window:set_left_status(workspace)
end)

-- recalculating padding on window_resize
wezterm.on('window-resized', function(window)
    local window_dims = window:get_dimensions()
    local overrides = window:get_config_overrides() or {}

    if not window_dims.is_full_screen then
        if not overrides.window_padding then
            return
        end
        overrides.window_padding = nil
    else
        local new_padding = {
            left = '1cell', right = '1cell',
            top = '0.5cell', bottom = '0.5cell',
        }
        if
            overrides.window_padding
            and new_padding.left == overrides.window_padding.left
        then
            return
        end
        overrides.window_padding = new_padding
        overrides.window_decorations = 'TITLE|RESIZE'
    end
    window:set_config_overrides(overrides)
end)

-- editing in vim
wezterm.on("open_in_vim", function(window, pane)
    local platform = get_platform()

    local file = ""
    if platform.is_win32 then
        file = os.getenv("TEMP") .. "\\wezterm_buf"
    end

	local handle = io.open(file, "w")
    if not handle then
        wezterm.log_error("failed to open file")
        return
    end

	handle:write(pane:get_lines_as_text(3000))
	handle:close()
    window:perform_action(
        wezterm.action({
            SpawnCommandInNewTab = {
                args = { "nvim", file, "-c", "call cursor(3000,0)" }
            },
        }),
        pane
    )
end)


local platform = get_platform()
if platform.is_win32 then
    config.default_prog = {
        'cmd.exe',
        '/k C:\\Users\\"Thinh Pham"\\Dev\\setup.bat'
    }
    config.default_cwd  = os.getenv("USERPROFILE") .. "\\dev\\projects\\"
end

-- domains
if platform.is_win32 then
    config.wsl_domains = {
        {
            name = 'WSL:Arch',
            distribution = 'Arch',
            default_cwd = '/home/tpham',
        },
        {
            name = 'WSL:Ubuntu',
            distribution = 'Ubuntu',
            default_cwd = '/home/tpham',
        },
    }
end

-- general
config.automatically_reload_config = true
config.exit_behavior = "CloseOnCleanExit"
config.exit_behavior_messaging = "Verbose"
config.scrollback_lines = 20000


-- rendering
config.max_fps = 60
config.animation_fps = 60
if platform.is_win32 or platform.is_linux then
    config.front_end = "OpenGL"
else
    config.front_end = "WebGPU"
end

-- color
config.term = "xterm-256color"
config.colors = {
    tab_bar = {
        background = "#000000",
        active_tab = {
            bg_color = "#000000",
            fg_color = "#C0C0C0",
        },
        inactive_tab = {
            bg_color = "#000000",
            fg_color = "#303030",
        },
        inactive_tab_hover = {
            bg_color = "#000000",
            fg_color = "#C0C0C0",
        },
    }
}


-- fonts
config.font_size = 12.0
config.font = wezterm.font({
    family = "Cascadia Mono",
    weight = "Medium"
})


-- cursor
config.default_cursor_style = "BlinkingBlock"


-- tabs
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_max_width = 25
config.show_tab_index_in_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true

-- windows
config.window_background_opacity = 0.9
config.window_decorations = "NONE"
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false

config.window_padding = {
    left = '1cell', right = '1cell',
    top = '0.5cell', bottom = '0.5cell',
}

config.inactive_pane_hsb = {
    saturation = 0.1,
    brightness = 0.2,
}


-- key bindings
config.use_dead_keys = false
config.disable_default_key_bindings = true
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

local function focus_pane(key, direction)
    return {
        key = key,
        mods = "CTRL",
        action = action.ActivatePaneDirection(direction),
    }
end

local function split_pane(key, direction)
    local opts = { domain = "CurrentPaneDomain" }
    local function get_pane_direction()
        if direction == "horizontal" then
            return wezterm.action.SplitHorizontal(opts)
        end
        return action.SplitVertical(opts)
    end

    return {
        key = key,
        mods = 'LEADER',
        action = get_pane_direction()
    }
end

-- project selection
local function get_project_dirs(path)
    local projects = {}
    for _, project_dir in ipairs(wezterm.glob(path .. '/*')) do
        table.insert(projects, project_dir)
    end
    return projects
end

local function choose_project()
    local choices = {}
    local project_path = os.getenv("USERPROFILE") .. "\\dev\\projects\\"
    for _, value in pairs(get_project_dirs(project_path)) do
        table.insert(choices, { label = value })
    end

    local lua_conf_path = os.getenv("USERPROFILE") .. "\\AppData\\local\\nvim\\lua"
    for _, value in pairs(get_project_dirs(lua_conf_path)) do
        table.insert(choices, { label = value })
    end

    return wezterm.action.InputSelector({
        title = "Projects",
        choices = choices,
        fuzzy = false,
        action = wezterm.action_callback(function(window, pane, id, label)
            if not label then return end

            window:perform_action(action.SwitchToWorkspace {
                name = label:match("([^/]+)$"),
                spawn = { cwd = label },
            }, pane)
        end),
    })
end


config.keys = {
    split_pane('l', "horizontal"),
    split_pane('j', "vertical"),
    focus_pane('h', "Left"),
    focus_pane('l', "Right"),
    focus_pane('k', "Up"),
    focus_pane('j', "Down"),

    { key = 'T', mods = 'CTRL|SHIFT', action = action.SpawnTab 'CurrentPaneDomain' },
    { key = 'D', mods = 'CTRL|SHIFT', action = action.ShowDebugOverlay },
    { key = 'x', mods = 'LEADER', action = action.ActivateCopyMode },
    { key = 'p', mods = 'LEADER', action = choose_project() },
    {
        key = 'r',
        mods = 'LEADER',
        action = action.ActivateKeyTable {
            name = 'resize_pane',
            one_shot = false
        }
    },
    {
        key = 'w',
        mods = 'LEADER',
        action = action.ActivateKeyTable({
            name = 'switch_workspace',
            one_shot = false,
        }),
    },
    {
        key = 't',
        mods = 'LEADER',
        action = action.ActivateKeyTable({
            name = 'toggle_fullscreen',
        }),
    },
}

-- Keys for switching tabs
for i = 1, 8 do
    table.insert(config.keys, {
        key = tostring(i),
        mods = 'ALT',
        action = action.ActivateTab(i - 1),
    })
    table.insert(config.keys, {
        key = 'F' .. tostring(i),
        action = action.ActivateTab(i - 1),
    })
end

config.key_tables = {
    resize_pane = {
        { key = 'LeftArrow', mods = 'NONE', action = action.AdjustPaneSize { 'Left', 1 } },
        { key = 'h', mods = 'NONE', action = action.AdjustPaneSize { 'Left', 1 } },

        { key = 'RightArrow', mods = 'NONE', action = action.AdjustPaneSize { 'Right', 1 } },
        { key = 'l', mods = 'NONE', action = action.AdjustPaneSize { 'Right', 1 } },

        { key = 'UpArrow', mods = 'NONE', action = action.AdjustPaneSize { 'Up', 1 } },
        { key = 'k', mods = 'NONE', action = action.AdjustPaneSize { 'Up', 1 } },

        { key = 'DownArrow', mods = 'NONE', action = action.AdjustPaneSize { 'Down', 1 } },
        { key = 'j', mods = 'NONE', action = action.AdjustPaneSize { 'Down', 1 } },

        { key = 'Escape', action = 'PopKeyTable' },
    },
    copy_mode = {
        { key = 'h', mods = 'NONE', action = action.CopyMode 'MoveLeft' },
        { key = 'j', mods = 'NONE', action = action.CopyMode 'MoveDown' },
        { key = 'k', mods = 'NONE', action = action.CopyMode 'MoveUp' },
        { key = 'l', mods = 'NONE', action = action.CopyMode 'MoveRight' },
        { key = 'b', mods = 'NONE', action = action.CopyMode 'MoveBackwardWord' },
        { key = 'g', mods = 'NONE', action = action.CopyMode 'MoveToScrollbackBottom' },
        { key = 'v', mods = 'NONE', action = action.CopyMode { SetSelectionMode = 'Cell' } },
        { key = 'v', mods = 'SHIFT', action = action.CopyMode { SetSelectionMode = 'Line' } },
        {
            key = 'y',
            mods = 'NONE',
            action = action.Multiple {
                { CopyTo = 'ClipboardAndPrimarySelection' },
                { CopyMode = 'Close' },
            },
        },
        {
            key = 'Escape',
            mods = 'NONE',
            action = action.Multiple {
                { CopyMode = 'Close' },
            }
        },
    },
    switch_workspace = {
        { key = 'k', mods = 'NONE', action = action.SwitchWorkspaceRelative(1) },
        { key = 'j', mods = 'NONE', action = action.SwitchWorkspaceRelative(-1) },
        {
            key = 'f',
            mods = 'NONE',
            action = action.Multiple {
                action.ShowLauncherArgs({ flags = 'WORKSPACES' }),
                'PopKeyTable'
            }
        },
        { key = 'Escape', action = 'PopKeyTable' }
    },
    toggle_fullscreen = {
        {
            key = 'f',
            mods = 'NONE',
            action = action.ToggleFullScreen,
        },
    }
}



return config

