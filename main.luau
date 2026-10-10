--!nonstrict
--============================================================
-- angel ui — extended
-- Version: 2.0.0
--============================================================

local UIS         = game:GetService("UserInputService")
local TweenService= game:GetService("TweenService")
local RunService  = game:GetService("RunService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local IS_MOBILE = UIS.TouchEnabled and not UIS.MouseEnabled

local function guiParent()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return LocalPlayer:WaitForChild("PlayerGui")
end

--============================================================
-- THEME (all colors + geometry tokens live here)
--============================================================
local THEME = {
    Accent        = Color3.fromRGB(147, 161, 254),
    AccentDark    = Color3.fromRGB(121, 132, 208),
    TextActive    = Color3.fromRGB(255, 255, 255),
    TextInactive  = Color3.fromRGB(136, 136, 136),

    OuterBorder   = Color3.fromRGB(0,   0,   0),
    InnerBorder   = Color3.fromRGB(31,  30,  31),
    PanelFill     = Color3.fromRGB(17,  17,  16),

    ContentOuter  = Color3.fromRGB(31,  30,  31),
    ContentInner  = Color3.fromRGB(0,   0,   0),
    ContentFill   = Color3.fromRGB(21,  21,  20),
    ChildFill     = Color3.fromRGB(15,  14,  14),

    ComboInner    = Color3.fromRGB(24,  24,  25),
    ComboFill     = Color3.fromRGB(18,  19,  19),
    ComboSelected = Color3.fromRGB(155, 168, 250),

    HeaderTop     = Color3.fromRGB(28,  29,  28),
    HeaderBottom  = Color3.fromRGB(15,  14,  14),
    TabTop        = Color3.fromRGB(38,  39,  38),
    TabMid        = Color3.fromRGB(27,  27,  27),
    TabBottom     = Color3.fromRGB(21,  21,  20),
    TabInactive   = Color3.fromRGB(128, 128, 128),
    TabHover      = Color3.fromRGB(208, 208, 208),
}
local DEFAULT_THEME = {}
for k, v in pairs(THEME) do DEFAULT_THEME[k] = v end

local FONT       = Enum.Font.SourceSans
local FONT_BOLD  = Enum.Font.SourceSansBold
local TEXT_SIZE  = 13
local STROKE_T   = 0.55
local T_HOVER    = 0.15
local T_OPEN     = 0.25

local Library = {}
Library.__index = Library
Library.Theme    = THEME
Library.Toggled  = true
Library.ToggleKey= Enum.KeyCode.Insert
Library._VERSION = "2.0.0"
Library.Flags    = {}
Library._subs    = {}
Library._popups  = {}
Library._windows = {}
Library._hotkeys = {}
Library._hotkeyPanel = nil

--============================================================
-- UTILITIES
--============================================================
local function new(class, props, parent)
    local o = Instance.new(class)
    if props then for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end end
    if parent then o.Parent = parent end
    return o
end

local function applyFont(label, bold)
    label.Font = bold and FONT_BOLD or FONT
end

local function tween(inst, t, goal)
    return TweenService:Create(inst, TweenInfo.new(t or T_HOVER, Enum.EasingStyle.Quad), goal)
end

-- registers a themed prop so SetTheme() can repaint live
local function bind(inst, prop, key)
    if not inst or not key then return end
    inst[prop] = THEME[key]
    Library._subs[#Library._subs + 1] = {inst = inst, prop = prop, key = key}
end

local function outlined(parent, text, colorKey, props)
    local bold = props and props.Bold
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Text                   = text or "",
        TextSize               = TEXT_SIZE,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Center,
        TextStrokeColor3       = THEME.OuterBorder,
        TextStrokeTransparency = STROKE_T,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        RichText               = false,
        ZIndex                 = 5,
    }, parent)
    applyFont(l, bold)
    if type(colorKey) == "Color3" then
        l.TextColor3 = colorKey
    else
        bind(l, "TextColor3", colorKey or "TextActive")
    end
    bind(l, "TextStrokeColor3", "OuterBorder")
    if props then
        for k, v in pairs(props) do if k ~= "Bold" then l[k] = v end end
    end
    return l
end

local function framedBox(parent, outerKey, innerKey, fillKey, props)
    local outer = new("Frame", {
        BackgroundColor3 = THEME[outerKey] or outerKey,
        BorderSizePixel  = 0,
        Size             = UDim2.fromScale(1, 1),
    }, parent)
    bind(outer, "BackgroundColor3", outerKey)
    if props then for k, v in pairs(props) do outer[k] = v end end
    local inner = new("Frame", {
        BackgroundColor3 = THEME[innerKey] or innerKey,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(1, 1),
        Size             = UDim2.new(1, -2, 1, -2),
        ZIndex           = (outer.ZIndex or 1),
    }, outer)
    bind(inner, "BackgroundColor3", innerKey)
    local fill = new("Frame", {
        Name             = "Fill",
        BackgroundColor3 = THEME[fillKey] or fillKey,
        BorderSizePixel  = 0,
        Position         = UDim2.fromOffset(2, 2),
        Size             = UDim2.new(1, -4, 1, -4),
        ZIndex           = (outer.ZIndex or 1),
    }, outer)
    bind(fill, "BackgroundColor3", fillKey)
    return outer, fill
end

local function vGradient(frame, topC, botC)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    return new("UIGradient", {
        Rotation = 90,
        Color    = ColorSequence.new(topC, botC),
    }, frame)
end

local KEY_NAMES = {
    [Enum.UserInputType.MouseButton1] = "Mouse1",
    [Enum.UserInputType.MouseButton2] = "Mouse2",
    [Enum.UserInputType.MouseButton3] = "Mouse3",
    [Enum.KeyCode.LeftShift]  = "LeftShift", [Enum.KeyCode.RightShift]  = "RightShift",
    [Enum.KeyCode.LeftControl]= "LeftCtrl",  [Enum.KeyCode.RightControl]= "RightCtrl",
    [Enum.KeyCode.LeftAlt]    = "LeftAlt",   [Enum.KeyCode.RightAlt]    = "RightAlt",
    [Enum.KeyCode.Space]      = "Space",
    [Enum.KeyCode.Return]     = "Enter",
    [Enum.KeyCode.Tab]        = "Tab",
    [Enum.KeyCode.Backspace]  = "Backspace",
    [Enum.KeyCode.Escape]     = "None",
    [Enum.KeyCode.Insert]     = "Insert",
    [Enum.KeyCode.Delete]     = "Delete",
    [Enum.KeyCode.Up]   = "Up",   [Enum.KeyCode.Down] = "Down",
    [Enum.KeyCode.Left] = "Left", [Enum.KeyCode.Right]= "Right",
}
local function keyName(k)
    if k == nil then return "None" end
    if type(k) == "string" then return k end
    if KEY_NAMES[k] then return KEY_NAMES[k] end
    if typeof(k) == "EnumItem" then return k.Name end
    return "None"
end

--============================================================
-- SCREEN — double-load guard
--============================================================
do
    local root = guiParent()
    local old = root:FindFirstChild("ui")
    if old then old:Destroy() end
end

local screenGui = new("ScreenGui", {
    Name            = "ui",
    IgnoreGuiInset  = true,
    ResetOnSpawn    = false,
    ZIndexBehavior  = Enum.ZIndexBehavior.Sibling,
    DisplayOrder    = 999,
}, guiParent())

