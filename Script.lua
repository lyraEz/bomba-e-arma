local StarterGui = game:GetService("StarterGui")  
local Players = game:GetService("Players")  
local UserInputService = game:GetService("UserInputService")  
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

local GUN_KEYBIND = Enum.KeyCode.F
local BOMB_KEYBIND = Enum.KeyCode.E
local BOMB_COOLDOWN = 23
local JUMP_POWER_MULTIPLIER = 1.02

local GUN_NAMES = {"gun", "arma", "weapon", "pistol", "rifle", "shotgun", "blaster"}
local BOMB_NAMES = {"fakebomb", "bomba", "bomb", "explosive", "explosivo", "tnt", "c4", "dynamite"}

local function nameMatchesAny(toolName, nameList)
    local lowerName = toolName:lower()
    for _, name in ipairs(nameList) do
        if lowerName:find(name) then
            return true
        end
    end
    return false
end

local function findGun()
    local player = Players.LocalPlayer  
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    if not backpack or not character then
        return nil
    end

    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and nameMatchesAny(tool.Name, GUN_NAMES) then
            return tool
        end
    end

    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") and nameMatchesAny(tool.Name, GUN_NAMES) then
            return tool
        end
    end

    return nil
end

local function findBomb()
    local player = Players.LocalPlayer  
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character

    if not backpack or not character then
        return nil
    end

    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and nameMatchesAny(tool.Name, BOMB_NAMES) then
            return tool
        end
    end

    for _, tool in pairs(character:GetChildren()) do
        if tool:IsA("Tool") and nameMatchesAny(tool.Name, BOMB_NAMES) then
            return tool
        end
    end

    return nil
end

local lastExplosionTime = 0
local bombJustExploded = false

local function isBombInCooldown()
    local player = Players.LocalPlayer
    if not player then return true end
    
    if bombJustExploded then
        return true
    end
    
    if os.time() - lastExplosionTime < BOMB_COOLDOWN then
        return true
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return true end
    
    local bombFound = false
    local character = player.Character
    
    if character then
        for _, item in pairs(character:GetChildren()) do
            if item:IsA("Tool") and nameMatchesAny(item.Name, BOMB_NAMES) then
                bombFound = true
                
                if item.Parent == character then
                    local canUse = true
                    if item:FindFirstChild("InCooldown") or 
                       item:GetAttribute("Cooldown") or 
                       (item:IsA("Tool") and not item.Enabled) then
                        canUse = false
                    end
                    
                    if not canUse then
                        return true
                    end
                end
            end
        end
    end
    
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and nameMatchesAny(item.Name, BOMB_NAMES) then
            bombFound = true
            
            if item:FindFirstChild("InCooldown") or 
               item:GetAttribute("Cooldown") or 
               (item:IsA("Tool") and not item.Enabled) then
                return true
            end
        end
    end
    
    if not bombFound and lastExplosionTime > 0 then
        return true
    end
    
    return false
end

local function detectExplosion()
    workspace.ChildAdded:Connect(function(child)
        if child:IsA("Explosion") then
            lastExplosionTime = os.time()
            bombJustExploded = true
            
            task.delay(0.5, function()
                bombJustExploded = false
            end)
        end
    end)
    
    local player = Players.LocalPlayer
    if player then
        local function setupHumanoidDiedConnection(character)
            if not character then return end
            
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.Died:Connect(function()
                    resetBombCooldown()
                end)
            end
        end
        
        setupHumanoidDiedConnection(player.Character)
        player.CharacterAdded:Connect(setupHumanoidDiedConnection)
    end
end

local function quickUseGun()
    local player = Players.LocalPlayer  
    local character = player.Character  
    if character then  
        local backpack = player:WaitForChild("Backpack")  
        local gunTool = findGun()

        if gunTool then  
            local wasEquipped = (gunTool.Parent == character)

            if not wasEquipped then
                gunTool.Parent = character
                task.wait(0.05)
            end

            VirtualUser:Button1Down(Vector2.new(0, 0))  
            VirtualUser:Button1Up(Vector2.new(0, 0))
            task.wait(0.05)

            if not wasEquipped then
                gunTool.Parent = backpack
            end
        end
    end  
end

local bombCooldownActive = false
local bombCooldownEndTime = 0

