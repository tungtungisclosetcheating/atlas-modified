-- atlas ui -- facility-compatible api
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local function root()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return LP:WaitForChild("PlayerGui")
end

local Theme = {
    Accent = Color3.fromRGB(255,255,255),
    AccentSoft = Color3.fromRGB(240,240,240),
    AccentDim = Color3.fromRGB(180,180,180),
    Text = Color3.fromRGB(255,255,255),
    TextDim = Color3.fromRGB(140,140,140),
    Bg = Color3.fromRGB(15,15,20),
    Surface = Color3.fromRGB(20,20,26),
    SurfaceHigh = Color3.fromRGB(30,30,36),
    SurfaceLow = Color3.fromRGB(11,11,15),
    Border = Color3.fromRGB(40,40,50),
    BorderHigh = Color3.fromRGB(65,65,78),
}
local FONT = Enum.Font.SourceSans
local FONT_B = Enum.Font.SourceSansBold

local function mk(c, p, parent)
    local o = Instance.new(c)
    if p then for k,v in pairs(p) do if k ~= "Parent" then o[k] = v end end end
    if parent then o.Parent = parent end
    return o
end
local function tw(i, t, g) return TS:Create(i, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), g) end
local function corner(i, r) return mk("UICorner", {CornerRadius = UDim.new(0, r or 6)}, i) end
local function stroke(i, c, t) return mk("UIStroke", {Color = c or Theme.Border, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, i) end

local function ensureScreen()
    local r = root()
    local old = r:FindFirstChild("atlas")
    if old then old:Destroy() end
    return mk("ScreenGui", {Name="atlas", IgnoreGuiInset=true, ResetOnSpawn=false, ZIndexBehavior=Enum.ZIndexBehavior.Sibling, DisplayOrder=999}, r)
end
local screen = ensureScreen()
local popupLayer = mk("Frame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=900}, screen)
local openPopups = {}
local function closePopups() local l = openPopups; openPopups = {}; for _, fn in ipairs(l) do pcall(fn) end end
local function pushPopup(fn) openPopups[#openPopups+1] = fn end

-- notifications
local notifHost = mk("Frame", {BackgroundTransparency=1, AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-14,0,14), Size=UDim2.new(0,260,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=800}, screen)
mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, HorizontalAlignment=Enum.HorizontalAlignment.Right, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,5)}, notifHost)
local notifOrder = 0
local function notifyObj(o)
    o = o or {}
    local st = o.Style or "info"
    local acc = st=="success" and Color3.fromRGB(90,200,120) or st=="warn" and Color3.fromRGB(240,180,80) or st=="error" and Color3.fromRGB(220,82,82) or Theme.Accent
    notifOrder = notifOrder + 1
    local card = mk("CanvasGroup", {BackgroundColor3=Theme.Bg, BorderSizePixel=0, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Position=UDim2.fromOffset(40,0), LayoutOrder=notifOrder, GroupTransparency=1, ZIndex=801}, notifHost)
    corner(card, 8); stroke(card)
    mk("UIPadding", {PaddingLeft=UDim.new(0,12), PaddingRight=UDim.new(0,12), PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8)}, card)
    local strip = mk("Frame", {BackgroundColor3=acc, BorderSizePixel=0, Size=UDim2.new(0,3,1,0), Position=UDim2.fromOffset(-12,0), ZIndex=802}, card)
    corner(strip, 2)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2), HorizontalAlignment=Enum.HorizontalAlignment.Left}, card)
    mk("TextLabel", {BackgroundTransparency=1, Text=o.Title or "notice", Font=FONT_B, TextSize=13, TextColor3=Theme.Text, Size=UDim2.new(1,0,0,16), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=803}, card)
    if o.Text then
        mk("TextLabel", {BackgroundTransparency=1, Text=o.Text, Font=FONT, TextSize=12, TextColor3=Theme.TextDim, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=803}, card)
    end
    tw(card, 0.25, {GroupTransparency=0, Position=UDim2.fromOffset(0,0)})
    task.delay(o.Duration or 3, function()
        if not card.Parent then return end
        local out = tw(card, 0.25, {GroupTransparency=1, Position=UDim2.fromOffset(40,0)})
        out.Completed:Connect(function() card:Destroy() end)
    end)
    return card
end

-- registries
local Toggles, Options, Dropdowns, Inputs, Keybinds = {}, {}, {}, {}, {}
local Flags = {}
local Serializables = {}

local function isSerializable(v)
    local t = typeof(v)
    return t == "boolean" or t == "number" or t == "string" or t == "Color3"
end
local function ser(v)
    if typeof(v) == "Color3" then return {__c3 = true, r=v.R, g=v.G, b=v.B} end
    return v
end
local function deser(v)
    if type(v) == "table" and v.__c3 then return Color3.new(v.r, v.g, v.b) end
    return v
end