local popupLayer = new("Frame", {
    Name = "PopupLayer", BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), ZIndex = 900,
}, screenGui)

local function closeAllPopups()
    local list = Library._popups
    Library._popups = {}
    for _, fn in ipairs(list) do pcall(fn) end
end

local function pushPopup(closeFn)
    Library._popups[#Library._popups + 1] = closeFn
end

--============================================================
-- THEME SYSTEM
--============================================================
function Library:SetTheme(key, value)
    THEME[key] = value
    for _, s in ipairs(self._subs) do
        if s.key == key and s.inst and s.inst.Parent then
            pcall(function() s.inst[s.prop] = value end)
        end
    end
end

function Library:GetTheme(key) return THEME[key] end

function Library:ChangeAccent(c)
    self:SetTheme("Accent", c)
    self:SetTheme("AccentDark", c:Lerp(Color3.fromRGB(0, 0, 0), 0.35))
end

function Library:ResetTheme()
    for k, v in pairs(DEFAULT_THEME) do self:SetTheme(k, v) end
end

--============================================================
-- NOTIFICATIONS
--============================================================
local notifHost = new("Frame", {
    Name = "Notifications",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 0, 14),
    Size = UDim2.new(0, 260, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    ZIndex = 700,
}, screenGui)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5),
}, notifHost)

