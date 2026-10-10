--[[
    open-source UI library
    ============================================================
    usage:
        local Library = loadstring(game:HttpGet("..."))()

        local win = Library:Window({ Title = "my script" })
        local tab = win:Tab("main")
        local group = tab:Group("group")

        group:Checkbox("enable", false, function(v) end, {flag = "my_flag"})
        group:Slider("speed", {min=0, max=100, default=50, flag="my_slider"}, function(v) end)
        group:Keybind("toggle key", Enum.KeyCode.RightShift, function(k) end)

        Library:Notify("title", "body")

    public api:
        Library.Version
        Library.Theme
        Library.Flags               -- [flag] = {Set, Get}
        Library:Window(opts)
        Library:Notify(title, body, duration)
        Library:BuildSettings(win)  -- optional, adds a settings tab
        Library.SetAccent(color)
        Library.SetTheme(key, color)
        Library.ResetTheme()
        Library.saveConfig(name)
        Library.loadConfig(name)
        Library.listConfigs()
]]

local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local TextService  = game:GetService("TextService")
local Players      = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local IS_MOBILE   = UIS.TouchEnabled and not UIS.MouseEnabled

local function guiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- THEME
-- ============================================================
local THEME = {
    Accent        = Color3.fromRGB(147, 161, 254),
    AccentDark    = Color3.fromRGB(121, 132, 208),

    Window        = Color3.fromRGB(17,  17,  16),
    Surface       = Color3.fromRGB(21,  21,  20),
    Element       = Color3.fromRGB(15,  14,  14),
    Input         = Color3.fromRGB(18,  19,  19),
    InputBorder   = Color3.fromRGB(24,  24,  25),

    BorderOuter   = Color3.fromRGB(0,   0,   0),
    BorderInner   = Color3.fromRGB(31,  30,  31),

    Text          = Color3.fromRGB(255, 255, 255),
    TextDim       = Color3.fromRGB(136, 136, 136),
    TextSelected  = Color3.fromRGB(155, 168, 250),

    HeaderTop     = Color3.fromRGB(28,  29,  28),
    HeaderBottom  = Color3.fromRGB(15,  14,  14),

    TabTop        = Color3.fromRGB(38,  39,  38),
    TabMid        = Color3.fromRGB(27,  27,  27),
    TabBottom     = Color3.fromRGB(21,  21,  20),
    TabText       = Color3.fromRGB(128, 128, 128),
    TabTextHover  = Color3.fromRGB(208, 208, 208),
}

local DEFAULT_THEME = {}
for k, v in pairs(THEME) do DEFAULT_THEME[k] = v end

local FONT      = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansBold
local FONT_FACE = nil
local TEXT_SIZE = 13
local STROKE_T  = 0.55

-- ============================================================
-- HELPERS
-- ============================================================
local function new(class, props, parent)
    local o = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then o[k] = v end
        end
    end
    if parent then o.Parent = parent end
    return o
end

local function applyFont(label, bold)
    if FONT_FACE then label.FontFace = FONT_FACE
    else label.Font = bold and FONT_BOLD or FONT end
end

local function outlined(parent, text, color, props)
    local bold = props and props.Bold
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Text                   = text or "",
        TextColor3             = color or THEME.Text,
        TextSize               = TEXT_SIZE,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Center,
        TextStrokeColor3       = THEME.BorderOuter,
        TextStrokeTransparency = STROKE_T,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        RichText               = false,
        ZIndex                 = 5,
    }, parent)
    applyFont(l, bold)
    if props then
        for k, v in pairs(props) do
            if k ~= "Bold" then l[k] = v end
        end
    end
    return l
end

local function framedBox(parent, outerC, innerC, fillC, props)
    local outer = new("Frame", {
        BackgroundColor3 = outerC,
        BorderSizePixel  = 0,
        Size             = UDim2.fromScale(1, 1),
    }, parent)
    if props then for k, v in pairs(props) do outer[k] = v end end
    new("Frame", {
        BackgroundColor3 = innerC,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(1, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        ZIndex           = (outer.ZIndex or 1),
    }, outer)
    local fill = new("Frame", {
        Name             = "Fill",
        BackgroundColor3 = fillC,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(2, 2),
        Size             = UDim2.new(1, -4, 1, -4),
        ZIndex           = (outer.ZIndex or 1),
    }, outer)
    return outer, fill
end

local function vGradient(frame, topC, botC, transSeq)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    return new("UIGradient", {
        Rotation     = 90,
        Color        = ColorSequence.new(topC, botC),
        Transparency = transSeq or NumberSequence.new(0),
    }, frame)
end

local function tween(inst, t, goal)
    return TweenService:Create(inst, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), goal)
end

local KEY_NAMES = {
    [Enum.UserInputType.MouseButton1] = "LM",
    [Enum.UserInputType.MouseButton2] = "RM",
    [Enum.UserInputType.MouseButton3] = "MM",
    [Enum.KeyCode.LeftShift]   = "Shift", [Enum.KeyCode.RightShift]   = "Shift",
    [Enum.KeyCode.LeftControl] = "Ctrl",  [Enum.KeyCode.RightControl] = "Ctrl",
    [Enum.KeyCode.LeftAlt]     = "Alt",   [Enum.KeyCode.RightAlt]     = "Alt",
    [Enum.KeyCode.Space]       = "Space", [Enum.KeyCode.Return]       = "Enter",
    [Enum.KeyCode.Tab]         = "Tab",   [Enum.KeyCode.Backspace]    = "Back",
    [Enum.KeyCode.CapsLock]    = "Caps",  [Enum.KeyCode.Escape]       = "Esc",
    [Enum.KeyCode.Insert]      = "Insert",[Enum.KeyCode.Delete]       = "Del",
    [Enum.KeyCode.Up]="Up",[Enum.KeyCode.Down]="Down",[Enum.KeyCode.Left]="Left",[Enum.KeyCode.Right]="Right",
}
local function keyName(key)
    if key == nil then return "-" end
    if KEY_NAMES[key] then return KEY_NAMES[key] end
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        return key.Name
    end
    return "?"
end

-- ============================================================
-- LIBRARY TABLE
-- ============================================================
local Library = {}
Library.__index = Library

Library.Version   = "1.0.0"
Library.Theme     = THEME
Library.ToggleKey = Enum.KeyCode.Insert
Library.CursorEnabled = true

Library.Flags          = {}
Library._registered    = {}
Library._windows       = {}
Library._hotkeys       = {}
Library._hotkeyPanel   = nil
Library._accentTargets = {}
Library.Watermark      = nil

local screenGui