local function quickUseBomb()
    local player = Players.LocalPlayer  
    local character = player.Character  
    
    if isBombInCooldown() then
        if not bombCooldownActive then
            bombCooldownActive = true
            bombCooldownEndTime = os.time() + BOMB_COOLDOWN
        end
        return
    end
    
    if character and not bombCooldownActive then  
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then
            return
        end
        
        local backpack = player:WaitForChild("Backpack")  
        local bombTool = findBomb()

        if bombTool then  
            local wasEquipped = (bombTool.Parent == character)

            bombCooldownActive = true
            bombCooldownEndTime = os.time() + BOMB_COOLDOWN

            if not wasEquipped then
                bombTool.Parent = character
                task.wait(0.05)
            end

            VirtualUser:Button1Down(Vector2.new(0, 0))  
            VirtualUser:Button1Up(Vector2.new(0, 0))
            
            task.wait(0.05)
            
            task.spawn(function()
                local currentState = humanoid:GetState()
                
                local originalJumpPower = humanoid.JumpPower
                local originalJumpHeight = humanoid.JumpHeight
                local originalGravity = workspace.Gravity
                
                pcall(function()
                    humanoid.JumpPower = originalJumpPower * JUMP_POWER_MULTIPLIER
                    
                    workspace.Gravity = workspace.Gravity * 0.95
                    
                    humanoid:ChangeState(Enum.HumanoidStateType.Landed)
                    task.wait(0.01)
                    
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    humanoid.Jump = true
                    
                    task.wait(0.2)
                    
                    humanoid.JumpPower = originalJumpPower
                    workspace.Gravity = originalGravity
                end)
            end)

            task.wait(0.05)

            if not wasEquipped then
                bombTool.Parent = backpack
            end
        end
    end  
end

