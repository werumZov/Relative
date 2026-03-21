-- Services declaration
local playersService = game:GetService("Players")
local runService     = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")

-- Client references
local clientPlayer = playersService.LocalPlayer
local PlayerGui    = clientPlayer:WaitForChild("PlayerGui", 10)

-- Load WindUI library
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Create main window
local Window = WindUI:CreateWindow({
    Title         = "NektoSaken STAB",
    Icon          = "sparkle",
    Author        = "Maintained by Paster",
    Folder        = "NektoSakenScript",
    Size          = UDim2.fromOffset(560, 480),
    Transparent   = true,
    Theme         = "Dark",
    Resizable     = true,
    SideBarWidth  = 150,
    HideSearchBar = true,
    ScrollBarEnabled = false,
})

Window:SetToggleKey(UiBindd)
WindUI:SetFont("rbxasset://fonts/families/AccanthisADFStd.json")

Window:EditOpenButton({
    Title          = "NektoSaken STAB",
    Icon           = "sparkle",
    CornerRadius   = UDim.new(0, 16),
    StrokeThickness = 0,
    Color = ColorSequence.new(
        Color3.fromHex("000000"),
        Color3.fromHex("000000")
    ),
    OnlyMobile = true,
    Enabled    = true,
    Draggable  = true,
})

----------------------------------------------------------------
-- Backstab Tab
----------------------------------------------------------------
local BackstabTab = Window:Tab({
    Title = "Backstab",
    Icon  = "sword",
})

----------------------------------------------------------------
-- Settings Section
----------------------------------------------------------------
local SettingsSection = BackstabTab:Section({
    Title  = "Settings",
    Opened = true,
})

----------------------------------------------------------------
-- CONFIG 
----------------------------------------------------------------
local DEFAULT_PROXIMITY   = 8
local DEFAULT_DURATION    = 0.7
local BEHIND_DISTANCE     = 3.5
local CHECK_INTERVAL      = 0.07
local COOLDOWN            = 5
local LERP_SPEED          = 0.37
local DELAY_BEFORE_STAB   = 0.07

-- Mutable state driven by UI
local isRunning      = true
local enabled        = false
local daggerEnabled  = false
local rangeMode      = "Behind"        
local backstabType   = "Aim"          
local proximity      = DEFAULT_PROXIMITY
local lastTrigger    = 0
local aimRefCount    = 0

----------------------------------------------------------------
-- Helper functions
----------------------------------------------------------------
local function getCharacter()
    return clientPlayer.Character or clientPlayer.CharacterAdded:Wait()
end

local function getDaggerButton()
    local pg        = clientPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local mainUI    = pg:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local container = mainUI:FindFirstChild("AbilityContainer")
    if not container then return nil end
    return container:FindFirstChild("Dagger")
end

local function getDaggerCooldown()
    local btn = getDaggerButton()
    if not btn then return nil end
    return btn:FindFirstChild("CooldownTime")
        or btn:FindFirstChild("Cooldown")
        or btn:FindFirstChildWhichIsA("NumberValue")
        or btn:FindFirstChildWhichIsA("StringValue")
        or btn:FindFirstChild("CooldownLabel")
        or btn:FindFirstChild("Timer")
        or btn:FindFirstChild("CD")
end

local function readCooldownValue(cdObj)
    if not cdObj then return nil end
    if cdObj:IsA("NumberValue") then return cdObj.Value end
    if cdObj:IsA("StringValue") then return tonumber(cdObj.Value) end
    if cdObj:IsA("TextLabel") or cdObj:IsA("TextBox") then return tonumber(cdObj.Text) end
    if type(cdObj.Value) == "number" then return cdObj.Value end
    if type(cdObj.Value) == "string" then return tonumber(cdObj.Value) end
    if cdObj.Text ~= nil then return tonumber(cdObj.Text) end
    return nil
end

local function getKillersFolder()
    local playersFolder = workspaceService:FindFirstChild("Players")
    if not playersFolder then return nil end
    return playersFolder:FindFirstChild("Killers")
end

local function isValidKillerModel(model)
    if not model then return false end
    local hrp      = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChildWhichIsA("Humanoid")
    return hrp and humanoid and humanoid.Health and humanoid.Health > 0
end

local function tryActivateButton(btn)
    if not btn then return false end
    pcall(function() if btn.Activate then btn:Activate() end end)
    local ok, conns = pcall(function()
        if type(getconnections) == "function" and btn.MouseButton1Click then
            return getconnections(btn.MouseButton1Click)
        end
        return nil
    end)
    if ok and conns then
        for _, conn in ipairs(conns) do
            pcall(function()
                if conn.Function then conn.Function()
                elseif conn.func then conn.func()
                elseif conn.Fire then conn.Fire() end
            end)
        end
    end
    pcall(function() if btn.Activated then btn.Activated:Fire() end end)
    return true
end

local function setAutoRotate(value)
    local char = clientPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildWhichIsA("Humanoid")
    if hum then pcall(function() hum.AutoRotate = value end) end
end

