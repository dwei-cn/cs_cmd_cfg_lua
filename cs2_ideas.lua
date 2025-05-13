-- 创建 Visuals 下的新 Tab
local tabAll = gui.Tab(gui.Reference("Visuals"), "allinone_tab", "Sound ESP Plus")

-- Sound ESP 分组
local groupSoundESP = gui.Groupbox(tabAll, "Sound ESP", 15, 15, 300, 0)
local guiSoundESP = gui.Checkbox(groupSoundESP, "sound_esp_enable", "Enable Sound ESP", true)
local guiOnlyHearableSounds = gui.Checkbox(groupSoundESP, "sound_esp_hearable", "Only Show Hearable Sounds", true)
local guiEnemySounds = gui.Checkbox(groupSoundESP, "sound_esp_enemy", "Show Enemy Sounds", true)
guiEnemySounds:SetDescription("Visualize enemy player sounds.")
local guiEnemyColor = gui.ColorPicker(guiEnemySounds, "clr", "Enemy Sound Color", 0, 255, 0, 255)
local guiFriendlySounds = gui.Checkbox(groupSoundESP, "sound_esp_friendly", "Show Friendly Sounds", false)
guiFriendlySounds:SetDescription("Visualize friendly player sounds.")
local guiFriendlyColor = gui.ColorPicker(groupSoundESP, "clr", "Friendly Sound Color", 0, 255, 255, 255)

-- Head Highlight 控件
local guiHeadHighlight = gui.Checkbox(groupSoundESP, "head_highlight_enable", "Enable Head Highlight", false)
local guiHeadColor = gui.ColorPicker(groupSoundESP, "head_color", "Head Highlight Color", 255, 255, 0, 255)
local guiHeadSize = gui.Slider(groupSoundESP, "head_size", "Head Highlight Size", 5, 2, 10)

local guiSoundKeepTime = gui.Slider(groupSoundESP, "sound_keep", "Sound Visible Time", 2.0, 0.1, 5.0, 0.1)
local guiSoundFadeOut = gui.Slider(groupSoundESP, "sound_fade", "Sound Fade-out Time", 3.0, 0.1, 5.0, 0.1)

-- Dot Crosshair 分组
local groupDot = gui.Groupbox(tabAll, "Simple Dot Crosshair", 335, 15, 300, 0)
local fDotEnabled = gui.Checkbox(groupDot, "dot_enabled", "Enable Dot Crosshair", true)
local dotColor = gui.ColorPicker(groupDot, "dot_color", "Dot Color", 0, 255, 0, 255)
local dotSize = gui.Slider(groupDot, "dot_size", "Dot Size", 2, 1, 10, 1)

-- Velocity 分组
-- local groupVelocity = gui.Groupbox(tabAll, "Velocity Display", 335, 260, 300, 0)
-- local velocityEnabled = gui.Checkbox(groupVelocity, "velocity_show", "Show Velocity", false)
-- local velocityColor = gui.ColorPicker(groupVelocity, "velocity_color", "Text Color", 255, 255, 255, 255)

-- 工具函数
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

local function IsVisible(from, to, skip)
    local skipIndex = skip and skip:GetIndex() or 0
    local trace = engine.TraceLine(from, to, MASK_VISIBLE, skipIndex)
    return trace.fraction > 0.97
end

local function ShouldForceShow(pawn)
    if not pawn or not pawn:IsAlive() then return false end

    if pawn:GetPropBool("m_bSpotted") then return true end
    if pawn:GetPropInt("m_iHealth") < 30 then return true end

    local localPlayer = entities.GetLocalPlayer()
    if localPlayer and localPlayer:IsAlive() then
        local eyes = localPlayer:GetAbsOrigin() + localPlayer:GetPropVector("m_vecViewOffset")
        local head = pawn:GetHitboxPosition(0)
        if head and IsVisible(eyes, head, localPlayer) then
            return true
        end
    end

    return false
end

-- Sound ESP 存储
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

