--[[
    Lost Frontier Delta Script (Refactored)
    Версия: 1.2
    Изменения: Новый компактный интерфейс меню, оптимизация обновлений (объединённый игровой цикл), слайдеры для основных настроек, улучшенная производительность ESP/aimbot.
    Использование: loadstring(game:HttpGet("URL",true))()
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Key system (unchanged behaviour)
local KeySystem = { Activated = false }
KeySystem.MasterKey = "KOLYA-MASTER-2024-INFINITE"
KeySystem.ValidKeys = {}
KeySystem.APIUrl = "https://your-api-server.com/api/validate"
KeySystem.UserId = LocalPlayer.UserId

function KeySystem:ValidateKeyOnline(InputKey)
    local ok, response = pcall(function()
        local url = self.APIUrl .. "?key=" .. InputKey .. "&userid=" .. self.UserId
        return HttpService:GetAsync(url, true)
    end)
    if ok and response then
        local data = HttpService:JSONDecode(response)
        if data and data.valid then
            self.Activated = true
            if data.expires then
                local HoursLeft = math.floor((data.expires - os.time()) / 3600)
                return true, "Ключ активирован! Осталось: " .. HoursLeft .. " часов"
            else
                return true, "Ключ активирован! Доступ навсегда."
            end
        end
    end
    return false, nil
end

function KeySystem:ValidateKey(InputKey)
    if not InputKey or InputKey == "" then return false, "Ключ не введен" end
    if InputKey == self.MasterKey then self.Activated = true; return true, "Мастер-ключ активирован!" end
    local onlineValid, onlineMsg = self:ValidateKeyOnline(InputKey)
    if onlineValid then return true, onlineMsg end
    local now = os.time()
    for _, k in pairs(self.ValidKeys) do
        if k.Key == InputKey then
            if now < k.ExpireTime then
                self.Activated = true
                local HoursLeft = math.floor((k.ExpireTime - now) / 3600)
                return true, "Ключ активирован! Осталось: " .. HoursLeft .. " часов"
            else
                return false, "Ключ истек"
            end
        end
    end
    return false, "Неверный ключ"
end

local function CheckSavedKey()
    local ok, saved = pcall(function()
        if readfile then return HttpService:JSONDecode(readfile("LostFrontier_Key.txt")) end
    end)
    if ok and saved then
        local valid = KeySystem:ValidateKey(saved.Key)
        if valid then KeySystem.Activated = true; return true end
    end
    return false
end

local function SaveKey(Key)
    pcall(function() if writefile then writefile("LostFrontier_Key.txt", HttpService:JSONEncode({Key=Key})) end end)
end

LocalPlayer.CharacterAdded:Connect(function(c)
    Character = c
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart")
    Humanoid = c:WaitForChild("Humanoid")
end)

-- Settings with defaults
local Settings = {
    AutoFarm = false,
    AutoAttack = false,
    ESP = false,
    ESPDistance = 500,
    WalkSpeed = 20,
    JumpPower = 50,
    NoClip = false,
    InfiniteJump = false,
    -- Aimbot
    Aimbot = false,
    AimbotFOV = 120,
    AimbotSmoothing = 0.25,
    AimbotAutoFire = true,
    AimbotRange = 200,
    AimbotTargetPart = "Head",
}

if not CheckSavedKey() then KeySystem.Activated = false end

-- Drawing availability
local DrawingSupported = pcall(function() local t = Drawing.new("Square"); t:Remove() end)

-- Lightweight ESP store
local ESPLibrary = { Objects = {} }

local function createESPForCharacter(char, color, name)
    if not DrawingSupported or not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local esp = { Object = char, Name = name or char.Name, Color = color or Color3.fromRGB(255,0,0), Drawing = {} }
    local Box = Drawing.new("Square")
    Box.Thickness = 2; Box.Filled = false; Box.Visible = false; Box.Color = esp.Color
    local NameText = Drawing.new("Text"); NameText.Size = 14; NameText.Visible = false; NameText.Color = esp.Color; NameText.Outline = true
    local DistText = Drawing.new("Text"); DistText.Size = 12; DistText.Visible = false; DistText.Color = esp.Color; DistText.Outline = true
    esp.Drawing.Box = Box; esp.Drawing.Name = NameText; esp.Drawing.Distance = DistText
    ESPLibrary.Objects[#ESPLibrary.Objects+1] = esp
    return esp
end

local function removeESP(esp)
    if not esp then return end
    for i,v in ipairs(ESPLibrary.Objects) do if v==esp then table.remove(ESPLibrary.Objects,i); break end end
    for _,d in pairs(esp.Drawing) do pcall(function() d:Remove() end) end
end

local function clearAllESP()
    for i=#ESPLibrary.Objects,1,-1 do removeESP(ESPLibrary.Objects[i]) end
end

-- Utility: get visible screen position and on-screen check
local function worldToScreen(camera, pos)
    local v, on = camera:WorldToViewportPoint(pos)
    return v, on
end

-- Cache players to avoid table allocations every frame
local function getAlivePlayers()
    local list = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild(Settings.AimbotTargetPart) then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health>0 then list[#list+1]=p end
        end
    end
    return list
end

-- Find nearest object by world distance
local function GetNearestObjectByPart(list, reference)
    local nearest, nd = nil, math.huge
    for _,obj in ipairs(list) do
        if obj and obj.Parent then
            local part = obj:FindFirstChild("HumanoidRootPart") or (obj:IsA("BasePart") and obj)
            if part and reference then
                local d = (part.Position - reference.Position).Magnitude
                if d < nd then nd = d; nearest = obj end
            end
        end
    end
    return nearest, nd
end

-- Lightweight resource/enemy finders with throttling
local lastResourceScan = 0; local cachedResources = {}
local function FindResources(force)
    local now = tick()
    if not force and now - lastResourceScan < 1 then return cachedResources end
    lastResourceScan = now
    local R = {}
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("wood") or name:find("stone") or name:find("ore") or name:find("tree") or name:find("rock") then
                R[#R+1] = obj
            end
        end
    end
    cachedResources = R
    return R
end

local lastEnemyScan = 0; local cachedEnemies = {}
local function FindEnemies(force)
    local now = tick()
    if not force and now - lastEnemyScan < 0.6 then return cachedEnemies end
    lastEnemyScan = now
    local E = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health>0 then E[#E+1] = p.Character end
        end
    end
    cachedEnemies = E
    return E
end

-- Teleport helper
local function TeleportTo(position)
    if HumanoidRootPart then HumanoidRootPart.CFrame = CFrame.new(position) end
end

-- Single unified update loop for performance (RenderStepped)
local UpdateConnection
local aimState = { enabled = false }
local function StartUnifiedLoop()
    if UpdateConnection then return end
    local camera = Workspace.CurrentCamera
    local lastTick = tick()
    UpdateConnection = RunService.RenderStepped:Connect(function()
        local now = tick(); local dt = now - lastTick; lastTick = now
        if not Character or not Character:FindFirstChild("HumanoidRootPart") then return end

        -- Speed & Jump
        if Humanoid then
            Humanoid.WalkSpeed = Settings.WalkSpeed
            Humanoid.JumpPower = Settings.JumpPower
        end

        -- NoClip (cheap implementation)
        if Settings.NoClip and Character then
            for _,part in ipairs(Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end

        -- ESP update (only if enabled)
        if Settings.ESP and DrawingSupported then
            -- Ensure we have ESP objects for players
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local exists
                    for _,e in ipairs(ESPLibrary.Objects) do if e.Object==p.Character then exists=true; break end end
                    if not exists then createESPForCharacter(p.Character, Color3.fromRGB(255,100,100), p.Name) end
                end
            end
            -- Update all ESP drawings
            for i=#ESPLibrary.Objects,1,-1 do
                local esp = ESPLibrary.Objects[i]
                if not esp.Object or not esp.Object.Parent then removeESP(esp) else
                    local part = esp.Object:FindFirstChild("HumanoidRootPart")
                    if part then
                        local screenPos, on = worldToScreen(camera, part.Position)
                        local dist = (part.Position - HumanoidRootPart.Position).Magnitude
                        if not on or dist > Settings.ESPDistance then
                            esp.Drawing.Box.Visible = false; esp.Drawing.Name.Visible=false; esp.Drawing.Distance.Visible=false
                        else
                            local size = Vector2.new(60,100)
                            esp.Drawing.Box.Position = Vector2.new(screenPos.X - size.X/2, screenPos.Y - size.Y/2)
                            esp.Drawing.Box.Size = size
                            esp.Drawing.Box.Visible = true
                            esp.Drawing.Name.Position = Vector2.new(screenPos.X, screenPos.Y - 60)
                            esp.Drawing.Name.Text = esp.Name
                            esp.Drawing.Name.Visible = true
                            esp.Drawing.Distance.Position = Vector2.new(screenPos.X, screenPos.Y - 44)
                            esp.Drawing.Distance.Text = math.floor(dist) .. " studs"
                            esp.Drawing.Distance.Visible = true
                        end
                    end
                end
            end
        elseif not Settings.ESP then
            if #ESPLibrary.Objects>0 then clearAllESP() end
        end

        -- AutoFarm (throttled via FindResources)
        if Settings.AutoFarm then
            local resources = FindResources()
            local nearest, d = GetNearestObjectByPart(resources, HumanoidRootPart)
            if nearest then
                local part = (nearest:FindFirstChild("HumanoidRootPart") or nearest)
                if part then
                    if d > 10 then TeleportTo(part.Position) end
                    if d < 5 then
                        local prompt = nearest:FindFirstChildOfClass("ProximityPrompt")
                        if prompt then pcall(function() fireproximityprompt(prompt) end) end
                    end
                end
            end
        end

        -- AutoAttack (use cached enemies)
        if Settings.AutoAttack then
            local enemies = FindEnemies()
            local target, d = GetNearestObjectByPart(enemies, HumanoidRootPart)
            if target and target:FindFirstChild("HumanoidRootPart") then
                if d < 50 then
                    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target.HumanoidRootPart.Position)
                    if d < 10 then local Tool = Character:FindFirstChildOfClass("Tool") if Tool then pcall(function() Tool:Activate() end) end end
                end
            end
        end

        -- Aimbot (targeting by screen proximity to mouse)
        if Settings.Aimbot then
            local mouse = LocalPlayer:GetMouse()
            local candidates = getAlivePlayers()
            local closestPart, closestDist = nil, math.huge
            for _,p in ipairs(candidates) do
                local part = p.Character and p.Character:FindFirstChild(Settings.AimbotTargetPart)
                if part then
                    local sp, on = worldToScreen(camera, part.Position)
                    if on then
                        local dx = sp.X - mouse.X; local dy = sp.Y - mouse.Y
                        local dd = math.sqrt(dx*dx + dy*dy)
                        if dd < Settings.AimbotFOV and dd < closestDist then closestDist = dd; closestPart = part end
                    end
                end
            end
            if closestPart then
                camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(camera.CFrame.Position, closestPart.Position), math.clamp(Settings.AimbotSmoothing, 0, 1))
                if Settings.AimbotAutoFire then
                    local worldDist = (closestPart.Position - HumanoidRootPart.Position).Magnitude
                    if worldDist <= Settings.AimbotRange then local Tool = Character:FindFirstChildOfClass("Tool") if Tool then pcall(function() Tool:Activate() end) end end
                end
            end
        end

        -- Infinite jump handled via event (no per-frame cost)
    end)
end

-- Start unified loop immediately (does nothing until features enabled)
StartUnifiedLoop()

-- Infinite jump
UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump and Humanoid then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- GUI (новое компактное меню)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LF_GUI"
ScreenGui.Parent = game:GetService("CoreGui")

local MainToggle = Instance.new("TextButton")
MainToggle.Name = "MainToggle"; MainToggle.Size = UDim2.new(0,48,0,48); MainToggle.Position = UDim2.new(1,-68,0,12)
MainToggle.BackgroundColor3 = Color3.fromRGB(255,107,107); MainToggle.BorderSizePixel = 0; MainToggle.Text = "☰"; MainToggle.Font = Enum.Font.GothamBold; MainToggle.TextSize=24
MainToggle.Parent = ScreenGui

local Menu = Instance.new("Frame")
Menu.Size = UDim2.new(0,300,0,380); Menu.Position = UDim2.new(1,-320,0,70); Menu.BackgroundColor3 = Color3.fromRGB(30,30,30); Menu.BorderSizePixel=0; Menu.Visible=false; Menu.Parent = ScreenGui

local UIList = Instance.new("UIListLayout", Menu); UIList.Padding = UDim.new(0,6)

local function MakeSection(title)
    local sec = Instance.new("Frame"); sec.Size = UDim2.new(1,-12,0,40); sec.BackgroundTransparency=1; sec.Parent = Menu
    local label = Instance.new("TextLabel"); label.Size=UDim2.new(1,0,1,0); label.BackgroundTransparency=1; label.Text=title; label.TextSize=16; label.TextColor3=Color3.fromRGB(255,255,255); label.Font=Enum.Font.GothamBold; label.Parent=sec
    return sec
end

local function MakeToggle(name, settingKey)
    local frame = Instance.new("Frame"); frame.Size = UDim2.new(1,-12,0,34); frame.Parent = Menu; frame.BackgroundColor3 = Color3.fromRGB(40,40,40); frame.BorderSizePixel=0
    local label = Instance.new("TextLabel", frame); label.Size=UDim2.new(0.65,0,1,0); label.BackgroundTransparency=1; label.Text=name; label.TextColor3=Color3.fromRGB(255,255,255); label.Font=Enum.Font.Gotham
    local btn = Instance.new("TextButton", frame); btn.Size=UDim2.new(0,70,0,26); btn.Position = UDim2.new(1,-80,0,4); btn.Text="OFF"; btn.Font = Enum.Font.GothamBold; btn.TextColor3=Color3.fromRGB(255,255,255)
    btn.BackgroundColor3 = Color3.fromRGB(130,130,130)
    btn.MouseButton1Click:Connect(function()
        if not KeySystem.Activated then
            -- show key frame below
            KeyFrame.Visible = true; return
        end
        Settings[settingKey] = not Settings[settingKey]
        btn.Text = Settings[settingKey] and "ON" or "OFF"
        btn.BackgroundColor3 = Settings[settingKey] and Color3.fromRGB(46,213,115) or Color3.fromRGB(130,130,130)
    end)
    return frame
end

local function MakeSlider(name, key, minv, maxv, step)
    local frame = Instance.new("Frame"); frame.Size = UDim2.new(1,-12,0,46); frame.Parent = Menu; frame.BackgroundColor3 = Color3.fromRGB(40,40,40); frame.BorderSizePixel=0
    local label = Instance.new("TextLabel", frame); label.Size=UDim2.new(0.6,0,0.5,0); label.Position=UDim2.new(0,8,0,4); label.BackgroundTransparency=1; label.Text=name; label.TextColor3=Color3.fromRGB(255,255,255); label.Font=Enum.Font.Gotham
    local valueLabel = Instance.new("TextLabel", frame); valueLabel.Size=UDim2.new(0.35,0,0.5,0); valueLabel.Position=UDim2.new(0.6,0,0,4); valueLabel.BackgroundTransparency=1; valueLabel.Text= tostring(Settings[key]); valueLabel.TextColor3=Color3.fromRGB(200,200,200); valueLabel.Font=Enum.Font.GothamBold
    -- simple +/- buttons
    local minus = Instance.new("TextButton", frame); minus.Text = "-"; minus.Size=UDim2.new(0,36,0,26); minus.Position=UDim2.new(0,8,0,20); minus.Font=Enum.Font.GothamBold
    local plus = Instance.new("TextButton", frame); plus.Text = "+"; plus.Size=UDim2.new(0,36,0,26); plus.Position=UDim2.new(1,-44,0,20); plus.Font=Enum.Font.GothamBold
    minus.MouseButton1Click:Connect(function()
        local v = Settings[key] - (step or 1); if v < (minv or 0) then v = minv end; Settings[key] = v; valueLabel.Text = tostring(v)
    end)
    plus.MouseButton1Click:Connect(function()
        local v = Settings[key] + (step or 1); if v > (maxv or 9999) then v = maxv end; Settings[key] = v; valueLabel.Text = tostring(v)
    end)
    return frame
end

-- Key activation mini-frame (compact)
local KeyFrame = Instance.new("Frame"); KeyFrame.Size = UDim2.new(0,320,0,120); KeyFrame.Position = UDim2.new(0.5,-160,0.3,0); KeyFrame.BackgroundColor3 = Color3.fromRGB(255,107,107); KeyFrame.BorderSizePixel=0; KeyFrame.Visible = not KeySystem.Activated; KeyFrame.Parent = ScreenGui
local kLabel = Instance.new("TextLabel", KeyFrame); kLabel.Size = UDim2.new(1,0,0,30); kLabel.BackgroundTransparency=0.3; kLabel.Text = "🔐 Активация ключа"; kLabel.TextColor3=Color3.fromRGB(255,255,255); kLabel.Font=Enum.Font.GothamBold
local kInput = Instance.new("TextBox", KeyFrame); kInput.Size = UDim2.new(1,-20,0,28); kInput.Position = UDim2.new(0,10,0,36); kInput.PlaceholderText = "Введите ключ..."; kInput.ClearTextOnFocus=false
local kStatus = Instance.new("TextLabel", KeyFrame); kStatus.Size = UDim2.new(1,-20,0,20); kStatus.Position = UDim2.new(0,10,0,68); kStatus.BackgroundTransparency=1; kStatus.Text = "Введите ключ для активации"
local kBtn = Instance.new("TextButton", KeyFrame); kBtn.Size = UDim2.new(0,120,0,26); kBtn.Position = UDim2.new(0.5,-60,1,-36); kBtn.Text = "Активировать"; kBtn.Font=Enum.Font.GothamBold
kBtn.MouseButton1Click:Connect(function()
    local valid, msg = KeySystem:ValidateKey(kInput.Text)
    if valid then kStatus.Text = "✅ "..msg; kStatus.TextColor3=Color3.fromRGB(0,255,0); SaveKey(kInput.Text); wait(0.8); KeyFrame.Visible=false; MainToggle.Visible=true
    else kStatus.Text = "❌ "..tostring(msg); kStatus.TextColor3=Color3.fromRGB(255,0,0) end
end)

-- Build menu controls
MakeSection("Основные")
MakeToggle("Auto Farm", "AutoFarm")
MakeToggle("Auto Attack", "AutoAttack")
MakeToggle("ESP", "ESP")
MakeToggle("No Clip", "NoClip")
MakeToggle("Infinite Jump", "InfiniteJump")

MakeSection("Перемещение")
MakeSlider("WalkSpeed", "WalkSpeed", 8, 100, 1)
MakeSlider("JumpPower", "JumpPower", 30, 200, 1)

MakeSection("Aimbot")
MakeToggle("Aimbot", "Aimbot")
MakeSlider("Aimbot FOV", "AimbotFOV", 20, 500, 5)
MakeSlider("Aimbot Smooth", "AimbotSmoothing", 0, 1, 0.05)
MakeSlider("Aimbot Range", "AimbotRange", 50, 800, 10)

-- Toggle behavior
MainToggle.MouseButton1Click:Connect(function()
    if not KeySystem.Activated then KeyFrame.Visible = true; return end
    Menu.Visible = not Menu.Visible
    MainToggle.BackgroundColor3 = Menu.Visible and Color3.fromRGB(46,213,115) or Color3.fromRGB(255,107,107)
end)

-- Keybind: Insert to toggle
UserInputService.InputBegan:Connect(function(inp, processed)
    if not processed and inp.KeyCode == Enum.KeyCode.Insert then
        Menu.Visible = not Menu.Visible
        MainToggle.BackgroundColor3 = Menu.Visible and Color3.fromRGB(46,213,115) or Color3.fromRGB(255,107,107)
    end
end)

print("Lost Frontier Cheat загружен! Используй меню для настройки. ")