local _notifOrder = 0
function Library:Notify(o)
    o = o or {}
    local accentKey = (o.Style == "success") and "Success"
        or (o.Style == "warn" or o.Style == "warning") and "Warn"
        or (o.Style == "error" or o.Style == "danger") and "Danger"
        or "Accent"

    -- ensure accent-key colors exist (fallbacks)
    if accentKey == "Success" and not THEME.Success then
        THEME.Success = Color3.fromRGB(90, 200, 120)
    elseif accentKey == "Warn" and not THEME.Warn then
        THEME.Warn = Color3.fromRGB(240, 180, 80)
    elseif accentKey == "Danger" and not THEME.Danger then
        THEME.Danger = Color3.fromRGB(220, 82, 82)
    end

    _notifOrder += 1
    local card = new("CanvasGroup", {
        BackgroundColor3 = THEME.OuterBorder,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(40, 0),
        LayoutOrder = _notifOrder,
        GroupTransparency = 1,
        ZIndex = 701,
    }, notifHost)
    bind(card, "BackgroundColor3", "OuterBorder")

    local inner = new("Frame", {
        BackgroundColor3 = THEME.InnerBorder,
        BorderSizePixel = 0, Position = UDim2.fromOffset(1,1),
        Size = UDim2.new(1,-2,1,-2), ZIndex = 701,
    }, card)
    bind(inner, "BackgroundColor3", "InnerBorder")

    local fill = new("Frame", {
        BackgroundColor3 = THEME.PanelFill, BorderSizePixel = 0,
        Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2),
        ZIndex = 701,
    }, inner)
    bind(fill, "BackgroundColor3", "PanelFill")

    local strip = new("Frame", {
        BackgroundColor3 = THEME[accentKey] or THEME.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, 3, 1, 0),
        ZIndex = 702,
    }, fill)
    bind(strip, "BackgroundColor3", accentKey)

    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
    }, fill)

    local vl = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    }, fill)

    local t = outlined(fill, o.Title or "notice", "TextActive", {
        Size = UDim2.new(1, 0, 0, 15), Bold = true, ZIndex = 703,
    })
    if o.Text and o.Text ~= "" then
        local b = outlined(fill, o.Text, "TextInactive", {
            Size = UDim2.new(1, 0, 0, 0), ZIndex = 703,
            TextSize = 12, TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
        })
    end

    tween(card, T_OPEN, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
    task.delay(o.Duration or 4, function()
        if not card.Parent then return end
        local out = tween(card, T_OPEN, {GroupTransparency = 1, Position = UDim2.fromOffset(40, 0)})
        out.Completed:Connect(function() card:Destroy() end)
    end)
    return card
end

function Library:Success(t, x, d) self:Notify({Title=t, Text=x, Duration=d, Style="success"}) end
function Library:Warn(t, x, d)    self:Notify({Title=t, Text=x, Duration=d, Style="warn"})    end
function Library:Error(t, x, d)   self:Notify({Title=t, Text=x, Duration=d, Style="error"})   end

--============================================================
-- CONFIG
--============================================================
local CONFIG_DIR = "angel_configs"
if isfolder and not isfolder(CONFIG_DIR) then pcall(makefolder, CONFIG_DIR) end

local function serialize(v)
    local t = typeof(v)
    if t == "Color3" then return {__t = "Color3", r = v.R, g = v.G, b = v.B} end
    if t == "EnumItem" then return {__t = "EnumItem", e = tostring(v.EnumType), n = v.Name} end
    return v
end

local function deserialize(v)
    if type(v) == "table" and v.__t == "Color3" then return Color3.new(v.r, v.g, v.b) end
    if type(v) == "table" and v.__t == "EnumItem" then
        local ok, e = pcall(function() return Enum[v.e:gsub("^Enum%.", "")][v.n] end)
        if ok then return e end
    end
    return v
end

function Library:GetConfig()
    local out = {}
    for flag, h in pairs(self.Flags) do
        if h and h.Get then
            local ok, v = pcall(h.Get, h)
            if ok then out[flag] = serialize(v) end
        end
    end
    return out
end

function Library:LoadConfig(data)
    if type(data) ~= "table" then return false end
    for flag, v in pairs(data) do
        local h = self.Flags[flag]
        if h and h.Set then pcall(h.Set, h, deserialize(v)) end
    end
    return true
end

function Library:SaveConfig(name)
    if not writefile then return false end
    return pcall(writefile, CONFIG_DIR .. "/" .. name .. ".json",
        HttpService:JSONEncode(self:GetConfig()))
end

function Library:LoadConfigFile(name)
    if not readfile or not isfile then return false end
    local path = CONFIG_DIR .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, raw = pcall(readfile, path)
    if not ok then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return false end
    return self:LoadConfig(data)
end

function Library:ListConfigs()
    if not listfiles or not isfolder then return {} end
    local out = {}
    local ok, files = pcall(listfiles, CONFIG_DIR)
    if ok and files then
        for _, f in ipairs(files) do
            local n = f:match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end
    return out
end

--============================================================
-- HANDLE REGISTRY
--============================================================
local function registerHandle(flag, h)
    if flag then Library.Flags[flag] = h end
    return h
end

local function registerHotkey(name, getKeyFn)
    Library._hotkeys[#Library._hotkeys + 1] = {name = name, getKey = getKeyFn}
    if Library._hotkeyPanel then Library._hotkeyPanel.refresh() end
end

--============================================================
-- WINDOW LAYOUT
--============================================================
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
        host.Size = canvas.Size
        host.Visible = canvas.Visible
    end
    canvas:GetPropertyChangedSignal("Position"):Connect(syncHost)
    canvas:GetPropertyChangedSignal("Size"):Connect(syncHost)
    canvas:GetPropertyChangedSignal("Visible"):Connect(syncHost)

    local edges = {
        {n="N",  p=UDim2.new(0,T,0,-T),    s=UDim2.new(1,-T*2,0,T*2), sx= 0, sy=-1},
        {n="S",  p=UDim2.new(0,T,1,-T),    s=UDim2.new(1,-T*2,0,T*2), sx= 0, sy= 1},
        {n="W",  p=UDim2.new(0,-T,0,T),    s=UDim2.new(0,T*2,1,-T*2), sx=-1, sy= 0},
        {n="E",  p=UDim2.new(1,-T,0,T),    s=UDim2.new(0,T*2,1,-T*2), sx= 1, sy= 0},
        {n="NW", p=UDim2.new(0,-T,0,-T),   s=UDim2.fromOffset(T*2,T*2), sx=-1, sy=-1},
        {n="NE", p=UDim2.new(1,-T,0,-T),   s=UDim2.fromOffset(T*2,T*2), sx= 1, sy=-1},
        {n="SW", p=UDim2.new(0,-T,1,-T),   s=UDim2.fromOffset(T*2,T*2), sx=-1, sy= 1},
        {n="SE", p=UDim2.new(1,-T,1,-T),   s=UDim2.fromOffset(T*2,T*2), sx= 1, sy= 1},
    }
    for _, e in ipairs(edges) do
        local h = new("TextButton", {
            Name = "Resize" .. e.n, Text = "", AutoButtonColor = false,
            BackgroundTransparency = 1, Position = e.p, Size = e.s, ZIndex = 60,
        }, host)
        local active, startSize, startPos, startMouse = false, nil, nil, nil
        local function begin()
            active = true
            startSize = Vector2.new(canvas.Size.X.Offset, canvas.Size.Y.Offset)
            startPos = canvas.Position
            startMouse = UIS:GetMouseLocation()
            closeAllPopups()
        end
        h.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then begin() end
        end)
        UIS.InputChanged:Connect(function(i)
            if not active then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local d = UIS:GetMouseLocation() - startMouse
            local w = math.clamp(startSize.X + e.sx * d.X, MIN_SIZE.X, MAX_SIZE.X)
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
    local size = opts.Size or Vector2.new(620, 450)

    local canvas = new("CanvasGroup", {
        Name              = "Window",
        AnchorPoint       = Vector2.new(0, 0),
        Position          = UDim2.new(0.5, -math.floor(size.X/2), 0.5, -math.floor(size.Y/2)),
        Size              = UDim2.fromOffset(size.X, size.Y),
        BackgroundTransparency = 1,
        GroupTransparency = 0,
        ZIndex            = 10,
    }, screenGui)

    local wOuter = new("Frame", {BackgroundColor3 = THEME.OuterBorder, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 1}, canvas)
    bind(wOuter, "BackgroundColor3", "OuterBorder")
    local wInner = new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 1}, wOuter)
    bind(wInner, "BackgroundColor3", "InnerBorder")
    local wFill  = new("Frame", {BackgroundColor3 = THEME.PanelFill,  BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 1}, wOuter)
    bind(wFill, "BackgroundColor3", "PanelFill")

    local titleLbl = outlined(canvas, "", "TextActive", {
        Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(240, 14),
        RichText = true, Bold = true, ZIndex = 6,
    })
    local leftTitle  = opts.TitleLeft or "ui"
    local rightTitle = opts.TitleRight or "library"
    local function refreshTitle()
        titleLbl.Text = string.format('%s<font color="%s">%s</font>',
            leftTitle, string.format("#%02X%02X%02X",
                math.floor(THEME.Accent.R*255), math.floor(THEME.Accent.G*255), math.floor(THEME.Accent.B*255)),
            rightTitle)
    end
    refreshTitle()
    Library._subs[#Library._subs + 1] = {inst = {Refresh = refreshTitle}, prop = "Text", key = "Accent"}

    local G, B = THEME.ContentOuter, THEME.ContentInner
    local panel = new("Frame", {Name = "Panel", BackgroundTransparency = 1, Position = UDim2.fromOffset(10,29), Size = UDim2.new(1,-20,1,-39), ZIndex = 2}, canvas)
    new("Frame", {BackgroundColor3 = THEME.ContentFill, BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 2}, panel)

    new("Frame", {BackgroundColor3 = G, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0),  Size = UDim2.new(0,1,1,0), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = G, BorderSizePixel = 0, Position = UDim2.new(1,-1,0,0),    Size = UDim2.new(0,1,1,0), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = G, BorderSizePixel = 0, Position = UDim2.new(0,0,1,-1),    Size = UDim2.new(1,0,0,1), ZIndex = 2}, panel)
    local oT1 = new("Frame", {BackgroundColor3 = G, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,0,0,1), ZIndex = 2}, panel)
    local oT2 = new("Frame", {BackgroundColor3 = G, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.fromOffset(0,1), ZIndex = 2}, panel)

    new("Frame", {BackgroundColor3 = B, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1),  Size = UDim2.new(0,1,1,-2), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = B, BorderSizePixel = 0, Position = UDim2.new(1,-2,0,1),    Size = UDim2.new(0,1,1,-2), ZIndex = 2}, panel)
    new("Frame", {BackgroundColor3 = B, BorderSizePixel = 0, Position = UDim2.new(0,1,1,-2),    Size = UDim2.new(1,-2,0,1), ZIndex = 2}, panel)
    local iT1 = new("Frame", {BackgroundColor3 = B, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,0,1), ZIndex = 2}, panel)
    local iT2 = new("Frame", {BackgroundColor3 = B, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.fromOffset(0,1), ZIndex = 2}, panel)

    local TAB_W, TAB_H, TAB_SP = 81, 18, 2
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
        DragZone = dragZone,
        Tabs = {}, ActiveTab = nil, _tabW = TAB_W, _tabH = TAB_H, _tabSp = TAB_SP,
        _oT1 = oT1, _oT2 = oT2, _iT1 = iT1, _iT2 = iT2,
        _tabsTotal = 0, _visible = true,
    }, {__index = Library._WindowMethods})

    addResizeHandles(canvas, function() syncTabGap(window) end)
    Library._windows[#Library._windows + 1] = window
    return window
end

Library._WindowMethods = {}

function Library._WindowMethods:Close()
    self._visible = false
    closeAllPopups()
    self.Canvas.Visible = false
end

function Library._WindowMethods:Toggle()
    self._visible = not self._visible
    if self._visible then
        self.Canvas.Visible = true
        tween(self.Canvas, T_OPEN, {GroupTransparency = 0})
    else
        closeAllPopups()
        local t = tween(self.Canvas, T_OPEN, {GroupTransparency = 1})
        t.Completed:Connect(function() self.Canvas.Visible = false end)
    end
end

function Library._WindowMethods:Destroy()
    self.Canvas:Destroy()
end

function Library._WindowMethods:Tab(name)
    local win = self
    local idx = #win.Tabs
    local x = idx * (win._tabW + win._tabSp)

    local btn = new("TextButton", {
        Name = name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(win._tabW, win._tabH),
        ZIndex = 4,
    }, win.TabHost)

    local tOuter = new("Frame", {BackgroundColor3 = THEME.ContentOuter, BorderSizePixel = 0, Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,0,0,win._tabH),   ZIndex = 4}, btn)
    bind(tOuter, "BackgroundColor3", "ContentOuter")
    local tInner = new("Frame", {BackgroundColor3 = THEME.ContentInner, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,0,win._tabH-1), ZIndex = 4}, tOuter)
    bind(tInner, "BackgroundColor3", "ContentInner")
    local tFill  = new("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,0,win._tabH-2), ZIndex = 4}, tOuter)
    local grad = new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, THEME.TabTop),
            ColorSequenceKeypoint.new(0.45, THEME.TabMid),
            ColorSequenceKeypoint.new(1.00, THEME.ContentFill),
        }),
    }, tFill)

    local label = outlined(btn, name, "TabInactive", {
        Size = UDim2.new(1,0,0,win._tabH), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
    })

    local page = new("Frame", {
        Name = name, BackgroundTransparency = 1, Visible = false, Size = UDim2.fromScale(1,1), ZIndex = 3,
    }, win.PageHost)
    new("UIPadding", {PaddingLeft = UDim.new(0,2), PaddingTop = UDim.new(0,2), PaddingRight = UDim.new(0,2), PaddingBottom = UDim.new(0,2)}, page)
    new("UIGridLayout", {
        CellSize = UDim2.new(0.5, -3, 0.5, -3),
        CellPadding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        FillDirectionMaxCells = 2,
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
    }, page)

    local tab = setmetatable({
        Window = win, Button = btn, Outer = tOuter, Inner = tInner, Fill = tFill,
        Grad = grad, Label = label, Page = page, Index = idx, _groups = 0,
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
            tween(t.Label, T_HOVER, {TextColor3 = on and THEME.Accent or THEME.TabInactive})
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
        if win.ActiveTab ~= tab then tween(label, T_HOVER, {TextColor3 = THEME.TabHover}) end
    end)
    btn.MouseLeave:Connect(function()
        if win.ActiveTab ~= tab then tween(label, T_HOVER, {TextColor3 = THEME.TabInactive}) end
    end)

    if #win.Tabs == 1 then select() end
    return tab
end

Library._TabMethods = {}

function Library._TabMethods:Group(title)
    local tab = self
    tab._groups += 1

    local HEADER_H = 19

    local col = new("Frame", {
        Name = title, BackgroundColor3 = THEME.OuterBorder, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), LayoutOrder = tab._groups, ZIndex = 3,
    }, tab.Page)
    bind(col, "BackgroundColor3", "OuterBorder")
    local inner = new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 3}, col)
    bind(inner, "BackgroundColor3", "InnerBorder")
    local body = new("Frame", {
        Name = "Body", BackgroundColor3 = THEME.ChildFill, BorderSizePixel = 0,
        Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 3, ClipsDescendants = true,
    }, col)
    bind(body, "BackgroundColor3", "ChildFill")

    local header = new("Frame", {BackgroundColor3 = THEME.HeaderTop, BorderSizePixel = 0, Size = UDim2.new(1,0,0,HEADER_H), ZIndex = 3}, body)
    vGradient(header, THEME.HeaderTop, THEME.HeaderBottom)
    outlined(header, title, "TextActive", {Position = UDim2.fromOffset(6,0), Size = UDim2.new(1,-6,1,0), ZIndex = 4})
    new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0, Position = UDim2.fromOffset(0,HEADER_H), Size = UDim2.new(1,0,0,1), ZIndex = 4}, body)

    local content = new("Frame", {
        Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, HEADER_H + 1), Size = UDim2.new(1,0,1,-(HEADER_H+1)), ZIndex = 3,
    }, body)
    new("UIPadding", {PaddingLeft = UDim.new(0,6), PaddingTop = UDim.new(0,5), PaddingRight = UDim.new(0,6)}, content)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder}, content)

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

