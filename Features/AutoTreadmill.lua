-- ==================================================
-- YOKUDO HUB | FEATURE | Auto Treadmill (Central Controller)
-- ✅ Aggregate Pause/Resume reasons from FarmingManager (egg) + ManagerDrone (event)
-- ✅ Master toggle + priority panel (self-contained ScreenGui)
-- ✅ Watchdog reconcile + ConfigSystem persistence
-- ==================================================

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- ==================================================
-- STATE
-- ==================================================
local MasterEnabled = true
local PauseReasons = {}
local Priority = { "egg", "boss" }
local Busy = false

local PriorityNames = {
    egg = "Egg Spawn",
    boss = "Boss Event",
}

-- ==================================================
-- CORE
-- ==================================================
local function ShouldRun()
    return MasterEnabled and next(PauseReasons) == nil
end

local function DoEnable()
    local AFK = _G.YOKUDO_AFKSystem
    if not AFK then return end
    if not AFK.IsEnabled() then
        AFK.Enable()
    end
end

local function DoDisable(Callback)
    local AFK = _G.YOKUDO_AFKSystem
    if not AFK or not AFK.IsEnabled() then
        if Callback then Callback() end
        return
    end

    local TreadmillPos = AFK.GetMyTreadmillPos()
    if not TreadmillPos then
        local _, Treadmill = AFK.FindMyPlotAndTreadmill()
        if Treadmill then TreadmillPos = Treadmill.Position end
    end

    if TreadmillPos then
        AFK.JumpOutTreadmill(TreadmillPos, function()
            AFK.Disable()
            if Callback then Callback() end
        end)
    else
        AFK.Disable()
        if Callback then Callback() end
    end
end

local function Transition(Want, Callback)
    task.spawn(function()
        local Guard = 0
        while Busy and Guard < 100 do
            task.wait(0.1)
            Guard = Guard + 1
        end

        Busy = true

        if Want then
            DoEnable()
            Busy = false
            if Callback then Callback() end
        else
            DoDisable(function()
                Busy = false
                if Callback then Callback() end
            end)
        end
    end)
end

local function Refresh(Callback)
    if not _G.YOKUDO_AFKSystem then
        if Callback then Callback() end
        return
    end
    Transition(ShouldRun(), Callback)
end

-- ==================================================
-- UI REFS (forward declared)
-- ==================================================
local MasterCheck, MasterButton
local RowLabels = {}
local RefreshUIInternal

local function Save()
    if _G.YOKUDO_ConfigSystem then
        _G.YOKUDO_ConfigSystem.Save()
    end
end

-- ==================================================
-- PUBLIC API
-- ==================================================
local API = {}

function API.Enable()
    MasterEnabled = true
    if RefreshUIInternal then RefreshUIInternal() end
    Refresh()
    Save()
end

function API.Disable()
    MasterEnabled = false
    if RefreshUIInternal then RefreshUIInternal() end
    Refresh()
    Save()
end

function API.Toggle()
    if MasterEnabled then API.Disable() else API.Enable() end
end

function API.IsEnabled()
    return MasterEnabled
end

function API.Pause(Reason, Callback)
    PauseReasons[tostring(Reason or "pause")] = true
    Refresh(Callback)
end

function API.Resume(Reason)
    PauseReasons[tostring(Reason or "pause")] = nil
    Refresh()
end

function API.IsPaused()
    return next(PauseReasons) ~= nil
end

function API.GetPauseReasons()
    local Out = {}
    for K in pairs(PauseReasons) do Out[K] = true end
    return Out
end

function API.CanRun(Owner)
    return ShouldRun()
end

function API.Refresh(Callback)
    Refresh(Callback)
end

function API.GetPriority()
    return { Priority[1], Priority[2] }
end

function API.SetPriority(List)
    if type(List) ~= "table" then return end
    local New = {}
    for _, Item in ipairs(List) do
        if Item == "egg" or Item == "boss" then
            table.insert(New, Item)
        end
    end
    for _, Item in ipairs({ "egg", "boss" }) do
        local Found = false
        for _, X in ipairs(New) do
            if X == Item then Found = true end
        end
        if not Found then table.insert(New, Item) end
    end
    Priority = New
    if RefreshUIInternal then RefreshUIInternal() end
    Save()
end

function API.MovePriority(Item, Dir)
    local Index
    for I, V in ipairs(Priority) do
        if V == Item then Index = I end
    end
    if not Index then return end

    local NewIndex = Index + Dir
    if NewIndex < 1 or NewIndex > #Priority then return end

    Priority[Index], Priority[NewIndex] = Priority[NewIndex], Priority[Index]
    if RefreshUIInternal then RefreshUIInternal() end
    Save()