local function createMobileButtons()  
    local screenGui = Instance.new("ScreenGui")  
    screenGui.Name = "DualEquipGui"  
    screenGui.ResetOnSpawn = false  
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling  

    local function createRoundedCorner(parent, radius)
        local uiCorner = Instance.new("UICorner")
        uiCorner.CornerRadius = UDim.new(0, radius)
        uiCorner.Parent = parent
        return uiCorner
    end
    
    local function styleButton(button, color, text)
        button.BackgroundTransparency = 0.8
        button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        button.BorderSizePixel = 2
        button.BorderColor3 = Color3.fromRGB(50, 50, 50)
        
        local border = Instance.new("Frame")
        border.Name = "ColorBorder"
        border.Size = UDim2.new(1, -10, 1, -10)
        border.Position = UDim2.new(0, 5, 0, 5)
        border.BackgroundColor3 = color
        border.BackgroundTransparency = 0.3
        border.BorderSizePixel = 0
        border.ZIndex = 0
        createRoundedCorner(border, 12)
        border.Parent = button
        
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 45
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
        })
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.9)
        })
        gradient.Parent = border
        
        button.Text = text
        button.TextSize = 24
        button.Font = Enum.Font.GothamBold
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.ZIndex = 2
        
        local textStroke = Instance.new("UIStroke")
        textStroke.Thickness = 1.5
        textStroke.Color = Color3.fromRGB(0, 0, 0)
        textStroke.Transparency = 0.3
        textStroke.Parent = button
        
        createRoundedCorner(button, 15)
        
        return button
    end
    
    local function styleKeybindButton(button, color, text)
        button.BackgroundTransparency = 0.7
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        button.BorderSizePixel = 1
        button.BorderColor3 = Color3.fromRGB(60, 60, 60)
        
        local border = Instance.new("Frame")
        border.Name = "ColorBorder"
        border.Size = UDim2.new(1, -6, 1, -6)
        border.Position = UDim2.new(0, 3, 0, 3)
        border.BackgroundColor3 = color
        border.BackgroundTransparency = 0.5
        border.BorderSizePixel = 0
        border.ZIndex = 0
        createRoundedCorner(border, 8)
        border.Parent = button
        
        button.Text = text
        button.TextSize = 16
        button.Font = Enum.Font.GothamSemibold
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.ZIndex = 2
        
        createRoundedCorner(button, 10)
        
        return button
    end

    local gunButton = Instance.new("TextButton")  
    gunButton.Name = "GunButton"  
    gunButton.Size = UDim2.new(0, 110, 0, 110)  
    gunButton.Position = UDim2.new(0.8, 0, 0.7, 0)  
    styleButton(gunButton, Color3.fromRGB(220, 60, 60), "Arma")
    gunButton.Parent = screenGui  

    local bombButton = Instance.new("TextButton")  
    bombButton.Name = "BombButton"  
    bombButton.Size = UDim2.new(0, 110, 0, 110)  
    bombButton.Position = UDim2.new(0.65, 0, 0.7, 0)  
    styleButton(bombButton, Color3.fromRGB(60, 60, 220), "Bomba")
    bombButton.Parent = screenGui
    
    local bombCooldownLabel = Instance.new("TextLabel")
    bombCooldownLabel.Name = "BombCooldownLabel"
    bombCooldownLabel.Size = UDim2.new(0, 110, 0, 26)
    bombCooldownLabel.Position = UDim2.new(0.65, 0, 0.81, 0)
    bombCooldownLabel.Text = ""
    bombCooldownLabel.TextSize = 18
    bombCooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    bombCooldownLabel.Font = Enum.Font.GothamBold
    bombCooldownLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    bombCooldownLabel.BackgroundTransparency = 0.6
    bombCooldownLabel.BorderSizePixel = 0
    createRoundedCorner(bombCooldownLabel, 8)
    
    local cooldownStroke = Instance.new("UIStroke")
    cooldownStroke.Thickness = 1
    cooldownStroke.Color = Color3.fromRGB(0, 0, 0)
    cooldownStroke.Transparency = 0.2
    cooldownStroke.Parent = bombCooldownLabel
    
    bombCooldownLabel.Visible = false
    bombCooldownLabel.Parent = screenGui

    local gunKeybindButton = Instance.new("TextButton")
    gunKeybindButton.Name = "GunKeybindButton"
    gunKeybindButton.Size = UDim2.new(0, 110, 0, 34)
    gunKeybindButton.Position = UDim2.new(0.8, 0, 0.64, 0)
    styleKeybindButton(gunKeybindButton, Color3.fromRGB(220, 60, 60), "Tecla: F")
    gunKeybindButton.Parent = screenGui

    local bombKeybindButton = Instance.new("TextButton")
    bombKeybindButton.Name = "BombKeybindButton"
    bombKeybindButton.Size = UDim2.new(0, 110, 0, 34)
    bombKeybindButton.Position = UDim2.new(0.65, 0, 0.64, 0)
    styleKeybindButton(bombKeybindButton, Color3.fromRGB(60, 60, 220), "Tecla: E")
    bombKeybindButton.Parent = screenGui

    local function makeButtonDraggable(button, keybindButton)  
        local dragging = false  
        local dragStart  
        local startPos  

        button.InputBegan:Connect(function(input)  
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then  
                dragging = true  
                dragStart = input.Position  
                startPos = button.Position  
            end  
        end)  

        button.InputChanged:Connect(function(input)  
            if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then  
                local delta = input.Position - dragStart  
                button.Position = UDim2.new(  
                    startPos.X.Scale,  
                    startPos.X.Offset + delta.X,  
                    startPos.Y.Scale,  
                    startPos.Y.Offset + delta.Y  
                )
                keybindButton.Position = UDim2.new(
                    button.Position.X.Scale,
                    button.Position.X.Offset,
                    button.Position.Y.Scale - 0.05,
                    button.Position.Y.Offset
                )
            end  
        end)  

        button.InputEnded:Connect(function(input)  
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then  
                dragging = false  
            end  
        end)  
    end

    makeButtonDraggable(gunButton, gunKeybindButton)
    makeButtonDraggable(bombButton, bombKeybindButton)

    gunButton.Activated:Connect(quickUseGun)
    bombButton.Activated:Connect(quickUseBomb)

    local currentGunKeybind = GUN_KEYBIND
    local currentBombKeybind = BOMB_KEYBIND

    local function updateGunKeybindText()
        gunKeybindButton.Text = "Tecla: " .. currentGunKeybind.Name
    end

    local function updateBombKeybindText()
        bombKeybindButton.Text = "Tecla: " .. currentBombKeybind.Name
    end

    gunKeybindButton.Activated:Connect(function()
        local listening = true
        gunKeybindButton.Text = "Pressione uma tecla..."

        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard and listening then
                currentGunKeybind = input.KeyCode
                updateGunKeybindText()
                listening = false
                connection:Disconnect()
            end
        end)

        task.delay(5, function()
            if listening then
                listening = false
                updateGunKeybindText()
                if connection.Connected then
                    connection:Disconnect()
                end
            end
        end)
    end)

    bombKeybindButton.Activated:Connect(function()
        local listening = true
        bombKeybindButton.Text = "Pressione uma tecla..."

        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard and listening then
                currentBombKeybind = input.KeyCode
                updateBombKeybindText()
                listening = false
                connection:Disconnect()
            end
        end)

        task.delay(5, function()
            if listening then
                listening = false
                updateBombKeybindText()
                if connection.Connected then
                    connection:Disconnect()
                end
            end
        end)
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == currentGunKeybind then
                quickUseGun()
            elseif input.KeyCode == currentBombKeybind then
                quickUseBomb()
            end
        end
    end)

    return screenGui  