--============================================================
-- COMPONENTS
--============================================================

-- checkbox --------------------------------------------------
local function buildCheckbox(group, text, default, callback, extra, flagName)
    extra = extra or {}
    local state = default and true or false
    local rowH    = IS_MOBILE and 22 or 16
    local boxSize = IS_MOBILE and 14 or 12
    local textX   = boxSize + 7

    local row = nextRow(group, rowH, "TextButton")
    row.Text = ""; row.AutoButtonColor = false; row.ZIndex = 3

    local visual = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, (rowH - boxSize) / 2),
        Size = UDim2.fromOffset(boxSize, boxSize),
        ZIndex = 3,
    }, row)
    local _, fill = framedBox(visual, "OuterBorder", "InnerBorder", "ChildFill", {ZIndex = 3})
    local accent = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), BackgroundTransparency = state and 0 or 1, ZIndex = 3}, fill)
    local accentGrad = vGradient(accent, THEME.Accent, THEME.AccentDark)
    Library._subs[#Library._subs + 1] = {inst = accentGrad, prop = "Color", key = "AccentGrad"}

    local label = outlined(row, text, state and "TextActive" or "TextInactive", {
        Position = UDim2.fromOffset(textX, 0),
        Size = UDim2.new(1, -(textX + 40), 1, 0),
        ZIndex = 3,
    })

    local function set(v, fireCb)
        state = v and true or false
        tween(accent, T_HOVER, {BackgroundTransparency = state and 0 or 1})
        tween(label, T_HOVER, {TextColor3 = state and THEME.TextActive or THEME.TextInactive})
        if fireCb ~= false and callback then task.spawn(callback, state) end
    end

    row.MouseButton1Click:Connect(function() set(not state, true) end)
    row.MouseEnter:Connect(function()
        if not state then tween(fill, T_HOVER, {BackgroundColor3 = Color3.fromRGB(39,40,57)}) end
    end)
    row.MouseLeave:Connect(function()
        if not state then tween(fill, T_HOVER, {BackgroundColor3 = THEME.ChildFill}) end
    end)

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

    local h = {
        _kind = "Checkbox", _row = row,
        Set = function(_, v) set(v, true) end,
        Get = function() return state end,
        Destroy = function() row:Destroy() end,
    }
    return registerHandle(flagName, h)
end

function Library._GroupMethods:Checkbox(text, default, callback, extra)
    return buildCheckbox(self, text, default, callback, extra, extra and extra.flag)
end

-- swatch ----------------------------------------------------
function Library._GroupMethods:_swatch(row, cfg, pos)
    local color = cfg.default or THEME.Accent
    local btn = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(12,12), Position = pos, ZIndex = 4}, row)
    local _, fill = framedBox(btn, "OuterBorder", "InnerBorder", color, {ZIndex = 4})

    btn.MouseButton1Click:Connect(function()
        closeAllPopups()
        local abs = btn.AbsolutePosition
        Library._ColorPicker(popupLayer, abs + Vector2.new(0, 14), color, function(c)
            color = c; fill.BackgroundColor3 = c
            if cfg.callback then task.spawn(cfg.callback, c) end
        end)
    end)
    return btn
end

-- slider ----------------------------------------------------
function Library._GroupMethods:Slider(text, o, callback, flagName)
    o = o or {}
    local minv, maxv = o.min or 0, o.max or 1
    local decimals   = o.decimals ~= nil and o.decimals or 3
    local isInt      = o.int and true or false
    local suffix     = o.suffix or ""
    local value      = o.default or minv

    local row = nextRow(self, 28)
    local label = outlined(row, text, "TextInactive", {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})
    local valLbl = outlined(row, "", "TextInactive", {Position = UDim2.new(1,-120,0,0), Size = UDim2.fromOffset(120,13), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local track = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,12), ZIndex = 3}, row)
    local _, tFill = framedBox(track, "OuterBorder", "InnerBorder", "ChildFill", {ZIndex = 3})
    local prog = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0,1), ZIndex = 3}, tFill)
    local progGrad = vGradient(prog, THEME.Accent, THEME.AccentDark)

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
            dragging = true; fromMouse()
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        fromMouse()
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    track.MouseEnter:Connect(function()
        tween(label, T_HOVER, {TextColor3 = THEME.TextActive})
        tween(valLbl, T_HOVER, {TextColor3 = THEME.TextActive})
    end)
    track.MouseLeave:Connect(function()
        if not dragging then
            tween(label, T_HOVER, {TextColor3 = THEME.TextInactive})
            tween(valLbl, T_HOVER, {TextColor3 = THEME.TextInactive})
        end
    end)

    render()
    if callback and o.default ~= nil then task.spawn(callback, value) end

    local h = {
        _kind = "Slider", _row = row,
        Set = function(_, v) set(v, true) end,
        Get = function() return value end,
        Destroy = function() row:Destroy() end,
    }
    return registerHandle(flagName or o.flag, h)
