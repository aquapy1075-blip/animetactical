    -- ==============================
    -- SERVICES
    -- ==============================
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local player = Players.LocalPlayer
    local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"))()
    local vu = game:GetService("VirtualUser")
	game:GetService("Players").LocalPlayer.Idled:Connect(function()
		vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	end)
    -- ==============================
    -- SETTINGS
    -- ==============================
    local select_map = "Namex Planet"
    local select_difficulty = "Nightmare"
    local autoraid = false
    local useDungeonKey = false
    local RaidsVisual = workspace:WaitForChild("Raids_Visual")
    local partyMode = "Solo" -- "Solo", "Join", "Host"
    local hostPlayerName = "" -- dùng khi Join mode
    local requiredOtherPlayers = 1

    -- ==============================
    -- RAID STATE CHECK
    -- ==============================
  local function is_in_raid()
    for _, child in pairs(RaidsVisual:GetChildren()) do
        if partyMode == "Join" then
            if hostPlayerName ~= "" and string.find(child.Name, hostPlayerName) then
                return true
            end
        else
            if string.find(child.Name, player.Name) then
                return true
            end
        end
    end
    return false
end

    -- ==============================
    -- GET PARTY
    -- ==============================
local function get_party()
        local parties = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Parties")
        repeat task.wait() until parties:FindFirstChild(player.Name)
        return parties[player.Name]
    end
local function party_has_required_members()
    local parties = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Parties")
    local myParty = parties:FindFirstChild(player.Name)
    if not myParty then return false end

    return (#myParty:GetChildren() - 1) >= requiredOtherPlayers
end
    -- ==============================
    -- START RAID
    -- ==============================
   local function auto_start_raid()
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    -- ===== JOIN MODE =====
    if partyMode == "Join" then
        if hostPlayerName == "" then return end

        local parties = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Parties")

        while autoraid and not parties:FindFirstChild(hostPlayerName) do
            task.wait(0.5)
        end

        if not autoraid then return end
    end

    -- ===== TELEPORT LOGIC =====
    if select_map == "Double Dungeons" then
        -- Map này cần fire riêng
        ReplicatedStorage.ByteNetReliable:FireServer(
            buffer.fromstring("\005\r\000Dungeons Town")
        )

        task.wait(1.5)
        hrp.CFrame = CFrame.new(-3025, 1040, -1859)
        task.wait(1.5)
    else
        local pod = workspace:WaitForChild("Raids_Entering"):WaitForChild("Pod_03")
        hrp.CFrame = pod:GetPivot()
        task.wait(1.5)
    end

    -- ===== PARTY CHECK =====
    local partyFolder = get_party()

    if not partyFolder and partyMode ~= "Solo" then
        return
    end

    -- ===== SELECT MAP =====
    ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
        partyFolder,
        "Worlds_" .. select_map
    )

    task.wait(0.5)

    -- ===== SELECT DIFFICULTY =====
    ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
        partyFolder,
        "Diffculty_" .. select_difficulty
    )

    task.wait(0.5)

    -- ===== HOST WAIT FOR MEMBERS =====
    if partyMode == "Host" then
        local startWait = tick()
        local WAIT_TIMEOUT = 60

        repeat
            task.wait(1)
        until party_has_required_members()
            or tick() - startWait > WAIT_TIMEOUT

        if not party_has_required_members() then
            return
        end
    end

    -- ===== START RAID =====
    ReplicatedStorage.Remotes.Systems.RaidsEvent:FireServer(
        select_map,
        select_difficulty
    )