local function register(flagName, ctrl)
    if not flagName then return end
    Library.Flags[flagName] = ctrl
    Library._registered[#Library._registered + 1] = flagName
end

local function registerAccent(frame, grad, fn)
    Library._accentTargets[#Library._accentTargets + 1] = {frame = frame, grad = grad, fn = fn}
end

local function registerHotkey(name, getKeyFn)
    Library._hotkeys[#Library._hotkeys + 1] = {name = name, getKey = getKeyFn}
    if Library._hotkeyPanel then Library._hotkeyPanel.refresh() end
end

-- ============================================================
-- THEME ENGINE
-- ============================================================
local SWATCH_ATTR = "NoThemeSwap"

local function markNoSwap(obj)
    obj:SetAttribute(SWATCH_ATTR, true)
end

local function swapColorInTree(root, old, newC)
    for _, d in ipairs(root:GetDescendants()) do
        if not d:GetAttribute(SWATCH_ATTR) then
            pcall(function()
                if d:IsA("GuiObject") and d.BackgroundColor3 == old then
                    d.BackgroundColor3 = newC
                end
                if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                    if d.TextColor3 == old then d.TextColor3 = newC end
                    if d.TextStrokeColor3 == old then d.TextStrokeColor3 = newC end
                end
                if d:IsA("UIStroke") and d.Color == old then
                    d.Color = newC
                end
                if d:IsA("UIGradient") then
                    local cs = d.Color
                    local kps = cs.Keypoints
                    local nk, changed = {}, false
                    for i, kp in ipairs(kps) do
                        if kp.Value == old then
                            nk[i] = ColorSequenceKeypoint.new(kp.Time, newC)
                            changed = true
                        else
                            nk[i] = kp
                        end
                    end
                    if changed then d.Color = ColorSequence.new(nk) end
                end
            end)
        end
    end
end

function Library.SetTheme(key, color)
    local old = THEME[key]
    if old == color then return end
    THEME[key] = color
    if screenGui then swapColorInTree(screenGui, old, color) end
    if Library.Watermark and Library.Watermark.refresh then Library.Watermark.refresh() end
end

function Library.SetAccent(c)
    THEME.Accent = c
    THEME.AccentDark = c:Lerp(Color3.new(0, 0, 0), 0.35)
    for _, t in ipairs(Library._accentTargets) do
        if t.grad and t.grad.Parent then
            t.grad.Color = ColorSequence.new(THEME.Accent, THEME.AccentDark)
        elseif t.frame and t.frame.Parent then
            t.frame.BackgroundColor3 = THEME.Accent
        end
        if t.fn then pcall(t.fn) end
    end
    if Library.Watermark and Library.Watermark.refresh then
        Library.Watermark.refresh()
    end
end

function Library.ResetTheme()
    for k, v in pairs(DEFAULT_THEME) do
        Library.SetTheme(k, v)
    end
    Library.SetAccent(DEFAULT_THEME.Accent)
end

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG_FOLDER = "UI_Configs"

local function ensureFolder()
    if not isfolder then return end
    if not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end
end
ensureFolder()

local function configPath(name) return CONFIG_FOLDER .. "/" .. name .. ".json" end

local function serializeValue(v)
    local t = typeof(v)
    if t == "Color3"   then return {__type = "Color3", r = v.R, g = v.G, b = v.B} end
    if t == "Vector2"  then return {__type = "Vector2", x = v.X, y = v.Y} end
    if t == "Vector3"  then return {__type = "Vector3", x = v.X, y = v.Y, z = v.Z} end
    if t == "EnumItem" then return {__type = "EnumItem", enum = tostring(v.EnumType), name = v.Name} end
    return v
end

local function deserializeValue(v)
    if type(v) == "table" and v.__type then
        if v.__type == "Color3"   then return Color3.new(v.r, v.g, v.b) end
        if v.__type == "Vector2"  then return Vector2.new(v.x, v.y) end
        if v.__type == "Vector3"  then return Vector3.new(v.x, v.y, v.z) end
        if v.__type == "EnumItem" then
            local ok, e = pcall(function()
                local et = v.enum:gsub("^Enum%.", "")
                return Enum[et][v.name]
            end)
            if ok then return e end
        end
    end
    return v
end

local function jsonEncode(val)
    local t = type(val)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(val) end
    if t == "number" then
        if val ~= val or val == math.huge or val == -math.huge then return "null" end
        return tostring(val)
    end
    if t == "string" then
        return '"' .. val:gsub('[%z\1-\31\\"]', function(c)
            if c == '"'  then return '\\"' end
            if c == '\\' then return '\\\\' end
            if c == '\n' then return '\\n' end
            if c == '\r' then return '\\r' end
            if c == '\t' then return '\\t' end
            return string.format('\\u%04x', c:byte())
        end) .. '"'
    end
    if t == "table" then
        local isArr, n = true, 0
        for k in pairs(val) do
            n = n + 1
            if type(k) ~= "number" then isArr = false; break end
        end
        if isArr and n == #val then
            local p = {}
            for i = 1, #val do p[i] = jsonEncode(val[i]) end
            return "[" .. table.concat(p, ",") .. "]"
        else
            local p = {}
            for k, v in pairs(val) do
                if type(k) == "string" then
                    p[#p + 1] = jsonEncode(k) .. ":" .. jsonEncode(v)
                end
            end
            return "{" .. table.concat(p, ",") .. "}"
        end
    end
    return "null"
end

local function jsonDecode(str)
    local pos = 1
    local function skip() while pos <= #str and str:sub(pos,pos):match("%s") do pos = pos + 1 end end
    local parseValue
    local function parseString()
        pos = pos + 1
        local out = {}
        while pos <= #str do
            local c = str:sub(pos,pos)
            if c == '"' then pos = pos + 1; break end
            if c == '\\' then
                local n = str:sub(pos+1,pos+1)
                if n == 'n' then out[#out+1] = '\n'
                elseif n == 't' then out[#out+1] = '\t'
                elseif n == 'r' then out[#out+1] = '\r'
                elseif n == 'u' then
                    local hex = str:sub(pos+2,pos+5)
                    out[#out+1] = string.char(tonumber(hex,16) or 63)
                    pos = pos + 4
                else out[#out+1] = n end
                pos = pos + 2
            else
                out[#out+1] = c; pos = pos + 1
            end
        end
        return table.concat(out)
    end
    local function parseNumber()
        local s = pos
        while pos <= #str and str:sub(pos,pos):match("[%d%.eE%+%-]") do pos = pos + 1 end
        return tonumber(str:sub(s, pos-1))
    end
    local function parseObject()
        pos = pos + 1
        local obj = {}
        skip()
        if str:sub(pos,pos) == "}" then pos = pos + 1; return obj end
        while true do
            skip()
            local k = parseString()
            skip(); pos = pos + 1; skip()
            obj[k] = parseValue()
            skip()
            local c = str:sub(pos,pos); pos = pos + 1
            if c == "}" then break end
        end
        return obj
    end
    local function parseArray()
        pos = pos + 1
        local arr = {}
        skip()
        if str:sub(pos,pos) == "]" then pos = pos + 1; return arr end
        while true do
            skip()
            arr[#arr+1] = parseValue()
            skip()
            local c = str:sub(pos,pos); pos = pos + 1
            if c == "]" then break end
        end
        return arr
    end
    function parseValue()
        skip()
        local c = str:sub(pos,pos)
        if c == '"' then return parseString() end
        if c == "{" then return parseObject() end
        if c == "[" then return parseArray() end
        if str:sub(pos,pos+3) == "true"  then pos = pos + 4; return true  end
        if str:sub(pos,pos+4) == "false" then pos = pos + 5; return false end
        if str:sub(pos,pos+3) == "null"  then pos = pos + 4; return nil   end
        return parseNumber()
    end
    local ok, res = pcall(parseValue)
    if ok then return res end
    return nil
end

function Library.saveConfig(name)
    ensureFolder()
    if not writefile then return false, "no writefile" end
    local data = {}
    for _, flagName in ipairs(Library._registered) do
        local ctrl = Library.Flags[flagName]
        if ctrl and ctrl.Get then
            local ok, v = pcall(ctrl.Get, ctrl)
            if ok then data[flagName] = serializeValue(v) end
        end
    end
    data.__accent = serializeValue(THEME.Accent)
    data.__theme = {}
    for k, v in pairs(THEME) do
        if k ~= "Accent" and k ~= "AccentDark" then
            data.__theme[k] = serializeValue(v)
        end
    end
    if Library.Watermark then
        data.__watermark = {
            enabled  = Library.Watermark.enabled,
            position = serializeValue(Library.Watermark.host.Position),
            label1   = Library.Watermark.label1,
            label2   = Library.Watermark.label2,
            label3   = Library.Watermark.label3,
        }
    end
    return pcall(writefile, configPath(name), jsonEncode(data))
end

function Library.loadConfig(name)
    if not readfile or not isfile then return false, "no readfile" end
    if not isfile(configPath(name)) then return false, "not found" end
    local ok, raw = pcall(readfile, configPath(name))
    if not ok then return false, "read failed" end
    local data = jsonDecode(raw)
    if type(data) ~= "table" then return false, "bad json" end
    for flagName, v in pairs(data) do
        if flagName ~= "__watermark" and flagName ~= "__accent" and flagName ~= "__theme" then
            local ctrl = Library.Flags[flagName]
            if ctrl and ctrl.Set then pcall(ctrl.Set, ctrl, deserializeValue(v)) end
        end
    end
    if data.__theme then
        for k, v in pairs(data.__theme) do
            local c = deserializeValue(v)
            if typeof(c) == "Color3" and THEME[k] then Library.SetTheme(k, c) end
        end
    end
    if data.__accent then
        local c = deserializeValue(data.__accent)
        if typeof(c) == "Color3" then Library.SetAccent(c) end
    end
    if data.__watermark and Library.Watermark then
        local wm = Library.Watermark
        wm.enabled = data.__watermark.enabled ~= false
        if wm.host then wm.host.Visible = wm.enabled end
        if data.__watermark.position then wm.host.Position = deserializeValue(data.__watermark.position) end
        if data.__watermark.label1 then wm.label1 = data.__watermark.label1 end
        if data.__watermark.label2 then wm.label2 = data.__watermark.label2 end
        if data.__watermark.label3 then wm.label3 = data.__watermark.label3 end
        if wm.refresh then wm.refresh() end
    end
    return true
end

function Library.listConfigs()
    if not listfiles or not isfolder then return {} end
    ensureFolder()
    local out = {}
    local ok, files = pcall(listfiles, CONFIG_FOLDER)
    if not ok or not files then return out end
    for _, f in ipairs(files) do
        local n = f:match("([^/\\]+)%.json$")
        if n then out[#out + 1] = n end
    end
    return out
end

-- ============================================================
-- SCREEN
-- ============================================================
screenGui = new("ScreenGui", {
    Name           = "ui",
    IgnoreGuiInset = true,
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder   = 999,
}, guiParent())

Library.Screen = screenGui

local popupLayer = new("Frame", {
    Name = "PopupLayer", BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), ZIndex = 500,
}, screenGui)

local openPopups = {}
local function closeAllPopups()
    for _, fn in ipairs(openPopups) do pcall(fn) end
    table.clear(openPopups)
end

local function setScrollLocked(locked)
    for _, w in ipairs(Library._windows) do
        for _, tab in ipairs(w.Tabs) do
            if tab.Page:IsA("ScrollingFrame") then
                tab.Page.ScrollingEnabled = not locked
            end
        end
    end
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
local notifHost = new("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 40),
    Size = UDim2.new(0, 260, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    ZIndex = 420,
}, screenGui)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Padding       = UDim.new(0, 4),
}, notifHost)

local notifOrder = 0
function Library.Notify(title, body, duration, accent)
    accent   = accent or THEME.Accent
    duration = duration or 4
    notifOrder += 1

    local W = 260
    local H = body and 46 or 26

    local row = new("CanvasGroup", {
        Name = "Notif",
        BackgroundColor3 = THEME.BorderOuter,
        BorderSizePixel  = 0,
        Size             = UDim2.fromOffset(W, H),
        Position         = UDim2.fromOffset(-W - 20, 0),
        LayoutOrder      = notifOrder,
        GroupTransparency = 0,
        ZIndex           = 421,
    }, notifHost)

    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0,
        Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 421}, row)
    local fill = new("Frame", {Name = "Fill", BackgroundColor3 = THEME.Window, BorderSizePixel = 0,
        Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 421}, row)
    vGradient(fill, THEME.HeaderTop, THEME.HeaderBottom)

    local strip = new("Frame", {
        BackgroundColor3 = THEME.Accent, BorderSizePixel = 0,
        Position = UDim2.fromOffset(2, 2), Size = UDim2.new(0, 3, 1, -4), ZIndex = 422,
    }, fill)
    registerAccent(strip, nil)

    outlined(fill, title or "notice", THEME.Text, {
        Position = UDim2.fromOffset(12, 4),
        Size     = UDim2.new(1, -18, 0, 14),
        TextSize = 12, Bold = true, ZIndex = 423,
    })
    if body then
        outlined(fill, body, THEME.TextDim, {
            Position = UDim2.fromOffset(12, 22),
            Size     = UDim2.new(1, -18, 0, 14),
            TextSize = 11, ZIndex = 423,
        })
    end

    tween(row, 0.28, {Position = UDim2.fromOffset(0, 0)}):Play()

    task.delay(duration, function()
        if not row.Parent then return end
        local fadeOut = TweenService:Create(row, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
            Position = UDim2.fromOffset(-W - 20, 0),
            GroupTransparency = 1,
        })
        fadeOut:Play()
        fadeOut.Completed:Connect(function() row:Destroy() end)
    end)

    return row
end

-- ============================================================
-- WINDOW
-- ============================================================
local MIN_SIZE = Vector2.new(360, 360)
local MAX_SIZE = Vector2.new(900, 800)

local function syncTabGap(win)
    local tab = win.ActiveTab
    if not tab then return end
    local panelW = win.Canvas.Size.X.Offset - 20
    local gx = panelW - win._tabsTotal + tab.Index * (win._tabW + win._tabSp)
    local tw = win._tabW
    local function seg(f, x, w)
        f.Position = UDim2.fromOffset(x, f.Position.Y.Offset)
        f.Size = UDim2.fromOffset(math.max(0, w), 1)
    end
    seg(win._oT1, 0,           gx)
    seg(win._oT2, gx + tw,     panelW - (gx + tw))
    seg(win._iT1, 1,           gx)
    seg(win._iT2, gx + tw - 1, panelW - gx - tw)
end

local function addResizeHandles(canvas, onResize)
    local T = IS_MOBILE and 8 or 4

    local host = new("Frame", {
        Name = "ResizeHost", BackgroundTransparency = 1, Active = false,
        Position = canvas.Position, Size = canvas.Size, ZIndex = 60,
    }, canvas.Parent)
    local function syncHost()
        host.Position = canvas.Position
        host.Size     = canvas.Size
        host.Visible  = canvas.Visible
    end
    canvas:GetPropertyChangedSignal("Position"):Connect(syncHost)
    canvas:GetPropertyChangedSignal("Size"):Connect(syncHost)
    canvas:GetPropertyChangedSignal("Visible"):Connect(syncHost)

    local edges = {
        {n="N",  p=UDim2.new(0,T,0,-T),  s=UDim2.new(1,-T*2,0,T*2), sx= 0, sy=-1},
        {n="S",  p=UDim2.new(0,T,1,-T),  s=UDim2.new(1,-T*2,0,T*2), sx= 0, sy= 1},
        {n="W",  p=UDim2.new(0,-T,0,T),  s=UDim2.new(0,T*2,1,-T*2), sx=-1, sy= 0},
        {n="E",  p=UDim2.new(1,-T,0,T),  s=UDim2.new(0,T*2,1,-T*2), sx= 1, sy= 0},
        {n="NW", p=UDim2.new(0,-T,0,-T), s=UDim2.fromOffset(T*2,T*2), sx=-1, sy=-1},
        {n="NE", p=UDim2.new(1,-T,0,-T), s=UDim2.fromOffset(T*2,T*2), sx= 1, sy=-1},
        {n="SW", p=UDim2.new(0,-T,1,-T), s=UDim2.fromOffset(T*2,T*2), sx=-1, sy= 1},
        {n="SE", p=UDim2.new(1,-T,1,-T), s=UDim2.fromOffset(T*2,T*2), sx= 1, sy= 1},
    }
    for _, e in ipairs(edges) do
        local h = new("TextButton", {
            Name = "Resize" .. e.n, Text = "", AutoButtonColor = false,
            BackgroundTransparency = 1, Position = e.p, Size = e.s, ZIndex = 60,
        }, host)

        local active, startSize, startPos, startMouse = false, nil, nil, nil
        h.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                active = true
                startSize = Vector2.new(canvas.Size.X.Offset, canvas.Size.Y.Offset)
                startPos  = canvas.Position
                startMouse = UIS:GetMouseLocation()
                closeAllPopups()
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if not active then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local d  = UIS:GetMouseLocation() - startMouse
            local w  = math.clamp(startSize.X + e.sx * d.X, MIN_SIZE.X, MAX_SIZE.X)
            local ht = math.clamp(startSize.Y + e.sy * d.Y, MIN_SIZE.Y, MAX_SIZE.Y)
            local ox = (e.sx < 0) and (startSize.X - w) or 0
            local oy = (e.sy < 0) and (startSize.Y - ht) or 0
            canvas.Size = UDim2.fromOffset(w, ht)
            canvas.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + ox,
                startPos.Y.Scale, startPos.Y.Offset + oy)
            if onResize then onResize() end
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                active = false
            end
        end)
    end
end

function Library:Window(opts)
    opts = opts or {}
    local size  = opts.Size  or Vector2.new(500, 400)
    local title = opts.Title or ""

    local canvas = new("CanvasGroup", {
        Name = "Window",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(0.5, -math.floor(size.X/2), 0.5, -math.floor(size.Y/2)),
        Size = UDim2.fromOffset(size.X, size.Y),
        BackgroundTransparency = 1,
        GroupTransparency = 0,
        ZIndex = 10,
    }, screenGui)

    local wOuter = new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 1}, canvas)
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 1}, wOuter)
    new("Frame", {BackgroundColor3 = THEME.Window, BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 1}, wOuter)

    local titleLbl = outlined(canvas, title, THEME.Text, {
        Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(240, 14),
        Bold = true, ZIndex = 6,
    })

    local panel = new("Frame", {Name = "Panel", BackgroundTransparency = 1, Position = UDim2.fromOffset(10,29), Size = UDim2.new(1,-20,1,-39), ZIndex = 2}, canvas)
    new("Frame", {BackgroundColor3 = THEME.Surface, BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 2}, panel)

    new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.new(0,1,1,0), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Position = UDim2.new(1,-1,0,0), Size = UDim2.new(0,1,1,0), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Position = UDim2.new(0,0,1,-1), Size = UDim2.new(1,0,0,1), ZIndex = 2}, panel)
    local oT1 = new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,0,0,1), ZIndex = 2}, panel)
    local oT2 = new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.fromOffset(0,1), ZIndex = 2}, panel)

    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(0,1,1,-2), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.new(1,-2,0,1), Size = UDim2.new(0,1,1,-2), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.new(0,1,1,-2), Size = UDim2.new(1,-2,0,1), ZIndex = 2}, panel)
    local iT1 = new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,0,1), ZIndex = 2}, panel)
    local iT2 = new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.fromOffset(0,1), ZIndex = 2}, panel)

    local TAB_W, TAB_H, TAB_SP = 76, 18, 2
    local tabHost = new("Frame", {
        Name = "Tabs", BackgroundTransparency = 1,
        Position = UDim2.new(1, -10, 0, 29 - TAB_H),
        Size = UDim2.fromOffset(0, TAB_H), ZIndex = 4,
    }, canvas)

    local pageHost = new("Frame", {
        Name = "Pages", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 37), Size = UDim2.new(1,-36,1,-55),
        ZIndex = 3,
    }, canvas)

    local dragZone = new("TextButton", {BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,-14,0,29), ZIndex = 7, AutoButtonColor = false}, canvas)
    do
        local dragging, startPos, startMouse
        dragZone.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                startPos = canvas.Position
                startMouse = UIS:GetMouseLocation()
                closeAllPopups()
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local d = UIS:GetMouseLocation() - startMouse
            canvas.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local window = setmetatable({
        Canvas = canvas, TabHost = tabHost, PageHost = pageHost,
        DragZone = dragZone, TitleLbl = titleLbl,
        Tabs = {}, ActiveTab = nil, _tabW = TAB_W, _tabH = TAB_H, _tabSp = TAB_SP,
        _oT1 = oT1, _oT2 = oT2, _iT1 = iT1, _iT2 = iT2,
        _tabsTotal = 0,
    }, {__index = Library._WindowMethods})

    addResizeHandles(canvas, function() syncTabGap(window) end)

    Library._windows[#Library._windows + 1] = window
    return window
end

Library._WindowMethods = {}

function Library._WindowMethods:Tab(name)
    local win = self
    local idx = #win.Tabs
    local x = idx * (win._tabW + win._tabSp)

    local btn = new("TextButton", {
        Name = name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(win._tabW, win._tabH),
        ZIndex = 4,
    }, win.TabHost)

    local tOuter = new("Frame", {BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,0,0,win._tabH), ZIndex = 4}, btn)
    local tInner = new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,0,win._tabH-1), ZIndex = 4}, tOuter)
    local tFill  = new("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,0,win._tabH-2), ZIndex = 4}, tOuter)
    local grad = new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, THEME.TabTop),
            ColorSequenceKeypoint.new(0.45, THEME.TabMid),
            ColorSequenceKeypoint.new(1.00, THEME.Surface),
        }),
    }, tFill)

    local label = outlined(btn, name, THEME.TabText, {
        Size = UDim2.new(1,0,0,win._tabH), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
    })

    local page = new("ScrollingFrame", {
        Name = name, BackgroundTransparency = 1, Visible = false,
        Size = UDim2.fromScale(1,1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        ScrollBarImageTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, win.PageHost)
    registerAccent(nil, nil, function() page.ScrollBarImageColor3 = THEME.Accent end)

    local inner = new("Frame", {
        Name = "Inner", BackgroundTransparency = 1,
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
    }, page)

    local leftCol = new("Frame", {
        Name = "LeftCol", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0.5, -3, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3,
    }, inner)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, leftCol)

    local rightCol = new("Frame", {
        Name = "RightCol", BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 3, 0, 0),
        Size = UDim2.new(0.5, -3, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3,
    }, inner)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, rightCol)

    local tab = setmetatable({
        Window = win, Button = btn, Outer = tOuter, Inner = tInner, Fill = tFill,
        Grad = grad, Label = label, Page = page,
        LeftCol = leftCol, RightCol = rightCol,
        Index = idx, _groups = 0,
    }, {__index = Library._TabMethods})
    win.Tabs[#win.Tabs + 1] = tab

    local n = #win.Tabs
    local total = n * win._tabW + (n - 1) * win._tabSp
    win._tabsTotal = total
    win.TabHost.Size = UDim2.fromOffset(total, win._tabH)
    win.TabHost.Position = UDim2.new(1, -(10 + total), 0, 29 - win._tabH)
    win.DragZone.Size = UDim2.new(1, -(14 + total), 0, 29)

    local function select()
        for _, t in ipairs(win.Tabs) do
            local on = (t == tab)
            t.Page.Visible = on
            tween(t.Label, 0.12, {TextColor3 = on and THEME.Accent or THEME.TabText}):Play()

            local oh = win._tabH + (on and 1 or 0)
            local ih = on and (win._tabH + 1) or (win._tabH - 1)
            local fh = on and win._tabH or (win._tabH - 2)
            t.Outer.Size = UDim2.new(1, 0,  0, oh)
            t.Inner.Size = UDim2.new(1, -2, 0, ih)
            t.Fill.Size  = UDim2.new(1, -4, 0, fh)

            local z = on and 6 or 4
            t.Outer.ZIndex, t.Inner.ZIndex, t.Fill.ZIndex = z, z, z
            t.Button.ZIndex = on and 7 or 4
        end
        win.ActiveTab = tab
        syncTabGap(win)
    end
    tab.Select = select

    btn.MouseButton1Click:Connect(function() closeAllPopups(); select() end)
    btn.MouseEnter:Connect(function()
        if win.ActiveTab ~= tab then tween(label, 0.12, {TextColor3 = THEME.TabTextHover}):Play() end
    end)
    btn.MouseLeave:Connect(function()
        if win.ActiveTab ~= tab then tween(label, 0.12, {TextColor3 = THEME.TabText}):Play() end
    end)

    if #win.Tabs == 1 then select() end
    return tab
end

Library._TabMethods = {}

function Library._TabMethods:Group(title)
    local tab = self
    tab._groups += 1

    local HEADER_H = 19
    local parent = (tab._groups % 2 == 1) and tab.LeftCol or tab.RightCol

    local col = new("Frame", {
        Name = title, BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = math.ceil(tab._groups / 2), ZIndex = 3,
    }, parent)
    new("UIPadding", {PaddingTop = UDim.new(0,1), PaddingBottom = UDim.new(0,1),
        PaddingLeft = UDim.new(0,1), PaddingRight = UDim.new(0,1)}, col)

    local innerBox = new("Frame", {
        BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3,
    }, col)
    new("UIPadding", {PaddingTop = UDim.new(0,1), PaddingBottom = UDim.new(0,1),
        PaddingLeft = UDim.new(0,1), PaddingRight = UDim.new(0,1)}, innerBox)

    local body = new("Frame", {
        Name = "Body", BackgroundColor3 = THEME.Element, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3,
    }, innerBox)

    local header = new("Frame", {BackgroundColor3 = THEME.HeaderTop, BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,HEADER_H), ZIndex = 3}, body)
    vGradient(header, THEME.HeaderTop, THEME.HeaderBottom)
    outlined(header, title, THEME.Text, {Position = UDim2.fromOffset(6,0), Size = UDim2.new(1,-6,1,0), ZIndex = 4})
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0,HEADER_H), Size = UDim2.new(1,0,0,1), ZIndex = 4}, body)

    local content = new("Frame", {
        Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, HEADER_H + 1),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3,
    }, body)
    new("UIPadding", {PaddingLeft = UDim.new(0,6), PaddingTop = UDim.new(0,5),
        PaddingRight = UDim.new(0,6), PaddingBottom = UDim.new(0,5)}, content)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder}, content)

    return setmetatable({Tab = tab, Content = content, _order = 0}, {__index = Library._GroupMethods})
