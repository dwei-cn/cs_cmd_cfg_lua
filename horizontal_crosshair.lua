-- 创建 Tab 和 Groupbox
local tabCrosshair = gui.Tab(gui.Reference("Visuals"), "crosshair_tab", "Crosshair Line")
local groupCrosshair = gui.Groupbox(tabCrosshair, "Crosshair Line", 15, 15, 300, 0)

local crosshairEnabled = gui.Checkbox(groupCrosshair, "crosshair_show", "Show Crosshair Line", true)
local crosshairLength = gui.Slider(groupCrosshair, "crosshair_length", "Line Length", 1000, 10, 2000)
local crosshairThickness = gui.Slider(groupCrosshair, "crosshair_thickness", "Line Thickness", 10, 1, 20)
local showAng = gui.Checkbox(groupCrosshair, "crosshair_showang", "Use Angle to Color Line", true)
local crosshairAlpha = gui.Slider(groupCrosshair, "crosshair_alpha", "Line Alpha", 80, 0, 255)
local showPitch = gui.Checkbox(groupCrosshair, "crosshair_showpitch", "Show Pitch Value", false)

-- 新增：控制是否显示黄色和红色
local showYellowRed = gui.Checkbox(groupCrosshair, "crosshair_showyellowred", "Show Yellow/Red Color", false)

-- 自定义阈值和颜色
local angThreshold1 = gui.Slider(groupCrosshair, "ang_threshold1", "Green/Yellow Threshold", 1.5, 0.5, 30)
local angThreshold2 = gui.Slider(groupCrosshair, "ang_threshold2", "Yellow/Red Threshold", 15, 1, 89)
local angGreen = gui.ColorPicker(groupCrosshair, "ang_green", "Green Color", 0, 255, 0, 255)
local angYellow = gui.ColorPicker(groupCrosshair, "ang_yellow", "Yellow Color", 255, 255, 0, 255)
local angRed = gui.ColorPicker(groupCrosshair, "ang_red", "Red Color", 255, 0, 0, 255)

callbacks.Register("Draw", function()
    if not crosshairEnabled:GetValue() then return end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer or not localPlayer:IsAlive() then return end

    local screenW, screenH = draw.GetScreenSize()
    local centerX = math.floor(screenW / 2)
    local centerY = math.floor(screenH / 2)
    local lineLength = crosshairLength:GetValue()
    local thickness = crosshairThickness:GetValue()
    local alpha = crosshairAlpha:GetValue()

    -- 获取视角角度（这里用pitch，也可以改为yaw）
    local ang = 0
    if showAng:GetValue() or showPitch:GetValue() then
        local viewAngles = engine.GetViewAngles()
        ang = viewAngles.x or 0
    end
    local absAng = math.abs(ang)

    local threshold1 = angThreshold1:GetValue()
    local threshold2 = angThreshold2:GetValue()

    local r, g, b = 255, 255, 255 -- 默认白色

    if absAng < threshold1 then
        r, g, b = angGreen:GetValue()
    elseif showYellowRed:GetValue() then
        if absAng < threshold2 then
            r, g, b = angYellow:GetValue()
        else
            r, g, b = angRed:GetValue()
        end
    else
        -- 不显示线
        return
    end

    -- 画水平线
    draw.Color(r, g, b, alpha)
    local x1 = centerX - math.floor(lineLength / 2)
    local y1 = centerY - math.floor(thickness / 2)
    local x2 = centerX + math.floor(lineLength / 2)
    local y2 = centerY + math.floor(thickness / 2)
    draw.FilledRect(x1, y1, x2, y2)

    -- 显示 pitch 数值
    if showPitch:GetValue() then
        draw.Color(255, 255, 255, 255)
        draw.Text(centerX - 20, centerY + 20 + thickness, string.format("Pitch: %.2f", ang))
    end
end)
