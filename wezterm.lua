local wezterm = require("wezterm")
local action = wezterm.action

local config = {}

-- startup events
wezterm.on("gui-startup", function()
    local mux = wezterm.mux

    local tab, pane, window = mux.spawn_window {}
    window:gui_window():maximize()

end)


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

local platform = get_platform()
if platform.is_win32 then
    config.default_prog = { "powershell.exe", "-NoLogo"}
    config.default_cwd  = os.getenv("USERPROFILE") .. "\\dev\\projects\\"
end


-- domains
config.ssh_domains = {}
config.unix_domains = {}
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


-- general
config.automatically_reload_config = true
config.exit_behavior = "CloseOnCleanExit"
config.exit_behavior_messaging = "Verbose"
config.scrollback_lines = 20000


-- rendering
config.max_fps = 144
config.front_end = "WebGpu"
config.prefer_egl = true

-- color
config.colors = {
    tab_bar = { background = "rgba(0,0,0,0)" }
}


-- fonts
config.font_size = 12.0
config.font = wezterm.font({
    family = "Cascadia Mono",
    weight = "Medium"
})


-- cursor
config.default_cursor_style = "SteadyBlock"


-- color
config.term = "xterm-256color"


-- tabs
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.tab_max_width = 25
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.switch_to_last_active_tab_when_closing_tab = true

-- show current active key table in the status area 
wezterm.on('update-right-status', function(window, pane)
    local name = window:active_key_table()
    if name then
        name = 'KEYTABLE: ' .. name
    end
    window:set_right_status(name or '')
end)


wezterm.on('update-status', function(window, pane)
    wezterm.log_info(window:tabs_with_info())
end)


-- windows
config.window_background_opacity = 0.9
config.window_decorations = "NONE"
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false

config.window_padding = {
    left = 10, right = 10,
    top = 10, bottom = 10
}

config.inactive_pane_hsb = {
    saturation = 0.1,
    brightness = 0.2,
}


-- key bindings
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

local function debug_overlay(key, mods)
    return {
        key = key,
        mods = mods,
        action = action.ShowDebugOverlay
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
    local path = os.getenv("USERPROFILE") .. "\\dev\\projects\\"
    for _, value in pairs(get_project_dirs(path)) do
        table.insert(choices, { label = value })
    end

    return wezterm.action.InputSelector {
        title = "Projects",
        choices = choices,
        fuzzy = true,
        action = wezterm.action_callback(function(child_window, child_pane, id, label)
            if not label then return end

            child_window:perform_action(action.SwitchToWorkspace {
                name = label:match("([^/]+)$"),
                spawn = { cwd = label },
            },
            child_pane)
        end),
    }
end

config.keys = {
    split_pane('l', "horizontal"),
    split_pane('j', "vertical"),
    debug_overlay('D', 'LEADER'),
    focus_pane('h', "Left"),
    focus_pane('l', "Right"),
    focus_pane('k', "Up"),
    focus_pane('j', "Down"),
    {
        key = 'r',
        mods = 'LEADER',
        action = action.ActivateKeyTable {
            name = 'resize_pane',
            one_shot = false
        }
    },
    {
        key = 'i',
        mods = 'LEADER',
        action = choose_project(),
    },
    {
        key = 'f',
        mods = 'LEADER',
        action = action.ShowLauncherArgs({ flags = 'WORKSPACES' }),
    },
}

config.key_tables = {
    resize_pane = {
        { key = 'LeftArrow', action = action.AdjustPaneSize { 'Left', 1 } },
        { key = 'h', action = action.AdjustPaneSize { 'Left', 1 } },

        { key = 'RightArrow', action = action.AdjustPaneSize { 'Right', 1 } },
        { key = 'l', action = action.AdjustPaneSize { 'Right', 1 } },

        { key = 'UpArrow', action = action.AdjustPaneSize { 'Up', 1 } },
        { key = 'k', action = action.AdjustPaneSize { 'Up', 1 } },

        { key = 'DownArrow', action = action.AdjustPaneSize { 'Down', 1 } },
        { key = 'j', action = action.AdjustPaneSize { 'Down', 1 } },

        -- Cancel the mode by pressing escape
        { key = 'Escape', action = 'PopKeyTable' },
    },
    copy_mode = {
        {
            key = 'Escape',
            mods = 'NONE',
            action = action.CopyMode('Close'),
        },
        { key = 'h', mods = 'NONE', action = action.CopyMode 'MoveLeft' },
        { key = 'j', mods = 'NONE', action = action.CopyMode 'MoveDown' },
        { key = 'k', mods = 'NONE', action = action.CopyMode 'MoveUp' },
        { key = 'l', mods = 'NONE', action = action.CopyMode 'MoveRight' },
        { key = 'b', mods = 'NONE', action = action.CopyMode 'MoveBackwardWord' },
    },
}



return config

