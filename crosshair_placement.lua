-- 创建 Tab 和 Groupbox
local tabCrosshair = gui.Tab(gui.Reference("Visuals"), "crosshair_tab", "Crosshair Line")
local groupCrosshair = gui.Groupbox(tabCrosshair, "Crosshair Line Settings", 15, 15, 300, 0)

local crosshairEnabled = gui.Checkbox(groupCrosshair, "crosshair_show", "Show Crosshair Line", true)
local crosshairLength = gui.Slider(groupCrosshair, "crosshair_length", "Line Length", 2500, 10, 5000)
local crosshairThickness = gui.Slider(groupCrosshair, "crosshair_thickness", "Line Thickness", 25, 1, 80)

local showAng = gui.Checkbox(groupCrosshair, "crosshair_showang", "Use Pitch to Color Line", true)

-- 三阶段角度阈值
local stage1Threshold = gui.Slider(groupCrosshair, "crosshair_stage1_thresh", "Stage 1 Max (°)", 0.5, 0.5, 10)
local stage2Threshold = gui.Slider(groupCrosshair, "crosshair_stage2_thresh", "Stage 2 Max (°)", 1.5, 0.5, 20)

-- 三阶段透明度
local alphaStage1 = gui.Slider(groupCrosshair, "crosshair_alpha_stage1", "Stage 1 Alpha", 60, 0, 255)
local alphaStage2 = gui.Slider(groupCrosshair, "crosshair_alpha_stage2", "Stage 2 Alpha", 25, 0, 255)
local alphaStage3 = gui.Slider(groupCrosshair, "crosshair_alpha_stage3", "Stage 3 Alpha", 0, 0, 0)

local showPitch = gui.Checkbox(groupCrosshair, "crosshair_showpitch", "Show Pitch Value", false)

callbacks.Register("Draw", function()
    if not crosshairEnabled:GetValue() then return end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer or not localPlayer:IsAlive() then return end

    local screenW, screenH = draw.GetScreenSize()
    local centerX = math.floor(screenW / 2)
    local centerY = math.floor(screenH / 2)
    local lineLength = crosshairLength:GetValue()
    local thickness = crosshairThickness:GetValue()

    local ang = 0
    if showAng:GetValue() or showPitch:GetValue() then
        local viewAngles = engine.GetViewAngles()
        ang = viewAngles.x or 0
    end

    local absAng = math.abs(ang)

    -- 阶段阈值
    local stage1 = stage1Threshold:GetValue()
    local stage2 = stage2Threshold:GetValue()

    local r, g, b, a = 0, 255, 0, 0 -- 绿色，alpha 默认 0

    -- 三阶段判定
    if absAng <= stage1 then
        a = alphaStage1:GetValue() -- Stage 1
    elseif absAng <= stage2 then
        a = alphaStage2:GetValue() -- Stage 2
    else
        a = alphaStage3:GetValue() -- Stage 3
    end

    draw.Color(r, g, b, a)
    local x1 = centerX - math.floor(lineLength / 2)
    local y1 = centerY - math.floor(thickness / 2)
    local x2 = centerX + math.floor(lineLength / 2)
    local y2 = centerY + math.floor(thickness / 2)
    draw.FilledRect(x1, y1, x2, y2)

    if showPitch:GetValue() then
        draw.Color(255, 255, 255, 255)
        draw.Text(centerX - 30, centerY + 20 + thickness, string.format("Pitch: %.2f", ang))
    end
end)