end

Library._GroupMethods = {}

local function nextRow(group, height, class)
    group._order += 1
    return new(class or "Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1,0,0,height),
        LayoutOrder = group._order, ZIndex = 3,
    }, group.Content)
end

-- ============================================================
-- CONTROLS
-- ============================================================
local function buildCheckbox(group, text, default, callback, extra, flagName)
    extra = extra or {}
    local state = default and true or false
    local rowH    = IS_MOBILE and 22 or 16
    local boxSize = IS_MOBILE and 14 or 12
    local textX   = boxSize + 7

    local row = nextRow(group, rowH, "TextButton")
    row.Text = ""
    row.AutoButtonColor = false
    row.ZIndex = 3

    local visual = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, (rowH - boxSize) / 2),
        Size     = UDim2.fromOffset(boxSize, boxSize),
        ZIndex   = 3,
    }, row)
    local _, fill = framedBox(visual, THEME.BorderOuter, THEME.BorderInner, THEME.Element, {ZIndex = 3})
    local accent = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), BackgroundTransparency = state and 0 or 1, ZIndex = 3}, fill)
    local accentGrad = vGradient(accent, THEME.Accent, THEME.AccentDark)
    registerAccent(accent, accentGrad)

    local label = outlined(row, text, state and THEME.Text or THEME.TextDim, {
        Position = UDim2.fromOffset(textX, 0),
        Size     = UDim2.new(1, -(textX + 40), 1, 0),
        ZIndex   = 3,
    })

    local function set(v, fireCb)
        state = v and true or false
        tween(accent, 0.12, {BackgroundTransparency = state and 0 or 1}):Play()
        tween(label, 0.12, {TextColor3 = state and THEME.Text or THEME.TextDim}):Play()
        if fireCb ~= false and callback then task.spawn(callback, state) end
    end

    row.MouseButton1Click:Connect(function() set(not state, true) end)
    row.MouseEnter:Connect(function() if not state then tween(fill, 0.12, {BackgroundColor3 = Color3.fromRGB(39,40,57)}):Play() end end)
    row.MouseLeave:Connect(function() if not state then tween(fill, 0.12, {BackgroundColor3 = THEME.Element}):Play() end end)

    if extra.colors then
        local sx = 0
        for _, c in ipairs(extra.colors) do
            sx += 14
            group:_swatch(row, c, UDim2.new(1, -sx, 0, 1))
        end
    end

    if extra.makeKeybind then
        extra.makeKeybind(row, extra.key, 1)
    end

    if callback and default ~= nil then task.spawn(callback, state) end

    local ctrl = {Set = function(_, v) set(v, true) end, Get = function() return state end, _row = row}
    register(flagName, ctrl)
    return ctrl
