--[[
    Lost Frontier Delta Script для iPhone
    Версия: 1.1
    Использование: loadstring(game:HttpGet("URL",true))()
    Система ключей активации
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Система ключей
local KeySystem = {}
KeySystem.Activated = false
KeySystem.MasterKey = "KOLYA-MASTER-2024-INFINITE" -- Твой бесконечный ключ
KeySystem.ValidKeys = {} -- Временные ключи будут здесь
KeySystem.APIUrl = "https://your-api-server.com/api/validate" -- ЗАМЕНИ НА СВОЙ API
KeySystem.UserId = LocalPlayer.UserId

-- Проверка ключа через веб-API
function KeySystem:ValidateKeyOnline(InputKey)
    local success, response = pcall(function()
        local url = self.APIUrl .. "?key=" .. InputKey .. "&userid=" .. self.UserId
        return HttpService:GetAsync(url, true)
    end)
    
    if success and response then
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
    
    return false, nil -- Если онлайн проверка не удалась, пробуем локально
end

-- Функция проверки ключа
function KeySystem:ValidateKey(InputKey)
    if not InputKey or InputKey == "" then
        return false, "Ключ не введен"
    end
    
    -- Проверка мастер-ключа (бесконечный)
    if InputKey == self.MasterKey then
        self.Activated = true
        return true, "Мастер-ключ активирован! Доступ навсегда."
    end
    
    -- Сначала пробуем проверить через веб-API
    local onlineValid, onlineMsg = self:ValidateKeyOnline(InputKey)
    if onlineValid then
        return true, onlineMsg
    end
    
    -- Если онлайн проверка не удалась, проверяем локально
    local CurrentTime = os.time()
    for _, KeyData in pairs(self.ValidKeys) do
        if KeyData.Key == InputKey then
            if CurrentTime < KeyData.ExpireTime then
                self.Activated = true
                local HoursLeft = math.floor((KeyData.ExpireTime - CurrentTime) / 3600)
                return true, "Ключ активирован! Осталось: " .. HoursLeft .. " часов"
            else
                return false, "Ключ истек"
            end
        end
    end
    
    return false, "Неверный ключ"
end

-- Функция генерации временного ключа (24 часа)
function KeySystem:GenerateTempKey()
    local Key = HttpService:GenerateGUID(false):sub(1, 20):upper()
    local ExpireTime = os.time() + (24 * 3600) -- 24 часа
    
    table.insert(self.ValidKeys, {
        Key = Key,
        ExpireTime = ExpireTime
    })
    
    return Key, ExpireTime
end

-- Проверка сохраненного ключа
local function CheckSavedKey()
    local success, saved = pcall(function()
        if readfile then
            return game:GetService("HttpService"):JSONDecode(readfile("LostFrontier_Key.txt"))
        end
    end)
    
    if success and saved then
        local valid, msg = KeySystem:ValidateKey(saved.Key)
        if valid then
            KeySystem.Activated = true
            return true
        end
    end
    return false
end

-- Сохранение ключа
local function SaveKey(Key)
    pcall(function()
        if writefile then
            writefile("LostFrontier_Key.txt", game:GetService("HttpService"):JSONEncode({Key = Key}))
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(NewCharacter)
    Character = NewCharacter
    HumanoidRootPart = NewCharacter:WaitForChild("HumanoidRootPart")
    Humanoid = NewCharacter:WaitForChild("Humanoid")
end)

local Settings = {
    AutoFarm = false,
    AutoAttack = false,
    ESP = false,
    ESPDistance = 500,
    AutoCollect = false,
    TeleportToResources = false,
    WalkSpeed = 20,
    JumpPower = 50,
    NoClip = false,
    InfiniteJump = false,
    AutoSell = false,
    AutoBuild = false,
}

-- Проверка сохраненного ключа при запуске
if not CheckSavedKey() then
    KeySystem.Activated = false
end

local DrawingSupported = pcall(function()
    local test = Drawing.new("Square")
    test:Remove()
end)

local ESPLibrary = {}
ESPLibrary.Objects = {}

function ESPLibrary:CreateESP(Object, Color, Name)
    if not Object or not Object:FindFirstChild("HumanoidRootPart") then return end
    if not DrawingSupported then 
        warn("Drawing API не поддерживается в этом executor!")
        return 
    end
    
    local ESP = {
        Object = Object,
        Name = Name or Object.Name,
        Color = Color or Color3.fromRGB(255, 0, 0),
        Drawing = {},
    }
    
    ESP.Drawing.Box = Drawing.new("Square")
    ESP.Drawing.Box.Visible = false
    ESP.Drawing.Box.Color = ESP.Color
    ESP.Drawing.Box.Thickness = 2
    ESP.Drawing.Box.Transparency = 1
    ESP.Drawing.Box.Filled = false
    
    ESP.Drawing.Name = Drawing.new("Text")
    ESP.Drawing.Name.Visible = false
    ESP.Drawing.Name.Color = ESP.Color
    ESP.Drawing.Name.Size = 14
    ESP.Drawing.Name.Font = 2
    ESP.Drawing.Name.Outline = true
    ESP.Drawing.Name.OutlineColor = Color3.new(0, 0, 0)
    
    ESP.Drawing.Distance = Drawing.new("Text")
    ESP.Drawing.Distance.Visible = false
    ESP.Drawing.Distance.Color = ESP.Color
    ESP.Drawing.Distance.Size = 12
    ESP.Drawing.Distance.Font = 2
    ESP.Drawing.Distance.Outline = true
    ESP.Drawing.Distance.OutlineColor = Color3.new(0, 0, 0)
    
    ESP.Drawing.HealthBar = Drawing.new("Square")
    ESP.Drawing.HealthBar.Visible = false
    ESP.Drawing.HealthBar.Color = Color3.fromRGB(0, 255, 0)
    ESP.Drawing.HealthBar.Thickness = 2
    ESP.Drawing.HealthBar.Transparency = 1
    ESP.Drawing.HealthBar.Filled = true
    
    table.insert(ESPLibrary.Objects, ESP)
    return ESP
end

function ESPLibrary:UpdateESP(ESP)
    if not DrawingSupported then return end
    if not ESP.Object or not ESP.Object.Parent then
        ESPLibrary:RemoveESP(ESP)
        return
    end
    
    local HumanoidRootPart = ESP.Object:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return end
    
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local Camera = Workspace.CurrentCamera
    local Vector, OnScreen = Camera:WorldToViewportPoint(HumanoidRootPart.Position)
    local Distance = (HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
    
    if Distance > Settings.ESPDistance then
        if ESP.Drawing.Box then ESP.Drawing.Box.Visible = false end
        if ESP.Drawing.Name then ESP.Drawing.Name.Visible = false end
        if ESP.Drawing.Distance then ESP.Drawing.Distance.Visible = false end
        if ESP.Drawing.HealthBar then ESP.Drawing.HealthBar.Visible = false end
        return
    end
    
    if OnScreen then
        local Size = Vector3.new(4, 5, 0)
        local CF = HumanoidRootPart.CFrame
        local SizeX, SizeY = Size.X / 2, Size.Y / 2
        
        local TopLeft = Camera:WorldToViewportPoint((CF * CFrame.new(-SizeX, SizeY, 0)).Position)
        local TopRight = Camera:WorldToViewportPoint((CF * CFrame.new(SizeX, SizeY, 0)).Position)
        local BottomLeft = Camera:WorldToViewportPoint((CF * CFrame.new(-SizeX, -SizeY, 0)).Position)
        local BottomRight = Camera:WorldToViewportPoint((CF * CFrame.new(SizeX, -SizeY, 0)).Position)
        
        if ESP.Drawing.Box then
            local BoxSize = Vector2.new(
                math.abs(TopRight.X - TopLeft.X),
                math.abs(BottomLeft.Y - TopLeft.Y)
            )
            ESP.Drawing.Box.Position = Vector2.new(TopLeft.X, TopLeft.Y)
            ESP.Drawing.Box.Size = BoxSize
            ESP.Drawing.Box.Visible = true
        end
        
        if ESP.Drawing.Name then
            ESP.Drawing.Name.Position = Vector2.new(Vector.X, Vector.Y - 30)
            ESP.Drawing.Name.Text = ESP.Name
            ESP.Drawing.Name.Visible = true
        end
        
        if ESP.Drawing.Distance then
            ESP.Drawing.Distance.Position = Vector2.new(Vector.X, Vector.Y - 15)
            ESP.Drawing.Distance.Text = math.floor(Distance) .. " studs"
            ESP.Drawing.Distance.Visible = true
        end
        
        local Humanoid = ESP.Object:FindFirstChild("Humanoid")
        if Humanoid and ESP.Drawing.HealthBar then
            local HealthPercent = Humanoid.Health / Humanoid.MaxHealth
            local BarSize = 50
            local BarHeight = 4
            
            ESP.Drawing.HealthBar.Size = Vector2.new(BarSize * HealthPercent, BarHeight)
            ESP.Drawing.HealthBar.Position = Vector2.new(Vector.X - BarSize / 2, Vector.Y + 20)
            ESP.Drawing.HealthBar.Color = Color3.fromRGB(255 * (1 - HealthPercent), 255 * HealthPercent, 0)
            ESP.Drawing.HealthBar.Visible = true
        end
    else
        if ESP.Drawing.Box then ESP.Drawing.Box.Visible = false end
        if ESP.Drawing.Name then ESP.Drawing.Name.Visible = false end
        if ESP.Drawing.Distance then ESP.Drawing.Distance.Visible = false end
        if ESP.Drawing.HealthBar then ESP.Drawing.HealthBar.Visible = false end
    end
end

function ESPLibrary:RemoveESP(ESP)
    for i, v in pairs(ESPLibrary.Objects) do
        if v == ESP then
            table.remove(ESPLibrary.Objects, i)
            break
        end
    end
    
    for _, Drawing in pairs(ESP.Drawing) do
        Drawing:Remove()
    end
end

function ESPLibrary:ClearAll()
    for _, ESP in pairs(ESPLibrary.Objects) do
        ESPLibrary:RemoveESP(ESP)
    end
end

function FindResources()
    local Resources = {}
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Part") or obj:IsA("MeshPart") then
            local Name = obj.Name:lower()
            if Name:find("wood") or Name:find("stone") or Name:find("ore") or 
               Name:find("resource") or Name:find("tree") or Name:find("rock") then
                table.insert(Resources, obj)
            end
        end
    end
    
    return Resources
end

function FindEnemies()
    local Enemies = {}
    
    for _, Player in pairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local Humanoid = Player.Character:FindFirstChild("Humanoid")
            if Humanoid and Humanoid.Health > 0 then
                table.insert(Enemies, Player.Character)
            end
        end
    end
    
    return Enemies
end

function TeleportTo(Position)
    if HumanoidRootPart then
        HumanoidRootPart.CFrame = CFrame.new(Position)
    end
end

function GetNearestObject(Objects)
    if not HumanoidRootPart then return nil, math.huge end
    
    local Nearest = nil
    local NearestDistance = math.huge
    
    for _, Obj in pairs(Objects) do
        if Obj and Obj.Parent then
            local Part = Obj:FindFirstChild("HumanoidRootPart") or (Obj:IsA("BasePart") and Obj)
            if Part then
                local Distance = (Part.Position - HumanoidRootPart.Position).Magnitude
                if Distance < NearestDistance then
                    NearestDistance = Distance
                    Nearest = Obj
                end
            end
        end
    end
    
    return Nearest, NearestDistance
end

local AutoFarmConnection
function StartAutoFarm()
    if AutoFarmConnection then return end
    
    AutoFarmConnection = RunService.Heartbeat:Connect(function()
        if not Settings.AutoFarm then
            AutoFarmConnection:Disconnect()
            AutoFarmConnection = nil
            return
        end
        
        local Resources = FindResources()
        local Nearest, Distance = GetNearestObject(Resources)
        
        if Nearest then
            local Part = Nearest:FindFirstChild("HumanoidRootPart") or Nearest
            if Part then
                if Distance > 10 then
                    TeleportTo(Part.Position)
                end
                
                if Distance < 5 then
                    local Prompt = Nearest:FindFirstChildOfClass("ProximityPrompt")
                    if Prompt then
                        fireproximityprompt(Prompt)
                    end
                end
            end
        end
    end)
end

local AutoAttackConnection
function StartAutoAttack()
    if AutoAttackConnection then return end
    
    AutoAttackConnection = RunService.Heartbeat:Connect(function()
        if not Settings.AutoAttack then
            AutoAttackConnection:Disconnect()
            AutoAttackConnection = nil
            return
        end
        
        local Enemies = FindEnemies()
        local Nearest, Distance = GetNearestObject(Enemies)
        
        if Nearest and Nearest:FindFirstChild("HumanoidRootPart") then
            local Target = Nearest.HumanoidRootPart
            
            if Distance < 50 then
                local Camera = Workspace.CurrentCamera
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, Target.Position)
                
                if Distance < 10 then
                    local Tool = Character:FindFirstChildOfClass("Tool")
                    if Tool then
                        Tool:Activate()
                    end
                end
            end
        end
    end)
end

local ESPConnection
function StartESP()
    if ESPConnection then return end
    
    ESPConnection = RunService.RenderStepped:Connect(function()
        if not Settings.ESP then
            ESPLibrary:ClearAll()
            ESPConnection:Disconnect()
            ESPConnection = nil
            return
        end
        
        for _, Player in pairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local Humanoid = Player.Character:FindFirstChild("Humanoid")
                if Humanoid and Humanoid.Health > 0 then
                    local Found = false
                    for _, ESP in pairs(ESPLibrary.Objects) do
                        if ESP.Object == Player.Character then
                            Found = true
                            ESPLibrary:UpdateESP(ESP)
                            break
                        end
                    end
                    if not Found then
                        local ESP = ESPLibrary:CreateESP(Player.Character, Color3.fromRGB(255, 0, 0), Player.Name)
                        ESPLibrary:UpdateESP(ESP)
                    end
                end
            end
        end
        
        for _, ESP in pairs(ESPLibrary.Objects) do
            ESPLibrary:UpdateESP(ESP)
        end
    end)
end

local NoClipConnection
function StartNoClip()
    if NoClipConnection then return end
    
    NoClipConnection = RunService.Stepped:Connect(function()
        if not Settings.NoClip then
            NoClipConnection:Disconnect()
            NoClipConnection = nil
            return
        end
        
        if Character then
            for _, Part in pairs(Character:GetDescendants()) do
                if Part:IsA("BasePart") and Part.CanCollide then
                    Part.CanCollide = false
                end
            end
        end
    end)
end

UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump and Character and Humanoid then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local SpeedConnection
function StartSpeed()
    if SpeedConnection then return end
    
    SpeedConnection = RunService.Heartbeat:Connect(function()
        if Character and Humanoid then
            Humanoid.WalkSpeed = Settings.WalkSpeed
            Humanoid.JumpPower = Settings.JumpPower
        end
    end)
end
StartSpeed()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LostFrontierGUI"
ScreenGui.Parent = game:GetService("CoreGui")

-- Функция создания закругленных углов
local function AddRoundedCorners(Frame, CornerRadius)
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, CornerRadius)
    UICorner.Parent = Frame
    return UICorner
end

-- Функция создания градиента заката
local function AddSunsetGradient(Frame)
    local UIGradient = Instance.new("UIGradient")
    UIGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 107, 107)), -- Оранжево-красный
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 159, 64)), -- Оранжевый
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 206, 84)) -- Желтый
    })
    UIGradient.Rotation = 45
    UIGradient.Parent = Frame
    return UIGradient
