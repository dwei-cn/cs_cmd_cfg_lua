-- 创建 Visuals 下的新 Tab
local tabAll = gui.Tab(gui.Reference("Visuals"), "allinone_tab", "All In One ESP")

-- Sound ESP 分组
local groupSoundESP = gui.Groupbox(tabAll, "Sound ESP", 15, 15, 300, 0)
local guiSoundESP = gui.Checkbox(groupSoundESP, "sound_esp_enable", "Enable Sound ESP", true)
local guiOnlyHearableSounds = gui.Checkbox(groupSoundESP, "sound_esp_hearable", "Only Show Hearable Sounds", true)
local guiEnemySounds = gui.Checkbox(groupSoundESP, "sound_esp_enemy", "Show Enemy Sounds", true)
guiEnemySounds:SetDescription("Visualize enemy player sounds.")
local guiEnemyColor = gui.ColorPicker(guiEnemySounds, "clr", "Enemy Sound Color", 255, 0, 0, 255)
local guiFriendlySounds = gui.Checkbox(groupSoundESP, "sound_esp_friendly", "Show Friendly Sounds", true)
guiFriendlySounds:SetDescription("Visualize friendly player sounds.")
local guiFriendlyColor = gui.ColorPicker(guiFriendlySounds, "clr", "Friendly Sound Color", 0, 255, 255, 255)
local guiHeadColor = gui.ColorPicker(groupSoundESP, "head_color", "Head Highlight Color", 255, 255, 0, 255)
local guiHeadSize = gui.Slider(groupSoundESP, "head_size", "Head Highlight Size", 5, 2, 10)

-- 新增：显示时间设置
local guiSoundKeepTime = gui.Slider(groupSoundESP, "sound_keep", "Sound Visible Time", 1.0, 0.1, 5.0, 0.1)
local guiSoundFadeOut = gui.Slider(groupSoundESP, "sound_fade", "Sound Fade-out Time", 2.0, 0.1, 5.0, 0.1)

-- Dot Crosshair 分组
local groupDot = gui.Groupbox(tabAll, "Simple Dot Crosshair", 335, 15, 300, 0)
local fDotEnabled = gui.Checkbox(groupDot, "dot_enabled", "Enable Dot Crosshair", true)
local dotColor = gui.ColorPicker(groupDot, "dot_color", "Dot Color", 0, 255, 0, 255)
local dotSize = gui.Slider(groupDot, "dot_size", "Dot Size", 2, 1, 10, 1)

-- Velocity Display 分组
local groupVelocity = gui.Groupbox(tabAll, "Velocity Display", 335, 260, 300, 0)
local velocityEnabled = gui.Checkbox(groupVelocity, "velocity_show", "Show Velocity", true)
local velocityColor = gui.ColorPicker(groupVelocity, "velocity_color", "Text Color", 255, 255, 255, 255)

-- Sound ESP 相关逻辑
local function AreTeamsEnemies(team1, team2)
    return client.GetConVar("mp_teammates_are_enemies") or (team1 ~= team2 and team1 > 1 and team2 > 1)
end

local function GetEventPlayerController(ctx, str)
    if type(ctx) ~= "userdata" then return end
    local index = ctx:GetInt(str)
    if not index then return end
    local controller = entities.GetByIndex(index + 1)
    return (controller and controller:GetClass() == "CCSPlayerController") and controller or nil
end

local function GetEnemyTopFragger()
    local players = entities.FindByClass("CCSPlayerController")
    local topFragger = nil
    local topKills = -1
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return nil end
    local myTeam = localPlayer:GetTeamNumber()

    for _, player in pairs(players) do
        if player:IsValid() and player:GetTeamNumber() ~= myTeam then
            local kills = player:GetPropInt("m_iKills") or 0
            if kills > topKills then
                topKills = kills
                topFragger = player
            end
        end
    end

    return topFragger
end

local g_aSounds = {}
client.AllowListener("player_sound")

callbacks.Register("FireGameEvent", function(ctx)
    if ctx:GetName() ~= "player_sound" or not gui.GetValue("esp.master") or not guiSoundESP:GetValue() then return end

    local localPlayer = entities.GetLocalPlayer()
    local controller = GetEventPlayerController(ctx, "userid")
    if not localPlayer or not controller then return end

    local pawn = controller:GetPropEntity("m_hPawn")
    if not pawn or pawn:GetIndex() == localPlayer:GetIndex() then return end

    local isEnemy = AreTeamsEnemies(localPlayer:GetTeamNumber(), pawn:GetTeamNumber())
    if (isEnemy and not guiEnemySounds:GetValue()) or (not isEnemy and not guiFriendlySounds:GetValue()) then return end

    local origin = pawn:GetAbsOrigin()
    local localOrigin = localPlayer:GetAbsOrigin() + localPlayer:GetPropVector("m_vecViewOffset")
    local distance = (localOrigin - origin):Length()

    if guiOnlyHearableSounds:GetValue() and distance > ctx:GetInt("radius") then return end

    if pawn:IsAlive() then
        table.insert(g_aSounds, {
            m_flTime = globals.CurTime(),
            m_pPawn = pawn,
            m_bEnemy = isEnemy
        })
    end
end)