-- screen already created above
local Library = {
    Theme = Theme,
    Flags = Flags,
    Toggles = Toggles,
    Options = Options,
    Dropdowns = Dropdowns,
    Inputs = Inputs,
    Keybinds = Keybinds,
}
function Library:Notify(o) return notifyObj(o) end
function Library:Success(t,x,d) return notifyObj({Title=t,Text=x,Duration=d,Style="success"}) end
function Library:Warn(t,x,d) return notifyObj({Title=t,Text=x,Duration=d,Style="warn"}) end
function Library:Error(t,x,d) return notifyObj({Title=t,Text=x,Duration=d,Style="error"}) end
function Library:Repaint() end
function Library:ChangeAccent(c) Theme.Accent = c end

_G.notify = function(title, text, style) return notifyObj({Title=title, Text=text, Style=style}) end

-- window
local Window = {}
Window.__index = Window

function Library:Window(o)
    o = o or {}
    local W = o.Width or 640
    local H = o.Height or 480
    local canvas = mk("CanvasGroup", {
        Name = "Window", AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,0,0.5,0),
        Size = UDim2.fromOffset(W,H),
        BackgroundColor3 = Theme.Bg, BorderSizePixel = 0, ZIndex = 10,
    }, screen)
    corner(canvas, 8); stroke(canvas, Theme.Border, 1)

    local titleLbl = mk("TextLabel", {BackgroundTransparency=1, Text=o.Title or "ui", Font=FONT_B, TextSize=14, TextColor3=Theme.Text, Position=UDim2.fromOffset(14,0), Size=UDim2.new(1,-60,0,32), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13}, canvas)

    local drag = mk("TextButton", {BackgroundTransparency=1, Text="", Size=UDim2.new(1,0,0,32), AutoButtonColor=false, ZIndex=12}, canvas)
    do
        local d, sp, sm = false, nil, nil
        drag.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                d = true; sp = canvas.Position; sm = UIS:GetMouseLocation(); closePopups()
            end
        end)
        UIS.InputChanged:Connect(function(i)
            if not d then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local dx = UIS:GetMouseLocation() - sm
            canvas.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dx.X, sp.Y.Scale, sp.Y.Offset + dx.Y)
        end)
        UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end
        end)
    end

    local tabBar = mk("Frame", {BackgroundTransparency=1, Position=UDim2.fromOffset(0,34), Size=UDim2.new(1,0,0,26), ZIndex=12}, canvas)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4), VerticalAlignment=Enum.VerticalAlignment.Center}, tabBar)
    mk("UIPadding", {PaddingLeft=UDim.new(0,12)}, tabBar)

    local pageHost = mk("Frame", {BackgroundTransparency=1, Position=UDim2.fromOffset(0,64), Size=UDim2.new(1,0,1,-64), ZIndex=12}, canvas)

    local win = setmetatable({_canvas=canvas, _tabBar=tabBar, _pageHost=pageHost, Tabs={}, ActiveTab=nil, _visible=true}, Window)

    -- toggle key
    UIS.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Enum.KeyCode.Insert then
            win._visible = not win._visible
            canvas.Visible = win._visible
            closePopups()
        end
    end)

    return win
end

local Tab = {}
Tab.__index = Tab