end

function Library._GroupMethods:Checkbox(text, default, callback, extra)
    return buildCheckbox(self, text, default, callback, extra, extra and extra.flag)
end

-- swatch: single frame + fixed gray stroke, protected from theme swap
local function makeSwatch(parent, size, pos, initialColor, onChange)
    local btn = new("TextButton", {
        Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Size = size, Position = pos, ZIndex = 4, Name = "Swatch",
    }, parent)
    markNoSwap(btn)

    local fill = new("Frame", {
        BackgroundColor3 = initialColor,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 4,
    }, btn)
    markNoSwap(fill)

    local stroke = new("UIStroke", {
        Color = Color3.fromRGB(80, 80, 80),
        Thickness = 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, fill)
    markNoSwap(stroke)

    local current = initialColor
    btn.MouseButton1Click:Connect(function()
        closeAllPopups()
        local abs = btn.AbsolutePosition
        Library._ColorPicker(popupLayer, abs + Vector2.new(size.X.Offset + 4, size.Y.Offset + 4), current, function(c)
            current = c
            fill.BackgroundColor3 = c
            if onChange then task.spawn(onChange, c) end
        end)
    end)

    return function() return current end, function(v)
        if typeof(v) == "Color3" then
            current = v
            fill.BackgroundColor3 = v
            if onChange then task.spawn(onChange, v) end
        end
    end
end

function Library._GroupMethods:_swatch(row, cfg, pos)
    local color = cfg.default or THEME.Accent
    local get, set = makeSwatch(row, UDim2.fromOffset(12, 12), pos, color, cfg.callback)
    return {Get = get, Set = set}
end

function Library._GroupMethods:ColorRow(text, default, callback, flagName)
    local row = nextRow(self, 20)
    outlined(row, text, THEME.TextDim, {
        Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,-30,1,0), ZIndex = 3,
    })
    local get, set = makeSwatch(row, UDim2.fromOffset(20, 14),
        UDim2.new(1, -20, 0, 3), default or THEME.Accent, callback)
    local ctrl = {Get = get, Set = set}
    register(flagName, ctrl)
    return ctrl