----------------------------------------------------------------
-- Aiming logic
----------------------------------------------------------------
local function activateForKiller(killerModel, duration)
    if not killerModel or not isRunning then return end
    local char     = getCharacter()
    local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
    local hrp      = char and char:FindFirstChild("HumanoidRootPart")
    local khrp     = killerModel:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp or not khrp then return end

    aimRefCount += 1
    if aimRefCount == 1 then pcall(function() humanoid.AutoRotate = false end) end

    local function finishAiming()
        aimRefCount = math.max(0, aimRefCount - 1)
        if aimRefCount == 0 then setAutoRotate(true) end
    end

    local function computeDesiredCFrame()
        local kCF       = khrp.CFrame
        local behindPos = kCF.Position - (kCF.LookVector.Unit * BEHIND_DISTANCE)
        behindPos = Vector3.new(behindPos.X, kCF.Position.Y, behindPos.Z)
        return CFrame.new(behindPos, behindPos + kCF.LookVector.Unit)
    end

    if backstabType == "Lerp" then
        local t0 = os.clock()
        local conn
        conn = runService.Heartbeat:Connect(function()
            if not isRunning or os.clock() - t0 >= duration then
                conn:Disconnect()
                finishAiming()
                return
            end
            if khrp and hrp then
                hrp.CFrame = hrp.CFrame:Lerp(computeDesiredCFrame(), LERP_SPEED)
            end
        end)

    elseif backstabType == "Teleport" then
        local t0 = os.clock()
        local conn
        conn = runService.Heartbeat:Connect(function()
            if not isRunning or os.clock() - t0 >= duration then
                conn:Disconnect()
                finishAiming()
                return
            end
            if khrp and hrp then hrp.CFrame = computeDesiredCFrame() end
        end)

    elseif backstabType == "Aim" then
        local t0 = os.clock()
        local conn
        conn = runService.Heartbeat:Connect(function()
            if not isRunning or os.clock() - t0 >= duration then
                conn:Disconnect()
                finishAiming()
                return
            end
            if khrp and hrp then
                local targetPos = Vector3.new(khrp.Position.X, hrp.Position.Y, khrp.Position.Z)
                hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(hrp.Position, targetPos), LERP_SPEED * 1.6)
            end
        end)
    end
end

----------------------------------------------------------------
-- Main watcher
----------------------------------------------------------------
task.spawn(function()
    while isRunning do
        task.wait(CHECK_INTERVAL)
        if not enabled or not isRunning then continue end

        local killersFolder = getKillersFolder()
        if not killersFolder then continue end

        local char = getCharacter()
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        for _, killer in pairs(killersFolder:GetChildren()) do
            if not isValidKillerModel(killer) then continue end
            local khrp = killer:FindFirstChild("HumanoidRootPart")
            local dist = (khrp.Position - hrp.Position).Magnitude
            local shouldTrigger = false

            if rangeMode == "Around" then
                if dist <= proximity then shouldTrigger = true end
            else -- "Behind"
                local relative   = hrp.Position - khrp.Position
                local forwardDot = relative:Dot(khrp.CFrame.LookVector)
                if forwardDot < 0.3 and (-forwardDot) <= proximity and dist <= proximity then
                    shouldTrigger = true
                end
            end

            if shouldTrigger and os.clock() - lastTrigger >= COOLDOWN then
                local cdNum = readCooldownValue(getDaggerCooldown())
                if not (cdNum and cdNum > 0.1) then
                    lastTrigger = os.clock()
                    task.spawn(function()
                        activateForKiller(killer, DEFAULT_DURATION)
                        if daggerEnabled then
                            task.wait(DELAY_BEFORE_STAB)
                            tryActivateButton(getDaggerButton())
                        end
                    end)
                    break
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- Variables above
----------------------------------------------------------------

-- Auto Backstab toggle
SettingsSection:Toggle({
    Title    = "Auto Backstab",
    Type     = "Checkbox",
    Default  = false,
    Callback = function(state)
        enabled = state
    end,
})

-- Auto Stab on Backstab toggle
SettingsSection:Toggle({
    Title    = "Auto Stab on Backstab",
    Type     = "Checkbox",
    Default  = false,
    Callback = function(state)
        daggerEnabled = state
    end,
})

-- Backstab Type
SettingsSection:Dropdown({
    Title    = "Backstab Type",
    Values   = {"Lerp", "Teleport", "Aim"},
    Value    = "Lerp",
    Callback = function(value)
        backstabType = value
    end,
})

-- Range Mode dropdown
SettingsSection:Dropdown({
    Title    = "Range Mode",
    Values   = {"Around", "Behind"},
    Value    = "Behind",
    Callback = function(value)
        rangeMode = value
    end,
})

-- Detection Range slider
SettingsSection:Slider({
    Title    = "Detection Range",
    Step     = 1,
    Value    = { Min = 1, Max = 30, Default = DEFAULT_PROXIMITY },
    Callback = function(value)
        proximity = value
    end,
})

----------------------------------------------------------------
-- Interface Tab
----------------------------------------------------------------
local InterfaceTab = Window:Tab({
    Title  = "Interface",
    Icon   = "scan",
    Locked = false,
})

local UIFunctionsSection = InterfaceTab:Section({
    Title  = "UI Functions",
    Opened = true,
})

-- Unload (kills the watcher loop & restores AutoRotate)
InterfaceTab:Button({
    Title    = "Unload Script",
    Locked   = false,
    Callback = function()
        isRunning = false
        enabled   = false
        setAutoRotate(true)
        Window:Destroy()
    end,
})

-- Close UI only (loop keeps running in background)
InterfaceTab:Button({
    Title    = "Close UI",
    Locked   = false,
    Callback = function()
        Window:Destroy()
    end,
})

 local UiBindd = InterfaceTab:Keybind({
    Title = "Ui bind",
    Desc = "Keybind to open ui",
    Value = "J",
    Callback = function(v)
        Window:SetToggleKey(Enum.KeyCode[v])
    end
})  
