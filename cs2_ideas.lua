-- Sound ESP Plus 优化版（含legit触发：开枪、换弹、开镜、安包/拆包、被击中、被闪/HE/燃烧等）

-- 创建 UI
local tab = gui.Tab(gui.Reference("Visuals"), "sound_esp_plus", "Sound ESP Plus")
local groupSound = gui.Groupbox(tab, "Sound ESP", 15, 15, 300, 0)
local groupCrosshair = gui.Groupbox(tab, "Dot Crosshair", 335, 15, 300, 0)

local enableSoundESP = gui.Checkbox(groupSound, "soundesp_enable", "Enable Sound ESP", true)
local onlyHearable = gui.Checkbox(groupSound, "soundesp_hear", "Only Hearable", true)
local showEnemy = gui.Checkbox(groupSound, "soundesp_enemy", "Show Enemy", true)
local enemyColor = gui.ColorPicker(showEnemy, "enemy_color", "Enemy Color", 0, 250, 0, 255)
local showFriendly = gui.Checkbox(groupSound, "soundesp_friendly", "Show Friendly", false)
local friendlyColor = gui.ColorPicker(showFriendly, "friend_color", "Friendly Color", 0, 255, 255, 255)
local snapline = gui.Checkbox(groupSound, "soundesp_snapline", "Snap Line (Enemy Only)", true)
local highlightHead = gui.Checkbox(groupSound, "soundesp_head", "Head Highlight", true)
local headColor = gui.ColorPicker(groupSound, "head_color", "Head Color", 255, 255, 0, 255)
local headSize = gui.Slider(groupSound, "head_size", "Head Highlight Size", 5, 2, 10)
local duration = gui.Slider(groupSound, "soundesp_duration", "Box Duration", 2.0, 0.1, 5.0, 0.1)
local fadeTime = gui.Slider(groupSound, "soundesp_fade", "Fade Time", 3.0, 0.1, 5.0, 0.1)

local dotEnabled = gui.Checkbox(groupCrosshair, "dot_enable", "Enable Dot Crosshair", true)
local dotColor = gui.ColorPicker(groupCrosshair, "dot_color", "Dot Color", 0, 255, 0, 255)
local dotSize = gui.Slider(groupCrosshair, "dot_size", "Dot Size", 2, 1, 10)

local function AreEnemies(t1, t2)
    return client.GetConVar("mp_teammates_are_enemies") or (t1 ~= t2 and t1 > 1 and t2 > 1)
end

local function IsVisible(from, to, skip)
    local trace = engine.TraceLine(from, to, MASK_VISIBLE, skip and skip:GetIndex() or 0)
    return trace.fraction > 0.97
end

-- 检查pawn是否被本地玩家或队友spotbymask
local function IsSpottedByAnyTeammate(pawn)
    local localPlayer = entities.GetLocalPlayer()
    if not pawn or not localPlayer then return false end
    local team = localPlayer:GetTeamNumber()
    local players = entities.FindByClass("CCSPlayer")
    local spottedMask = pawn:GetProp("m_entitySpottedState.m_bSpottedByMask")
    if not spottedMask or type(spottedMask) ~= "table" then return false end
    for _, teammate in ipairs(players) do
        if teammate:IsAlive() and teammate:GetTeamNumber() == team then
            local idx = teammate:GetIndex() - 1
            local maskIndex = math.floor(idx / 32) + 1
            local bitPos = idx % 32
            if bit.band(spottedMask[maskIndex], bit.lshift(1, bitPos)) ~= 0 then
                return true
            end
        end
    end
    return false
end

local activePawns = {}

-- legit事件表
local legit_events = {
    -- ★★★★★ 最高legit推荐
    weapon_fire = true,            -- 开枪
    weapon_reload = true,          -- 换弹
    weapon_zoom = true,            -- 开镜
    player_hurt = true,            -- 被击中
    inferno_startburn = true,      -- 燃烧弹点燃
    bomb_beginplant = true,        -- 安包
    bomb_begindefuse = true,       -- 拆包

    -- ★★★★ 适度legit
    player_footstep = true,        -- 脚步声
    player_jump = true,            -- 跳跃
    player_land = true,            -- 落地
    player_falldamage = true,      -- 摔伤
    item_pickup = true,            -- 捡起武器/道具
    item_drop = true,              -- 丢弃武器/道具
    water_enter = true,            -- 进入水体
    water_leave = true,            -- 离开水体
    hostage_pickup = true,         -- 挟持人质
    hostage_rescued = true,        -- 救援人质
    door_moving = true,            -- 门移动

    -- ★ 低legit性（建议注释留作参考）
    -- player_blind = true,           -- 被闪（不推荐，听觉难判断）
    -- hegrenade_detonate = true,     -- HE（不推荐，声音不明显）
    -- flashbang_detonate = true,     -- 闪光（不推荐，声音不明显）
    -- smokegrenade_detonate = true,  -- 烟雾（不推荐，声音不明显）
}