function Window:Tab(name)
    local btn = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, Size=UDim2.fromOffset(0,22), AutomaticSize=Enum.AutomaticSize.X, ZIndex=13}, self._tabBar)
    corner(btn, 4); stroke(btn)
    local lbl = mk("TextLabel", {BackgroundTransparency=1, Text=name, Font=FONT, TextSize=13, TextColor3=Theme.TextDim, Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-20,1,0), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=14}, btn)
    lbl.Size = UDim2.fromOffset(0, 22); lbl.AutomaticSize = Enum.AutomaticSize.X

    local page = mk("Frame", {Name=name, BackgroundTransparency=1, Visible=false, Size=UDim2.fromScale(1,1), ZIndex=12}, self._pageHost)
    mk("UIPadding", {PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10)}, page)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8), VerticalAlignment=Enum.VerticalAlignment.Top}, page)

    local leftCol = mk("Frame", {BackgroundTransparency=1, Size=UDim2.new(0.5,-4,1,0), LayoutOrder=1, ZIndex=12}, page)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8)}, leftCol)

    local rightCol = mk("Frame", {BackgroundTransparency=1, Size=UDim2.new(0.5,-4,1,0), LayoutOrder=2, ZIndex=12}, page)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,8)}, rightCol)

    local tab = setmetatable({_win=self, _btn=btn, _lbl=lbl, _page=page, _left=leftCol, _right=rightCol, _secCount=0, Sections={}}, Tab)
    self.Tabs[#self.Tabs + 1] = tab

    btn.MouseButton1Click:Connect(function()
        closePopups()
        for _, t in ipairs(self.Tabs) do
            t._page.Visible = false
            tw(t._lbl, 0.12, {TextColor3 = Theme.TextDim}):Play()
            tw(t._btn, 0.12, {BackgroundColor3 = Theme.SurfaceHigh}):Play()
        end
        page.Visible = true
        tw(lbl, 0.12, {TextColor3 = Theme.Text}):Play()
        tw(btn, 0.12, {BackgroundColor3 = Theme.BorderHigh}):Play()
        self.ActiveTab = tab
    end)
    btn.MouseEnter:Connect(function() if self.ActiveTab ~= tab then tw(btn, 0.12, {BackgroundColor3 = Theme.Border}):Play() end end)
    btn.MouseLeave:Connect(function() if self.ActiveTab ~= tab then tw(btn, 0.12, {BackgroundColor3 = Theme.SurfaceHigh}):Play() end end)

    if #self.Tabs == 1 then
        page.Visible = true
        lbl.TextColor3 = Theme.Text
        btn.BackgroundColor3 = Theme.BorderHigh
        self.ActiveTab = tab
    end
    return tab
end

-- Section
local Section = {}
Section.__index = Section

local function section(parent, title, column)
    local col = (column == 2) and parent._right or parent._left
    parent._secCount = parent._secCount + 1

    local box = mk("Frame", {BackgroundColor3=Theme.Surface, BorderSizePixel=0, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, LayoutOrder=parent._secCount, ZIndex=12}, col)
    corner(box, 6); stroke(box)

    local header = mk("Frame", {BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, Size=UDim2.new(1,0,0,22), ZIndex=13}, box)
    local hc = mk("UICorner", {CornerRadius=UDim.new(0,6)}, header)
    mk("Frame", {BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, Position=UDim2.new(0,0,1,-6), Size=UDim2.new(1,0,0,6), ZIndex=13}, header)
    mk("TextLabel", {BackgroundTransparency=1, Text=title or "section", Font=FONT_B, TextSize=13, TextColor3=Theme.Text, Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-10,1,0), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, header)

    local content = mk("Frame", {BackgroundTransparency=1, Position=UDim2.fromOffset(0,22), Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=12}, box)
    mk("UIPadding", {PaddingLeft=UDim.new(0,8), PaddingRight=UDim.new(0,8), PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8)}, content)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,6)}, content)

    local sec = setmetatable({_parent=parent, _box=box, Content=content, _order=0}, Section)
    parent.Sections[#parent.Sections + 1] = sec
    return sec
end

function Tab:Section(name, column)
    return section(self, name, column)
end
function Tab:Divider()
    local s = section(self, "", 1)
    return s
end
function Tab:Paragraph(o)
    local s = section(self, "", 1)
    s:Paragraph(o)
    return s
end

local function nextRow(sec, h)
    sec._order = sec._order + 1
    return mk("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,h), LayoutOrder=sec._order, ZIndex=13}, sec.Content)
end

local function newHandle(kind, flag, get, set)
    local h = {}
    h._kind = kind
    h._flag = flag
    h.Value = get and get() or nil
    function h:SetValue(v)
        if set then set(v) end
        h.Value = get and get() or nil
    end
    function h:GetValue() return get and get() or nil end
    function h:Set(v) return h:SetValue(v) end
    function h:Get() return h:GetValue() end
    function h:Destroy() end
    if flag then
        Flags[flag] = h
        Serializables[flag] = {get = get, set = set}
    end
    return h
end

-- Toggle
function Section:Toggle(o)
    o = o or {}
    local state = o.Default and true or false
    local row = nextRow(self, 18)
    local btn = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=14}, row)

    local box = mk("Frame", {BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, Size=UDim2.fromOffset(14,14), Position=UDim2.fromOffset(0,2), ZIndex=14}, row)
    corner(box, 3); stroke(box)
    local check = mk("Frame", {BackgroundColor3=Theme.Accent, BorderSizePixel=0, Size=UDim2.fromScale(1,1), BackgroundTransparency=state and 0 or 1, ZIndex=15}, box)
    corner(check, 3)

    local lbl = mk("TextLabel", {BackgroundTransparency=1, Text=o.Text or "", Font=FONT, TextSize=13, TextColor3=state and Theme.Text or Theme.TextDim, Position=UDim2.fromOffset(22,0), Size=UDim2.new(1,-22,1,0), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)

    local function set(v, silent)
        state = v and true or false
        tw(check, 0.12, {BackgroundTransparency = state and 0 or 1}):Play()
        tw(lbl, 0.12, {TextColor3 = state and Theme.Text or Theme.TextDim}):Play()
        if not silent and o.Callback then task.spawn(o.Callback, state) end
    end
    btn.MouseButton1Click:Connect(function() set(not state) end)
    btn.MouseEnter:Connect(function() if not state then tw(box, 0.12, {BackgroundColor3 = Theme.BorderHigh}):Play() end end)
    btn.MouseLeave:Connect(function() if not state then tw(box, 0.12, {BackgroundColor3 = Theme.SurfaceHigh}):Play() end end)

    if o.Callback and o.Default ~= nil then task.spawn(o.Callback, state) end

    local h = newHandle("Toggle", o.Flag, function() return state end, function(v) set(v) end)
    h._row = row
    h.Value = state

    function h:Keybind(ko)
        ko = ko or {}
        local chip = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(50,16), ZIndex=15}, row)
        corner(chip, 3); stroke(chip)
        local cl = mk("TextLabel", {BackgroundTransparency=1, Text=ko.Default or "None", Font=FONT, TextSize=11, TextColor3=Theme.TextDim, Size=UDim2.fromScale(1,1), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=16}, chip)
        lbl.Size = UDim2.new(1,-70,1,0)
        local listening = false
        chip.MouseButton1Click:Connect(function()
            listening = true
            cl.Text = "..."
            cl.TextColor3 = Theme.Accent
            local conn
            conn = UIS.InputBegan:Connect(function(inp, gp)
                if not listening or gp then return end
                if inp.UserInputType == Enum.UserInputType.Touch then return end
                listening = false; conn:Disconnect()
                local key
                if inp.UserInputType == Enum.UserInputType.Keyboard then
                    key = inp.KeyCode.Name
                else
                    key = tostring(inp.UserInputType):gsub("Enum.UserInputType%.", "")
                end
                cl.Text = key; cl.TextColor3 = Theme.TextDim
                if ko.Callback then task.spawn(ko.Callback, key) end
            end)
        end)
        if ko.Flag then
            local kh = newHandle("Keybind", ko.Flag, function() return cl.Text end, function(v) cl.Text = v end)
            Keybinds[ko.Flag] = kh
        end
        return h
    end

    if o.Flag then Toggles[o.Flag] = h end
    return h