end

-- combo popup helper ----------------------------------------
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

local function buildComboPopup(box, items, isMulti, getState, onPick, search)
    closeAllPopups()
    local ITEM_H = IS_MOBILE and 22 or 16
    local abs, sz = box.AbsolutePosition, box.AbsoluteSize
    local searchH = search and 22 or 0
    local maxH = 200
    local listH = math.min(#items * ITEM_H, maxH)

    local pop = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(abs.X, abs.Y + sz.Y + 1),
        Size = UDim2.fromOffset(sz.X, listH + searchH + 4),
        ZIndex = 901,
    }, popupLayer)
    local _, pfill = framedBox(pop, "OuterBorder", "ComboInner", "ComboFill", {ZIndex = 901})

    local searchBox
    if search then
        searchBox = new("TextBox", {
            BackgroundColor3 = THEME.ComboInner,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 0, searchH - 2),
            PlaceholderText = "search...",
            Text = "",
            TextSize = 12,
            Font = FONT,
            TextColor3 = THEME.TextInactive,
            PlaceholderColor3 = Color3.fromRGB(80, 80, 80),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 902,
        }, pfill)
        new("UIPadding", {PaddingLeft = UDim.new(0, 5)}, searchBox)
    end

    local listFrame = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, searchH),
        Size = UDim2.new(1, 0, 1, -searchH),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 902,
    }, pfill)

    local function rebuild(filter)
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local order = 0
        for _, it in ipairs(items) do
            if not filter or filter == "" or it:lower():find(filter:lower(), 1, true) then
                order += 1
                local idx = table.find(items, it)
                local sel = getState(idx)
                local ib = new("TextButton", {
                    Text = "", AutoButtonColor = false,
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, (order-1)*ITEM_H),
                    Size = UDim2.new(1, -6, 0, ITEM_H),
                    ZIndex = 903,
                }, listFrame)
                local il = outlined(ib, (sel and "> " or "") .. it, sel and "ComboSelected" or "TextInactive", {
                    Position = UDim2.fromOffset(5,0), Size = UDim2.new(1,-7,1,0), ZIndex = 904,
                })
                ib.MouseEnter:Connect(function()
                    if not getState(idx) then tween(il, T_HOVER, {TextColor3 = THEME.TextActive}) end
                end)
                ib.MouseLeave:Connect(function()
                    if not getState(idx) then tween(il, T_HOVER, {TextColor3 = THEME.TextInactive}) end
                end)
                ib.MouseButton1Click:Connect(function()
                    onPick(idx)
                    if isMulti then
                        local s = getState(idx)
                        il.Text = (s and "> " or "") .. it
                        il.TextColor3 = s and THEME.ComboSelected or THEME.TextInactive
                    else
                        closeAllPopups()
                    end
                end)
            end
        end
        listFrame.CanvasSize = UDim2.new(0, 0, 0, order * ITEM_H)
    end

    rebuild("")
    if search and searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            rebuild(searchBox.Text)
        end)
    end

    local blocker = new("TextButton", {
        Name = "Blocker", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1), ZIndex = 900,
    }, popupLayer)
    blocker.MouseButton1Click:Connect(closeAllPopups)

    local closeFn = function() blocker:Destroy(); pop:Destroy() end
    pushPopup(closeFn)
    return pop
end

-- combo -----------------------------------------------------
function Library._GroupMethods:Combo(text, items, default, callback, flagName, opts)
    opts = opts or {}
    local index = default or 1
    local row = nextRow(self, 34)
    outlined(row, text, "TextInactive", {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,18), ClipsDescendants = true, ZIndex = 3}, row)
    local _, bFill = framedBox(box, "OuterBorder", "ComboInner", "ComboFill", {ZIndex = 3})
    local preview = outlined(box, items[index] or "", "TextInactive", {Position = UDim2.fromOffset(5,1), Size = UDim2.new(1,-20,1,-2), TextSize = 12, ZIndex = 4})
    local icon = plusIcon(box, THEME.Accent)

    box.MouseEnter:Connect(function() tween(preview, T_HOVER, {TextColor3 = THEME.TextActive}) end)
    box.MouseLeave:Connect(function() tween(preview, T_HOVER, {TextColor3 = THEME.TextInactive}) end)
    box.MouseButton1Click:Connect(function()
        if icon.IsOpen() then closeAllPopups(); icon.SetOpen(false); return end
        icon.SetOpen(true)
        local pop = buildComboPopup(box, items, false,
            function(i) return i == index end,
            function(i)
                index = i; preview.Text = items[i]
                if callback then task.spawn(callback, i, items[i]) end
            end,
            opts.Search)
        pushPopup(function() icon.SetOpen(false) end)
        pop.AncestryChanged:Connect(function() if not pop.Parent then icon.SetOpen(false) end end)
    end)
    if callback and default then task.spawn(callback, index, items[index]) end

    local h = {
        _kind = "Combo", _row = row,
        Set = function(_, i) index = i; preview.Text = items[i] end,
        Get = function() return index end,
        SetOptions = function(_, newItems)
            items = newItems
            if index > #items then index = 1 end
            preview.Text = items[index] or ""
        end,
        Destroy = function() row:Destroy() end,
    }
    return registerHandle(flagName, h)
end