end

-- Окно активации ключа с закатом
local KeyFrame = Instance.new("Frame")
KeyFrame.Name = "KeyActivation"
KeyFrame.Size = UDim2.new(0, 400, 0, 250)
KeyFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
KeyFrame.BackgroundColor3 = Color3.fromRGB(255, 107, 107)
KeyFrame.BorderSizePixel = 0
KeyFrame.Visible = not KeySystem.Activated
KeyFrame.ZIndex = 100
AddRoundedCorners(KeyFrame, 15)
AddSunsetGradient(KeyFrame)
KeyFrame.Parent = ScreenGui

-- Тень для KeyFrame
local KeyFrameShadow = Instance.new("Frame")
KeyFrameShadow.Size = KeyFrame.Size
KeyFrameShadow.Position = KeyFrame.Position
KeyFrameShadow.Position = KeyFrameShadow.Position + UDim2.new(0, 3, 0, 3)
KeyFrameShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
KeyFrameShadow.BackgroundTransparency = 0.7
KeyFrameShadow.BorderSizePixel = 0
KeyFrameShadow.ZIndex = 99
AddRoundedCorners(KeyFrameShadow, 15)
KeyFrameShadow.Parent = ScreenGui

local KeyTitle = Instance.new("TextLabel")
KeyTitle.Size = UDim2.new(1, 0, 0, 40)
KeyTitle.Position = UDim2.new(0, 0, 0, 0)
KeyTitle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
KeyTitle.BackgroundTransparency = 0.3
KeyTitle.Text = "🔐 Активация ключа"
KeyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyTitle.TextSize = 18
KeyTitle.Font = Enum.Font.GothamBold
AddRoundedCorners(KeyTitle, 15)
KeyTitle.Parent = KeyFrame

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(1, -20, 0, 35)
KeyInput.Position = UDim2.new(0, 10, 0, 60)
KeyInput.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.BackgroundTransparency = 0.9
KeyInput.BorderSizePixel = 0
KeyInput.Text = ""
KeyInput.PlaceholderText = "Введите ключ активации..."
KeyInput.PlaceholderColor3 = Color3.fromRGB(200, 200, 200)
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.TextSize = 14
KeyInput.Font = Enum.Font.Gotham
KeyInput.ClearTextOnFocus = false
AddRoundedCorners(KeyInput, 8)
KeyInput.Parent = KeyFrame

