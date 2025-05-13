-- 创建 Sound ESP Plus 界面
local tab = gui.Tab(gui.Reference("Visuals"), "sound_esp_plus", "Sound ESP Plus")
local groupSound = gui.Groupbox(tab, "Sound ESP", 15, 15, 300, 0)
local groupCrosshair = gui.Groupbox(tab, "Dot Crosshair", 335, 15, 300, 0)

-- 控件
local enableSoundESP = gui.Checkbox(groupSound, "soundesp_enable", "Enable Sound ESP", true)
local onlyHearable = gui.Checkbox(groupSound, "soundesp_hear", "Only Hearable", true)
local showEnemy = gui.Checkbox(groupSound, "soundesp_enemy", "Show Enemy", true)
local enemyColor = gui.ColorPicker(showEnemy, "enemy_color", "Enemy Color", 255, 0, 0, 255)
local showFriendly = gui.Checkbox(groupSound, "soundesp_friendly", "Show Friendly", false)
local friendlyColor = gui.ColorPicker(showFriendly, "friend_color", "Friendly Color", 0, 255, 255, 255)
local snapline = gui.Checkbox(groupSound, "soundesp_snapline", "Snap Line (Enemy Only)", true)
local highlightHead = gui.Checkbox(groupSound, "soundesp_head", "Head Highlight", false)
local headColor = gui.ColorPicker(groupSound, "head_color", "Head Color", 255, 255, 0, 255)
local headSize = gui.Slider(groupSound, "head_size", "Head Highlight Size", 5, 2, 10)
local duration = gui.Slider(groupSound, "soundesp_duration", "Box Duration", 2.0, 0.1, 5.0, 0.1)
local fadeTime = gui.Slider(groupSound, "soundesp_fade", "Fade Time", 2.0, 0.1, 5.0, 0.1)

-- Dot Crosshair
local dotEnabled = gui.Checkbox(groupCrosshair, "dot_enable", "Enable Dot Crosshair", true)
local dotColor = gui.ColorPicker(groupCrosshair, "dot_color", "Dot Color", 0, 255, 0, 255)
local dotSize = gui.Slider(groupCrosshair, "dot_size", "Dot Size", 2, 1, 10)

-- 工具函数
local function AreEnemies(t1, t2)
    return client.GetConVar("mp_teammates_are_enemies") or (t1 ~= t2 and t1 > 1 and t2 > 1)
end

local function IsVisible(from, to, skip)
    local trace = engine.TraceLine(from, to, MASK_VISIBLE, skip and skip:GetIndex() or 0)
    return trace.fraction > 0.97
end

local function ForceShow(pawn)
    if not pawn or not pawn:IsAlive() then return false end
    if pawn:GetPropBool("m_bSpotted") then return true end
    if pawn:GetPropInt("m_iHealth") < 30 then return true end

    local localPlayer = entities.GetLocalPlayer()
    if localPlayer and localPlayer:IsAlive() then
        local eyes = localPlayer:GetAbsOrigin() + localPlayer:GetPropVector("m_vecViewOffset")
        local head = pawn:GetHitboxPosition(0)
        return head and IsVisible(eyes, head, localPlayer)
    end
    return false
end

-- 声音数据存储
local soundList = {}

-- 注册声音事件
client.AllowListener("player_sound")
callbacks.Register("FireGameEvent", function(event)
    if event:GetName() ~= "player_sound" or not enableSoundESP:GetValue() then return end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    local index = event:GetInt("userid") + 1
    local controller = entities.GetByIndex(index)
    if not controller or controller:GetClass() ~= "CCSPlayerController" then return end

    local pawn = controller:GetPropEntity("m_hPawn")
    if not pawn or not pawn:IsAlive() or pawn:GetIndex() == localPlayer:GetIndex() then return end

    local isEnemy = AreEnemies(localPlayer:GetTeamNumber(), pawn:GetTeamNumber())
    if (isEnemy and not showEnemy:GetValue()) or (not isEnemy and not showFriendly:GetValue()) then return end

    local dist = (localPlayer:GetAbsOrigin() - pawn:GetAbsOrigin()):Length()
    if onlyHearable:GetValue() and dist > event:GetInt("radius") then return end

    table.insert(soundList, {
        time = globals.CurTime(),
        pawn = pawn,
        enemy = isEnemy
    })
end)