-- 注册所有事件
for eventName in pairs(legit_events) do
    client.AllowListener(eventName)
end
client.AllowListener("player_sound")

local function tryAddPawnFromEvent(event, isHurt)
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    local index
    if isHurt then
        index = event:GetInt("attacker") + 1
    else
        index = event:GetInt("userid") + 1
    end

    local controller = entities.GetByIndex(index)
    if not controller or controller:GetClass() ~= "CCSPlayerController" then return end
    local pawn = controller:GetPropEntity("m_hPawn")
    if not pawn or not pawn:IsAlive() or pawn:GetIndex() == localPlayer:GetIndex() then return end

    local isEnemy = AreEnemies(localPlayer:GetTeamNumber(), pawn:GetTeamNumber())
    if (isEnemy and not showEnemy:GetValue()) or (not isEnemy and not showFriendly:GetValue()) then return end

    activePawns[pawn:GetIndex()] = { time = globals.CurTime(), pawn = pawn, enemy = isEnemy }
end

callbacks.Register("FireGameEvent", function(event)
    local name = event:GetName()
    if not enableSoundESP:GetValue() then return end

    if name == "player_sound" then
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

        activePawns[pawn:GetIndex()] = { time = globals.CurTime(), pawn = pawn, enemy = isEnemy }
        return
    end

    if legit_events[name] then
        tryAddPawnFromEvent(event, name == "player_hurt")
    end
end)

callbacks.Register("Draw", function()
    if not enableSoundESP:GetValue() then return end
    local now = globals.CurTime()
    local dur, fade = duration:GetValue(), fadeTime:GetValue()
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end

    local lpPos = localPlayer:GetAbsOrigin()
    local screenW, screenH = draw.GetScreenSize()

    -- spotbymask: 让所有被自己或队友spot的敌人也能显示
    local team = localPlayer:GetTeamNumber()
    local players = entities.FindByClass("CCSPlayer")
    for _, p in ipairs(players) do
        if p:IsAlive() and AreEnemies(team, p:GetTeamNumber()) then
            if IsSpottedByAnyTeammate(p) then
                local id = p:GetIndex()
                if not activePawns[id] then
                    activePawns[id] = { time = now, pawn = p, enemy = true }
                end
            end
        end
    end

    -- 清理过期
    for id, data in pairs(activePawns) do
        local elapsed = now - data.time
        if not data.pawn or not data.pawn:IsAlive() or elapsed > (dur + fade) then
            activePawns[id] = nil
        end
    end

    for id, data in pairs(activePawns) do
        local pawn = data.pawn
        local elapsed = now - data.time
        if not pawn then goto continue end

        local origin = pawn:GetAbsOrigin()
        local mins, maxs = pawn:GetMins(), pawn:GetMaxs()
        local top3D, bot3D = origin + maxs, origin + mins
        local x1, y1 = client.WorldToScreen(top3D)
        local x2, y2 = client.WorldToScreen(bot3D)
        if not (x1 and x2) then goto continue end

        local fadeAlpha = elapsed > dur and 1.0 - ((elapsed - dur) / fade) or 1.0
        local r, g, b, a
        if data.enemy then r, g, b, a = enemyColor:GetValue() else r, g, b, a = friendlyColor:GetValue() end
        local alpha = math.floor(a * fadeAlpha)

        local left, right = math.min(x1, x2) - 5, math.max(x1, x2) + 5
        local topY, botY = math.min(y1, y2), math.max(y1, y2)

        draw.Color(r, g, b, alpha)
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
            local hx, hy = client.WorldToScreen(origin + Vector3(0, 0, maxs.z - 5))
            if hx and hy then
                local hr, hg, hb, ha = headColor:GetValue()
                draw.Color(hr, hg, hb, math.floor(ha * fadeAlpha * 0.3))
                draw.FilledCircle(hx, hy, headSize:GetValue() + 5)
            end
        end

        -- Health bar
        local hp = pawn:GetPropInt("m_iHealth")
        local hpPct = math.max(0, math.min(hp / 100, 1))
        local barH = (botY - topY) * hpPct
        local barColor = (hpPct < 0.3) and {255, 0, 0} or (hpPct < 0.85) and {255, 255, 0} or {0, 255, 0}
        draw.Color(unpack(barColor))
        draw.FilledRect(left - 6, botY - barH, left - 3, botY)

        -- HP text
        local tx, ty = client.WorldToScreen(origin + Vector3(0, 0, maxs.z + 10))
        if tx and ty then
            draw.Color(255, 255, 255, alpha)
            draw.Text(tx - 15, ty, tostring(hp) .. " HP")
        end

        ::continue::
    end

    -- Dot Crosshair
    if dotEnabled:GetValue() and localPlayer:GetWeaponType() == 5 then
        draw.Color(dotColor:GetValue())
        draw.FilledCircle(math.floor(screenW / 2), math.floor(screenH / 2), dotSize:GetValue())
    end
end)