local KeyStatus = Instance.new("TextLabel")
KeyStatus.Size = UDim2.new(1, -20, 0, 30)
KeyStatus.Position = UDim2.new(0, 10, 0, 105)
KeyStatus.BackgroundTransparency = 1
KeyStatus.Text = "Введите ключ для активации скрипта"
KeyStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
KeyStatus.TextSize = 12
KeyStatus.Font = Enum.Font.Gotham
KeyStatus.TextWrapped = true
KeyStatus.Parent = KeyFrame

local ActivateButton = Instance.new("TextButton")
ActivateButton.Size = UDim2.new(0, 150, 0, 40)
ActivateButton.Position = UDim2.new(0.5, -75, 1, -50)
ActivateButton.BackgroundColor3 = Color3.fromRGB(46, 213, 115)
ActivateButton.Text = "Активировать"
ActivateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ActivateButton.TextSize = 14
ActivateButton.Font = Enum.Font.GothamBold
AddRoundedCorners(ActivateButton, 10)
ActivateButton.Parent = KeyFrame

ActivateButton.MouseButton1Click:Connect(function()
    local InputKey = KeyInput.Text
    local Valid, Message = KeySystem:ValidateKey(InputKey)
    
    if Valid then
        KeyStatus.Text = "✅ " .. Message
        KeyStatus.TextColor3 = Color3.fromRGB(0, 255, 0)
        SaveKey(InputKey)
        wait(1)
        KeyFrame.Visible = false
        ToggleButton.Visible = true
    else
        KeyStatus.Text = "❌ " .. Message
        KeyStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- Кнопка для открытия меню (для iPhone) с закатом
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "MenuToggle"
ToggleButton.Size = UDim2.new(0, 60, 0, 60)
ToggleButton.Position = UDim2.new(1, -70, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 107, 107)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "☰"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 24
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.ZIndex = 10
ToggleButton.Visible = KeySystem.Activated
AddRoundedCorners(ToggleButton, 30)
AddSunsetGradient(ToggleButton)
ToggleButton.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 450)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(255, 107, 107)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
AddRoundedCorners(MainFrame, 20)
AddSunsetGradient(MainFrame)
MainFrame.Parent = ScreenGui

