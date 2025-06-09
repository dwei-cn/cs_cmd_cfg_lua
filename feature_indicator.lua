-- Indicator渲染函数
local renderer_indicator = (function()
    local font = {}
    for scale, size in pairs {[1] = 29, [1.25] = 37, [1.5] = 44, [1.75] = 51, [2] = 59} do
        font[scale] = {draw.CreateFont("Segoe UI Bold", size), size}
    end

    local background = draw.CreateTexture(common.RasterizeSVG
        [[
            <svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="leftToRightGradient" x1="50%" y1="0%" x2="0%" y2="0%">
                <stop offset="0%" style="stop-color:rgb(255,0,0);stop-opacity:1" />
                <stop offset="100%" style="stop-color:rgb(255,255,255);stop-opacity:0" />
                </linearGradient>
            </defs>
            <rect width="100" height="100" fill="url(#leftToRightGradient)" />
            </svg>
        ]]
    )

    local indicators = {}
    callbacks.Register("Draw", function() indicators = {} end)

    return function(r, g, b, a, ...)
        local dpi = (gui.GetValue "adv.dpi" + 3) * 0.25
        local _, sh = draw.GetScreenSize()
        local y = sh - 350 * dpi

        draw.SetFont(font[dpi][1])
        local text = table.concat {...}
        local fs = font[dpi][2]
        local tw, th = draw.GetTextSize(text)

        local index = #indicators
        local offset = (fs + 12 * dpi) * index
        table.insert(indicators, index)

        draw.SetTexture(background)
        draw.Color(0, 0, 0, 40)
        draw.FilledRect(math.floor(fs + (tw * 0.5) - tw * 0.8), y - offset, math.floor(fs + (tw * 0.5)), y - offset + fs + 4 * dpi)
        draw.FilledRect(math.floor(fs + (tw * 0.5) + tw * 0.8), y - offset, math.floor(fs + (tw * 0.5)), y - offset + fs + 4 * dpi)
        draw.SetTexture(nil)

        draw.Color(r, g, b, a)
        draw.TextShadow(math.floor(fs), math.floor(y - offset + 2 * dpi + (fs - th) * 0.5), text)

        return math.floor(y - offset)
    end
end)()

