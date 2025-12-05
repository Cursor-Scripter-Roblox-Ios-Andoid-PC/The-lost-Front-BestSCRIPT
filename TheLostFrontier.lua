--[[
    Lost Frontier Delta Script для iPhone
    Версия: 1.0
    Использование: loadstring(game:HttpGet("URL",true))()
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

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
    WalkSpeed = 16,
    JumpPower = 50,
    NoClip = false,
    InfiniteJump = false,
    AutoSell = false,
    AutoBuild = false,
}

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

-- Кнопка для открытия меню (для iPhone)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "MenuToggle"
ToggleButton.Size = UDim2.new(0, 60, 0, 60)
ToggleButton.Position = UDim2.new(1, -70, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleButton.BorderSizePixel = 2
ToggleButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
ToggleButton.Text = "☰"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 24
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.ZIndex = 10
ToggleButton.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.Text = "Lost Frontier Cheat"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Name = "ScrollingFrame"
ScrollingFrame.Size = UDim2.new(1, -10, 1, -40)
ScrollingFrame.Position = UDim2.new(0, 5, 0, 35)
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.ScrollBarThickness = 5
ScrollingFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = ScrollingFrame

function CreateToggle(Name, YPosition, Callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Name = Name .. "Toggle"
    ToggleFrame.Size = UDim2.new(1, 0, 0, 30)
    ToggleFrame.BackgroundTransparency = 1
    ToggleFrame.Parent = ScrollingFrame
    
    local ToggleLabel = Instance.new("TextLabel")
    ToggleLabel.Name = "Label"
    ToggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    ToggleLabel.Position = UDim2.new(0, 0, 0, 0)
    ToggleLabel.BackgroundTransparency = 1
    ToggleLabel.Text = Name
    ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleLabel.TextSize = 14
    ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    ToggleLabel.Font = Enum.Font.Gotham
    ToggleLabel.Parent = ToggleFrame
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "Button"
    ToggleButton.Size = UDim2.new(0, 60, 0, 25)
    ToggleButton.Position = UDim2.new(1, -60, 0.5, -12.5)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    ToggleButton.Text = "OFF"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 12
    ToggleButton.Font = Enum.Font.Gotham
    ToggleButton.Parent = ToggleFrame
    
    ToggleButton.MouseButton1Click:Connect(function()
        local CurrentValue = Settings[Name]
        Settings[Name] = not CurrentValue
        ToggleButton.Text = Settings[Name] and "ON" or "OFF"
        ToggleButton.BackgroundColor3 = Settings[Name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(50, 50, 50)
        if Callback then
            Callback(Settings[Name])
        end
    end)
end

CreateToggle("AutoFarm", 0, function(Value)
    Settings.AutoFarm = Value
    if Value then
        StartAutoFarm()
    end
end)

CreateToggle("AutoAttack", 0, function(Value)
    Settings.AutoAttack = Value
    if Value then
        StartAutoAttack()
    end
end)

CreateToggle("ESP", 0, function(Value)
    Settings.ESP = Value
    if Value then
        StartESP()
    else
        ESPLibrary:ClearAll()
    end
end)

CreateToggle("NoClip", 0, function(Value)
    Settings.NoClip = Value
    if Value then
        StartNoClip()
    end
end)

CreateToggle("InfiniteJump", 0, function(Value)
    Settings.InfiniteJump = Value
end)

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 10)
end)

-- Кнопка для открытия/закрытия меню (для iPhone)
ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    if MainFrame.Visible then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
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

print("Lost Frontier Cheat загружен! Нажми кнопку ☰ в правом верхнем углу для открытия меню.")