-- Sound ESP + Dot Crosshair
callbacks.Register("Draw", function()
    local g_kDuration = guiSoundKeepTime:GetValue()
    local g_kFadeOut = guiSoundFadeOut:GetValue()

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
                local fade = (delta > g_kDuration) and (1.0 - ((delta - g_kDuration) / g_kFadeOut)) or 1.0

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

                        draw.Color(r, g, b, alpha)
                        draw.OutlinedRect(left, topY, right, bottomY)

                        local headPosX, headPosY = client.WorldToScreen(origin + Vector3(0, 0, maxs.z - 5))
                        if guiHeadHighlight:GetValue() and headPosX and headPosY then
                            local hr, hg, hb, ha = unpack(headColor)
                            draw.Color(hr, hg, hb, math.floor(ha * fade * 0.3))
                            draw.FilledCircle(headPosX, headPosY, headSize + 5)
                        end

                        local health = pawn:GetPropInt("m_iHealth")
                        local healthPercent = health / 100
                        local barColor = (healthPercent < 0.3) and {255, 0, 0} or (healthPercent < 0.85) and {255, 255, 0} or {0, 255, 0}
                        local healthBarHeight = (bottomY - topY) * healthPercent

                        draw.Color(unpack(barColor))
                        draw.FilledRect(left - 7, bottomY - healthBarHeight, left - 4, bottomY)

                        local healthTextX, healthTextY = client.WorldToScreen(origin + Vector3(0, 0, maxs.z + 15))
                        if healthTextX and healthTextY then
                            draw.Color(255, 255, 255, alpha)
                            draw.Text(healthTextX - 40, healthTextY, tostring(health) .. " HP")
                        end
                    end
                end
            end
        end

        -- 添加额外显示逻辑
        local localPlayer = entities.GetLocalPlayer()
        if localPlayer then
            for _, entity in pairs(entities.FindByClass("CCSPlayerPawn")) do
                if entity:IsAlive() and entity:GetIndex() ~= localPlayer:GetIndex() and ShouldForceShow(entity) then
                    local mins = entity:GetMins()
                    local maxs = entity:GetMaxs()
                    local origin = entity:GetAbsOrigin()

                    local top = origin + maxs
                    local bottom = origin + mins
                    local x1, y1 = client.WorldToScreen(top)
                    local x2, y2 = client.WorldToScreen(bottom)

                    if x1 and y1 and x2 and y2 then
                        local left = math.min(x1, x2) - 10
                        local right = math.max(x1, x2) + 10
                        local topY = math.min(y1, y2)
                        local bottomY = math.max(y1, y2)

                        draw.Color(255, 255, 255, 200)
                        draw.OutlinedRect(left, topY, right, bottomY)
                    end
                end
            end
        end

        -- 清理无效项
        local i = 1
        while i <= #g_aSounds do
            if not g_aSounds[i] then
                table.remove(g_aSounds, i)
            else
                i = i + 1
            end
        end
    end

    -- Dot Crosshair
    if fDotEnabled:GetValue() then
        local lPlayer = entities.GetLocalPlayer()
        if lPlayer and lPlayer:GetWeaponType() == 5 then
            local x, y = draw.GetScreenSize()
            x = math.floor(x * 0.5)
            y = math.floor(y * 0.5)
            draw.Color(dotColor:GetValue())
            draw.FilledCircle(x, y, dotSize:GetValue())
        end
    end
end)

-- -- Velocity 显示
-- callbacks.Register("Draw", function()
--     if not velocityEnabled:GetValue() then return end

--     local localPlayer = entities.GetLocalPlayer()
--     if not localPlayer or not localPlayer:IsAlive() then return end

--     local vel = localPlayer:GetPropVector("m_vecVelocity")
--     local speed = math.floor(vel:Length2D() + 0.5)

--     local screenW, screenH = draw.GetScreenSize()
--     local text = "Velocity: " .. speed
--     local r, g, b, a = velocityColor:GetValue()

--     if speed < 10 then
--         r, g, b = 0, 255, 0
--     elseif speed < 120 then
--         r, g, b = 255, 255, 0
--     else
--         r, g, b = 255, 0, 0
--     end

--     draw.Color(r, g, b, a)
--     draw.Text(screenW - 150, screenH - 100, text)
-- end)