end

function Library._GroupMethods:Slider(text, o, callback)
    o = o or {}
    local minv, maxv = o.min or 0, o.max or 1
    local decimals   = o.decimals ~= nil and o.decimals or 3
    local isInt      = o.int and true or false
    local suffix     = o.suffix or ""
    local value      = o.default or minv

    local row = nextRow(self, 28)
    local label = outlined(row, text, THEME.TextDim, {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})
    local valLbl = outlined(row, "", THEME.TextDim, {Position = UDim2.new(1,-120,0,0), Size = UDim2.fromOffset(120,13), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local track = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,12), ZIndex = 3}, row)
    local _, tFill = framedBox(track, THEME.BorderOuter, THEME.BorderInner, THEME.Element, {ZIndex = 3})
    local prog = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0,1), ZIndex = 3}, tFill)
    local progGrad = vGradient(prog, THEME.Accent, THEME.AccentDark)
    registerAccent(prog, progGrad)

    local function fmt(v)
        if isInt then return string.format("%d%s", v, suffix) end
        return string.format("%." .. decimals .. "f%s", v, suffix)
    end
    local function render()
        local t = (maxv > minv) and (value - minv) / (maxv - minv) or 0
        prog.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
        valLbl.Text = fmt(value)
    end
    local function set(v, fireCb)
        v = math.clamp(v, minv, maxv)
        if isInt then v = math.floor(v + 0.5) end
        value = v; render()
        if fireCb ~= false and callback then task.spawn(callback, value) end
    end

    local dragging = false
    local function fromMouse()
        local rel = (UIS:GetMouseLocation().X - tFill.AbsolutePosition.X) / tFill.AbsoluteSize.X
        set(minv + math.clamp(rel, 0, 1) * (maxv - minv), true)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setScrollLocked(true); fromMouse()
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        fromMouse()
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging then setScrollLocked(false) end
            dragging = false
        end
    end)
    track.MouseEnter:Connect(function() tween(label,0.12,{TextColor3=THEME.Text}):Play(); tween(valLbl,0.12,{TextColor3=THEME.Text}):Play() end)
    track.MouseLeave:Connect(function() if not dragging then tween(label,0.12,{TextColor3=THEME.TextDim}):Play(); tween(valLbl,0.12,{TextColor3=THEME.TextDim}):Play() end end)

    render()
    if callback and o.default ~= nil then task.spawn(callback, value) end
    local ctrl = {Set = function(_, v) set(v, true) end, Get = function() return value end}
    register(o.flag, ctrl)
    return ctrl
end

local function plusIcon(parent, color)
    local host = new("Frame", {
        Name = "Icon", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0),
        Size = UDim2.fromOffset(7, 7), ZIndex = 4,
    }, parent)
    new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(0,3), Size = UDim2.fromOffset(7,1), ZIndex = 4}, host)
    local vbar = new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(3,0), Size = UDim2.fromOffset(1,7), ZIndex = 4}, host)
    return {
        SetOpen = function(open) vbar.Visible = not open end,
        IsOpen  = function() return not vbar.Visible end,
    }
end