-- multi combo -----------------------------------------------
function Library._GroupMethods:MultiCombo(text, items, defaults, callback, flagName, opts)
    opts = opts or {}
    local state = {}
    for i = 1, #items do state[i] = defaults and defaults[i] or false end
    local row = nextRow(self, 34)
    outlined(row, text, "TextInactive", {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,18), ClipsDescendants = true, ZIndex = 3}, row)
    local _, bFill = framedBox(box, "OuterBorder", "ComboInner", "ComboFill", {ZIndex = 3})
    local preview = outlined(box, "", "TextInactive", {Position = UDim2.fromOffset(5,1), Size = UDim2.new(1,-20,1,-2), TextSize = 12, ZIndex = 4})
    local icon = plusIcon(box, THEME.Accent)

    local function refresh()
        local parts = {}
        for i, on in ipairs(state) do if on then parts[#parts+1] = items[i] end end
        preview.Text = (#parts == 0) and "none" or table.concat(parts, ", ")
    end
    refresh()

    box.MouseEnter:Connect(function() tween(preview, T_HOVER, {TextColor3 = THEME.TextActive}) end)
    box.MouseLeave:Connect(function() tween(preview, T_HOVER, {TextColor3 = THEME.TextInactive}) end)
    box.MouseButton1Click:Connect(function()
        if icon.IsOpen() then closeAllPopups(); icon.SetOpen(false); return end
        icon.SetOpen(true)
        local pop = buildComboPopup(box, items, true,
            function(i) return state[i] end,
            function(i)
                state[i] = not state[i]; refresh()
                if callback then task.spawn(callback, state) end
            end,
            opts.Search)
        pushPopup(function() icon.SetOpen(false) end)
        pop.AncestryChanged:Connect(function() if not pop.Parent then icon.SetOpen(false) end end)
    end)

    local h = {
        _kind = "MultiCombo", _row = row,
        Set = function(_, tbl)
            for i = 1, #items do state[i] = tbl[i] and true or false end
            refresh()
            if callback then task.spawn(callback, state) end
        end,
        Get = function() return state end,
        SetOptions = function(_, newItems, keep)
            items = newItems
            local old = state
            state = {}
            for i = 1, #items do state[i] = false end
            if keep then
                for i, on in ipairs(old) do if on and items[i] then state[i] = true end end
            end
            refresh()
        end,
        Destroy = function() row:Destroy() end,
    }
    return registerHandle(flagName, h)
end

-- keybind box -----------------------------------------------
local function makeKeybindBox(parent, key, mode, onKey, onMode, flag)
    local BOX_W, BOX_H = 32, 12
    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1,0,0,1), Size = UDim2.fromOffset(BOX_W, BOX_H), ZIndex = 5}, parent)
    local _, bFill = framedBox(box, "OuterBorder", "InnerBorder", "ChildFill", {ZIndex = 5})
    local lbl = outlined(bFill, keyName(key), "TextInactive", {Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, TextSize = 11})

    local listening = false
    box.MouseButton1Click:Connect(function()
        listening = true; lbl.Text = "..."; lbl.TextColor3 = THEME.Accent
        local conn
        conn = UIS.InputBegan:Connect(function(inp, gp)
            if not listening or gp then return end
            if inp.UserInputType == Enum.UserInputType.Touch then return end
            listening = false; conn:Disconnect()
            local k = (inp.UserInputType == Enum.UserInputType.Keyboard)
                and keyName(inp.KeyCode) or keyName(inp.UserInputType)
            key = k; lbl.Text = k; lbl.TextColor3 = THEME.TextInactive
            if onKey then onKey(k) end
            if Library._hotkeyPanel then Library._hotkeyPanel.refresh() end
        end)
    end)

    local function openModePopup()
        closeAllPopups()
        local abs = bFill.AbsolutePosition
        local modes = {"toggle", "hold", "always"}
        local ITEM_H = IS_MOBILE and 22 or 16
        local pop = new("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(abs.X - 28, abs.Y + 13), Size = UDim2.fromOffset(60, #modes*ITEM_H), ZIndex = 901}, popupLayer)
        local _, pf = framedBox(pop, "OuterBorder", "ComboInner", "ComboFill", {ZIndex = 901})
        for i, m in ipairs(modes) do
            local mb = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,(i-1)*ITEM_H), Size = UDim2.fromOffset(60,ITEM_H), ZIndex = 902}, pf)
            outlined(mb, m, (mode == i) and "Accent" or "TextInactive", {Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 903})
            mb.MouseButton1Click:Connect(function()
                mode = i
                if onMode then onMode(i, m) end
                closeAllPopups()
            end)
        end
        local blocker = new("TextButton", {BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1,1), ZIndex = 900}, popupLayer)
        blocker.MouseButton1Click:Connect(closeAllPopups)
        pushPopup(function() blocker:Destroy(); pop:Destroy() end)
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

    local h = {
        _kind = "Keybind", _box = box,
        Set = function(_, k) key = k; lbl.Text = keyName(k) end,
        Get = function() return key end,
        Destroy = function() box:Destroy() end,
    }
    return registerHandle(flag, h), function() return key, mode end
end

-- keybind (standalone) --------------------------------------
function Library._GroupMethods:Keybind(text, default, callback, flagName)
    local row = nextRow(self, IS_MOBILE and 20 or 14)
    outlined(row, text, "TextInactive", {Position = UDim2.fromOffset(0,0), Size = UDim2.new(1,-38,1,0), ZIndex = 3})
    local h, getKb = makeKeybindBox(row, default, 1,
        function(k) if callback then task.spawn(callback, k) end end,
        nil, flagName)
    registerHotkey(text, getKb)
    return h
end

-- checkbox + keybind ----------------------------------------
function Library._GroupMethods:CheckboxKeybind(text, default, key, callback, flagName)
    local getKbRef
    local h = buildCheckbox(self, text, default, callback, {
        key = key,
        makeKeybind = function(row, kbKey, kbMode)
            local _, getKb = makeKeybindBox(row, kbKey, kbMode)
            getKbRef = getKb
        end,
    }, flagName)
    if getKbRef then registerHotkey(text, getKbRef) end
    -- chain :Keybind onto handle too
    h.Keybind = function(_, kopts)
        kopts = kopts or {}
        local kb, getKb = makeKeybindBox(h._row, kopts.Default, 1,
            function(k) if kopts.Callback then task.spawn(kopts.Callback, k) end end,
            nil, kopts.Flag)
        registerHotkey(text, getKb)
        return kb
    end
    return h
end

-- label -----------------------------------------------------
function Library._GroupMethods:Label(text, flagName)
    local row = nextRow(self, 14)
    local l = outlined(row, text, "TextInactive", {Size = UDim2.fromScale(1,1), ZIndex = 3})
    return registerHandle(flagName, {
        _kind = "Label", _row = row,
        Set = function(_, v) l.Text = tostring(v or "") end,
        Get = function() return l.Text end,
        Destroy = function() row:Destroy() end,
    })
end

-- paragraph -------------------------------------------------
function Library._GroupMethods:Paragraph(o, flagName)
    o = o or {}
    local row = nextRow(self, 40)
    local _, body = framedBox(row, "OuterBorder", "InnerBorder", "ChildFill", {ZIndex = 3})
    local accentKey = (o.Style == "warn") and "Warn"
        or (o.Style == "error") and "Danger" or "Accent"
    if accentKey == "Warn" and not THEME.Warn then THEME.Warn = Color3.fromRGB(240, 180, 80) end
    if accentKey == "Danger" and not THEME.Danger then THEME.Danger = Color3.fromRGB(220, 82, 82) end
    local bar = new("Frame", {
        BackgroundColor3 = THEME[accentKey] or THEME.Accent,
        BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, 3, 1, 0), ZIndex = 4,
    }, body)
    bind(bar, "BackgroundColor3", accentKey)

    new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, body)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, body)

    if o.Title then outlined(body, o.Title, "TextActive", {Size = UDim2.new(1,0,0,14), Bold = true, ZIndex = 5}) end
    if o.Content then outlined(body, o.Content, "TextInactive", {Size = UDim2.new(1,0,0,0), TextSize = 12, ZIndex = 5, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y}) end

    return registerHandle(flagName, {
        _kind = "Paragraph", _row = row,
        Set = function() end, Get = function() return nil end,
        Destroy = function() row:Destroy() end,
    })
end

-- divider ---------------------------------------------------
function Library._GroupMethods:Divider()
    local row = nextRow(self, 5)
    local l = new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0, Position = UDim2.fromOffset(0,2), Size = UDim2.new(1,0,0,1), ZIndex = 3}, row)
    bind(l, "BackgroundColor3", "InnerBorder")
    return { _kind = "Divider", _row = row, Set = function() end, Get = function() return nil end, Destroy = function() row:Destroy() end }
end