end

function API.GetState()
    return { Enabled = MasterEnabled, Priority = { Priority[1], Priority[2] } }
end

_G.YOKUDO_AutoTreadmill = API

-- ==================================================
-- WATCHDOG (reconcile desired vs actual)
-- ==================================================
task.spawn(function()
    while task.wait(2) do
        local AFK = _G.YOKUDO_AFKSystem
        if AFK and not Busy then
            local Want = ShouldRun()
            local Is = AFK.IsEnabled()
            if Want and not Is then
                Transition(true)
            elseif (not Want) and Is then
                Transition(false)
            end
        end
    end
end)

-- ==================================================
-- UI
-- ==================================================
local GuiParent = _G.YOKUDO_GuiParent or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "YOKUDO_AutoTreadmill"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 998
ScreenGui.Parent = GuiParent

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "AT_Toggle"
ToggleBtn.Size = UDim2.new(0, 46, 0, 46)
ToggleBtn.Position = UDim2.new(1, -62, 0.5, 90)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "AFK"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 13
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor = false
ToggleBtn.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(200, 200, 220)
ToggleStroke.Thickness = 1.5
ToggleStroke.Transparency = 0.2
ToggleStroke.Parent = ToggleBtn

local Panel = Instance.new("Frame")
Panel.Name = "AT_Panel"
Panel.Size = UDim2.new(0, 210, 0, 176)
Panel.Position = UDim2.new(1, -284, 0.5, -40)
Panel.BackgroundColor3 = Color3.fromRGB(16, 17, 23)
Panel.BorderSizePixel = 0
Panel.Visible = false
Panel.Parent = ScreenGui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 10)
PanelCorner.Parent = Panel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Color = Color3.fromRGB(105, 90, 190)
PanelStroke.Thickness = 1.5
PanelStroke.Transparency = 0.3
PanelStroke.Parent = Panel

local PanelTitle = Instance.new("TextLabel")
PanelTitle.Size = UDim2.new(1, -20, 0, 26)
PanelTitle.Position = UDim2.new(0, 10, 0, 6)
PanelTitle.BackgroundTransparency = 1
PanelTitle.Text = "Auto Treadmill"
PanelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelTitle.TextSize = 14
PanelTitle.TextXAlignment = Enum.TextXAlignment.Left
PanelTitle.Font = Enum.Font.GothamBold
PanelTitle.Parent = Panel

local MasterLabel = Instance.new("TextLabel")
MasterLabel.Size = UDim2.new(1, -60, 0, 24)
MasterLabel.Position = UDim2.new(0, 12, 0, 40)
MasterLabel.BackgroundTransparency = 1
MasterLabel.Text = "Enable Auto Treadmill"
MasterLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
MasterLabel.TextSize = 12
MasterLabel.TextXAlignment = Enum.TextXAlignment.Left
MasterLabel.Font = Enum.Font.GothamMedium
MasterLabel.Parent = Panel

MasterButton = Instance.new("TextButton")
MasterButton.Size = UDim2.new(0, 24, 0, 24)
MasterButton.Position = UDim2.new(1, -36, 0, 40)
MasterButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
MasterButton.BorderSizePixel = 0
MasterButton.Text = ""
MasterButton.AutoButtonColor = false
MasterButton.Parent = Panel

local MasterBtnCorner = Instance.new("UICorner")
MasterBtnCorner.CornerRadius = UDim.new(0, 6)
MasterBtnCorner.Parent = MasterButton

local MasterBtnStroke = Instance.new("UIStroke")
MasterBtnStroke.Color = Color3.fromRGB(200, 200, 220)
MasterBtnStroke.Thickness = 1.5
MasterBtnStroke.Parent = MasterButton

MasterCheck = Instance.new("TextLabel")
MasterCheck.Size = UDim2.new(1, 0, 1, 0)
MasterCheck.BackgroundTransparency = 1
MasterCheck.Text = "✓"
MasterCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterCheck.TextSize = 16
MasterCheck.Font = Enum.Font.GothamBold
MasterCheck.Visible = false
MasterCheck.Parent = MasterButton