local function buildComboPopup(box, items, isMulti, getState, onPick)
    closeAllPopups()
    local ITEM_H = IS_MOBILE and 22 or 16
    local abs, sz = box.AbsolutePosition, box.AbsoluteSize
    local pop = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(abs.X, abs.Y + sz.Y + 1), Size = UDim2.fromOffset(sz.X, #items * ITEM_H + 4), ZIndex = 501}, popupLayer)
    local _, pfill = framedBox(pop, THEME.BorderOuter, THEME.InputBorder, THEME.Input, {ZIndex = 501})

    for i, it in ipairs(items) do
        local ib = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,(i-1)*ITEM_H), Size = UDim2.new(1,0,0,ITEM_H), ClipsDescendants = true, ZIndex = 502}, pfill)
        local sel = getState(i)
        local il = outlined(ib, (sel and "> " or "") .. it, sel and THEME.TextSelected or THEME.TextDim, {Position = UDim2.fromOffset(5,0), Size = UDim2.new(1,-7,1,0), ZIndex = 503})
        ib.MouseEnter:Connect(function() if not getState(i) then tween(il,0.1,{TextColor3=THEME.Text}):Play() end end)
        ib.MouseLeave:Connect(function() if not getState(i) then tween(il,0.1,{TextColor3=THEME.TextDim}):Play() end end)
        ib.MouseButton1Click:Connect(function()
            onPick(i)
            if isMulti then
                local s = getState(i)
                il.Text = (s and "> " or "") .. it
                il.TextColor3 = s and THEME.TextSelected or THEME.TextDim
            else
                closeAllPopups()
            end
        end)
    end

    local blocker = new("TextButton", {
        Name = "Blocker", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = 500,
    }, popupLayer)
    blocker.MouseButton1Click:Connect(closeAllPopups)

    openPopups[#openPopups + 1] = function() blocker:Destroy(); pop:Destroy() end
    return pop
end

function Library._GroupMethods:Combo(text, items, default, callback, flagName)
    local index = default or 1
    local row = nextRow(self, 34)
    outlined(row, text, THEME.TextDim, {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,18), ClipsDescendants = true, ZIndex = 3}, row)
    framedBox(box, THEME.BorderOuter, THEME.InputBorder, THEME.Input, {ZIndex = 3})
    local preview = outlined(box, items[index] or "", THEME.TextDim, {Position = UDim2.fromOffset(5,1), Size = UDim2.new(1,-20,1,-2), TextSize = 12, ZIndex = 4})
    local icon = plusIcon(box, THEME.Accent)

    box.MouseEnter:Connect(function() tween(preview,0.12,{TextColor3=THEME.Text}):Play() end)
    box.MouseLeave:Connect(function() tween(preview,0.12,{TextColor3=THEME.TextDim}):Play() end)
    box.MouseButton1Click:Connect(function()
        if icon.IsOpen() then closeAllPopups(); icon.SetOpen(false); return end
        icon.SetOpen(true)
        local pop = buildComboPopup(box, items, false, function(i) return i == index end, function(i)
            index = i; preview.Text = items[i]; if callback then task.spawn(callback, i, items[i]) end
        end)
        openPopups[#openPopups + 1] = function() icon.SetOpen(false) end
        pop.AncestryChanged:Connect(function() if not pop.Parent then icon.SetOpen(false) end end)
    end)
    if callback and default then task.spawn(callback, index, items[index]) end
    local ctrl = {Set = function(_, i) index = i; preview.Text = items[i] end, Get = function() return index end}
    register(flagName, ctrl)
    return ctrl
end

function Library._GroupMethods:MultiCombo(text, items, defaults, callback, flagName)
    local state = {}
    for i = 1, #items do state[i] = defaults and defaults[i] or false end
    local row = nextRow(self, 34)
    outlined(row, text, THEME.TextDim, {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,18), ClipsDescendants = true, ZIndex = 3}, row)
    framedBox(box, THEME.BorderOuter, THEME.InputBorder, THEME.Input, {ZIndex = 3})
    local preview = outlined(box, "", THEME.TextDim, {Position = UDim2.fromOffset(5,1), Size = UDim2.new(1,-20,1,-2), TextSize = 12, ZIndex = 4})
    local icon = plusIcon(box, THEME.Accent)

    local function refresh()
        local parts = {}
        for i, on in ipairs(state) do if on then parts[#parts+1] = items[i] end end
        preview.Text = (#parts == 0) and "none" or table.concat(parts, ", ")
    end
    refresh()

    box.MouseEnter:Connect(function() tween(preview,0.12,{TextColor3=THEME.Text}):Play() end)
    box.MouseLeave:Connect(function() tween(preview,0.12,{TextColor3=THEME.TextDim}):Play() end)
    box.MouseButton1Click:Connect(function()
        if icon.IsOpen() then closeAllPopups(); icon.SetOpen(false); return end
        icon.SetOpen(true)
        local pop = buildComboPopup(box, items, true, function(i) return state[i] end, function(i)
            state[i] = not state[i]; refresh(); if callback then task.spawn(callback, state) end
        end)
        openPopups[#openPopups + 1] = function() icon.SetOpen(false) end
        pop.AncestryChanged:Connect(function() if not pop.Parent then icon.SetOpen(false) end end)
    end)
    local ctrl = {Get = function() return state end, Set = function(_, tbl)
        for i = 1, #items do state[i] = tbl[i] and true or false end
        refresh()
        if callback then task.spawn(callback, state) end
    end}
    register(flagName, ctrl)
    return ctrl
end

local function makeKeybindBox(parent, key, mode, onKey, onMode)
    local BOX_W, BOX_H = 32, 12
    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,0,0,1), Size = UDim2.fromOffset(BOX_W, BOX_H), ZIndex = 5}, parent)
    local _, bFill = framedBox(box, THEME.BorderOuter, THEME.BorderInner, THEME.Element, {ZIndex = 5})
    local lbl = outlined(bFill, keyName(key), THEME.TextDim, {Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, TextSize = 11})

    local listening = false
    box.MouseButton1Click:Connect(function()
        listening = true; lbl.Text = "..."; lbl.TextColor3 = THEME.Accent
        local conn
        conn = UIS.InputBegan:Connect(function(inp, gp)
            if not listening then return end
            if inp.UserInputType == Enum.UserInputType.Touch then return end
            local k
            if inp.UserInputType == Enum.UserInputType.Keyboard then
                if inp.KeyCode == Enum.KeyCode.Escape then k = nil else k = inp.KeyCode end
            elseif inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.MouseButton2
                or inp.UserInputType == Enum.UserInputType.MouseButton3 then
                k = inp.UserInputType
            else return end
            listening = false; conn:Disconnect()
            key = k; lbl.Text = keyName(k); lbl.TextColor3 = THEME.TextDim
            if onKey then onKey(k) end
            if Library._hotkeyPanel then Library._hotkeyPanel.refresh() end
        end)
    end)

    local function openModePopup()
        closeAllPopups()
        local abs = bFill.AbsolutePosition
        local modes = {"toggle", "hold", "always"}
        local ITEM_H = IS_MOBILE and 22 or 16
        local pop = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(abs.X - 28, abs.Y + 13), Size = UDim2.fromOffset(60, #modes*ITEM_H), ZIndex = 501}, popupLayer)
        local _, pf = framedBox(pop, THEME.BorderOuter, THEME.InputBorder, THEME.Input, {ZIndex = 501})
        for i, m in ipairs(modes) do
            local mb = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,(i-1)*ITEM_H), Size = UDim2.fromOffset(60,ITEM_H), ZIndex = 502}, pf)
            outlined(mb, m, (mode == i) and THEME.Accent or THEME.TextDim, {Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 503})
            mb.MouseButton1Click:Connect(function() mode = i; if onMode then onMode(i, m) end closeAllPopups() end)
        end
        local blocker = new("TextButton", {
            Name = "Blocker", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1), ZIndex = 500,
        }, popupLayer)
        blocker.MouseButton1Click:Connect(closeAllPopups)
        openPopups[#openPopups+1] = function() blocker:Destroy(); pop:Destroy() end
    end

    box.MouseButton2Click:Connect(openModePopup)

    local lpStart = nil
    box.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then lpStart = tick() end
    end)
    box.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch and lpStart then
            local dur = tick() - lpStart
            lpStart = nil
            if dur >= 0.5 then openModePopup() end
        end
    end)

    return box, function() return key, mode end
end

function Library._GroupMethods:Keybind(text, default, callback)
    local row = nextRow(self, IS_MOBILE and 20 or 14)
    outlined(row, text, THEME.TextDim, {Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,-38,1,0), ZIndex = 3})
    local _, getKb = makeKeybindBox(row, default, 1, function(k) if callback then task.spawn(callback, k) end end)
    registerHotkey(text, getKb)
end

function Library._GroupMethods:CheckboxKeybind(text, default, key, callback, flagName)
    local getKbRef
    local ctrl = buildCheckbox(self, text, default, callback, {
        key = key,
        makeKeybind = function(row, kbKey, kbMode)
            local _, getKb = makeKeybindBox(row, kbKey, kbMode)
            getKbRef = getKb
        end,
    }, flagName)
    if getKbRef then registerHotkey(text, getKbRef) end
    return ctrl
end

function Library._GroupMethods:Label(text)
    local row = nextRow(self, 14)
    outlined(row, text, THEME.TextDim, {Size = UDim2.fromScale(1,1), ZIndex = 3})
end

function Library._GroupMethods:Textbox(text, default, callback, flagName)
    local row = nextRow(self, 34)
    outlined(row, text, THEME.TextDim, {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,18), ZIndex = 3}, row)
    framedBox(box, THEME.BorderOuter, THEME.InputBorder, THEME.Input, {ZIndex = 3})

    local tb = new("TextBox", {
        BackgroundTransparency = 1,
        Text = default or "",
        TextColor3 = THEME.TextDim,
        TextSize = 12,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(5,1),
        Size = UDim2.new(1,-10,1,-2),
        ClearTextOnFocus = false,
        ZIndex = 5,
    }, box)

    local function apply() if callback then task.spawn(callback, tb.Text) end end
    tb.Focused:Connect(function() tween(tb, 0.12, {TextColor3 = THEME.Text}):Play() end)
    tb.FocusLost:Connect(function() tween(tb, 0.12, {TextColor3 = THEME.TextDim}):Play(); apply() end)

    local ctrl = {Set = function(_, v) tb.Text = tostring(v or "") end, Get = function() return tb.Text end}
    register(flagName, ctrl)
    return ctrl