-- textbox ---------------------------------------------------
function Library._GroupMethods:Textbox(text, default, callback, flagName)
    local row = nextRow(self, 34)
    outlined(row, text, "TextInactive", {Position = UDim2.fromOffset(1,0), Size = UDim2.fromOffset(120,13), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})

    local box = new("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(0,16), Size = UDim2.new(1,0,0,18), ZIndex = 3}, row)
    local _, bFill = framedBox(box, "OuterBorder", "ComboInner", "ComboFill", {ZIndex = 3})

    local tb = new("TextBox", {
        BackgroundTransparency = 1,
        Text = default or "",
        TextColor3 = THEME.TextInactive,
        TextSize = 12,
        Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(5,1),
        Size = UDim2.new(1,-10,1,-2),
        ClearTextOnFocus = false,
        ZIndex = 5,
    }, box)

    tb.Focused:Connect(function() tween(tb, T_HOVER, {TextColor3 = THEME.TextActive}) end)
    tb.FocusLost:Connect(function()
        tween(tb, T_HOVER, {TextColor3 = THEME.TextInactive})
        if callback then task.spawn(callback, tb.Text) end
    end)

    local h = {
        _kind = "Input", _row = row,
        Set = function(_, v) tb.Text = tostring(v or "") end,
        Get = function() return tb.Text end,
        Destroy = function() row:Destroy() end,
    }
    return registerHandle(flagName, h)
end

-- button ----------------------------------------------------
function Library._GroupMethods:Button(text, callback, flagName)
    local row = nextRow(self, 20, "TextButton")
    row.Text = ""; row.AutoButtonColor = false; row.ZIndex = 3
    local _, fill = framedBox(row, "OuterBorder", "InnerBorder", "ChildFill", {ZIndex = 3})
    vGradient(fill, THEME.HeaderTop, THEME.HeaderBottom)
    local t = outlined(fill, text, "TextActive", {Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4})
    row.MouseEnter:Connect(function() tween(fill, T_HOVER, {BackgroundColor3 = Color3.fromRGB(35,36,45)}) end)
    row.MouseLeave:Connect(function() tween(fill, T_HOVER, {BackgroundColor3 = THEME.ChildFill}) end)
    row.MouseButton1Click:Connect(function() if callback then task.spawn(callback) end end)
    return registerHandle(flagName, {
        _kind = "Button", _row = row,
        Set = function(_, v) t.Text = tostring(v or "") end,
        Get = function() return t.Text end,
        Destroy = function() row:Destroy() end,
    })
end

-- button row ------------------------------------------------
function Library._GroupMethods:ButtonRow(list)
    local row = nextRow(self, 20)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }, row)
    local n = math.max(#list, 1)
    local handles = {}
    for i, def in ipairs(list) do
        local cell = new("TextButton", {
            Text = "", AutoButtonColor = false,
            BackgroundColor3 = THEME.ChildFill, BorderSizePixel = 0,
            Size = UDim2.new(1/n, -(4 * (n - 1) / n), 1, 0),
            LayoutOrder = i, ZIndex = 4,
        }, row)
        bind(cell, "BackgroundColor3", "ChildFill")
        local _, fill = framedBox(cell, "OuterBorder", "InnerBorder", "ChildFill", {ZIndex = 4})
        vGradient(fill, THEME.HeaderTop, THEME.HeaderBottom)
        outlined(fill, def.text or def.Text or "", "TextActive", {
            Size = UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
        })
        cell.MouseEnter:Connect(function() tween(fill, T_HOVER, {BackgroundColor3 = Color3.fromRGB(35,36,45)}) end)
        cell.MouseLeave:Connect(function() tween(fill, T_HOVER, {BackgroundColor3 = THEME.ChildFill}) end)
        cell.MouseButton1Click:Connect(function()
            if def.callback or def.Callback then
                task.spawn(def.callback or def.Callback)
            end
        end)
        handles[i] = {
            _kind = "Button", _row = cell,
            Set = function() end, Get = function() return nil end,
            Destroy = function() cell:Destroy() end,
        }
    end
    return handles
end

--============================================================
-- COLOR PICKER
--============================================================
function Library._ColorPicker(parent, pos, startColor, onChange)
    local h, s, v = Color3.toHSV(startColor)
    local W = IS_MOBILE and 200 or 150
    local HGT = IS_MOBILE and 160 or 100
    local pop = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(pos.X - W + 12, pos.Y),
        Size = UDim2.fromOffset(W, HGT + 20),
        ZIndex = 910,
    }, parent)
    local _, pf = framedBox(pop, "OuterBorder", "InnerBorder", "PanelFill", {ZIndex = 910})

    local sv = new("ImageButton", {BackgroundColor3 = Color3.fromHSV(h,1,1), BorderSizePixel = 0, Position = UDim2.fromOffset(6,6), Size = UDim2.fromOffset(W-30, HGT), ZIndex = 911, AutoButtonColor = false}, pf)
    local white = new("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 911}, sv)
    new("UIGradient", {Rotation = 0, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})}, white)
    local blk = new("Frame", {BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 911}, sv)
    new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0)})}, blk)

    local hue = new("ImageButton", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Position = UDim2.new(1,-16,0,6), Size = UDim2.fromOffset(12,HGT), ZIndex = 911, AutoButtonColor = false}, pf)
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
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragSV = true end
    end)
    hue.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragHue = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragSV, dragHue = false, false end
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
        Size = UDim2.fromScale(1, 1), ZIndex = 909,
    }, parent)
    blocker.MouseButton1Click:Connect(function()
        if not dragSV and not dragHue then closeAllPopups() end
    end)
    pushPopup(function() blocker:Destroy(); pop:Destroy() end)
end

--============================================================
-- WATERMARK
--============================================================
Library.Watermark = {
    enabled = true,
    label1 = "library",
    label2 = "v" .. Library._VERSION,
    label3 = os.date("%b %d %Y"),
    host = nil,
}

function Library.Watermark.refresh()
    local wm = Library.Watermark
    if not wm.host then return end
    local PAD, GAP, H = 8, 4, 21
    local parts = {
        {t = wm.label1, c = THEME.TextActive},
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
        Name = "Watermark", BackgroundColor3 = THEME.OuterBorder, BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(100, H), ZIndex = 400,
        Visible = wm.enabled,
    }, screenGui)
    bind(host, "BackgroundColor3", "OuterBorder")
    new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 400}, host)
    local fill = new("Frame", {Name = "Fill", BackgroundColor3 = THEME.PanelFill, BorderSizePixel = 0, Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 400}, host)
    vGradient(fill, Color3.fromRGB(17,17,16), Color3.fromRGB(15,14,14))

    local strip = new("Frame", {Name = "Strip", BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1,-6,1,0), ZIndex = 401}, fill)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder}, strip)

    wm.host = host

    local grab = new("TextButton", {
        Name = "Drag", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), ZIndex = 402,
    }, host)
    local dragging, startPos, startMouse = false, nil, nil
    grab.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startPos = host.Position
            startMouse = UIS:GetMouseLocation()
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