end  

local function updateBombCooldown()
    local player = Players.LocalPlayer
    if not player then return end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local dualEquipGui = playerGui:FindFirstChild("DualEquipGui")
    if not dualEquipGui then return end
    
    local bombButton = dualEquipGui:FindFirstChild("BombButton")
    local cooldownLabel = dualEquipGui:FindFirstChild("BombCooldownLabel")
    
    if not bombButton or not cooldownLabel then return end
    
    RunService.Heartbeat:Connect(function()
        if isBombInCooldown() and not bombCooldownActive then
            bombCooldownActive = true
            bombCooldownEndTime = os.time() + BOMB_COOLDOWN
        end
        
        if bombCooldownActive then
            local timeLeft = bombCooldownEndTime - os.time()
            
            if timeLeft <= 0 then
                if not isBombInCooldown() then
                    bombCooldownActive = false
                    cooldownLabel.Visible = false
                    local border = bombButton:FindFirstChild("ColorBorder")
                    if border then
                        border.BackgroundColor3 = Color3.fromRGB(60, 60, 220)
                    end
                else
                    bombCooldownEndTime = os.time() + 1
                end
            else
                cooldownLabel.Visible = true
                local secondsText = math.floor(timeLeft) .. "s"
                cooldownLabel.Text = secondsText
                
                local border = bombButton:FindFirstChild("ColorBorder")
                if border then
                    border.BackgroundColor3 = Color3.fromRGB(70, 70, 140)
                end
                
                cooldownLabel.Position = UDim2.new(
                    bombButton.Position.X.Scale,
                    bombButton.Position.X.Offset,
                    bombButton.Position.Y.Scale + 0.11,
                    bombButton.Position.Y.Offset
                )
            end
        end
    end)
    
    if player.Character then
        local lastPosition = player.Character:GetPrimaryPartCFrame().Position
        local teleportThreshold = 999
        
        RunService.Heartbeat:Connect(function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local currentPosition = player.Character:GetPrimaryPartCFrame().Position
                local distance = (currentPosition - lastPosition).Magnitude
                
                if distance > teleportThreshold then
                    resetBombCooldown()
                end
                
                lastPosition = currentPosition
            end
        end)
    end
end

local function resetBombCooldown()
    bombCooldownActive = false
    bombCooldownEndTime = 0
    
    -- Reset visual da pra tirar depois
    task.spawn(function()
        local player = Players.LocalPlayer
        if player then
            local playerGui = player:FindFirstChild("PlayerGui")
            if playerGui then
                local dualEquipGui = playerGui:FindFirstChild("DualEquipGui")
                if dualEquipGui then
                    local bombButton = dualEquipGui:FindFirstChild("BombButton")
                    local cooldownLabel = dualEquipGui:FindFirstChild("BombCooldownLabel")
                    
                    if bombButton and cooldownLabel then
                        cooldownLabel.Visible = false
                        local border = bombButton:FindFirstChild("ColorBorder")
                        if border then
                            border.BackgroundColor3 = Color3.fromRGB(60, 60, 220)
                        end
                    end
                end
            end
        end
    end)
end

local function onPlayerAdded(player)  
    if player:IsA("Player") then  
        local gui = createMobileButtons()  
        gui.Parent = player:WaitForChild("PlayerGui")  
        
        if player == Players.LocalPlayer then
            player.CharacterAdded:Connect(function(character)  
                wait(0.001)  
                if gui.Parent ~= player.PlayerGui then  
                    gui.Parent = player:WaitForChild("PlayerGui")  
                end
                
                resetBombCooldown()
                
                character.AncestryChanged:Connect(function(_, newParent)
                    if newParent == nil then
                        resetBombCooldown()
                    end
                end)
            end)
            
            updateBombCooldown()
            detectExplosion()
        else
            player.CharacterAdded:Connect(function()  
                wait(0.001)  
                if gui.Parent ~= player.PlayerGui then  
                    gui.Parent = player:WaitForChild("PlayerGui")  
                end  
            end)
        end
    end  
end  

for _, player in ipairs(Players:GetPlayers()) do  
    onPlayerAdded(player)  
end  

Players.PlayerAdded:Connect(onPlayerAdded)

local message = Instance.new("Message")
message.Text = "Script com dois botões inicializado! Use F para arma e E para bomba."
message.Parent = game.Workspace
task.wait(2)
message:Destroy()