end

function Library._GroupMethods:Button(text, callback)
    local row = nextRow(self, 20, "TextButton")
    row.Text = ""
    row.AutoButtonColor = false
    row.ZIndex = 3
    local _, fill = framedBox(row, THEME.BorderOuter, THEME.BorderInner, THEME.Element, {ZIndex = 3})
    vGradient(fill, THEME.HeaderTop, THEME.HeaderBottom)
    outlined(fill, text, THEME.Text, {Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4})
    row.MouseEnter:Connect(function() tween(fill, 0.12, {BackgroundColor3 = Color3.fromRGB(35,36,45)}):Play() end)
    row.MouseLeave:Connect(function() tween(fill, 0.12, {BackgroundColor3 = THEME.Element}):Play() end)
    row.MouseButton1Click:Connect(function() if callback then task.spawn(callback) end end)
    return row
end

function Library._ColorPicker(parent, pos, startColor, onChange)
    local h, s, v = Color3.toHSV(startColor)
    local W   = IS_MOBILE and 200 or 150
    local HGT = IS_MOBILE and 160 or 100
    local pop = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(pos.X - W + 12, pos.Y), Size = UDim2.fromOffset(W, HGT + 20), ZIndex = 510}, parent)
    local _, pf = framedBox(pop, THEME.BorderOuter, THEME.BorderInner, THEME.Window, {ZIndex = 510})

    local sv = new("ImageButton", {BackgroundColor3 = Color3.fromHSV(h,1,1), BorderSizePixel = 0, Position = UDim2.fromOffset(6,6), Size = UDim2.fromOffset(W-30, HGT), ZIndex = 511, AutoButtonColor = false}, pf)
    local white = new("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 511}, sv)
    new("UIGradient", {Rotation = 0, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})}, white)
    local blk = new("Frame", {BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 511}, sv)
    new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)})}, blk)

    local hue = new("ImageButton", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Position = UDim2.new(1,-16,0,6), Size = UDim2.fromOffset(12,HGT), ZIndex = 511, AutoButtonColor = false}, pf)
    local hg = new("UIGradient", {Rotation = 90}, hue)
    hg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(0.34, Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)),
        ColorSequenceKeypoint.new(0.84, Color3.fromRGB(255,0,255)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
    })

    local function push() if onChange then onChange(Color3.fromHSV(h,s,v)) end end
    local function updateSV() sv.BackgroundColor3 = Color3.fromHSV(h,1,1); push() end

    local dragSV, dragHue = false, false
    sv.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragSV = true; setScrollLocked(true)
        end
    end)
    hue.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragHue = true; setScrollLocked(true)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragSV or dragHue then setScrollLocked(false) end
            dragSV, dragHue = false, false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local m = UIS:GetMouseLocation()
        if dragSV then
            s = math.clamp((m.X - sv.AbsolutePosition.X)/sv.AbsoluteSize.X, 0, 1)
            v = 1 - math.clamp((m.Y - sv.AbsolutePosition.Y)/sv.AbsoluteSize.Y, 0, 1)
            push()
        elseif dragHue then
            h = math.clamp((m.Y - hue.AbsolutePosition.Y)/hue.AbsoluteSize.Y, 0, 1)
            updateSV()
        end
    end)

    local blocker = new("TextButton", {
        Name = "Blocker", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = 509,
    }, parent)
    blocker.MouseButton1Click:Connect(function()
        if not dragSV and not dragHue then closeAllPopups() end
    end)

    openPopups[#openPopups+1] = function() blocker:Destroy(); pop:Destroy() end
end

-- ============================================================
-- WATERMARK
-- ============================================================
Library.Watermark = {
    enabled = true,
    label1  = "ui",
    label2  = "v" .. Library.Version,
    label3  = os.date("%b %d %Y"),
    host    = nil,
}

function Library.Watermark.refresh()
    local wm = Library.Watermark
    if not wm.host then return end
    local PAD, GAP, H = 8, 4, 21
    local parts = {
        {t = wm.label1, c = THEME.Text},
        {t = wm.label2, c = THEME.Accent},
        {t = wm.label3, c = Color3.fromRGB(100,100,100)},
    }
    local total = PAD * 2
    for i, p in ipairs(parts) do
        total = total + TextService:GetTextSize(p.t, TEXT_SIZE, FONT, Vector2.new(10000, 100)).X
        if i < #parts then total = total + GAP end
    end
    wm.host.Size = UDim2.fromOffset(math.ceil(total), H)
    local fill = wm.host:FindFirstChild("Fill")
    if fill then
        local strip = fill:FindFirstChild("Strip")
        if strip then
            for _, c in ipairs(strip:GetChildren()) do
                if c:IsA("TextLabel") then c:Destroy() end
            end
            for i, p in ipairs(parts) do
                outlined(strip, p.t, p.c, {
                    AutomaticSize = Enum.AutomaticSize.X,
                    Size = UDim2.fromOffset(0, H - 4),
                    TextTruncate = Enum.TextTruncate.None,
                    LayoutOrder = i, ZIndex = 401,
                })
            end
        end
    end
end

local function makeWatermark()
    local wm = Library.Watermark
    local H = 21
    local host = new("Frame", {
        Name = "Watermark", BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(100, H), ZIndex = 400,
        Visible = wm.enabled,
    }, screenGui)
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 400}, host)
    local fill = new("Frame", {Name = "Fill", BackgroundColor3 = THEME.Window, BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 400}, host)
    vGradient(fill, Color3.fromRGB(17,17,16), Color3.fromRGB(15,14,14))

    local strip = new("Frame", {Name = "Strip", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1,-6,1,0), ZIndex = 401}, fill)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder}, strip)

    wm.host = host

    local grab = new("TextButton", {Name = "Drag", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 402}, host)
    local dragging, startPos, startMouse = false, nil, nil
    grab.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startPos = host.Position; startMouse = UIS:GetMouseLocation()
            closeAllPopups()
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = UIS:GetMouseLocation() - startMouse
        host.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    Library.Watermark.refresh()
    return host
end

-- ============================================================
-- HOTKEYS PANEL
-- ============================================================
local function makeHotkeyPanel()
    local W, HDR = 200, 19
    local host = new("Frame", {
        Name = "HotkeysPanel", BackgroundColor3 = THEME.BorderOuter, BorderSizePixel = 0,
        Position = UDim2.new(1, -W - 14, 0, 60), Size = UDim2.fromOffset(W, HDR + 10),
        ZIndex = 410, Visible = false, AutomaticSize = Enum.AutomaticSize.Y,
    }, screenGui)
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 410}, host)
    local body = new("Frame", {Name = "Body", BackgroundColor3 = THEME.Element, BorderSizePixel = 0,
        Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 410, AutomaticSize = Enum.AutomaticSize.Y}, host)

    local header = new("Frame", {Name = "Header", BackgroundColor3 = THEME.HeaderTop, BorderSizePixel = 0, Size = UDim2.new(1,0,0,HDR), ZIndex = 411}, body)
    vGradient(header, THEME.HeaderTop, THEME.HeaderBottom)
    outlined(header, "hotkeys", THEME.Text, {Position = UDim2.fromOffset(6,0), Size = UDim2.new(1,-6,1,0), ZIndex = 412})
    new("Frame", {BackgroundColor3 = THEME.BorderInner, BorderSizePixel = 0, Position = UDim2.fromOffset(0,HDR), Size = UDim2.new(1,0,0,1), ZIndex = 412}, body)

    local content = new("Frame", {Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, HDR + 1), Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 411}, body)
    new("UIPadding", {PaddingLeft = UDim.new(0,6), PaddingTop = UDim.new(0,4), PaddingRight = UDim.new(0,6), PaddingBottom = UDim.new(0,6)}, content)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0,2), SortOrder = Enum.SortOrder.LayoutOrder}, content)

    local hDrag = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ZIndex = 413}, header)
    local dragging, startPos, startMouse = false, nil, nil
    hDrag.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startPos = host.Position; startMouse = UIS:GetMouseLocation()
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = UIS:GetMouseLocation() - startMouse
        host.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local panel = {host = host}
    function panel.refresh()
        for _, c in ipairs(content:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        local any, idx = false, 0
        for _, hk in ipairs(Library._hotkeys) do
            local k = hk.getKey and hk.getKey() or nil
            if k ~= nil then
                any = true; idx += 1
                local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = idx, ZIndex = 411}, content)
                outlined(row, hk.name, THEME.TextDim, {Position = UDim2.fromOffset(0,0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 412})
                outlined(row, keyName(k), THEME.Accent, {Position = UDim2.new(1, -56, 0, 0), Size = UDim2.fromOffset(56, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 412})
            end
        end
        if not any then
            local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, ZIndex = 411}, content)
            outlined(row, "no keybinds set", Color3.fromRGB(90,90,90), {Size = UDim2.fromScale(1,1), ZIndex = 412})
        end
    end
    panel.refresh()
    Library._hotkeyPanel = panel
    return panel
