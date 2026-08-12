-- Hyprland 配置
-- 0.55 起 hyprlang 弃用，本文件为 Lua 版本（原 hyprland.conf 已移除）
-- 文档: https://wiki.hypr.land/Configuring/

----------------
---- MONITORS --
----------------

-- 用 `hyprctl monitors` 查看接口名，按需修改
-- 1.25 缩放；外接显示器通常用 1
hl.monitor({ output = "DP-1", mode = "preferred", position = "0x0", scale = 1.25 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- hl.monitor({ output = "DP-2",  mode = "preferred", position = "0x0",    scale = 1.25 })
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x1440", scale = 1.25 })

-----------------
---- AUTOSTART --
-----------------

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("dunst")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("fcitx5 -d")
	hl.exec_cmd("nm-applet --indicator")
	hl.exec_cmd("blueman-applet")
	hl.exec_cmd("hyprpolkitagent")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	-- hl.exec_cmd("dropbox")

	-- 自启: chrome + terminal
	hl.exec_cmd("google-chrome-stable --hide-crash-restore-bubble", { workspace = "3 silent" })
	hl.exec_cmd("kitty", { workspace = "2 silent" })
end)

-----------------
---- ENV --------
-----------------

hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")

-- 中文输入法
-- 不设 GTK_IM_MODULE：wayland 下 GTK 原生程序走 text-input-v3，
-- 设置后 fcitx5 会弹 "Detect GTK_IM_MODULE being set..." 警告；
-- XWayland 下的 GTK 程序由 XMODIFIERS 覆盖
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("GLFW_IM_MODULE", "ibus")

-- Qt 走 wayland + gtk3 平台主题（对应原 qt.platformTheme gtk3 + kvantum）
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- Electron 应用（chrome/obsidian/zed）原生 wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- 光标主题（AUR: catppuccin-cursors-mocha）
hl.env("XCURSOR_THEME", "Catppuccin-Mocha-Blue-Cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Catppuccin-Mocha-Blue-Cursors")
hl.env("HYPRCURSOR_SIZE", "24")

-------------
---- INPUT --
-------------

hl.config({
	input = {
		kb_layout = "us",
		kb_options = "ctrl:nocaps", -- Caps 改 Ctrl（与原 xkb.options 一致）

		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = true,
			tap_to_click = true,
		},
	},
})

-- 笔记本触摸板手势（可选）
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

--------------
---- LOOK ----
--------------

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 10,
		border_size = 2,

		col = {
			-- catppuccin mocha: blue / surface1
			active_border = "rgba(89b4faff)",
			inactive_border = "rgba(45475aff)",
		},

		layout = "dwindle",
		resize_on_border = true,
	},

	decoration = {
		rounding = 6,

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
		},

		shadow = {
			enabled = true,
			range = 20,
			render_power = 3,
			color = 0xee1a1a1a,
		},
	},

	animations = { enabled = true },

	dwindle = { preserve_split = true },

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default" })

----------------
---- BINDINGS --
----------------

local mod = "SUPER"
local mod2 = "ALT"
local terminal = "kitty"
local browser = "google-chrome-stable --hide-crash-restore-bubble"

-- --- 程序启动 ---
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("rofi -show emoji"))
hl.bind(mod .. " + CTRL + C", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + CTRL + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + CTRL + R", hl.dsp.exec_cmd("rubymine"))
hl.bind(mod .. " + CTRL + P", hl.dsp.exec_cmd("pycharm"))
hl.bind(mod .. " + F3", hl.dsp.exec_cmd("pcmanfm"))
-- 选中文字查词典（xsel → wl-paste）
hl.bind(mod .. " + T", hl.dsp.exec_cmd('goldendict -t "$(wl-paste -p)"'))
-- 剪贴板历史
hl.bind(mod .. " + O", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))