end

-- Slider
function Section:Slider(o)
    o = o or {}
    local min, max = o.Min or 0, o.Max or 1
    local dec = o.Decimals or 0
    local val = o.Default or min
    local row = nextRow(self, 30)
    mk("TextLabel", {BackgroundTransparency=1, Text=o.Text or "", Font=FONT, TextSize=13, TextColor3=Theme.TextDim, Position=UDim2.fromOffset(0,0), Size=UDim2.new(1,-80,0,14), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)
    local vt = mk("TextLabel", {BackgroundTransparency=1, Text=string.format("%."..dec.."f", val), Font=FONT, TextSize=12, TextColor3=Theme.Text, Position=UDim2.new(1,-80,0,0), Size=UDim2.fromOffset(80,14), TextXAlignment=Enum.TextXAlignment.Right, ZIndex=14}, row)

    local track = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Theme.SurfaceLow, BorderSizePixel=0, Position=UDim2.fromOffset(0,17), Size=UDim2.new(1,0,0,10), ZIndex=15}, row)
    corner(track, 3); stroke(track)
    local fill = mk("Frame", {BackgroundColor3=Theme.Accent, BorderSizePixel=0, Size=UDim2.fromScale(0,1), ZIndex=15}, track)
    corner(fill, 3)

    local function set(v, silent)
        v = math.clamp(tonumber(v) or 0, min, max)
        if dec == 0 then v = math.floor(v + 0.5) end
        val = v
        fill.Size = UDim2.fromScale((val - min) / (max - min), 1)
        vt.Text = string.format("%."..dec.."f", val)
        if not silent and o.Callback then task.spawn(o.Callback, val) end
    end
    local drag = false
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            local rel = math.clamp((UIS:GetMouseLocation().X - fill.AbsolutePosition.X) / fill.AbsoluteSize.X, 0, 1)
            set(min + rel * (max - min))
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local rel = math.clamp((UIS:GetMouseLocation().X - fill.AbsolutePosition.X) / fill.AbsoluteSize.X, 0, 1)
        set(min + rel * (max - min))
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)

    set(val, true)
    if o.Callback and o.Default ~= nil then task.spawn(o.Callback, val) end

    local h = newHandle("Slider", o.Flag, function() return val end, function(v) set(v) end)
    if o.Flag then Options[o.Flag] = h; Toggles[o.Flag] = h end
    return h
end

