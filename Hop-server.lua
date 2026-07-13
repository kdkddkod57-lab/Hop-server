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

-- ระบบแก้บั๊ก Teleport Failed / Error Code 772
task.spawn(function()
    while task.wait(1) do
        local robloxPromptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if robloxPromptGui then
            local promptHolder = robloxPromptGui:FindFirstChild("promptOverlay") and robloxPromptGui.promptOverlay:FindFirstChild("ErrorPrompt")
            if promptHolder then
                local buttonLayout = promptHolder:FindFirstChild("ButtonLayout")
                local okButton = buttonLayout and buttonLayout:FindFirstChildWhichIsA("TextButton", true)
                
                if okButton and okButton.Visible then
                    print("⚠️ เจอหน้าต่าง Teleport Failed! กำลังคลิกปุ่ม OK เพื่อแก้ไข...")
                    local pos = okButton.AbsolutePosition + (okButton.AbsoluteSize / 2)
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                    task.wait(0.1)
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                    
                    task.wait(1)
                    HopServer()
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

-- 3. ระบบหลัก (แก้ไข: เพิ่มระบบหน่วงเวลา 7 วินาทีแรกให้สัตว์เกิดก่อนสแกน)
task.spawn(function()
    repeat task.wait(0.5) until game:IsLoaded() and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if getgenv().AutoFarm then
        -- [แก้ไขจุดสำคัญ] สั่งให้ยืนรอ 7 วินาที (ค่าเฉลี่ยกลางระหว่าง 5-10 วิ) เพื่อรอให้โมเดลสัตว์เลี้ยงโหลดเข้ามาในแผนที่ก่อน
        print("⏳ [ระบบหน่วงเวลารอสัตว์เกิด] กำลังยืนรอ 7 วินาที เพื่อให้ตัวเกมโหลดโมเดลสัตว์เลี้ยงเข้ามา...")
        task.wait(7.0)
        
        local mapFolder = Workspace:WaitForChild("Map", 10)
        local targetPrompt = nil
        local promptParentPart = nil
        
        print("🎯 ครบ 7 วินาทีแล้ว เริ่มทำสแกนหาตัวสัตว์เลี้ยงเป้าหมาย...")
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
        
        -- ตรวจสอบเงื่อนไขหลังสแกน
        if targetPrompt and promptParentPart and promptParentPart:IsA("BasePart") then
            -- [กรณีเจอสัตว์] เปิดระบบลบต้นไม้ และรอดีเลย์จนครบตามที่ตั้งไว้ในหน้าบ้าน
            isSafeToClear = true 
            
            -- ลบเวลา 7 วินาทีแรกที่รอไปแล้วออกจากดีเลย์รวม เพื่อความแม่นยำ (หน้าบ้านตั้งไว้ 20 วิ จะรอเพิ่มอีก 13 วิ)
            local configDelay = getgenv().DelayBeforeFly or 20.0
            local remainingWait = math.max(0.1, configDelay - 7.0)
            
            print("🎯 [พบสัตว์เป้าหมาย!] เปิดระบบลบต้นไม้ และรอหน่วงเวลาหายค้างเพิ่มอีก " .. tostring(remainingWait) .. " วินาที...")
            task.wait(remainingWait)
            
            print("⚡ หายค้างและเคลียร์ต้นไม้เสร็จแล้ว! กำลังบินไปซื้อพิกัดล่าสุด...")
            FlyToTargetPart(promptParentPart)
            
            task.wait(0.1)
            targetPrompt:InputHoldBegin()
            task.wait(2.0) 
            targetPrompt:InputHoldEnd()
            
            print("💰 ซื้อสำเร็จ! กำลังย้ายเซิร์ฟเวอร์...")
            task.wait(1.5) 
            HopServer()
        else
            -- [กรณีไม่เจอสัตว์หลังจากรอเกิด 7 วิแล้ว] สั่งย้ายเซิร์ฟเวอร์หนีทันที
            print("❌ ไม่พบสัตว์เป้าหมายในเซิร์ฟนี้! ย้ายเซิร์ฟเวอร์หนีทันที...")
            HopServer()
        end
    end
end)