-- --- 截图 ---
hl.bind(
	mod .. " + P",
	hl.dsp.exec_cmd(
		'grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/satty-$(date +%Y%m%d-%H%M%S).png'
	)
)
hl.bind("Print", hl.dsp.exec_cmd("grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png'))

-- DeepSeek scratchpad（special workspace）
hl.bind(mod .. " + Q", hl.dsp.workspace.toggle_special("deepseek"))
-- Kimi scratchpad
hl.bind(mod .. " + grave", hl.dsp.workspace.toggle_special("kimi"))

-- --- 窗口操作 ---
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + W", hl.dsp.group.toggle()) -- 标签组布局
hl.bind(mod .. " + V", hl.dsp.layout("preselect d")) -- 原 split v（dwindle 预置方向）
hl.bind(mod .. " + semicolon", hl.dsp.layout("preselect r")) -- 原 split h

-- --- 焦点切换 / 移动窗口（hjkl + 方向键）---
local dirs = { H = "l", J = "d", K = "u", L = "r", Left = "l", Down = "d", Up = "u", Right = "r" }
for key, dir in pairs(dirs) do
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = dir }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
end

-- --- 工作区 ---
hl.bind(mod2 .. " + Tab", hl.dsp.focus({ workspace = "previous" })) -- 原 workspace back_and_forth
hl.bind(mod .. " + CTRL + Left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mod .. " + CTRL + Right", hl.dsp.focus({ workspace = "r+1" }))

for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- 滚轮切换工作区
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "r-1" }))

-- 鼠标拖动/缩放窗口
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- --- 系统 ---
hl.bind(mod .. " + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session")) -- 锁屏（hypridle → hyprlock）
hl.bind(mod .. " + 0", hl.dsp.exec_cmd("rofi -show power-menu -modi power-menu:rofi-power-menu"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mod .. " + M", hl.dsp.exec_cmd("killall -SIGUSR1 waybar")) -- 隐藏/显示状态栏
hl.bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("killall dunst && notify-send 'restart dunst'"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))

-- --- 音量 / 亮度 / 媒体键 ---
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- --- 调整窗口大小模式 ---
hl.bind(mod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
	local steps = {
		H = { -20, 0 },
		J = { 0, 20 },
		K = { 0, -20 },
		L = { 20, 0 },
		Left = { -20, 0 },
		Down = { 0, 20 },
		Up = { 0, -20 },
		Right = { 20, 0 },
	}
	for key, d in pairs(steps) do
		hl.bind(key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }), { repeating = true })
	end
	hl.bind("Return", hl.dsp.submap("reset"))
	hl.bind("Escape", hl.dsp.submap("reset"))
end)

-------------------
---- WINDOW RULES --
-------------------

-- 图片查看/词典等保持浮动（按需增删）
hl.window_rule({ name = "float-viewnior", match = { class = "^(viewnior)$" }, float = true })
hl.window_rule({ name = "float-pcmanfm", match = { class = "^(pcmanfm)$" }, float = true })
hl.window_rule({ name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol)$" }, float = true })
hl.window_rule({
	name = "float-nautilus-archive",
	match = { class = "^(org.gnome.Nautilus)$", title = "^(存档管理器)$" },
	float = true,
})
hl.window_rule({
	name = "float-goldendict-ng",
	match = { class = "^(io.github.xiaoyifang.goldendict_ng)$" },
	float = true,
})

-- Chrome PWA（DeepSeek / Kimi）
hl.window_rule({
	name = "float-deepseek",
	match = { class = "^(chrome-hmjcdonmhijmnefklekckjkeoknbiipb-Default)$" },
	float = true,
	size = "1200 800",
	center = true,
	workspace = "special:deepseek silent",
})
hl.window_rule({
	name = "float-kimi",
	match = { class = "^(chrome-cfbmbdcmhmpondjkflgbghnelgpldahk-Default)$" },
	float = true,
	size = "1200 800",
	center = true,
	workspace = "special:kimi silent",
})

-- 抑制无焦点窗口的事件（默认推荐）
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})