xpcall(function()
    -- 功能指示器菜单
    local feature_indicators_reference = (function(reference, name, items)
        local ref = gui.Multibox(reference, name)
        for _, value in ipairs(items) do
            gui.Checkbox(ref, string.format("%s.%s", name:lower(), value:lower()), value, true)
        end
        return ref
    end)(gui.Reference("Visuals", "Other", "Extra"), "Feature indicators", {
        "Aiming type", "Min damage", "Rapid fire", "At edges", "At targets", "Legitbot toggle", "Scoped"
    })

    -- 颜色设置
    local aiming_type_enable_reference = feature_indicators_reference:Reference "Aiming type"
    local aiming_legit_color_reference = gui.ColorPicker(aiming_type_enable_reference, "legit", "Legit color", 255, 255, 255, 255)
    local aiming_rage_color_reference = gui.ColorPicker(aiming_type_enable_reference, "rage", "Rage color", 255, 255, 255, 255)

    local min_damage_enable_reference = feature_indicators_reference:Reference "Min damage"
    local min_damage_color_reference = gui.ColorPicker(min_damage_enable_reference, "clr", "Color", 255, 255, 255, 255)

    local rapid_fire_enable_reference = feature_indicators_reference:Reference "Rapid fire"
    local rapid_fire_color_reference = gui.ColorPicker(rapid_fire_enable_reference, "clr", "Color", 255, 215, 128, 255)

    local at_edges_enable_reference = feature_indicators_reference:Reference "At edges"
    local at_edges_color_reference = gui.ColorPicker(at_edges_enable_reference, "clr", "Color", 255, 255, 255, 255)

    local at_targets_enable_reference = feature_indicators_reference:Reference "At targets"
    local at_targets_color_reference = gui.ColorPicker(at_targets_enable_reference, "clr", "Color", 255, 255, 255, 255)

    local legitbot_toggle_enable_reference = feature_indicators_reference:Reference "Legitbot toggle"
    local legitbot_toggle_on_color = gui.ColorPicker(legitbot_toggle_enable_reference, "on", "Legit ON color", 0, 200, 255, 255)
    local legitbot_toggle_off_color = gui.ColorPicker(legitbot_toggle_enable_reference, "off", "Legit OFF color", 255, 60, 60, 255)

    -- Scoped indicator菜单和颜色
    local scoped_enable_reference = feature_indicators_reference:Reference "Scoped"
    local scoped_on_color = gui.ColorPicker(scoped_enable_reference, "on", "Scoped ON Color", 120, 200, 255, 255)
    local scoped_off_color = gui.ColorPicker(scoped_enable_reference, "off", "Scoped OFF Color", 255, 120, 120, 255)

    -- Legitbot toggle indicator
    local function show_legitbot_toggle()
        if not legitbot_toggle_enable_reference:GetValue() then return end
        local legit_master = gui.GetValue("lbot.master")
        local legit_enable = gui.GetValue("lbot.aim.enable")
        if legit_master and legit_enable then
            local r, g, b, a = legitbot_toggle_on_color:GetValue()
            renderer_indicator(r, g, b, a, "LEGIT ON")
        else
            local r, g, b, a = legitbot_toggle_off_color:GetValue()
            renderer_indicator(r, g, b, a, "LEGIT OFF")
        end
    end

    -- Scoped indicator
    local function show_scoped_indicator()
        if not scoped_enable_reference:GetValue() then return end
        local lp = entities.GetLocalPlayer()
        if lp == nil or not lp:IsAlive() then return end
        local is_scoped = lp:GetProp("m_bIsScoped") == 1
        if is_scoped then
            local r, g, b, a = scoped_on_color:GetValue()
            renderer_indicator(r, g, b, a, "SCOPED")
        else
            local r, g, b, a = scoped_off_color:GetValue()
            renderer_indicator(r, g, b, a, "UNSCOPED")
        end
    end

    -- 其他indicator
    local function on_aiming_type()
        if not aiming_type_enable_reference:GetValue() then return end
        if gui.GetValue "lbot.master" and gui.GetValue "lbot.aim.enable" then
            local r, g, b, a = aiming_legit_color_reference:GetValue()
            renderer_indicator(r, g, b, a, "LEGIT")
        end
        if gui.GetValue "rbot.master" then
            local typ = gui.GetValue "rbot.aim.enable"
            if typ == "\"Off\"" then return end
            local r, g, b, a = aiming_rage_color_reference:GetValue()
            renderer_indicator(r, g, b, a, typ == "\"Automatic\"" and "R:Auto" or "R:Press")
        end
    end

    local function on_min_damage()
        if not min_damage_enable_reference:GetValue() then return end
        if gui.GetValue "rbot.master" then
            local weapon = gui.GetValue "rbot.hitscan.accuracy"
            local min_damage = gui.GetValue(string.format("rbot.hitscan.accuracy.%s.mindamage", weapon:gsub('"', ''):lower()))
            local r, g, b, a = min_damage_color_reference:GetValue()
            renderer_indicator(r, g, b, a, min_damage <= 100 and string.format("M:%i", min_damage) or "HP+" .. min_damage - 100)
        end
    end

    local function on_rapid_fire()
        if not rapid_fire_enable_reference:GetValue() then return end
        if gui.GetValue "misc.antiuntrusted" then return end
        if gui.GetValue "rbot.master" and gui.GetValue "rbot.accuracy.attack.rapidfire" then
            local r, g, b, a = rapid_fire_color_reference:GetValue()
            renderer_indicator(r, g, b, a, "RF")
        end
    end

    local function on_at_edges()
        if not at_edges_enable_reference:GetValue() then return end
        if gui.GetValue "rbot.master" and gui.GetValue "rbot.antiaim.condition.autodir.edges" then
            local r, g, b, a = at_edges_color_reference:GetValue()
            renderer_indicator(r, g, b, a, "AE")
        end
    end

    local function on_at_targets()
        if not at_targets_enable_reference:GetValue() then return end
        if gui.GetValue "rbot.master" and gui.GetValue "rbot.antiaim.condition.autodir.targets" then
            local r, g, b, a = at_targets_color_reference:GetValue()
            renderer_indicator(r, g, b, a, "AT")
        end
    end

    callbacks.Register("Draw", function()
        if not gui.GetValue "esp.master" then return end
        show_legitbot_toggle()
        show_scoped_indicator()
        on_aiming_type()
        on_min_damage()
        on_rapid_fire()
        on_at_edges()
        on_at_targets()
    end)
end, print)