local PriorityHeader = Instance.new("TextLabel")
PriorityHeader.Size = UDim2.new(1, -20, 0, 18)
PriorityHeader.Position = UDim2.new(0, 12, 0, 72)
PriorityHeader.BackgroundTransparency = 1
PriorityHeader.Text = "Priority (top = first)"
PriorityHeader.TextColor3 = Color3.fromRGB(145, 145, 165)
PriorityHeader.TextSize = 10
PriorityHeader.TextXAlignment = Enum.TextXAlignment.Left
PriorityHeader.Font = Enum.Font.Gotham
PriorityHeader.Parent = Panel

local function CreatePriorityRow(Order)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, -20, 0, 34)
    Row.Position = UDim2.new(0, 10, 0, 92 + (Order - 1) * 38)
    Row.BackgroundColor3 = Color3.fromRGB(28, 29, 42)
    Row.BorderSizePixel = 0
    Row.Parent = Panel

    local RowCorner = Instance.new("UICorner")
    RowCorner.CornerRadius = UDim.new(0, 6)
    RowCorner.Parent = Row

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, -70, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = "?"
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Font = Enum.Font.GothamBold
    Label.Parent = Row

    local Up = Instance.new("TextButton")
    Up.Size = UDim2.new(0, 24, 0, 24)
    Up.Position = UDim2.new(1, -56, 0.5, -12)
    Up.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
    Up.BorderSizePixel = 0
    Up.Text = "▲"
    Up.TextColor3 = Color3.fromRGB(255, 255, 255)
    Up.TextSize = 11
    Up.Font = Enum.Font.GothamBold
    Up.AutoButtonColor = false
    Up.Parent = Row

    local UpCorner = Instance.new("UICorner")
    UpCorner.CornerRadius = UDim.new(0, 5)
    UpCorner.Parent = Up

    local Down = Instance.new("TextButton")
    Down.Size = UDim2.new(0, 24, 0, 24)
    Down.Position = UDim2.new(1, -28, 0.5, -12)
    Down.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
    Down.BorderSizePixel = 0
    Down.Text = "▼"
    Down.TextColor3 = Color3.fromRGB(255, 255, 255)
    Down.TextSize = 11
    Down.Font = Enum.Font.GothamBold
    Down.AutoButtonColor = false
    Down.Parent = Row

    local DownCorner = Instance.new("UICorner")
    DownCorner.CornerRadius = UDim.new(0, 5)
    DownCorner.Parent = Down

    RowLabels[Order] = Label

    Up.MouseButton1Click:Connect(function()
        API.MovePriority(Priority[Order], -1)
    end)

    Down.MouseButton1Click:Connect(function()
        API.MovePriority(Priority[Order], 1)
    end)

    return Row
end

CreatePriorityRow(1)
CreatePriorityRow(2)

-- ==================================================
-- UI UPDATE
-- ==================================================
RefreshUIInternal = function()
    MasterCheck.Visible = MasterEnabled
    if MasterEnabled then
        MasterButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        MasterBtnStroke.Color = Color3.fromRGB(135, 120, 225)
    else
        MasterButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        MasterBtnStroke.Color = Color3.fromRGB(200, 200, 220)
    end

    for Order = 1, 2 do
        local Item = Priority[Order]
        if RowLabels[Order] then
            RowLabels[Order].Text = PriorityNames[Item] or tostring(Item)
        end
    end
end

MasterButton.MouseButton1Click:Connect(function()
    API.Toggle()
end)

ToggleBtn.MouseButton1Click:Connect(function()
    Panel.Visible = not Panel.Visible
end)

_G.YOKUDO_RefreshAutoTreadmillUI = function()
    RefreshUIInternal()
end

RefreshUIInternal()

-- ==================================================
-- CONFIG REGISTRATION
-- ==================================================
if _G.YOKUDO_ConfigSystem then
    _G.YOKUDO_ConfigSystem.Register("AutoTreadmill", {
        Get = function()
            return { Enabled = MasterEnabled, Priority = { Priority[1], Priority[2] } }
        end,
        Set = function(Value)
            if type(Value) ~= "table" then return end
            if Value.Enabled ~= nil then
                MasterEnabled = Value.Enabled == true
            end
            if type(Value.Priority) == "table" then
                local New = {}
                for _, Item in ipairs(Value.Priority) do
                    if Item == "egg" or Item == "boss" then
                        table.insert(New, Item)
                    end
                end
                for _, Item in ipairs({ "egg", "boss" }) do
                    local Found = false
                    for _, X in ipairs(New) do
                        if X == Item then Found = true end
                    end
                    if not Found then table.insert(New, Item) end
                end
                Priority = New
            end
            RefreshUIInternal()
            Refresh()
        end,
    })
end

print("✅ AutoTreadmill Loaded (Central Controller + Panel)")