-- Тень для MainFrame
local MainFrameShadow = Instance.new("Frame")
MainFrameShadow.Size = MainFrame.Size
MainFrameShadow.Position = MainFrame.Position
MainFrameShadow.Position = MainFrameShadow.Position + UDim2.new(0, 5, 0, 5)
MainFrameShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrameShadow.BackgroundTransparency = 0.6
MainFrameShadow.BorderSizePixel = 0
MainFrameShadow.ZIndex = MainFrame.ZIndex - 1
AddRoundedCorners(MainFrameShadow, 20)
MainFrameShadow.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 45)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Title.BackgroundTransparency = 0.4
Title.Text = "🌅 Lost Frontier Cheat"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
AddRoundedCorners(Title, 20)
Title.Parent = MainFrame

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Name = "ScrollingFrame"
ScrollingFrame.Size = UDim2.new(1, -20, 1, -50)
ScrollingFrame.Position = UDim2.new(0, 10, 0, 50)
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.ScrollBarThickness = 6
ScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 206, 84)
ScrollingFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = ScrollingFrame

function CreateToggle(Name, YPosition, Callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Name = Name .. "Toggle"
    ToggleFrame.Size = UDim2.new(1, 0, 0, 40)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleFrame.BackgroundTransparency = 0.85
    AddRoundedCorners(ToggleFrame, 10)
    ToggleFrame.Parent = ScrollingFrame
    
    local ToggleLabel = Instance.new("TextLabel")
    ToggleLabel.Name = "Label"
    ToggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    ToggleLabel.Position = UDim2.new(0, 10, 0, 0)
    ToggleLabel.BackgroundTransparency = 1
    ToggleLabel.Text = Name
    ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleLabel.TextSize = 15
    ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    ToggleLabel.Font = Enum.Font.GothamBold
    ToggleLabel.Parent = ToggleFrame
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "Button"
    ToggleButton.Size = UDim2.new(0, 70, 0, 30)
    ToggleButton.Position = UDim2.new(1, -80, 0.5, -15)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(149, 165, 166)
    ToggleButton.Text = "OFF"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 13
    ToggleButton.Font = Enum.Font.GothamBold
    AddRoundedCorners(ToggleButton, 8)
    ToggleButton.Parent = ToggleFrame
    
    ToggleButton.MouseButton1Click:Connect(function()
        local CurrentValue = Settings[Name]
        Settings[Name] = not CurrentValue
        ToggleButton.Text = Settings[Name] and "ON" or "OFF"
        ToggleButton.BackgroundColor3 = Settings[Name] and Color3.fromRGB(46, 213, 115) or Color3.fromRGB(149, 165, 166)
        if Callback then
            Callback(Settings[Name])
        end
    end)
end

CreateToggle("AutoFarm", 0, function(Value)
    if not KeySystem.Activated then
        KeyStatus.Text = "❌ Требуется активация ключа!"
        KeyStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
        KeyFrame.Visible = true
        return
    end
    Settings.AutoFarm = Value
    if Value then
        StartAutoFarm()
    end
end)

CreateToggle("AutoAttack", 0, function(Value)
    if not KeySystem.Activated then
        KeyStatus.Text = "❌ Требуется активация ключа!"
        KeyStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
        KeyFrame.Visible = true
        return
    end
    Settings.AutoAttack = Value
    if Value then
        StartAutoAttack()
    end
end)

CreateToggle("ESP", 0, function(Value)
    if not KeySystem.Activated then
        KeyStatus.Text = "❌ Требуется активация ключа!"
        KeyStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
        KeyFrame.Visible = true
        return
    end
    Settings.ESP = Value
    if Value then
        StartESP()
    else
        ESPLibrary:ClearAll()
    end
end)

CreateToggle("NoClip", 0, function(Value)
    if not KeySystem.Activated then
        KeyStatus.Text = "❌ Требуется активация ключа!"
        KeyStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
        KeyFrame.Visible = true
        return
    end
    Settings.NoClip = Value
    if Value then
        StartNoClip()
    end
end)

CreateToggle("InfiniteJump", 0, function(Value)
    if not KeySystem.Activated then
        KeyStatus.Text = "❌ Требуется активация ключа!"
        KeyStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
        KeyFrame.Visible = true
        return
    end
    Settings.InfiniteJump = Value
end)

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
end)

-- Кнопка для открытия/закрытия меню (для iPhone)
ToggleButton.MouseButton1Click:Connect(function()
    if not KeySystem.Activated then
        KeyFrame.Visible = true
        return
    end
    MainFrame.Visible = not MainFrame.Visible
    if MainFrame.Visible then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 150, 30)
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    end
end)

-- Также поддерживаем клавишу INSERT для тех, у кого есть клавиатура
UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if not GameProcessed and Input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
        if MainFrame.Visible then
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        else
            ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        end
    end
end)

if KeySystem.Activated then
    print("Lost Frontier Cheat загружен! Нажми кнопку ☰ в правом верхнем углу для открытия меню.")
else
    print("Lost Frontier Cheat загружен! Введите ключ активации для использования.")
end