end

    -- ==============================
    -- GET SERVER MOB
    -- ==============================
    local function get_server_mob()
       local serverFolder = workspace.Worlds.Targets.Server
      
       for _, mob in pairs(serverFolder:GetChildren()) do
        local session = mob:GetAttribute("SessionId")
        if session then
            if partyMode == "Join" then
                if hostPlayerName ~= "" and string.find(session, hostPlayerName) then
                    return mob
                end
            else
                if string.find(session, player.Name) then
                    return mob
                end
            end
        end
    end

        return nil
    end

    local function isBossAlive()
    local server = workspace:FindFirstChild("Worlds")
        and workspace.Worlds:FindFirstChild("Targets")
        and workspace.Worlds.Targets:FindFirstChild("Server")

    if not server then return false end

    for _, v in pairs(server:GetChildren()) do
        if string.find(v.Name, "BossFight") then
            return true
        end
    end

    return false
end


    -- ==============================   
    -- INPUT
    -- ==============================
    local function press_E()
        VirtualInputManager:SendKeyEvent(true, "E", false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, "E", false, game)
    end


    -- ==============================
    -- CLAIM + EXIT
    -- ==============================
   local function claim_and_exit()

    local raidObj = nil
    local raidOwnerName = player.Name

    -- nếu Join mode thì raid theo tên host
    if partyMode == "Join" and hostPlayerName ~= "" then
        raidOwnerName = hostPlayerName
    end

    for _, child in pairs(RaidsVisual:GetChildren()) do
        if string.find(child.Name, select_map .. "_Server_" .. raidOwnerName) then
            raidObj = child
            break
        end
    end

    if not raidObj then return end

        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")

        local rewards = raidObj.Configs.Others.Rewards
        local portal = raidObj.Configs.Others.Portal.Travel
        if rewards:FindFirstChild("Special") then
            hrp.CFrame = rewards.Special:GetPivot()
            task.wait(0.5)
            press_E()
            task.wait(0.5)
        end
        local purple = rewards:FindFirstChild("Purple")
        local gold = rewards:FindFirstChild("Golds")


        if useDungeonKey and purple then

            local cf = purple:GetPivot()

            -- đứng bên trái 3 studs
            local targetPos = cf.Position - cf.RightVector * 3
            hrp.CFrame = CFrame.new(targetPos, cf.Position)

            task.wait(1)
            press_E()
        task.wait(1)
        end
        if gold then
            local cf = gold:GetPivot()
            local targetPos = cf.Position + cf.RightVector * 3
            hrp.CFrame = CFrame.new(targetPos, cf.Position)
            task.wait(1)
            press_E()
            task.wait(1)
        end

        if portal then
            local cf = portal:GetPivot()
            hrp.CFrame = cf * CFrame.new(0,0,-3)
            task.wait(1)
            press_E()
        end
    end
    -- ==============================
    -- CLEAR RAID
    -- ==============================
    local function clear_raid()
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")

        local mob = get_server_mob()
        if not mob then return end

        while mob and mob.Parent and autoraid do
            hrp.CFrame = mob:GetPivot()
            task.wait(0.01)
            mob = get_server_mob()
            
        end

        if autoraid then
            task.wait(1)
            claim_and_exit()
        end
    end
    -- ==============================
    -- AUTO RAID LOOP
    -- ==============================

function auto_raid_loop()

    if not autoraid then return end

    if not is_in_raid() then
        auto_start_raid()
        repeat task.wait()
        until is_in_raid() or not autoraid
    end

    if not autoraid then return end

    clear_raid()
    task.wait(1)
end
    -- ==============================
    -- Main World
    -- ==============================
    local automain = false
    local select_world_main = "Namex Planet"
    local autoboss = false
    local bossActive = false

    local MobByMap = {
    ["Namex Planet"] = {"Yumcha","Vejita","Goku","Broly","Buu"},
    ["Colosseum Kingdom"] = {"Joker","Zoro","Buggy","Ace","Luffy"},
    ["Demon Forest"] = {"Murata","Genya","Tanjiro","Zetnitsu","Giyu","Gyutaro"},
    ["Dungeons Town"] = {"Jinho","Bora-Lee","Iron","Heejin","Sung Jin Woo"},
}

local selectedMobs = {} -- lưu mob được chọn
local function isTargetUnit(unitName)
    for _, name in ipairs(selectedMobs) do
        if unitName == name then
            return true
        end
    end
    return false