-- Dropdown (single + multi)
function Section:Dropdown(o)
    o = o or {}
    local multi = o.Multi and true or false
    local items = {}
    for i, v in ipairs(o.Options or {}) do items[i] = tostring(v) end

    local sel
    if multi then
        sel = {}
        if type(o.Default) == "table" then for _, v in ipairs(o.Default) do sel[tostring(v)] = true end end
    else
        sel = tostring(o.Default or items[1] or "")
    end

    local row = nextRow(self, 32)
    mk("TextLabel", {BackgroundTransparency=1, Text=o.Text or "", Font=FONT, TextSize=13, TextColor3=Theme.TextDim, Position=UDim2.fromOffset(0,0), Size=UDim2.new(1,0,0,14), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)

    local box = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Theme.SurfaceLow, BorderSizePixel=0, Position=UDim2.fromOffset(0,17), Size=UDim2.new(1,0,0,20), ClipsDescendants=true, ZIndex=15}, row)
    corner(box, 4); stroke(box)
    local prev = mk("TextLabel", {BackgroundTransparency=1, Text="", Font=FONT, TextSize=12, TextColor3=Theme.Text, Position=UDim2.fromOffset(8,0), Size=UDim2.new(1,-24,1,0), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16}, box)
    mk("TextLabel", {BackgroundTransparency=1, Text="v", Font=FONT, TextSize=13, TextColor3=Theme.TextDim, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,-8,0.5,0), Size=UDim2.fromOffset(12,14), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=16}, box)

    local function refresh()
        if multi then
            local p = {}
            for _, v in ipairs(items) do if sel[v] then p[#p+1] = v end end
            prev.Text = #p > 0 and table.concat(p, ", ") or "none"
        else
            prev.Text = tostring(sel)
        end
    end
    refresh()

    local openFn = nil
    box.MouseButton1Click:Connect(function()
        if openFn then openFn(); return end
        closePopups()
        local ITEM_H = 20
        local pop = mk("Frame", {BackgroundColor3=Theme.Surface, BorderSizePixel=0, Position=UDim2.fromOffset(box.AbsolutePosition.X, box.AbsolutePosition.Y + box.AbsoluteSize.Y + 3), Size=UDim2.fromOffset(box.AbsoluteSize.X, math.min(#items * ITEM_H + 6, 200)), ZIndex=901, ClipsDescendants=true}, popupLayer)
        corner(pop, 6); stroke(pop)
        mk("UIPadding", {PaddingLeft=UDim.new(0,3), PaddingRight=UDim.new(0,3), PaddingTop=UDim.new(0,3), PaddingBottom=UDim.new(0,3)}, pop)
        local sf = mk("ScrollingFrame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, ScrollingDirection=Enum.ScrollingDirection.Y, ScrollBarThickness=3, BorderSizePixel=0, ZIndex=902}, pop)
        for i, it in ipairs(items) do
            local isSel = multi and sel[it] or (sel == it)
            local ib = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundTransparency=1, Position=UDim2.fromOffset(0,(i-1)*ITEM_H), Size=UDim2.new(1,-6,0,ITEM_H), ZIndex=903}, sf)
            local il = mk("TextLabel", {BackgroundTransparency=1, Text=(isSel and "> " or "") .. it, Font=FONT, TextSize=12, TextColor3=isSel and Theme.Text or Theme.TextDim, Position=UDim2.fromOffset(6,0), Size=UDim2.new(1,-6,1,0), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=904}, ib)
            ib.MouseEnter:Connect(function() tw(il, 0.1, {TextColor3 = Theme.Text}):Play() end)
            ib.MouseLeave:Connect(function()
                local s = multi and sel[it] or (sel == it)
                tw(il, 0.1, {TextColor3 = s and Theme.Text or Theme.TextDim}):Play()
            end)
            ib.MouseButton1Click:Connect(function()
                if multi then
                    sel[it] = not sel[it]
                    il.Text = (sel[it] and "> " or "") .. it
                    il.TextColor3 = sel[it] and Theme.Text or Theme.TextDim
                    refresh()
                    if o.Callback then
                        local arr = {}
                        for _, v in ipairs(items) do if sel[v] then arr[#arr+1] = v end end
                        task.spawn(o.Callback, arr)
                    end
                else
                    sel = it; refresh()
                    if o.Callback then task.spawn(o.Callback, sel) end
                    openFn()
                end
            end)
        end
        sf.CanvasSize = UDim2.new(0,0,0,#items * ITEM_H)
        local blk = mk("TextButton", {BackgroundTransparency=1, Text="", AutoButtonColor=false, Size=UDim2.fromScale(1,1), ZIndex=900}, popupLayer)
        openFn = function()
            openFn = nil
            blk:Destroy(); pop:Destroy()
        end
        blk.MouseButton1Click:Connect(openFn)
        pushPopup(openFn)
    end)

    local getVal = function()
        if multi then
            local arr = {}
            for _, v in ipairs(items) do if sel[v] then arr[#arr+1] = v end end
            return arr
        end
        return sel
    end

    local h = newHandle("Dropdown", o.Flag, getVal, function(v)
        if multi and type(v) == "table" then
            sel = {}
            for _, x in ipairs(v) do sel[tostring(x)] = true end
        else
            sel = tostring(v)
        end
        refresh()
    end)
    h.SetOptions = function(_, newItems)
        items = {}
        for i, v in ipairs(newItems) do items[i] = tostring(v) end
        refresh()
    end
    h.Set = function(_, v, silent)
        if multi and type(v) == "table" then
            sel = {}
            for _, x in ipairs(v) do sel[tostring(x)] = true end
        else
            sel = tostring(v)
        end
        refresh()
        if not silent and o.Callback then
            if multi then
                local arr = {}
                for _, vv in ipairs(items) do if sel[vv] then arr[#arr+1] = vv end end
                task.spawn(o.Callback, arr)
            else
                task.spawn(o.Callback, sel)
            end
        end
    end
    h.Value = getVal()
    if o.Flag then Options[o.Flag] = h; Dropdowns[o.Flag] = h end
    if o.Callback then task.spawn(o.Callback, getVal()) end
    return h
end

-- Input
function Section:Input(o)
    o = o or {}
    local val = tostring(o.Default or "")
    local row = nextRow(self, 32)
    mk("TextLabel", {BackgroundTransparency=1, Text=o.Text or "", Font=FONT, TextSize=13, TextColor3=Theme.TextDim, Position=UDim2.fromOffset(0,0), Size=UDim2.new(1,0,0,14), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)
    local box = mk("Frame", {BackgroundColor3=Theme.SurfaceLow, BorderSizePixel=0, Position=UDim2.fromOffset(0,17), Size=UDim2.new(1,0,0,20), ZIndex=15}, row)
    corner(box, 4); stroke(box)
    local tb = mk("TextBox", {BackgroundTransparency=1, Text=val, Font=FONT, TextSize=12, TextColor3=Theme.Text, PlaceholderText=o.Placeholder or "", PlaceholderColor3=Theme.TextDim, Position=UDim2.fromOffset(8,0), Size=UDim2.new(1,-16,1,0), TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, ClearTextOnFocus=false, ZIndex=16}, box)
    tb.Focused:Connect(function() tw(box, 0.12, {BackgroundColor3 = Theme.SurfaceHigh}):Play() end)
    tb.FocusLost:Connect(function()
        tw(box, 0.12, {BackgroundColor3 = Theme.SurfaceLow}):Play()
        val = tb.Text
        if o.Numeric and not tonumber(val) then tb.Text = val end
        if o.Callback then task.spawn(o.Callback, val) end
    end)
    local h = newHandle("Input", o.Flag, function() return tb.Text end, function(v) tb.Text = tostring(v or "") end)
    h.Set = function(_, v) tb.Text = tostring(v or "") end
    h.Value = tb.Text
    if o.Flag then Options[o.Flag] = h; Inputs[o.Flag] = h end
    if o.Callback then task.spawn(o.Callback, val) end
    return h
end

-- Button
function Section:Button(o)
    o = o or {}
    local row = nextRow(self, 22)
    local btn = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, Size=UDim2.fromScale(1,1), ZIndex=14}, row)
    corner(btn, 4); stroke(btn)
    mk("TextLabel", {BackgroundTransparency=1, Text=o.Text or "button", Font=FONT, TextSize=13, TextColor3=Theme.Text, Size=UDim2.fromScale(1,1), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=15}, btn)
    btn.MouseEnter:Connect(function() tw(btn, 0.12, {BackgroundColor3 = Theme.BorderHigh}):Play() end)
    btn.MouseLeave:Connect(function() tw(btn, 0.12, {BackgroundColor3 = Theme.SurfaceHigh}):Play() end)
    btn.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
    return btn
end

-- ButtonRow
function Section:ButtonRow(list)
    local row = nextRow(self, 22)
    local n = math.max(#list, 1)
    local handles = {}
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)}, row)
    for i, def in ipairs(list) do
        local cell = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=Theme.SurfaceHigh, BorderSizePixel=0, Size=UDim2.new(1/n, -(4*(n-1)/n), 1, 0), LayoutOrder=i, ZIndex=14}, row)
        corner(cell, 4); stroke(cell)
        mk("TextLabel", {BackgroundTransparency=1, Text=def.Text or "", Font=FONT, TextSize=12, TextColor3=Theme.Text, Size=UDim2.fromScale(1,1), TextXAlignment=Enum.TextXAlignment.Center, ZIndex=15}, cell)
        cell.MouseEnter:Connect(function() tw(cell, 0.12, {BackgroundColor3 = Theme.BorderHigh}):Play() end)
        cell.MouseLeave:Connect(function() tw(cell, 0.12, {BackgroundColor3 = Theme.SurfaceHigh}):Play() end)
        cell.MouseButton1Click:Connect(function() if def.Callback then task.spawn(def.Callback) end end)
        handles[i] = cell
    end
    return handles
end

-- ColorPicker
function Section:ColorPicker(o)
    o = o or {}
    local color = o.Default or Theme.Accent
    local row = nextRow(self, 18)
    mk("TextLabel", {BackgroundTransparency=1, Text=o.Text or "", Font=FONT, TextSize=13, TextColor3=Theme.TextDim, Position=UDim2.fromOffset(0,0), Size=UDim2.new(1,-30,1,0), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)
    local sw = mk("TextButton", {Text="", AutoButtonColor=false, BackgroundColor3=color, BorderSizePixel=0, AnchorPoint=Vector2.new(1,0.5), Position=UDim2.new(1,0,0.5,0), Size=UDim2.fromOffset(20,14), ZIndex=15}, row)
    corner(sw, 3); stroke(sw)

    local function set(v, silent)
        color = v
        sw.BackgroundColor3 = v
        if not silent and o.Callback then task.spawn(o.Callback, color) end
    end

    sw.MouseButton1Click:Connect(function()
        closePopups()
        local W, H = 180, 200
        local pop = mk("Frame", {BackgroundColor3=Theme.Surface, BorderSizePixel=0, Position=UDim2.fromOffset(math.clamp(sw.AbsolutePosition.X - W + 20, 8, screen.AbsoluteSize.X - W - 8), math.clamp(sw.AbsolutePosition.Y + 20, 8, screen.AbsoluteSize.Y - H - 8)), Size=UDim2.fromOffset(W,H), ZIndex=901}, popupLayer)
        corner(pop, 6); stroke(pop)
        mk("UIPadding", {PaddingLeft=UDim.new(0,10), PaddingRight=UDim.new(0,10), PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,10)}, pop)
        local h, s, v = Color3.toHSV(color)
        local svH = H - 60
        local svBox = mk("ImageButton", {BackgroundColor3=Color3.fromHSV(h,1,1), BorderSizePixel=0, Size=UDim2.fromOffset(W-40,svH), AutoButtonColor=false, ZIndex=902}, pop)
        corner(svBox, 4)
        local wg = mk("Frame", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, Size=UDim2.fromScale(1,1), ZIndex=903}, svBox)
        mk("UIGradient", {Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})}, wg)
        local bg = mk("Frame", {BackgroundColor3=Color3.fromRGB(0,0,0), BorderSizePixel=0, Size=UDim2.fromScale(1,1), ZIndex=904}, svBox)
        mk("UIGradient", {Rotation=90, Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})}, bg)
        local hueBar = mk("ImageButton", {BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, Position=UDim2.new(1,-24,0,0), Size=UDim2.fromOffset(16,svH), AutoButtonColor=false, ZIndex=902}, pop)
        corner(hueBar, 4)
        local hg = mk("UIGradient", {Rotation=90}, hueBar)
        hg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.34,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.50,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.84,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))})
        local preview = mk("Frame", {BackgroundColor3=color, BorderSizePixel=0, Position=UDim2.fromOffset(0,svH+8), Size=UDim2.fromOffset(W-40,20), ZIndex=902}, pop)
        corner(preview, 4)
        local okBtn = mk("TextButton", {Text="ok", Font=FONT_B, TextSize=11, TextColor3=Color3.fromRGB(15,15,20), BackgroundColor3=Theme.Accent, BorderSizePixel=0, Position=UDim2.new(1,-24,0,svH+8), Size=UDim2.fromOffset(24,20), AutoButtonColor=false, ZIndex=902}, pop)
        corner(okBtn, 4)
        local function push()
            local c = Color3.fromHSV(h,s,v)
            preview.BackgroundColor3 = c
            set(c)
        end
        local dsv, dh = false, false
        svBox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dsv = true; push() end end)
        hueBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dh = true end end)
        UIS.InputChanged:Connect(function(i)
            if not pop.Parent then return end
            if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local m = UIS:GetMouseLocation()
            if dsv then
                s = math.clamp((m.X - svBox.AbsolutePosition.X)/svBox.AbsoluteSize.X, 0, 1)
                v = 1 - math.clamp((m.Y - svBox.AbsolutePosition.Y)/svBox.AbsoluteSize.Y, 0, 1)
                push()
            elseif dh then
                h = math.clamp((m.Y - hueBar.AbsolutePosition.Y)/hueBar.AbsoluteSize.Y, 0, 1)
                svBox.BackgroundColor3 = Color3.fromHSV(h,1,1)
                push()
            end
        end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dsv, dh = false, false end end)
        local closeFn = function() pop:Destroy() end
        okBtn.MouseButton1Click:Connect(closeFn)
        pushPopup(closeFn)
    end)

    local h = newHandle("ColorPicker", o.Flag, function() return color end, function(v) set(v) end)
    h.Set = function(_, v, a, silent) set(v, silent) end
    h.Value = color
    if o.Flag then Options[o.Flag] = h end
    if o.Callback then task.spawn(o.Callback, color) end
    return h