local boxThickness = 3  -- 加粗框框

callbacks.Register("Draw", function()
    -- 更新显示时间设置
    local g_kDuration = guiSoundKeepTime:GetValue()
    local g_kFadeOut = guiSoundFadeOut:GetValue()

    -- Sound ESP
    if gui.GetValue("esp.master") and guiSoundESP:GetValue() then
        local curTime = globals.CurTime()
        local enemyColor = { guiEnemyColor:GetValue() }
        local friendlyColor = { guiFriendlyColor:GetValue() }
        local headColor = { guiHeadColor:GetValue() }
        local headSize = guiHeadSize:GetValue()

        for i, data in pairs(g_aSounds) do
            local delta = curTime - data.m_flTime
            if delta > (g_kDuration + g_kFadeOut) then
                g_aSounds[i] = nil
            else
                local fade = 1.0
                if delta > g_kDuration then
                    fade = 1.0 - ((delta - g_kDuration) / g_kFadeOut)
                end

                local baseColor = data.m_bEnemy and enemyColor or friendlyColor
                local r, g, b, a = unpack(baseColor)
                local alpha = math.floor(a * fade)

                local pawn = data.m_pPawn
                if pawn and pawn:IsAlive() then
                    local mins = pawn:GetMins()
                    local maxs = pawn:GetMaxs()
                    local origin = pawn:GetAbsOrigin()

                    local top = origin + maxs
                    local bottom = origin + mins

                    local x1, y1 = client.WorldToScreen(top)
                    local x2, y2 = client.WorldToScreen(bottom)

                    if x1 and y1 and x2 and y2 then
                        local left = math.min(x1, x2) - 10
                        local right = math.max(x1, x2) + 10
                        local topY = math.min(y1, y2)
                        local bottomY = math.max(y1, y2)

                        -- 高亮包匪和top fragger（绿色框框）
                        local drawR, drawG, drawB = r, g, b  -- 默认使用敌我颜色
                        local c4 = pawn:GetPropBool("m_bHasC4")
                        local topFragger = GetEnemyTopFragger()
                        local controller = pawn:GetPlayerController()

                        if c4 then
                            drawR, drawG, drawB = 0, 255, 0  -- 绿色框框表示包匪
                        elseif topFragger and controller and controller:GetIndex() == topFragger:GetIndex() then
                            drawR, drawG, drawB = 0, 255, 0  -- 绿色框框表示top fragger
                        end

                        draw.Color(drawR, drawG, drawB, alpha)
                        -- 加粗框框
                        for t = 0, boxThickness - 1 do
                            draw.OutlinedRect(left - t, topY - t, right + t, bottomY + t)
                        end

                        local headPosX, headPosY = client.WorldToScreen(origin + Vector3(0, 0, maxs.z - 5))
                        if headPosX and headPosY then
                            local hr, hg, hb, ha = unpack(headColor)
                            draw.Color(hr, hg, hb, math.floor(ha * fade * 0.3))
                            draw.FilledCircle(headPosX, headPosY, headSize + 5)
                        end
                    end
                end
            end
        end
    end

    -- Velocity Display
    if velocityEnabled:GetValue() then
        local localPlayer = entities.GetLocalPlayer()
        if not localPlayer or not localPlayer:IsAlive() then return end
        local vel = localPlayer:GetPropVector("m_vecVelocity")
        local speed = math.floor(vel:Length2D() + 0.5)
        local screenW, screenH = draw.GetScreenSize()
        local text = "Velocity: " .. speed
        local r, g, b, a = velocityColor:GetValue()
        
        -- 根据速度自动变色
        if speed < 10 then
            r, g, b = 0, 255, 0 -- 静止：绿色
        elseif speed < 120 then
            r, g, b = 255, 255, 0 -- 缓慢移动：黄色
        else
            r, g, b = 255, 0, 0 -- 快速移动：红色
        end
        
        draw.Color(r, g, b, a)
        draw.Text(screenW - 150, screenH - 100, text)
    end
end)