end

function auto_main_world()

    if not automain then return end
    if bossActive then return end

    local maps = workspace:WaitForChild("Maps")
    if not maps:FindFirstChild(select_world_main) then
        local stringname = "\004\r\000" .. select_world_main
        ReplicatedStorage.ByteNetReliable:FireServer(
            buffer.fromstring(stringname)
        )
        task.wait(1.5)
    end

    local server = workspace.Worlds
        and workspace.Worlds.Targets
        and workspace.Worlds.Targets.Server

    if not server then return end

    for _, mob in pairs(server:GetChildren()) do

        if not automain or bossActive then break end

        local humanoid = mob:FindFirstChildOfClass("Humanoid")
        if humanoid and isTargetUnit(humanoid.DisplayName) then

            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                character.HumanoidRootPart.CFrame =
                    mob:GetPivot() * CFrame.new(0,0,-5)
            end

            ReplicatedStorage.Remotes.Gameplays.Request:FireServer(
                mob.Name, "Mouse"
            )

            repeat task.wait(0.2)
            until not mob or not mob.Parent or bossActive
        end
    end
end

function auto_boss()

    print("=== AUTO BOSS START ===")

    -- Teleport map
    print("Sending map request...")
    ReplicatedStorage.ByteNetReliable:FireServer(
        buffer.fromstring("\005\f\000Demon Forest")
    )

    task.wait(0.5)

    local c = player.Character or player.CharacterAdded:Wait()
    local hrp = c:WaitForChild("HumanoidRootPart")

    print("Teleporting to portal...")
    hrp.CFrame = workspace.Maps["Demon Forest"]
        .Building.Portals:GetPivot()

    task.wait(3)

    local server = workspace:FindFirstChild("Worlds")
        and workspace.Worlds:FindFirstChild("Targets")
        and workspace.Worlds.Targets:FindFirstChild("Server")

    if not server then
        print("❌ Server folder not found")
        return
    end

    print("Server folder found")

    -- Debug: in hết object trong Server
    for _, v in pairs(server:GetChildren()) do
        print("Child:", v.Name)
    end

    print("Checking boss loop...")

    while true do

        local bossFound = false

        for _, v in pairs(server:GetChildren()) do
            if string.find(v.Name, "Boss") then
                bossFound = true
                print("Boss found:", v.Name)

                hrp.CFrame = v:GetPivot() * CFrame.new(0,0,-5)

                repeat
                    task.wait(0.5)
                until not v or not v.Parent

                print("Boss died:", v.Name)
            end
        end

        if not bossFound then
            print("No boss currently alive")
            break
        end

        task.wait(0.5)
    end

    print("=== AUTO BOSS END ===")
end
    -- ==============================
    -- HATCH
    -- ==============================
    local select_hatch_map = "Namex Planet"
    local autohatch = false
    local hatch_loop_running = false

    function auto_hatch()
        if hatch_loop_running then return end
        hatch_loop_running = true

        while autohatch do
            local args = {
                workspace:WaitForChild("Summoners"):WaitForChild(select_hatch_map),
                "Multi"
            }

            ReplicatedStorage.Remotes.Summoners.RemoteEvent:FireServer(unpack(args))
            task.wait(0.125)
        end

        hatch_loop_running = false
    end


    local currentTask = nil