--============================================================
-- HOTKEY PANEL
--============================================================
local function makeHotkeyPanel()
    local W, HDR = 200, 19
    local host = new("Frame", {
        Name = "HotkeysPanel", BackgroundColor3 = THEME.OuterBorder, BorderSizePixel = 0,
        Position = UDim2.new(1, -W - 14, 0, 60),
        Size = UDim2.fromOffset(W, HDR + 10),
        ZIndex = 410, Visible = false,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, screenGui)
    bind(host, "BackgroundColor3", "OuterBorder")
    new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0, Position = UDim2.fromOffset(1,1), Size = UDim2.new(1,-2,1,-2), ZIndex = 410}, host)
    local body = new("Frame", {Name = "Body", BackgroundColor3 = THEME.ChildFill, BorderSizePixel = 0,
        Position = UDim2.fromOffset(2,2), Size = UDim2.new(1,-4,1,-4), ZIndex = 410,
        AutomaticSize = Enum.AutomaticSize.Y}, host)

    local header = new("Frame", {BackgroundColor3 = THEME.HeaderTop, BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,HDR), ZIndex = 411}, body)
    vGradient(header, THEME.HeaderTop, THEME.HeaderBottom)
    outlined(header, "hotkeys", "TextActive", {Position = UDim2.fromOffset(6,0), Size = UDim2.new(1,-6,1,0), ZIndex = 412})
    new("Frame", {BackgroundColor3 = THEME.InnerBorder, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0,HDR), Size = UDim2.new(1,0,0,1), ZIndex = 412}, body)

    local content = new("Frame", {Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, HDR + 1),
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 411}, body)
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
            if k and k ~= "None" then
                any = true; idx += 1
                local row = new("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = idx, ZIndex = 411}, content)
                outlined(row, hk.name, "TextInactive", {Position = UDim2.fromOffset(0,0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 412})
                outlined(row, keyName(k), "Accent", {Position = UDim2.new(1, -56, 0, 0), Size = UDim2.fromOffset(56, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 412})
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

--============================================================
-- CURSOR
--============================================================
local function makeCursor()
    local S = 11
    local C = math.floor(S / 2)
    local gui = new("ScreenGui", {Name = "cursor", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2147483647}, guiParent())
    local host = new("Frame", {Name = "Cross", BackgroundTransparency = 1, Active = false, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(S, S), Visible = false, ZIndex = 1}, gui)
    local function noInput(o) o.Active = false; pcall(function() o.Interactable = false end) end
    noInput(host)
    local function bar(color, x, y, w, h, z)
        local f = new("Frame", {BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z}, host)
        noInput(f)
    end
    bar(THEME.OuterBorder, 0, C - 1, S, 3, 1)
    bar(THEME.OuterBorder, C - 1, 0, 3, S, 1)
    bar(THEME.TextActive, 1, C, S - 2, 1, 2)
    bar(THEME.TextActive, C, 1, 1, S - 2, 2)
    return host
end

Library.CursorEnabled = true
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
        local tw = TweenService:Create(window.Canvas, TweenInfo.new(0.30, Enum.EasingStyle.Cubic, visible and Enum.EasingDirection.Out or Enum.EasingDirection.In), {GroupTransparency = visible and 0 or 1})
        tw:Play()
        if not visible then tw.Completed:Connect(function() window.Canvas.Visible = false end) end
    end
    UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Library.ToggleKey then toggle() end
    end)
    return toggle
end

--============================================================
-- MOBILE TOGGLE
--============================================================
local function makeMobileToggle(onTap)
    local S, R = 48, 14
    local host = new("TextButton", {
        Name = "MobileToggle", BackgroundColor3 = THEME.PanelFill, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14),
        Size = UDim2.fromOffset(S, S), Text = "", AutoButtonColor = false,
        ClipsDescendants = true, ZIndex = 450,
    }, screenGui)
    bind(host, "BackgroundColor3", "PanelFill")
    new("UICorner", {CornerRadius = UDim.new(0, R)}, host)
    local fill = new("Frame", {BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 450}, host)
    new("UICorner", {CornerRadius = UDim.new(0, R)}, fill)
    vGradient(fill, THEME.HeaderTop, THEME.HeaderBottom)
    new("UIStroke", {Color = THEME.InnerBorder, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, host)
    local icon = new("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), Size = UDim2.fromOffset(20, 16), ZIndex = 452}, fill)
    for i = 1, 3 do
        local bar = new("Frame", {BackgroundColor3 = THEME.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(0, (i-1) * 7), Size = UDim2.new(1, 0, 0, 2), ZIndex = 452}, icon)
        bind(bar, "BackgroundColor3", "Accent")
    end
    local dragging, moved, startPos, startMouse = false, false, nil, nil
    host.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startPos = host.Position; startMouse = UIS:GetMouseLocation()
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

--============================================================
-- SETTINGS TAB (auto-built)
--============================================================
function Library:BuildSettings(window)
    local wm = Library.Watermark
    local st = window:Tab("settings")

    local appearance = st:Group("appearance")
    appearance:Label("accent")
    appearance:ButtonRow({
        {text = "blue",   Callback = function() Library:ChangeAccent(Color3.fromRGB(147,161,254)) end},
        {text = "red",    Callback = function() Library:ChangeAccent(Color3.fromRGB(230, 90, 90)) end},
        {text = "green",  Callback = function() Library:ChangeAccent(Color3.fromRGB( 90,200,120)) end},
    })
    appearance:ButtonRow({
        {text = "purple", Callback = function() Library:ChangeAccent(Color3.fromRGB(180,120,255)) end},
        {text = "amber",  Callback = function() Library:ChangeAccent(Color3.fromRGB(240,180, 80)) end},
        {text = "reset",  Callback = function() Library:ResetTheme() end},
    })
    appearance:Checkbox("show hotkeys", false, function(v)
        if Library._hotkeyPanel then
            Library._hotkeyPanel.host.Visible = v
            if v then Library._hotkeyPanel.refresh() end
        end
    end, {flag = "ui_show_hotkeys"})

    local cfg = st:Group("configs")
    local cfgName = "default"
    cfg:Label("folder: angel_configs/")
    cfg:Textbox("config name", "default", function(t) cfgName = t ~= "" and t or "default" end, "cfg_name")
    cfg:Button("save config", function()
        local ok = Library:SaveConfig(cfgName)
        Library:Notify({Title = ok and "saved" or "failed", Text = cfgName, Style = ok and "success" or "error"})
    end)
    cfg:Button("load config", function()
        local ok = Library:LoadConfigFile(cfgName)
        Library:Notify({Title = ok and "loaded" or "failed", Text = cfgName, Style = ok and "success" or "error"})
    end)
    cfg:Button("delete config", function()
        if delfile then pcall(delfile, CONFIG_DIR .. "/" .. cfgName .. ".json") end
    end)

    local wmg = st:Group("watermark")
    wmg:Checkbox("enabled", wm.enabled, function(v) wm.enabled = v; if wm.host then wm.host.Visible = v end end, {flag = "wm_enabled"})
    wmg:Textbox("line 1", wm.label1, function(t) wm.label1 = t; Library.Watermark.refresh() end, "wm_l1")
    wmg:Textbox("line 2", wm.label2, function(t) wm.label2 = t; Library.Watermark.refresh() end, "wm_l2")
    wmg:Textbox("line 3", wm.label3, function(t) wm.label3 = t; Library.Watermark.refresh() end, "wm_l3")

    local notifG = st:Group("notifications")
    notifG:Button("test info",    function() Library:Notify({Title = "info",    Text = "some content"}) end)
    notifG:Button("test success", function() Library:Success("done", "operation complete") end)
    notifG:Button("test warn",    function() Library:Warn("careful", "something's off") end)
    notifG:Button("test error",   function() Library:Error("failed", "couldn't connect") end)

    return st
end

--============================================================
-- BOOT
--============================================================
makeWatermark()
makeHotkeyPanel()

return Library