end

-- ============================================================
-- CURSOR
-- ============================================================
local function makeCursor()
    local S, C = 11, 5
    local gui = new("ScreenGui", {
        Name = "cursor", IgnoreGuiInset = true, ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2147483647,
    }, guiParent())

    local host = new("Frame", {
        Name = "Cross", BackgroundTransparency = 1, Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(S, S), Visible = false, ZIndex = 1,
    }, gui)
    host.Active = false
    pcall(function() host.Interactable = false end)

    local function bar(color, x, y, w, h, z)
        local f = new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z}, host)
        f.Active = false
        pcall(function() f.Interactable = false end)
    end

    bar(THEME.BorderOuter, 0, C - 1, S, 3, 1)
    bar(THEME.BorderOuter, C - 1, 0, 3, S, 1)
    bar(THEME.Text, 1, C, S - 2, 1, 2)
    bar(THEME.Text, C, 1, 1, S - 2, 2)
    return host
end

local cursor = makeCursor()
local cursorConns = {}

local function moveCursor()
    local m = UIS:GetMouseLocation()
    cursor.Position = UDim2.fromOffset(m.X, m.Y)
end

local function setCursorEnabled(on)
    on = on and Library.CursorEnabled
    if IS_MOBILE then on = false end
    cursor.Visible = on
    UIS.MouseIconEnabled = not on

    if on and #cursorConns == 0 then
        moveCursor()
        cursorConns[1] = RunService.RenderStepped:Connect(moveCursor)
        cursorConns[2] = UIS.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseMovement then moveCursor() end
        end)
    elseif not on and #cursorConns > 0 then
        for _, c in ipairs(cursorConns) do c:Disconnect() end
        table.clear(cursorConns)
    end
end

function Library:BindToggle(window)
    local visible = true
    setCursorEnabled(true)

    local function toggle(force)
        visible = (force ~= nil) and force or not visible
        closeAllPopups()
        setCursorEnabled(visible)
        if visible then window.Canvas.Visible = true end
        local tw = TweenService:Create(window.Canvas,
            TweenInfo.new(0.30, Enum.EasingStyle.Cubic, visible and Enum.EasingDirection.Out or Enum.EasingDirection.In),
            {GroupTransparency = visible and 0 or 1})
        tw:Play()
        if not visible then
            tw.Completed:Connect(function() window.Canvas.Visible = false end)
        end
    end

    UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Library.ToggleKey then toggle() end
    end)

    return toggle
end

local function makeMobileToggle(onTap)
    local S, R = 44, 12
    local host = new("TextButton", {
        Name = "MobileToggle", BackgroundColor3 = THEME.Window, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.fromOffset(S, S), Text = "", AutoButtonColor = false,
        ClipsDescendants = true, ZIndex = 450,
    }, screenGui)
    new("UICorner", {CornerRadius = UDim.new(0, R)}, host)

    local fill = new("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 450}, host)
    new("UICorner", {CornerRadius = UDim.new(0, R)}, fill)
    vGradient(fill, THEME.HeaderTop, THEME.HeaderBottom)

    new("UIStroke", {Color = THEME.BorderInner, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, host)

    local icon = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 14), ZIndex = 452}, fill)
    for i = 1, 3 do
        local bar = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, (i-1) * 6), Size = UDim2.new(1, 0, 0, 2), ZIndex = 452}, icon)
        registerAccent(bar, nil)
    end

    local dragging, moved, startPos, startMouse = false, false, nil, nil
    host.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startPos = host.Position
            startMouse = UIS:GetMouseLocation()
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = UIS:GetMouseLocation() - startMouse
        if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
        host.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then onTap() end
            dragging = false
        end
    end)
    return host
end

-- ============================================================
-- SETTINGS TAB
-- ============================================================
local COLOR_KEYS = {
    {"accent",          "Accent",        true},   -- accent uses SetAccent
    {"window background","Window",       false},
    {"panel background", "Surface",      false},
    {"element background","Element",     false},
    {"input background", "Input",        false},
    {"input border",     "InputBorder",  false},
    {"outer border",     "BorderOuter",  false},
    {"inner border",     "BorderInner",  false},
    {"text",             "Text",         false},
    {"text dim",         "TextDim",      false},
    {"text selected",    "TextSelected", false},
    {"header top",       "HeaderTop",    false},
    {"header bottom",    "HeaderBottom", false},
    {"tab top",          "TabTop",       false},
    {"tab mid",          "TabMid",       false},
    {"tab bottom",       "TabBottom",    false},
    {"tab text",         "TabText",      false},
    {"tab text hover",   "TabTextHover", false},
}

function Library:BuildSettings(window)
    local wm = Library.Watermark
    local st = window:Tab("settings")

    -- Row 1
    local appearance = st:Group("appearance")
    appearance:Checkbox("show hotkeys", false, function(v)
        if Library._hotkeyPanel then
            Library._hotkeyPanel.host.Visible = v
            if v then Library._hotkeyPanel.refresh() end
        end
    end, {flag = "ui_show_hotkeys"})
    appearance:Checkbox("custom cursor", true, function(v)
        Library.CursorEnabled = v
    end, {flag = "ui_cursor"})
    appearance:Label("right-click keybind = mode")

    local cfgGroup = st:Group("configs")
    local cfgName = "default"
    cfgGroup:Label("folder: " .. CONFIG_FOLDER .. "/")
    cfgGroup:Textbox("config name", cfgName, function(t)
        cfgName = t ~= "" and t or "default"
    end, "cfg_name")
    cfgGroup:Button("save config", function()
        local ok = Library.saveConfig(cfgName)
        Library.Notify(ok and "config saved" or "save failed", cfgName)
    end)
    cfgGroup:Button("load config", function()
        local ok = Library.loadConfig(cfgName)
        Library.Notify(ok and "config loaded" or "load failed", cfgName)
    end)
    cfgGroup:Button("delete config", function()
        if delfile then
            pcall(delfile, configPath(cfgName))
            Library.Notify("config deleted", cfgName)
        end
    end)

    -- Row 2
    local wmGroup = st:Group("watermark")
    wmGroup:Checkbox("enabled", wm.enabled, function(v)
        wm.enabled = v
        if wm.host then wm.host.Visible = v end
    end, {flag = "wm_enabled"})
    wmGroup:Textbox("line 1", wm.label1, function(t)
        wm.label1 = t; Library.Watermark.refresh()
    end, "wm_l1")
    wmGroup:Textbox("line 2", wm.label2, function(t)
        wm.label2 = t; Library.Watermark.refresh()
    end, "wm_l2")
    wmGroup:Textbox("line 3", wm.label3, function(t)
        wm.label3 = t; Library.Watermark.refresh()
    end, "wm_l3")

    local nGroup = st:Group("notifications")
    nGroup:Label("toasts appear top-left")
    nGroup:Button("test notification", function()
        Library.Notify("test", "this is a notification", 4)
    end)
    nGroup:Button("long notification", function()
        Library.Notify("heads up", "this one sticks around a bit longer", 6)
    end)

    -- Row 3+: colors, one per row (uses ColorRow)
    local colorsGroup = st:Group("colors")
    for _, entry in ipairs(COLOR_KEYS) do
        local label, key, isAccent = entry[1], entry[2], entry[3]
        colorsGroup:ColorRow(label, THEME[key], function(c)
            if isAccent then Library.SetAccent(c)
            else Library.SetTheme(key, c) end
        end, "color_" .. key)
    end

    -- reset group
    local resetGroup = st:Group("reset")
    resetGroup:Button("reset colors", function()
        Library.ResetTheme()
        Library.Notify("theme reset")
    end)
    resetGroup:Button("reload ui", function()
        Library.Notify("reload", "script will need manual re-run")
    end)

    return st
end

-- ============================================================
-- BOOT
-- ============================================================
makeWatermark()
makeHotkeyPanel()

Library._cursor = cursor
Library.setCursorEnabled = setCursorEnabled
Library.makeMobileToggle = makeMobileToggle
Library.closeAllPopups = closeAllPopups

return Library
