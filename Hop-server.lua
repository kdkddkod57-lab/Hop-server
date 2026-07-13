local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local isSafeToClear = false

-- 1. ระบบรัวกดปุ่ม K เพื่อข้ามหน้าโหลดเกม
task.spawn(function()
    print("⏳ เริ่มระบบกดปุ่ม K อัตโนมัติเพื่อข้ามหน้าโหลด...")
    local endTime = tick() + (getgenv().DelayBeforeFly or 20) + 5
    while tick() < endTime do
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.K, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.K, false, game)
        task.wait(0.2)
    end
    print("🛑 ข้ามหน้าโหลดเสร็จสิ้น")
end)

-- 2. ระบบลบต้นไม้แบบประหยัด CPU 
task.spawn(function()
    while task.wait(0.5) do
        if isSafeToClear then
            local gardensFolder = Workspace:FindFirstChild("Gardens")
            if gardensFolder then
                for _, plot in pairs(gardensFolder:GetChildren()) do
                    local plantsFolder = plot:FindFirstChild("Plants")
                    if plantsFolder then
                        local children = plantsFolder:GetChildren()
                        for i, plant in ipairs(children) do
                            if plant and plant.Parent then
                                plant.Parent = nil 
                                task.spawn(function()
                                    plant:Destroy()
                                end)
                                if i % 15 == 0 then
                                    task.wait()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ⚠️ [แก้ไขจุดสำคัญ] ระบบแก้บั๊ก Teleport Failed / Error Code 772 (ตรวจจับเพิ่มทั้งใน CoreGui และ PlayerGui ของเกม)
task.spawn(function()
    while task.wait(1) do
        -- แบบที่ 1: เช็คใน CoreGui (ของระบบ Roblox)
        local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if robloxPromptGui then
            local promptHolder = robloxPromptGui:FindFirstChild("promptOverlay") and robloxPromptGui.promptOverlay:FindFirstChild("ErrorPrompt")
            if promptHolder then
                local buttonLayout = promptHolder:FindFirstChild("ButtonLayout")
                local okButton = buttonLayout and buttonLayout:FindFirstChildWhichIsA("TextButton", true)
                
                if okButton and okButton.Visible then
                    print("⚠️ เจอหน้าต่าง Teleport Failed (CoreGui)! กำลังคลิกปุ่ม OK...")
                    local pos = okButton.AbsolutePosition + (okButton.AbsoluteSize / 2)
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                    task.wait(0.1)
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                    task.wait(1)
                    HopServer()
                end
            end
        end

        -- แบบที่ 2: เช็คใน PlayerGui (กรณีเป็น UI แจ้งเตือนของตัวเกมเองแบบในรูป)
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            -- สแกนหาหน้าต่างที่มีข้อความ Teleport Failed หรือ Error Code 772
            for _, gui in pairs(playerGui:GetDescendants()) do
                if gui:IsA("TextLabel") and (string.find(gui.Text, "Teleport Failed") or string.find(gui.Text, "772")) then
                    -- หาปุ่ม Ok หรือ Button ที่อยู่ในหน้าต่างนั้น
                    local frame = gui.Parent
                    if frame then
                        local okButton = frame:FindFirstChild("Ok") or frame:FindFirstChild("OK") or frame:FindFirstChildWhichIsA("TextButton", true)
                        if okButton and okButton.IsA("TextButton") and okButton.Visible then
                            print("⚠️ เจอหน้าต่าง Teleport Failed (Game UI)! กำลังคลิกปุ่ม OK อัตโนมัติ...")
                            local pos = okButton.AbsolutePosition + (okButton.AbsoluteSize / 2)
                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                            task.wait(0.1)
                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                            task.wait(1)
                            HopServer()
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- ฟังก์ชันสำหรับย้ายเซิร์ฟเวอร์
function HopServer()
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    
    if success and result then
        for _, Server in pairs(result.data) do
            if Server.playing < (Server.maxPlayers - 2) and Server.id ~= game.JobId then
                print("🔄 พบเซิร์ฟเวอร์ว่าง (ผู้เล่น: " .. Server.playing .. "/" .. Server.maxPlayers .. ") กำลังเดินทาง...")
                TeleportService:TeleportToPlaceInstance(game.PlaceId, Server.id, LocalPlayer)
                return
            end
        end
    end
    task.wait(1)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- ฟังก์ชันบินตามเป้าหมายแบบเรียลไทม์
local function FlyToTargetPart(targetPart)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp and targetPart and targetPart:IsA("BasePart") then
        local speed = getgenv().FlySpeed or 120 
        
        while targetPart and targetPart.Parent and (hrp.Position - targetPart.Position).Magnitude > 3 do
            local currentDist = (hrp.Position - targetPart.Position).Magnitude
            local duration = currentDist / speed
            
            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
            local targetCFrame = targetPart.CFrame * CFrame.new(0, 1.5, 0) 
            
            local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
            tween.Completed:Connect(function() tween:Destroy() end)
            tween:Play()
            
            task.wait(0.05)
            tween:Cancel() 
        end
    end
end

-- 3. ระบบหลัก
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    repeat task.wait(0.5) until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if getgenv().AutoFarm then
        print("⏳ [ระบบตรวจสอบความเสถียร] บังคับรอนิ่ง ๆ 7 วินาที เพื่อให้สัตว์เลี้ยงโหลดเสร็จ...")
        task.wait(7.0)
        
        local mapFolder = Workspace:WaitForChild("Map", 15)
        local targetPrompt = nil
        local promptParentPart = nil
        
        print("🎯 ครบ 7 วินาทีแล้ว เริ่มกระบวนการสแกนหาตัวสัตว์เลี้ยงเป้าหมายในแมพ...")
        if mapFolder then
            for _, obj in pairs(mapFolder:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local isTarget = false
                    local current = obj.Parent
                    while current and current ~= Workspace do
                        for _, targetName in pairs(getgenv().TargetPets or {}) do
                            if string.find(current.Name, targetName) then
                                isTarget = true
                                break
                            end
                        end
                        if isTarget then break end
                        current = current.Parent
                    end
                    
                    if isTarget then
                        targetPrompt = obj
                        promptParentPart = obj.Parent
                        break 
                    end
                end
            end
        end
        
        if targetPrompt and promptParentPart and promptParentPart:IsA("BasePart") then
            isSafeToClear = true 
            
            local configDelay = getgenv().DelayBeforeFly or 20.0
            local remainingWait = math.max(0.1, configDelay - 7.0)
            
            print("🎯 [พบสัตว์เป้าหมาย!] เปิดระบบลบต้นไม้ และรอเคลียร์จอค้างที่เหลืออีก " .. tostring(remainingWait) .. " วินาที...")
            task.wait(remainingWait)
            
            print("⚡ หายค้างชัวร์! กำลังพุ่งบินไปซื้อสัตว์ที่จุดพิกัดล่าสุด...")
            FlyToTargetPart(promptParentPart)
            
            task.wait(0.1)
            targetPrompt:InputHoldBegin()
            task.wait(2.0) 
            targetPrompt:InputHoldEnd()
            
            print("💰 ซื้อสัตว์เลี้ยงสำเร็จ! กำลังเตรียมย้ายเซิร์ฟเวอร์...")
            task.wait(1.5) 
            HopServer()
        else
            print("❌ ไม่พบสัตว์เป้าหมายหลังจากหน่วงเวลารอ 7 วินาที ทำการย้ายเซิร์ฟเวอร์หนี...")
            HopServer()
        end
    end
end)
