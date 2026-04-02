local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

-- GUI Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BackstabToggleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = lp:WaitForChild("PlayerGui")

-- Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 150, 0, 40)
toggleButton.Position = UDim2.new(0, 10, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 20
toggleButton.Text = "Backstab: OFF"
toggleButton.Parent = screenGui

-- Range Label
local rangeLabel = Instance.new("TextLabel")
rangeLabel.Size = UDim2.new(0, 150, 0, 20)
rangeLabel.Position = UDim2.new(0, 10, 0, 55)
rangeLabel.BackgroundTransparency = 1
rangeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
rangeLabel.Font = Enum.Font.SourceSans
rangeLabel.TextSize = 16
rangeLabel.Text = "Range:"
rangeLabel.Parent = screenGui

-- TextBox for Range Input
local rangeBox = Instance.new("TextBox")
rangeBox.Size = UDim2.new(0, 150, 0, 25)
rangeBox.Position = UDim2.new(0, 10, 0, 75)
rangeBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
rangeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
rangeBox.Font = Enum.Font.SourceSans
rangeBox.TextSize = 16
rangeBox.PlaceholderText = "Enter range (number)"
rangeBox.Text = "4"
rangeBox.ClearTextOnFocus = false
rangeBox.Parent = screenGui

-- Vars
local enabled = false
local cooldown = false
local lastTarget = nil
local range = 4
local daggerRemote = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Network"):WaitForChild("RemoteEvent")
local killerNames = { "Jason", "c00lkidd", "JohnDoe", "1x1x1x1", "Noli", "Slasher" }
local killersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")

-- GUI toggle
toggleButton.MouseButton1Click:Connect(function()
    enabled = not enabled
    toggleButton.Text = "Backstab: " .. (enabled and "ON" or "OFF")
    toggleButton.BackgroundColor3 = enabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(30, 30, 30)
end)

-- TextBox Range Handling
rangeBox.FocusLost:Connect(function()
    local input = tonumber(rangeBox.Text)
    if input and input >= 1 then
        range = input
    else
        rangeBox.Text = tostring(range)
    end
end)

-- Mode Toggle
local mode = "Behind"
local modeButton = Instance.new("TextButton")
modeButton.Size = UDim2.new(0, 150, 0, 25)
modeButton.Position = UDim2.new(0, 10, 0, 105)
modeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
modeButton.Font = Enum.Font.SourceSans
modeButton.TextSize = 16
modeButton.Text = "Mode: Behind"
modeButton.Parent = screenGui

modeButton.MouseButton1Click:Connect(function()
    if mode == "Behind" then
        mode = "Around"
    else
        mode = "Behind"
    end
    modeButton.Text = "Mode: " .. mode
end)

-- Match Facing Toggle (only for Legit mode)
local matchFacing = false
local facingButton = Instance.new("TextButton")
facingButton.Size = UDim2.new(0, 150, 0, 25)
facingButton.Position = UDim2.new(0, 10, 0, 165) -- under Backstab Type button
facingButton.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
facingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
facingButton.Font = Enum.Font.SourceSans
facingButton.TextSize = 16
facingButton.Text = "Legit Aimbot: OFF"
facingButton.Visible = false -- hidden until Legit mode
facingButton.Parent = screenGui

facingButton.MouseButton1Click:Connect(function()
    matchFacing = not matchFacing
    facingButton.Text = "Legit Aimbot: " .. (matchFacing and "ON" or "OFF")
    facingButton.BackgroundColor3 = matchFacing and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(110, 110, 110)
end)

-- Attack type button (Normal / Counter / Legit)
local attackType = "Normal"
local attackButton = Instance.new("TextButton")
attackButton.Size = UDim2.new(0, 150, 0, 25)
attackButton.Position = UDim2.new(0, 10, 0, 135) -- under mode button
attackButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
attackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
attackButton.Font = Enum.Font.SourceSans
attackButton.TextSize = 16
attackButton.Text = "Backstab Type: Normal"
attackButton.Parent = screenGui

attackButton.MouseButton1Click:Connect(function()
    if attackType == "Normal" then
        attackType = "Counter"
    elseif attackType == "Counter" then
        attackType = "Legit"
    elseif attackType == "Legit" then
        attackType = "Normal"
    end
    attackButton.Text = "Backstab Type: " .. attackType

    -- Show Match Facing button only if Legit
    facingButton.Visible = (attackType == "Legit")
end)

-- Hide Button
local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.new(0, 50, 0, 40)
hideButton.Position = UDim2.new(0, 165, 0, 10) -- right next to Backstab toggle
hideButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hideButton.Font = Enum.Font.SourceSansBold
hideButton.TextSize = 20
hideButton.Text = "Hide"
hideButton.Parent = screenGui

local guiHidden = false
local guiElements = {}

-- Store all GUI elements except toggle and hideButton
for _, obj in ipairs(screenGui:GetChildren()) do
    if obj ~= hideButton then
        table.insert(guiElements, obj)
    end
end

hideButton.MouseButton1Click:Connect(function()
    guiHidden = not guiHidden
    hideButton.Text = guiHidden and "Show" or "Hide"

    for _, obj in ipairs(guiElements) do
        obj.Visible = not guiHidden
    end
end)

-- Animation IDs for Counter mode
local counterAnimIDs = {
    "126830014841198", "126355327951215", "121086746534252",
    "18885909645", "98456918873918", "105458270463374",
    "83829782357897", "125403313786645", "118298475669935",
    "82113744478546", "70371667919898", "99135633258223",
    "97167027849946", "109230267448394", "139835501033932",
    "126896426760253", "109667959938617", "126681776859538",
    "129976080405072", "121293883585738", "81639435858902",
    "137314737492715", "92173139187970"
}

-- Helpers
local function killerPlayingCounterAnim(killer)
    local humanoid = killer:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid:FindFirstChildOfClass("Animator") then return false end

    for _, track in ipairs(humanoid.Animator:GetPlayingAnimationTracks()) do
        if track.Animation and track.Animation.AnimationId then
            local animIdNum = track.Animation.AnimationId:match("%d+")
            for _, id in ipairs(counterAnimIDs) do
                if tostring(animIdNum) == id then
                    return true
                end
            end
        end
    end
    return false
end

local function tryActivateButton(btn)
    if not btn then return false end

    pcall(function()
        if btn.Activate then btn:Activate() end
    end)

    local ok, conns = pcall(function()
        if type(getconnections) == "function" and btn.MouseButton1Click then
            return getconnections(btn.MouseButton1Click)
        end
        return nil
    end)

    if ok and conns then
        for _, conn in ipairs(conns) do
            pcall(function()
                if conn.Function then
                    conn.Function()
                elseif conn.func then
                    conn.func()
                elseif conn.Fire then
                    conn.Fire()
                end
            end)
        end
    end

    pcall(function()
        if btn.Activated then
            btn.Activated:Fire()
        end
    end)

    return true
end

local function getDaggerButton()
    local pg = lp:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local mainUI = pg:FindFirstChild("MainUI")
    if not mainUI then return nil end
    local container = mainUI:FindFirstChild("AbilityContainer")
    if not container then return nil end
    return container:FindFirstChild("Dagger")
end

local function isBehindTarget(hrp, targetHRP)
    local distance = (hrp.Position - targetHRP.Position).Magnitude
    if distance > range then return false end

    if mode == "Around" then
        return true
    else
        local direction = -targetHRP.CFrame.LookVector
        local toPlayer = (hrp.Position - targetHRP.Position)
        return toPlayer:Dot(direction) > 0.3
    end
end

-- keep daggerCooldownText up-to-date automatically
local daggerCooldownText
local function refreshDaggerRef()
    local mainui = lp:FindFirstChild("PlayerGui"):FindFirstChild("MainUI")
    if mainui and mainui:FindFirstChild("AbilityContainer") then
        local dagger = mainui.AbilityContainer:FindFirstChild("Dagger")
        if dagger and dagger:FindFirstChild("CooldownTime") then
            daggerCooldownText = dagger.CooldownTime
            return
        end
    end
    daggerCooldownText = nil
end

-- reconnect whenever relevant descendants change
lp.PlayerGui.DescendantAdded:Connect(refreshDaggerRef)
lp.PlayerGui.DescendantRemoving:Connect(function(obj)
    if obj == daggerCooldownText then
        daggerCooldownText = nil
    end
end)

refreshDaggerRef()

RunService.RenderStepped:Connect(function()
    if not daggerCooldownText or not daggerCooldownText.Parent then return end
    if tonumber(daggerCooldownText.Text) then return end -- still on cooldown
    if not enabled or cooldown then return end

    local char = lp.Character
    if not (char and char:FindFirstChild("HumanoidRootPart")) then return end
    local hrp = char.HumanoidRootPart
    local stats = game:GetService("Stats")

    for _, name in ipairs(killerNames) do
        local killer = killersFolder:FindFirstChild(name)
        if killer and killer:FindFirstChild("HumanoidRootPart") then
            local kHRP = killer.HumanoidRootPart

            if attackType == "Legit" then
                local dist = (kHRP.Position - hrp.Position).Magnitude
                if dist <= range then
                    -- Optional facing alignment
                    if matchFacing then
                        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + kHRP.CFrame.LookVector)
                    end
                    if mode == "Behind" then
                        local directionToTarget = (kHRP.Position - hrp.Position).Unit
                        local dot = hrp.CFrame.LookVector:Dot(directionToTarget)
                        if dot > 0.6 then
                            return -- target is in front
                        end
                    end
                    local daggerbtn = getDaggerButton()
                    tryActivateButton(daggerbtn)
                end
                return -- skip TP logic
            end

            if attackType == "Counter" and not killerPlayingCounterAnim(killer) then
                continue
            end

            if isBehindTarget(hrp, kHRP) and killer ~= lastTarget then
                cooldown = true
                lastTarget = killer

                local start = tick()
                local didDagger = false
                local connection

                connection = RunService.Heartbeat:Connect(function()
                    if not (char and char.Parent and kHRP and kHRP.Parent) then
                        if connection then connection:Disconnect() end
                        return
                    end

                    local elapsed = tick() - start
                    if elapsed >= 0.5 then
                        if connection then connection:Disconnect() end
                        return
                    end

                    -- LIVE Ping + velocity prediction
                    local ping = tonumber(stats.Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")) or 50
                    local pingSeconds = ping / 1000
                    local killerVelocity = kHRP.Velocity
                    local moveDir = killerVelocity.Magnitude > 0.1 and killerVelocity.Unit or Vector3.new()
                    local pingOffset = moveDir * (pingSeconds * killerVelocity.Magnitude)
                    local predictedPos = kHRP.Position + pingOffset

                    -- Apply mode logic with improved "Around" handling
                    local targetPos
                    if mode == "Behind" then
                        targetPos = predictedPos - (kHRP.CFrame.LookVector * 0.3)
                    elseif mode == "Around" then
                        local lookVec = kHRP.CFrame.LookVector
                        local rightVec = kHRP.CFrame.RightVector
                        local rel = (hrp.Position - kHRP.Position)
                        local lateralSpeed = killerVelocity:Dot(rightVec)

                        local baseOffset = (rel.Magnitude > 0.1) and rel.Unit * 0.3 or Vector3.new()
                        local lateralOffset = rightVec * lateralSpeed * 0.3

                        targetPos = predictedPos + baseOffset + lateralOffset
                    end

                    -- Constant live TP
                    hrp.CFrame = CFrame.new(targetPos, targetPos + kHRP.CFrame.LookVector)

                    -- Only dagger once
                    if not didDagger then
                        didDagger = true

                        -- Keep aligning for 0.7s
                        local faceStart = tick()
                        local faceConn
                        faceConn = RunService.Heartbeat:Connect(function()
                            if tick() - faceStart >= 0.7 or not kHRP or not kHRP.Parent then
                                if faceConn then faceConn:Disconnect() end
                                return
                            end

                            -- Live align during window
                            local livePing = tonumber(stats.Network.ServerStatsItem["Data Ping"]:GetValueString():match("%d+")) or 50
                            local livePingSeconds = livePing / 1000
                            local liveVelocity = kHRP.Velocity
                            local liveMoveDir = liveVelocity.Magnitude > 0.1 and liveVelocity.Unit or Vector3.new()
                            local livePingOffset = liveMoveDir * (livePingSeconds * liveVelocity.Magnitude)
                            local livePredictedPos = kHRP.Position + livePingOffset

                            local liveTargetPos
                            if mode == "Behind" then
                                liveTargetPos = livePredictedPos - (kHRP.CFrame.LookVector * 0.3)
                            elseif mode == "Around" then
                                local lookVec = kHRP.CFrame.LookVector
                                local rightVec = kHRP.CFrame.RightVector
                                local liveRel = (hrp.Position - kHRP.Position)
                                local liveLateralSpeed = liveVelocity:Dot(rightVec)

                                local baseOffset = (liveRel.Magnitude > 0.1) and liveRel.Unit * 0.3 or Vector3.new()
                                local lateralOffset = rightVec * liveLateralSpeed * 0.3

                                liveTargetPos = livePredictedPos + baseOffset + lateralOffset
                            end
                            hrp.CFrame = CFrame.new(liveTargetPos, liveTargetPos + kHRP.CFrame.LookVector)
                        end)
                        local daggerbtn = getDaggerButton()
                        tryActivateButton(daggerbtn)
                    end
                end)

                -- Reset cooldown when out of range
                task.delay(2, function()
                    RunService.Heartbeat:Wait()
                    while isBehindTarget(hrp, kHRP) do
                        RunService.Heartbeat:Wait()
                    end
                    lastTarget = nil
                    cooldown = false
                end)

                break
            end
        end
    end
end)