end

-- Label + Paragraph + Search
function Section:Label(text, opts)
    local row = nextRow(self, 16)
    mk("TextLabel", {BackgroundTransparency=1, Text=text or "", Font=FONT, TextSize=12, TextColor3=Theme.TextDim, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)
end

function Section:Paragraph(o)
    o = o or {}
    local style = o.Style or "info"
    local accent = style == "warning" and Color3.fromRGB(240,180,80) or style == "danger" and Color3.fromRGB(220,82,82) or style == "success" and Color3.fromRGB(90,200,120) or Theme.Accent
    local row = nextRow(self, 30)
    local card = mk("Frame", {BackgroundColor3=Theme.SurfaceLow, BorderSizePixel=0, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=14}, row)
    corner(card, 4); stroke(card)
    mk("Frame", {BackgroundColor3=accent, BorderSizePixel=0, Size=UDim2.new(0,3,1,0), ZIndex=15}, card)
    local body = mk("Frame", {BackgroundTransparency=1, Position=UDim2.fromOffset(10,0), Size=UDim2.new(1,-10,0,0), AutomaticSize=Enum.AutomaticSize.Y, ZIndex=15}, card)
    mk("UIPadding", {PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8)}, body)
    mk("UIListLayout", {FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,3)}, body)
    if o.Title then mk("TextLabel", {BackgroundTransparency=1, Text=o.Title, Font=FONT_B, TextSize=12, TextColor3=Theme.Text, Size=UDim2.new(1,0,0,14), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16}, body) end
    if o.Content then mk("TextLabel", {BackgroundTransparency=1, Text=o.Content, Font=FONT, TextSize=12, TextColor3=Theme.TextDim, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=16}, body) end