task.spawn(function()
    while true do
        if currentTask == nil then
            if autoraid and is_in_raid() then
                currentTask = "raid"
                auto_raid_loop()
                currentTask = nil

            elseif autoboss and isBossAlive() then
                currentTask = "boss"
                auto_boss()
                currentTask = nil
            
            elseif autoraid then
                currentTask = "raid"
                auto_raid_loop()
                currentTask = nil

            elseif automain then
                currentTask = "farm"
                auto_main_world()
                currentTask = nil
            end
        end

        task.wait(1)
    end
end)

    -- ==============================
    -- UI
    -- ==============================
    local Window = Library:MakeWindow({
        Title = "Aqua Hub: Anime Card Realm",
        SubTitle = "by aquane1075",
        ScriptFolder = "AquaHubConfigs",
    })

    local Minimizer = Window:NewMinimizer({
        KeyCode = Enum.KeyCode.LeftControl,
    })

    Minimizer:CreateMobileMinimizer({
        Image = "rbxassetid://114289527320220",
        BackgroundColor3 = Color3.fromRGB(32, 96, 169),
    })

    -- ==============================
    -- RAID TAB
    -- ==============================
    local Challenge = Window:MakeTab({ "Challenge", "sword" })

    Challenge:AddSection("Raid")

    Challenge:AddDropdown({
        Name = "Select Raid Map",
        Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town", "Double Dungeons"},
        Default = select_map,
        Flag = "Raid_Map",
        Callback = function(value)
            select_map = value
        end,
    })

    Challenge:AddDropdown({
        Name = "Select Raid Difficulty",
        Options = {"Easy","Medium","Hard","Nightmare"},
        Default = select_difficulty,
        Flag = "Raid_Difficulty",
        Callback = function(value)
            select_difficulty = value
        end,
    })
    Challenge:AddToggle({
        Name = "Auto Use Key",
        Default = false,
        Flag = "Auto_Use_Key",
        Callback = function(value)
            useDungeonKey = value
        end,
    })

    Challenge:AddDropdown({
    Name = "Party Mode",
    Options = {"Solo","Join","Host"},
    Default = "Solo",
    Flag = "Party_Mode",
    Callback = function(value)
        partyMode = tostring(value)
    end,
})

 Challenge:AddTextBox({
    Name = "Host Player Name (Join Mode)",
    Default = "",
    Placeholder = "Enter host name...",
    Callback = function(value)
        hostPlayerName = value
    end,
})
Challenge:AddTextBox({
    Name = "Required Other Players (Host)",
    Default = "1",
    Placeholder = "Enter number...",
    Callback = function(value)
        local num = tonumber(value)
        if num and num >= 0 then
            requiredOtherPlayers = num
        end
    end,
})
    Challenge:AddToggle({
        Name = "Auto Raid",
        Default = false,
        Flag = "Auto_Raid",
        Callback = function(value)
            autoraid = value
        end,
    })

    local Farm = Window:MakeTab({ "Farm", "pickaxe" })
       
local mobDropdown

mobDropdown = Farm:AddDropdown({
    Name = "Select Mob",
    MultiSelect = true,
    Options = MobByMap[select_world_main],
    Default = {},
    Flag = "Mob_Selected",
    Callback = function(Value)
        selectedMobs = {}
        for mobName, state in pairs(Value) do
            if state then
                table.insert(selectedMobs, mobName)
            end
        end
    end
})
Farm:AddDropdown({
    Name = "Select Farm Map",
    Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
    Default = select_world_main,
    Flag = "Farm_Map",
    Callback = function(value)
        select_world_main = value
        
        if mobDropdown then
            selectedMobs = {}
            mobDropdown:NewOptions(MobByMap[value])
        end
    end,
})
       Farm:AddToggle({
        Name = "Auto Farm Mob",
        Default = false,
        Flag = "Auto_Farm_Mob",
        Callback = function(value)
            automain = value
        end,
    })
    Farm:AddToggle({
    Name = "Auto Boss",
    Default = false,
    Callback = function(value)
        autoboss = value
    end,
})
    local Hatch = Window:MakeTab({ "Hatch", "egg" })

    Hatch:AddDropdown({
        Name = "Select Hatch Map",
        Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
        Default = select_hatch_map,
        Flag = "Hatch_Map",
        Callback = function(value)
            select_hatch_map = value
        end,
    })

    Hatch:AddToggle({
        Name = "Auto Hatch",
        Default = false,
        Flag = "Auto_Hatch",
        Callback = function(value)
            autohatch = value
                if autohatch then
                    auto_hatch()
                end
        end,
    })
