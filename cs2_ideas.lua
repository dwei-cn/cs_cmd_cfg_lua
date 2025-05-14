-- Sound ESP Plus 优化版本

-- 创建 UI
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
local highlightHead = gui.Checkbox(groupSound, "soundesp_head", "Head Highlight", true)
local headColor = gui.ColorPicker(groupSound, "head_color", "Head Color", 255, 255, 0, 255)
local headSize = gui.Slider(groupSound, "head_size", "Head Highlight Size", 5, 2, 10)
local duration = gui.Slider(groupSound, "soundesp_duration", "Box Duration", 2.0, 0.1, 5.0, 0.1)
local fadeTime = gui.Slider(groupSound, "soundesp_fade", "Fade Time", 3.0, 0.1, 5.0, 0.1)

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
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return false end

    -- 雷达上被看到
    local spottedMask = pawn:GetProp("m_entitySpottedState.m_bSpottedByMask")
    if spottedMask and type(spottedMask) == "table" then
        local localIdx = localPlayer:GetIndex() - 1
        local maskIndex = math.floor(localIdx / 32) + 1
        local bitPos = localIdx % 32
        if bit.band(spottedMask[maskIndex], bit.lshift(1, bitPos)) ~= 0 then return true end
    end

    -- 低血量
    if pawn:GetPropInt("m_iHealth") < 30 then return true end

    -- 可视范围
    local eyes = localPlayer:GetAbsOrigin() + localPlayer:GetPropVector("m_vecViewOffset")
    local head = pawn:GetHitboxPosition(0)
    return head and IsVisible(eyes, head, localPlayer)
end

-- 优化后的数据结构：活跃的玩家（包含敌人和友军）
local activePawns = {}

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

    -- 仅保存活跃玩家信息
    local id = pawn:GetIndex()
    activePawns[id] = { time = globals.CurTime(), pawn = pawn, enemy = isEnemy }
end)

-- 绘制 ESP
callbacks.Register("Draw", function()
    if not enableSoundESP:GetValue() then return end
    local now = globals.CurTime()
    local dur, fade = duration:GetValue(), fadeTime:GetValue()
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    local lpPos = localPlayer:GetAbsOrigin()
    local screenW, screenH = draw.GetScreenSize()

    -- 清理过期玩家
    for id, data in pairs(activePawns) do
        local elapsed = now - data.time
        if not data.pawn or not data.pawn:IsAlive() or elapsed > (dur + fade) then
            activePawns[id] = nil
        end
    end

    -- 绘制框框
    for id, data in pairs(activePawns) do
        local pawn = data.pawn
        local elapsed = now - data.time

        if pawn then
            local fadeAlpha = elapsed > dur and 1.0 - ((elapsed - dur) / fade) or 1.0
            local enemyColorR, enemyColorG, enemyColorB, enemyColorA = enemyColor:GetValue()
            local friendlyColorR, friendlyColorG, friendlyColorB, friendlyColorA = friendlyColor:GetValue()
            local color = data.enemy and {enemyColorR, enemyColorG, enemyColorB, enemyColorA} or {friendlyColorR, friendlyColorG, friendlyColorB, friendlyColorA}
            local alpha = math.floor(color[4] * fadeAlpha)

            local origin = pawn:GetAbsOrigin()
            local top, bottom = origin + pawn:GetMaxs(), origin + pawn:GetMins()
            local x1, y1 = client.WorldToScreen(top)
            local x2, y2 = client.WorldToScreen(bottom)

            if x1 and x2 then
                local left, right = math.min(x1, x2) - 5, math.max(x1, x2) + 5
                local topY, botY = math.min(y1, y2), math.max(y1, y2)

                draw.Color(color[1], color[2], color[3], alpha)
                draw.OutlinedRect(left, topY, right, botY)

                -- Snapline
                if data.enemy and snapline:GetValue() then
                    local dist = (origin - lpPos):Length()
                    if dist <= 2500 then
                        draw.Color(255, 0, 0, 250)
                        draw.Line(screenW / 2, screenH / 2, x1, y1)
                    end
                end

                -- Head highlight
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
                local hpPct = math.max(0, math.min(hp / 100, 1))
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

    -- Dot Crosshair
    if dotEnabled:GetValue() and localPlayer:GetWeaponType() == 5 then
        draw.Color(dotColor:GetValue())
        draw.FilledCircle(math.floor(screenW / 2), math.floor(screenH / 2), dotSize:GetValue())
    end
end)