end

function Section:Search(o)
    o = o or {}
    local row = nextRow(self, 34)
    if o.Label then
        mk("TextLabel", {BackgroundTransparency=1, Text=o.Label, Font=FONT, TextSize=12, TextColor3=Theme.TextDim, Position=UDim2.fromOffset(0,0), Size=UDim2.new(1,0,0,13), TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14}, row)
    end
    local box = mk("Frame", {BackgroundColor3=Theme.SurfaceLow, BorderSizePixel=0, Position=UDim2.fromOffset(0, o.Label and 16 or 0), Size=UDim2.new(1,0,0,20), ZIndex=15}, row)
    corner(box, 4); stroke(box)
    local tb = mk("TextBox", {BackgroundTransparency=1, Text="", PlaceholderText=o.Placeholder or "search...", PlaceholderColor3=Theme.TextDim, Font=FONT, TextSize=12, TextColor3=Theme.Text, Position=UDim2.fromOffset(8,0), Size=UDim2.new(1,-16,1,0), TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Center, ClearTextOnFocus=false, ZIndex=16}, box)
    if o.Live then
        tb:GetPropertyChangedSignal("Text"):Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
    else
        tb.FocusLost:Connect(function() if o.Callback then task.spawn(o.Callback, tb.Text) end end)
    end