-- 渲染
callbacks.Register("Draw", function()
    if not enableSoundESP:GetValue() then return end

    local now = globals.CurTime()
    local dur = duration:GetValue()
    local fade = fadeTime:GetValue()
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    -- 处理声音框
    for i = #soundList, 1, -1 do
        local data = soundList[i]
        local pawn = data.pawn
        local elapsed = now - data.time

        if not pawn or not pawn:IsAlive() or elapsed > (dur + fade) then
            table.remove(soundList, i)
        else
            local fadeAlpha = elapsed > dur and 1.0 - ((elapsed - dur) / fade) or 1.0
            local color = data.enemy and { enemyColor:GetValue() } or { friendlyColor:GetValue() }
            local alpha = math.floor(color[4] * fadeAlpha)

            local origin = pawn:GetAbsOrigin()
            local top = origin + pawn:GetMaxs()
            local bottom = origin + pawn:GetMins()
            local x1, y1 = client.WorldToScreen(top)
            local x2, y2 = client.WorldToScreen(bottom)
            if x1 and x2 then
                local left, right = math.min(x1, x2) - 5, math.max(x1, x2) + 5
                local topY, botY = math.min(y1, y2), math.max(y1, y2)

                draw.Color(color[1], color[2], color[3], alpha)
                draw.OutlinedRect(left, topY, right, botY)

               
        -- Snap Line：按距离分级（近红色，远黄色，不显示超远）
        if data.enemy and snapline:GetValue() then
            local sx, sy = draw.GetScreenSize()
            local dist = (origin - localPlayer:GetAbsOrigin()):Length()
            
            -- 设置不同距离的分级
            local closeDist = 1000    -- 近距离，红色
            local mediumDist = 2000  -- 中等距离，黄色
        
            local r, g, b = 0, 0, 0
            local alphaSnap = 250
        
            if dist <= closeDist then
                -- 近距离（红色）
                r, g, b = 255, 0, 0
            elseif dist <= mediumDist then
                -- 中等距离（黄色）
                r, g, b = 255, 255, 0
            else
                -- 远距离，不显示
                return
            end
        
            draw.Color(r, g, b, alphaSnap)
            draw.Line(sx / 2, sy / 2, x1, y1)
        end

                -- Head Highlight
                if highlightHead:GetValue() then
                    local hx, hy = client.WorldToScreen(origin + Vector3(0, 0, pawn:GetMaxs().z - 5))
                    if hx and hy then
                        local hr, hg, hb, ha = headColor:GetValue()
                        draw.Color(hr, hg, hb, math.floor(ha * fadeAlpha * 0.3))
                        draw.FilledCircle(hx, hy, headSize:GetValue() + 5)
                    end
                end

                -- Health Bar
                local hp = pawn:GetPropInt("m_iHealth")
                local hpPct = math.min(hp / 100, 1)
                local barH = (botY - topY) * hpPct
                local barColor = (hpPct < 0.3) and {255, 0, 0} or (hpPct < 0.85) and {255, 255, 0} or {0, 255, 0}

                draw.Color(unpack(barColor))
                draw.FilledRect(left - 6, botY - barH, left - 3, botY)

                draw.Color(255, 255, 255, alpha)
                local tx, ty = client.WorldToScreen(origin + Vector3(0, 0, pawn:GetMaxs().z + 10))
                if tx and ty then draw.Text(tx - 15, ty, tostring(hp) .. " HP") end
            end
        end
    end

    -- 强制显示（低血量、雷达、视野中）
    local players = entities.FindByClass("CCSPlayer")
    for _, p in pairs(players) do
        if p:IsAlive() and p:GetIndex() ~= localPlayer:GetIndex() then
            local isEnemy = AreEnemies(localPlayer:GetTeamNumber(), p:GetTeamNumber())
            if (isEnemy and showEnemy:GetValue()) or (not isEnemy and showFriendly:GetValue()) then
                if ForceShow(p) then
                    table.insert(soundList, {
                        time = now - 0.01,
                        pawn = p,
                        enemy = isEnemy
                    })
                end
            end
        end
    end

    -- Dot Crosshair
    if dotEnabled:GetValue() and localPlayer:GetWeaponType() == 5 then
        local x, y = draw.GetScreenSize()
        draw.Color(dotColor:GetValue())
        draw.FilledCircle(math.floor(x / 2), math.floor(y / 2), dotSize:GetValue())
    end
end)
