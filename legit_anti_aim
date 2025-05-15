-- Legit Anti-Aim 综合脚本 for Aimware V5，Visuals下，Slow Walk AA 默认关闭

local tab = gui.Tab(gui.Reference("Visuals"), "legit_aa_tab", "Legit Anti-Aim")
local group = gui.Groupbox(tab, "Legit Anti-Aim Options", 15, 15, 300, 0)

local master = gui.Checkbox(group, "legitaa_enable", "Enable Legit Anti-Aim", false)
local desync = gui.Checkbox(group, "legitaa_desync", "Small Desync (Yaw Offset)", true)
local jitter = gui.Checkbox(group, "legitaa_jitter", "Micro Jitter", true)
local jitter_range = gui.Slider(group, "legitaa_jitter_range", "Jitter Range (°)", 10, 1, 30)
local jitter_speed = gui.Slider(group, "legitaa_jitter_speed", "Jitter Speed (ms)", 150, 50, 400)
local slowwalk = gui.Checkbox(group, "legitaa_slowwalk", "Slow Walk AA", false)  -- 默认关闭
local onshot = gui.Checkbox(group, "legitaa_onshot", "On-shot Desync", true)
local onshot_range = gui.Slider(group, "legitaa_onshot_range", "On-shot Yaw (°)", 30, 10, 60)

-- 状态变量
local last_jitter = 0
local jitter_side = true
local onshot_tick = 0
local shot_fired = false

-- 监听射击
callbacks.Register("CreateMove", function(cmd)
    if not master:GetValue() then return end

    -- On-shot Desync
    if onshot:GetValue() then
        if bit.band(cmd.buttons, IN_ATTACK) ~= 0 and not shot_fired then
            onshot_tick = globals.TickCount()
            shot_fired = true
        elseif bit.band(cmd.buttons, IN_ATTACK) == 0 then
            shot_fired = false
        end
    end
end)

callbacks.Register("Draw", function()
    if not master:GetValue() then return end

    -- 基础设置
    gui.SetValue("rbot.antiaim.base", 0)
    gui.SetValue("rbot.antiaim.advanced.pitch", 0)
    gui.SetValue("rbot.antiaim.advanced.autodir.edges", false)
    gui.SetValue("rbot.antiaim.advanced.autodir.targets", false)

    -- Slow Walk时AA（默认关闭，只有手动开启才会生效）
    if slowwalk:GetValue() and gui.GetValue("misc.fakelag.enable") then
        local slowkey = gui.GetValue("misc.fakelag.slowkey")
        if slowkey ~= 0 and input.IsButtonDown(slowkey) then
            gui.SetValue("rbot.antiaim.base", 0)
            gui.SetValue("rbot.antiaim.advanced.pitch", 0)
        end
    end

    -- 小幅度Desync
    if desync:GetValue() then
        gui.SetValue("rbot.antiaim.advanced.bodyyaw", true)
        gui.SetValue("rbot.antiaim.advanced.bodyyaw.freestanding", false)
        gui.SetValue("rbot.antiaim.advanced.bodyyaw.offset", 25) -- 25°小幅度
    else
        gui.SetValue("rbot.antiaim.advanced.bodyyaw", false)
    end

    -- 微Jitter
    if jitter:GetValue() then
        local now = globals.CurTime() * 1000
        if now - last_jitter > jitter_speed:GetValue() then
            jitter_side = not jitter_side
            last_jitter = now
        end
        local yaw = jitter_side and jitter_range:GetValue() or -jitter_range:GetValue()
        gui.SetValue("rbot.antiaim.base", yaw)
    else
        gui.SetValue("rbot.antiaim.base", 0)
    end

    -- On-shot Desync
    if onshot:GetValue() and onshot_tick > 0 then
        if globals.TickCount() - onshot_tick < 8 then
            local side = math.random(0,1) == 1 and 1 or -1
            gui.SetValue("rbot.antiaim.base", side * onshot_range:GetValue())
        end
    end
end)