end

function Section:Divider()
    local row = nextRow(self, 6)
    mk("Frame", {BackgroundColor3=Theme.Border, BorderSizePixel=0, Position=UDim2.fromOffset(0,2), Size=UDim2.new(1,0,0,1), ZIndex=14}, row)
end

function Section:Destroy() self._box:Destroy() end

-- SaveManager
local SaveManager = {}
local smFolder = "atlas_configs"
local smLibrary = nil
local function ensureFolder(path)
    if not isfolder then return end
    if not isfolder(path) then pcall(makefolder, path) end
end
ensureFolder(smFolder)

function SaveManager:SetLibrary(lib) smLibrary = lib end
function SaveManager:SetFolder(path)
    smFolder = path
    ensureFolder(smFolder)
end
function SaveManager:Save(name)
    if not writefile then return false end
    ensureFolder(smFolder)
    local data = {}
    for flag, r in pairs(Serializables) do
        local ok, v = pcall(r.get)
        if ok then data[flag] = ser(v) end
    end
    return pcall(writefile, smFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
end
function SaveManager:Load(name)
    if not readfile or not isfile then return false end
    local path = smFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, raw = pcall(readfile, path)
    if not ok then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return false end
    for flag, v in pairs(data) do
        local r = Serializables[flag]
        if r and r.set then pcall(r.set, deser(v)) end
    end
    return true
end
function SaveManager:Delete(name)
    if delfile then pcall(delfile, smFolder .. "/" .. name .. ".json") end
end
function SaveManager:List()
    local out = {}
    if not listfiles or not isfolder then return out end
    ensureFolder(smFolder)
    local ok, files = pcall(listfiles, smFolder)
    if ok and files then
        for _, f in ipairs(files) do
            local n = f:match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end
    return out
end
function SaveManager:SetAutoloadConfig(name)
    ensureFolder(smFolder)
    if writefile then pcall(writefile, smFolder .. "/autoload.txt", name) end
end
function SaveManager:ClearAutoload()
    if delfile then pcall(delfile, smFolder .. "/autoload.txt") end
end
function SaveManager:LoadAutoloadConfig()
    if not readfile or not isfile then return end
    local path = smFolder .. "/autoload.txt"
    if not isfile(path) then return end
    local ok, name = pcall(readfile, path)
    if ok and name ~= "" then SaveManager:Load(name) end
end

_G.SaveManager = SaveManager
_G.Toggles = Toggles
_G.Options = Options
_G.Keybinds = Keybinds
_G.Library = Library

return Library
