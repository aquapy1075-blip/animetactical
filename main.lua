    -- ==============================
    -- SERVICES
    -- ==============================
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local player = Players.LocalPlayer

    local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"))()

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

    local count = 0

    for _, member in pairs(myParty:GetChildren()) do
        if member.Name ~= player.Name then
            count += 1
        end
    end

    return count >= requiredOtherPlayers
end
    -- ==============================
    -- START RAID
    -- ==============================
    local function auto_start_raid()
        

        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")

        local pod = workspace:WaitForChild("Raids_Entering"):WaitForChild("Pod_03")
        hrp.CFrame = pod:GetPivot()

        task.wait(1.5)
            if partyMode == "Join" then
        -- Join mode: chỉ cần teleport vào pod
        return
        end

        local partyFolder = get_party()
        if not partyFolder then return end

        ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
            partyFolder,
            "Worlds_" .. select_map
        )

        task.wait(0.5)

        ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
            partyFolder,
            "Diffculty_" .. select_difficulty
        )

        task.wait(0.5)
        if partyMode == "Host" then
            local startWait = tick()
            local WAIT_TIMEOUT = 60

         repeat
        task.wait(1)
           until party_has_required_members() or tick() - startWait > WAIT_TIMEOUT

        if not party_has_required_members() then
           return -- chưa đủ người
        end
end

        ReplicatedStorage.Remotes.Systems.RaidsEvent:FireServer(
            select_map,
            select_difficulty
        )
    end

    -- ==============================
    -- GET SERVER MOB
    -- ==============================
    local function get_server_mob()
        local serverFolder = workspace:FindFirstChild("Worlds")
        if not serverFolder then return nil end

        serverFolder = serverFolder:FindFirstChild("Targets")
        if not serverFolder then return nil end

        serverFolder = serverFolder:FindFirstChild("Server")
        if not serverFolder then return nil end

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

        for _, child in pairs(RaidsVisual:GetChildren()) do
            if string.find(child.Name, select_map .. "_Server_" .. player.Name) then
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
    local loop_running = false
    local raidBusy = false

    function auto_raid_loop()
        if loop_running then return end
        loop_running = true
    while autoraid do
            if not raidBusy then
                raidBusy = true
                if not is_in_raid() then auto_start_raid() end
                local startTime = tick()
                local JOIN_TIMEOUT = 10
                repeat task.wait()
                until is_in_raid() or tick() - startTime > JOIN_TIMEOUT
                if not is_in_raid() then
                        raidBusy = false
                            task.wait(2)
                           continue
                end
                clear_raid()
                task.wait(1)
                raidBusy = false
            end

            task.wait(1)
        end


        loop_running = false
    end
    -- ==============================
    -- Main World
    -- ==============================
    local automain = false
    local select_npc_main = "Players"
    local select_world_main = "Namex Planet"

function findUnitByName(targetText)
    local server = workspace.Worlds.Targets.Server
    for _, unit in ipairs(server:GetChildren()) do
            local unitsDisplay = unit:FindFirstChild("Units_Displays")
            if unitsDisplay then
                local name = unitsDisplay:FindFirstChild("Names")
                if name and name.Text == targetText then
                    return unit.Name
                end
            end
    end

    return nil
end
    function auto_main_world()
        while automain do
           local maps = workspace:WaitForChild("Maps")
           if maps:FindFirstChild(select_world_main) == nil then 
              local stringname = "\004\r\000" .. select_world_main
              local args = {
	             buffer.fromstring(stringname)
              }
              ReplicatedStorage.ByteNetReliable:FireServer(unpack(args))
              task.wait(1.5)
            end
            task.wait(0.5)
         local dps =  player.PlayerGui.HUD._Frame.DPS.Numbers
           if dps.Text == "0" then
                local target = findUnitByName(select_npc_main)
                if target then 
                    local args = { target,  "Mouse"}
                     ReplicatedStorage.Remotes.Gameplays.Request:FireServer(unpack(args))
                end

           end
            task.wait(1.5)
        end
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
            task.wait(0.1)
        end

        hatch_loop_running = false
    end

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
        Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
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
    Callback = function(value)
        partyMode = value
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
            if autoraid then
                auto_raid_loop()
            end
        end,
    })

    local Farm = Window:MakeTab({ "Farm", "pickaxe" })
       Farm:AddDropdown({
        Name = "Select Farm Map",
        Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
        Default = select_world_main,
        Flag = "Farm_Map",
        Callback = function(value)
            select_world_main = value
        end,
    })
       Farm:AddTextBox({
        Name = "Select NPC",
        Default = select_npc_main,
        Flag = "Farm_NPC",
        ClearOnFocus = true,
        Callback = function(value)
            select_npc_main = value
        end,
       })
       Farm:AddToggle({
        Name = "Auto Farm Main World",
        Default = false,
        Flag = "Auto_Farm_Main",
        Callback = function(value)
            automain = value
            if automain then
                auto_main_world()
            end
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

